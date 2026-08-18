import 'package:financeiro_ai/application/providers.dart';
import 'package:financeiro_ai/domain/finance_rules.dart';
import 'package:financeiro_ai/core/category_visuals.dart';
import 'package:financeiro_ai/domain/catalog_drafts.dart';
import 'package:financeiro_ai/domain/merchant_rule.dart';
import 'package:financeiro_ai/domain/models.dart';
import 'package:financeiro_ai/domain/invoice_import.dart';
import 'package:financeiro_ai/domain/review_item.dart';
import 'package:financeiro_ai/domain/shortcut_token.dart';
import 'package:financeiro_ai/domain/transaction_draft.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class SupabaseFinanceRepository implements FinanceRepository {
  SupabaseFinanceRepository(this._client);
  final SupabaseClient _client;
  static const _uuid = Uuid();

  @override
  Future<InvoiceImportPreview> previewInvoiceImport(
    InvoiceImportDocument document,
  ) async {
    final result = await _client.rpc(
      'preview_finora_invoice_import',
      params: {'p_payload': document.payload},
    );
    return InvoiceImportPreview.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }

  @override
  Future<InvoiceImportResult> importInvoice(
    InvoiceImportDocument document,
  ) async {
    final result = await _client.rpc(
      'import_finora_invoice',
      params: {'p_payload': document.payload},
    );
    return InvoiceImportResult.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }

  @override
  Future<void> saveTransaction(TransactionDraft draft) async {
    final errors = draft.validate();
    if (!errors.isEmpty) {
      throw FinanceWriteException(errors.firstMessage!);
    }
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const FinanceWriteException(
        'Entre na sua conta para salvar lançamentos.',
      );
    }

    final card = draft.cardId == null ? null : await _loadCard(draft.cardId!);
    final competence = card == null
        ? DateTime(draft.purchasedAt.year, draft.purchasedAt.month)
        : invoiceCompetence(draft.purchasedAt, card['closing_day'] as int);
    final invoiceId = card == null
        ? null
        : await _ensureInvoice(userId: userId, card: card, month: competence);

    final payload = <String, dynamic>{
      'user_id': userId,
      'purchased_at': draft.purchasedAt.toUtc().toIso8601String(),
      'competence': _isoDate(competence),
      'card_id': draft.cardId,
      'invoice_id': invoiceId,
      'holder_id': card?['holder_id'],
      'merchant_original': draft.merchant.trim(),
      'merchant_normalized': normalizeMerchant(draft.merchant),
      'amount': draft.amount,
      'movement_type': draft.movementType,
      'modality': draft.modality,
      'installment_current': draft.installmentCurrent,
      'installment_total': draft.installmentTotal,
      'category_id': draft.categoryId,
      'status': draft.status.name,
      'notes': draft.notes,
      'source': 'manual',
      'confidence': 'high',
      'reviewed': true,
    };

    try {
      if (draft.isEdit) {
        payload['updated_at'] = DateTime.now().toUtc().toIso8601String();
        await _client.from('transactions').update(payload).eq('id', draft.id!);
      } else {
        // A deliberate manual entry is never a duplicate of another manual
        // entry, so it gets its own key instead of the Shortcut's content hash.
        payload['dedup_key'] = 'manual:${_uuid.v4()}';
        await _client.from('transactions').insert(payload);
      }
    } on PostgrestException catch (error) {
      throw FinanceWriteException(_friendlyWriteError(error));
    }
  }

  @override
  Future<void> deleteTransaction(String id) async {
    try {
      await _client.from('transactions').delete().eq('id', id);
    } on PostgrestException catch (error) {
      throw FinanceWriteException(_friendlyWriteError(error));
    }
  }

  @override
  Future<List<ReviewItem>> loadReviewQueue() async {
    final rows = await _client
        .from('review_queue')
        .select()
        .eq('status', 'pending')
        .order('created_at', ascending: false)
        .limit(500);
    return (rows as List)
        .map((json) => ReviewItem.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> settleReview(String id, {required String status}) async {
    try {
      await _client
          .from('review_queue')
          .update({
            'status': status,
            'resolved_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id);
    } on PostgrestException catch (error) {
      throw FinanceWriteException(_friendlyWriteError(error));
    }
  }

  @override
  Future<void> setInvoicePaid(String invoiceId, {required bool paid}) async {
    try {
      await _client
          .from('invoices')
          .update({
            // A settled invoice keeps its own status rather than falling back
            // to the derived "overdue" the interface computes from the due date.
            'status': paid ? 'paid' : 'closed',
            'paid_at': paid ? DateTime.now().toUtc().toIso8601String() : null,
          })
          .eq('id', invoiceId);
    } on PostgrestException catch (error) {
      throw FinanceWriteException(_friendlyWriteError(error));
    }
  }

  @override
  Future<void> saveCard(CardDraft draft) async {
    final errors = draft.validate();
    if (!errors.isEmpty) throw FinanceWriteException(errors.firstMessage!);
    final userId = _requireUser();
    final payload = {
      'user_id': userId,
      'name': draft.name.trim(),
      'bank': draft.bank.trim(),
      'last_four': draft.lastFour.trim(),
      'closing_day': draft.closingDay,
      'due_day': draft.dueDay,
      'credit_limit': draft.limit,
      'holder_name': draft.holder.trim().isEmpty ? null : draft.holder.trim(),
      'include_in_totals': draft.includeInTotals,
      'active': draft.active,
    };
    try {
      if (draft.isEdit) {
        await _client.from('cards').update(payload).eq('id', draft.id!);
      } else {
        await _client.from('cards').insert(payload);
      }
    } on PostgrestException catch (error) {
      throw FinanceWriteException(_friendlyCardError(error));
    }
  }

  @override
  Future<void> setCardActive(String id, {required bool active}) async {
    try {
      await _client.from('cards').update({'active': active}).eq('id', id);
    } on PostgrestException catch (error) {
      throw FinanceWriteException(_friendlyWriteError(error));
    }
  }

  @override
  Future<void> saveCategory(CategoryDraft draft) async {
    final errors = draft.validate();
    if (!errors.isEmpty) throw FinanceWriteException(errors.firstMessage!);
    final userId = _requireUser();
    final payload = {
      'user_id': userId,
      'name': draft.name.trim(),
      'color': categoryColorHex(draft.color),
      'icon': draft.iconName,
      'monthly_budget': draft.monthlyBudget,
      'sort_order': draft.sortOrder,
      'active': draft.active,
    };
    try {
      if (draft.isEdit) {
        await _client.from('categories').update(payload).eq('id', draft.id!);
      } else {
        await _client.from('categories').insert(payload);
      }
    } on PostgrestException catch (error) {
      throw FinanceWriteException(_friendlyCategoryError(error));
    }
  }

  @override
  Future<void> setCategoryActive(String id, {required bool active}) async {
    try {
      await _client.from('categories').update({'active': active}).eq('id', id);
    } on PostgrestException catch (error) {
      throw FinanceWriteException(_friendlyWriteError(error));
    }
  }

  String _requireUser() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const FinanceWriteException('Entre na sua conta para salvar.');
    }
    return userId;
  }

  String _friendlyCardError(PostgrestException error) {
    final text = '${error.code} ${error.message}';
    if (text.contains('cards_user_id_last_four_key')) {
      return 'Já existe um cartão com esse final.';
    }
    if (text.contains('last_four_check')) {
      return 'O final precisa ter exatamente 4 dígitos.';
    }
    if (text.contains('closing_day_check') || text.contains('due_day_check')) {
      return 'Os dias de fechamento e vencimento vão de 1 a 31.';
    }
    return _friendlyWriteError(error);
  }

  String _friendlyCategoryError(PostgrestException error) =>
      '${error.code} ${error.message}'.contains('categories_user_id_name_key')
      ? 'Já existe uma categoria com esse nome.'
      : _friendlyWriteError(error);

  @override
  Future<List<ShortcutToken>> loadShortcutTokens() async {
    final rows = await _client
        .from('shortcut_tokens')
        .select()
        .order('created_at', ascending: false);
    return (rows as List)
        .map((json) => ShortcutToken.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<IssuedShortcutToken> createShortcutToken(String name) async {
    final errors = validateTokenName(name);
    if (!errors.isEmpty) throw FinanceWriteException(errors.firstMessage!);
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const FinanceWriteException(
        'Entre na sua conta para gerar tokens.',
      );
    }
    final secret = generateShortcutSecret();
    try {
      final row = await _client
          .from('shortcut_tokens')
          .insert({
            'user_id': userId,
            'name': name.trim(),
            // Only the hash is persisted; the secret leaves in memory only.
            'token_hash': hashShortcutSecret(secret),
          })
          .select()
          .single();
      return IssuedShortcutToken(
        secret: secret,
        token: ShortcutToken.fromJson(row),
      );
    } on PostgrestException catch (error) {
      throw FinanceWriteException(_friendlyWriteError(error));
    }
  }

  @override
  Future<void> revokeShortcutToken(String id) async {
    try {
      await _client
          .from('shortcut_tokens')
          .update({'revoked_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', id);
    } on PostgrestException catch (error) {
      throw FinanceWriteException(_friendlyWriteError(error));
    }
  }

  @override
  Future<List<MerchantRule>> loadMerchantRules() async {
    final rows = await _client
        .from('merchant_rules')
        .select('*, categories(name)')
        .order('priority')
        .limit(500);
    return (rows as List)
        .map((json) => MerchantRule.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> saveMerchantRule(MerchantRuleDraft draft) async {
    final errors = draft.validate();
    if (!errors.isEmpty) {
      throw FinanceWriteException(errors.firstMessage!);
    }
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const FinanceWriteException(
        'Entre na sua conta para salvar regras.',
      );
    }
    final payload = {
      'user_id': userId,
      'pattern': draft.pattern.trim(),
      'category_id': draft.categoryId,
      'subcategory': draft.subcategory,
      'priority': draft.priority,
      'active': draft.active,
    };
    try {
      if (draft.isEdit) {
        await _client
            .from('merchant_rules')
            .update(payload)
            .eq('id', draft.id!);
      } else {
        await _client.from('merchant_rules').insert(payload);
      }
    } on PostgrestException catch (error) {
      throw FinanceWriteException(_friendlyRuleError(error));
    }
  }

  @override
  Future<void> deleteMerchantRule(String id) async {
    try {
      await _client.from('merchant_rules').delete().eq('id', id);
    } on PostgrestException catch (error) {
      throw FinanceWriteException(_friendlyWriteError(error));
    }
  }

  String _friendlyRuleError(PostgrestException error) {
    if ('${error.code} ${error.message}'.contains(
      'merchant_rules_user_id_pattern_key',
    )) {
      return 'Já existe uma regra para esse trecho.';
    }
    return _friendlyWriteError(error);
  }

  Future<Map<String, dynamic>> _loadCard(String cardId) async {
    final card = await _client
        .from('cards')
        .select('id, closing_day, due_day, holder_id')
        .eq('id', cardId)
        .maybeSingle();
    if (card == null) {
      throw const FinanceWriteException(
        'O cartão escolhido não está mais disponível.',
      );
    }
    return card;
  }

  /// Returns the invoice for the competence, creating it only when missing.
  /// Upserting here would reset `status` to open on an invoice already closed
  /// or paid, so an existing invoice is reused untouched.
  Future<String> _ensureInvoice({
    required String userId,
    required Map<String, dynamic> card,
    required DateTime month,
  }) async {
    final referenceMonth = _isoDate(month);
    final existing = await _client
        .from('invoices')
        .select('id')
        .eq('card_id', card['id'] as String)
        .eq('reference_month', referenceMonth)
        .maybeSingle();
    if (existing != null) return existing['id'] as String;

    final created = await _client
        .from('invoices')
        .insert({
          'user_id': userId,
          'card_id': card['id'],
          'reference_month': referenceMonth,
          'due_date': _isoDate(
            DateTime(month.year, month.month, card['due_day'] as int),
          ),
          'status': 'open',
        })
        .select('id')
        .single();
    return created['id'] as String;
  }

  String _friendlyWriteError(PostgrestException error) {
    final text = '${error.code} ${error.message}';
    if (text.contains('transactions_user_id_dedup_key_key')) {
      return 'Este lançamento já existe no seu histórico.';
    }
    if (text.contains('amount_check')) {
      return 'O valor precisa ser maior que zero.';
    }
    if (error.code == '42501' || text.contains('row-level security')) {
      return 'Sua sessão expirou. Entre novamente para salvar.';
    }
    return 'Não foi possível salvar o lançamento. Tente novamente.';
  }

  static String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  @override
  Future<FinanceSnapshot> loadSnapshot() async {
    final results = await Future.wait([
      _client
          .from('transactions')
          .select('*, categories(name), cards(last_four)')
          .order('purchased_at', ascending: false)
          .limit(2000),
      _client
          .from('categories')
          .select()
          .eq('active', true)
          .order('sort_order'),
      _client.from('cards').select().eq('active', true).order('name'),
      _client
          .from('invoices')
          .select()
          .order('reference_month', ascending: false)
          .limit(12),
      _client.from('goals').select().eq('active', true).order('created_at'),
      _client.from('review_queue').select('id').eq('status', 'pending'),
      _client.from('profiles').select('currency').limit(1).maybeSingle(),
    ]);
    // The stored colour and icon are read now. They were written by the
    // schema's defaults from the first migration and ignored ever since: the
    // colour came from list position, so it changed whenever a category was
    // added, and every category drew the same icon.
    final categories = (results[1] as List).map((row) {
      final json = row as Map<String, dynamic>;
      return FinanceCategory(
        id: json['id'] as String,
        name: json['name'] as String,
        icon: categoryIconFor(json['icon'] as String?),
        color: parseCategoryColor(json['color'] as String?),
        monthlyBudget: (json['monthly_budget'] as num?)?.toDouble(),
      );
    }).toList();
    return FinanceSnapshot(
      transactions: (results[0] as List)
          .map(
            (json) => FinanceTransaction.fromJson(json as Map<String, dynamic>),
          )
          .toList(),
      categories: categories,
      cards: (results[2] as List)
          .map((json) => CreditCard.fromJson(json as Map<String, dynamic>))
          .toList(),
      invoices: (results[3] as List)
          .map((json) => Invoice.fromJson(json as Map<String, dynamic>))
          .toList(),
      goals: (results[4] as List)
          .map(
            (json) => Goal(
              name: json['name'] as String,
              current: (json['current_amount'] as num).toDouble(),
              target: (json['target_amount'] as num).toDouble(),
            ),
          )
          .toList(),
      pendingReviews: (results[5] as List).length,
      currencyCode:
          ((results[6] as Map<String, dynamic>?)?['currency'] as String?) ??
          'BRL',
    );
  }
}
