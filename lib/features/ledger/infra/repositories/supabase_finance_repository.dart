import 'package:financeiro_ai/features/ledger/domain/repositories/repositories.dart';
import 'package:financeiro_ai/core/errors/failure.dart';
import 'package:financeiro_ai/features/ledger/infra/models/row_mappers.dart';
import 'package:financeiro_ai/features/ledger/infra/supabase_failures.dart';
import 'package:financeiro_ai/features/ledger/domain/finance_rules.dart';
import 'package:financeiro_ai/features/catalog/domain/catalog_drafts.dart';
import 'package:financeiro_ai/features/review/domain/merchant_rule.dart';
import 'package:financeiro_ai/features/ledger/domain/entities/models.dart';
import 'package:financeiro_ai/features/imports/domain/invoice_import.dart';
import 'package:financeiro_ai/features/review/domain/review_item.dart';
import 'package:financeiro_ai/features/settings/domain/shortcut_token.dart';
import 'package:financeiro_ai/features/transactions/domain/transaction_draft.dart';
import 'package:flutter/foundation.dart';
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
      throw ValidationFailure(errors.firstMessage!);
    }
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const SessionExpired();
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
      'account_id': draft.accountId,
      'invoice_id': invoiceId,
      'merchant_original': draft.merchant.trim(),
      'merchant_normalized': normalizeMerchant(draft.merchant),
      'amount': draft.amount,
      'movement_type': draft.movementType,
      'modality': draft.modality,
      'installment_current': draft.installmentCurrent,
      'installment_total': draft.installmentTotal,
      'category_id': draft.categoryId,
      // An explicit holder on the transaction wins; otherwise it inherits the
      // card's, which is what the capture path already does.
      'holder_id': draft.holderId ?? card?['holder_id'],
      // Null means the whole charge is yours; the statement total is untouched
      // either way, since `amount` stays what the issuer charged.
      'personal_amount': draft.personalAmount,
      // Already uploaded by the time the draft arrives, so the row carries the
      // path in the same write rather than in a follow-up that could fail.
      'receipt_path': draft.receiptPath,
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
    } on PostgrestException catch (error, stack) {
      throw error.toFailure(stack);
    }
  }

  @override
  Future<void> deleteTransaction(String id) async {
    try {
      await _client.from('transactions').delete().eq('id', id);
    } on PostgrestException catch (error, stack) {
      throw error.toFailure(stack);
    }
  }

  @override
  Future<void> recategorizeTransactions(
    List<String> ids,
    String categoryId,
  ) async {
    if (ids.isEmpty) return;
    try {
      await _client
          .from('transactions')
          .update({
            'category_id': categoryId,
            // A hand-made correction is a decision, so it stops being a guess.
            'confidence': 'high',
            'reviewed': true,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .inFilter('id', ids);
    } on PostgrestException catch (error, stack) {
      throw error.toFailure(stack);
    }
  }

  @override
  Future<List<ReviewItem>> loadReviewQueue() => _mapped(_loadReviewQueue);

  Future<List<ReviewItem>> _loadReviewQueue() async {
    final rows = await _client
        .from('review_queue')
        .select()
        .eq('status', 'pending')
        .order('created_at', ascending: false)
        .limit(500);
    return (rows as List)
        .map((json) => reviewItemFromRow(json as Map<String, dynamic>))
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
    } on PostgrestException catch (error, stack) {
      throw error.toFailure(stack);
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
    } on PostgrestException catch (error, stack) {
      throw error.toFailure(stack);
    }
  }

  @override
  Future<void> saveCard(CardDraft draft) async {
    final errors = draft.validate();
    if (!errors.isEmpty) throw ValidationFailure(errors.firstMessage!);
    final userId = _requireUser();
    final payload = {
      'user_id': userId,
      'name': draft.name.trim(),
      'bank': draft.bank.trim(),
      'last_four': draft.lastFour.trim(),
      'closing_day': draft.closingDay,
      'due_day': draft.dueDay,
      'credit_limit': draft.limit,
      'holder_id': draft.holderId,
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
    } on PostgrestException catch (error, stack) {
      throw error.toFailure(stack);
    }
  }

  @override
  Future<void> setCardActive(String id, {required bool active}) async {
    try {
      await _client.from('cards').update({'active': active}).eq('id', id);
    } on PostgrestException catch (error, stack) {
      throw error.toFailure(stack);
    }
  }

  @override
  Future<void> saveCategory(CategoryDraft draft) async {
    final errors = draft.validate();
    if (!errors.isEmpty) throw ValidationFailure(errors.firstMessage!);
    final userId = _requireUser();
    final payload = {
      'user_id': userId,
      'name': draft.name.trim(),
      'color': draft.colorHex,
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
    } on PostgrestException catch (error, stack) {
      throw error.toFailure(stack);
    }
  }

  @override
  Future<void> setCategoryActive(String id, {required bool active}) async {
    try {
      await _client.from('categories').update({'active': active}).eq('id', id);
    } on PostgrestException catch (error, stack) {
      throw error.toFailure(stack);
    }
  }

  String _requireUser() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const SessionExpired();
    }
    return userId;
  }



  @override
  Future<void> saveGoal(GoalDraft draft) async {
    final errors = draft.validate();
    if (!errors.isEmpty) throw ValidationFailure(errors.firstMessage!);
    final payload = {
      'user_id': _requireUser(),
      'name': draft.name.trim(),
      'target_amount': draft.target,
      'current_amount': draft.current,
      'target_date': draft.targetDate == null
          ? null
          : _isoDate(draft.targetDate!),
      'active': draft.active,
    };
    try {
      if (draft.isEdit) {
        await _client.from('goals').update(payload).eq('id', draft.id!);
      } else {
        await _client.from('goals').insert(payload);
      }
    } on PostgrestException catch (error, stack) {
      throw error.toFailure(stack);
    }
  }

  @override
  Future<void> setGoalActive(String id, {required bool active}) async {
    try {
      await _client.from('goals').update({'active': active}).eq('id', id);
    } on PostgrestException catch (error, stack) {
      throw error.toFailure(stack);
    }
  }

  @override
  Future<void> saveAccount(AccountDraft draft) async {
    final errors = draft.validate();
    if (!errors.isEmpty) throw ValidationFailure(errors.firstMessage!);
    final payload = {
      'user_id': _requireUser(),
      'name': draft.name.trim(),
      'bank': draft.bank.trim().isEmpty ? null : draft.bank.trim(),
      'account_type': draft.type,
      'opening_balance': draft.openingBalance,
      'include_in_totals': draft.includeInTotals,
      'active': draft.active,
    };
    try {
      if (draft.isEdit) {
        await _client.from('accounts').update(payload).eq('id', draft.id!);
      } else {
        await _client.from('accounts').insert(payload);
      }
    } on PostgrestException catch (error, stack) {
      throw error.toFailure(stack);
    }
  }

  @override
  Future<void> setAccountActive(String id, {required bool active}) async {
    try {
      await _client.from('accounts').update({'active': active}).eq('id', id);
    } on PostgrestException catch (error, stack) {
      throw error.toFailure(stack);
    }
  }

  @override
  Future<void> saveHolder(HolderDraft draft) async {
    final errors = draft.validate();
    if (!errors.isEmpty) throw ValidationFailure(errors.firstMessage!);
    final payload = {
      'user_id': _requireUser(),
      'name': draft.name.trim(),
      'include_in_totals': draft.includeInTotals,
    };
    try {
      if (draft.isEdit) {
        await _client.from('holders').update(payload).eq('id', draft.id!);
      } else {
        await _client.from('holders').insert(payload);
      }
    } on PostgrestException catch (error, stack) {
      throw error.toFailure(stack);
    }
  }

  @override
  Future<void> deleteHolder(String id) async {
    try {
      // Cards keep working: the foreign key is `on delete set null`.
      await _client.from('holders').delete().eq('id', id);
    } on PostgrestException catch (error, stack) {
      throw error.toFailure(stack);
    }
  }

  @override
  Future<List<ImportBatch>> loadImportBatches() => _mapped(_loadImportBatches);

  Future<List<ImportBatch>> _loadImportBatches() async {
    final rows = await _client
        .from('import_batches')
        .select()
        .order('created_at', ascending: false)
        .limit(200);
    return (rows as List)
        .map((json) => importBatchFromRow(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<ShortcutToken>> loadShortcutTokens() => _mapped(_loadShortcutTokens);

  Future<List<ShortcutToken>> _loadShortcutTokens() async {
    final rows = await _client
        .from('shortcut_tokens')
        .select()
        .order('created_at', ascending: false);
    return (rows as List)
        .map((json) => shortcutTokenFromRow(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<IssuedShortcutToken> createShortcutToken(String name) async {
    final errors = validateTokenName(name);
    if (!errors.isEmpty) throw ValidationFailure(errors.firstMessage!);
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const SessionExpired();
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
        token: shortcutTokenFromRow(row),
      );
    } on PostgrestException catch (error, stack) {
      throw error.toFailure(stack);
    }
  }

  @override
  Future<void> revokeShortcutToken(String id) async {
    try {
      await _client
          .from('shortcut_tokens')
          .update({'revoked_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', id);
    } on PostgrestException catch (error, stack) {
      throw error.toFailure(stack);
    }
  }

  @override
  Future<List<MerchantRule>> loadMerchantRules() => _mapped(_loadMerchantRules);

  Future<List<MerchantRule>> _loadMerchantRules() async {
    final rows = await _client
        .from('merchant_rules')
        .select('*, categories(name)')
        .order('priority')
        .limit(500);
    return (rows as List)
        .map((json) => merchantRuleFromRow(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> saveMerchantRule(MerchantRuleDraft draft) async {
    final errors = draft.validate();
    if (!errors.isEmpty) {
      throw ValidationFailure(errors.firstMessage!);
    }
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const SessionExpired();
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
    } on PostgrestException catch (error, stack) {
      throw error.toFailure(stack);
    }
  }

  @override
  Future<void> deleteMerchantRule(String id) async {
    try {
      await _client.from('merchant_rules').delete().eq('id', id);
    } on PostgrestException catch (error, stack) {
      throw error.toFailure(stack);
    }
  }

  @override
  Future<String> uploadReceipt({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const SessionExpired();
    }
    // The owner id is the first path segment because that is exactly what the
    // storage policies match on. Any other shape uploads fine and then fails
    // to be readable.
    final path = '$userId/${_uuid.v4()}_$fileName';
    try {
      await _client.storage
          .from('receipts')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: false),
          );
      return path;
    } on StorageException catch (error, stack) {
      throw error.toFailure(stack);
    }
  }

  @override
  Future<String> receiptUrl(String path) =>
      _mapped(() => _receiptUrl(path));

  Future<String> _receiptUrl(String path) async {
    try {
      // Short-lived on purpose: the bucket is private, and a long-lived link
      // would be a permanent public address for a document that shows a
      // merchant, an amount and a date.
      return await _client.storage
          .from('receipts')
          .createSignedUrl(path, 60 * 10);
    } on StorageException catch (error, stack) {
      throw error.toFailure(stack);
    }
  }

  @override
  Future<void> deleteReceipt(String path) async {
    try {
      await _client.storage.from('receipts').remove([path]);
    } on StorageException catch (error, stack) {
      throw error.toFailure(stack);
    }
  }



  Future<Map<String, dynamic>> _loadCard(String cardId) async {
    final card = await _client
        .from('cards')
        .select('id, closing_day, due_day, holder_id')
        .eq('id', cardId)
        .maybeSingle();
    if (card == null) {
      throw const RecordNotFound(RecordKind.card);
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


  /// Every read passes through here.
  ///
  /// The write path maps at each `on PostgrestException` because it needs the
  /// constraint name to tell a duplicate from a refusal. Reads have no such
  /// branch and were simply letting the exception through — which is how a
  /// `PostgrestException` used to reach a `Text` widget, and how the loading
  /// screen ended up classifying errors by substring of `toString()`.
  Future<T> _mapped<T>(Future<T> Function() body) async {
    try {
      return await body();
    } catch (error, stack) {
      throw supabaseFailure(error, stack);
    }
  }

  static String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  @override
  Future<FinanceSnapshot> loadSnapshot() async {
    // Both halves in flight together: splitting them is about what gets
    // *refetched* after a write, not about making the first load serial.
    final loaded = await Future.wait([loadCatalog(), loadLedger()]);
    return FinanceSnapshot.compose(
      catalog: loaded[0] as FinanceCatalog,
      ledger: loaded[1] as FinanceLedger,
    );
  }

  @override
  Future<FinanceCatalog> loadCatalog() => _mapped(_loadCatalog);

  Future<FinanceCatalog> _loadCatalog() async {
    final results = await Future.wait([
      _client
          .from('categories')
          .select()
          .eq('active', true)
          .order('sort_order'),
      _client.from('cards').select().eq('active', true).order('name'),
      _client.from('goals').select().eq('active', true).order('created_at'),
      _client.from('holders').select().order('name'),
      _client.from('accounts').select().eq('active', true).order('name'),
      _client.from('profiles').select('currency').limit(1).maybeSingle(),
    ]);

    // The stored colour and icon are read here. They were written by the
    // schema's defaults from the first migration and ignored ever since: the
    // colour came from list position, so it changed whenever a category was
    // added, and every category drew the same icon.
    final categories = (results[0] as List).map((row) {
      final json = row as Map<String, dynamic>;
      return FinanceCategory(
        id: json['id'] as String,
        name: json['name'] as String,
        iconName: json['icon'] as String? ?? 'category',
        colorHex: json['color'] as String? ?? '#06485B',
        monthlyBudget: (json['monthly_budget'] as num?)?.toDouble(),
      );
    }).toList();

    final profile = results[5] as Map<String, dynamic>?;

    return FinanceCatalog(
      categories: categories,
      cards: (results[1] as List)
          .map((json) => cardFromRow(json as Map<String, dynamic>))
          .toList(),
      goals: (results[2] as List)
          .map((json) => goalFromRow(json as Map<String, dynamic>))
          .toList(),
      holders: (results[3] as List)
          .map((json) => holderFromRow(json as Map<String, dynamic>))
          .toList(),
      accounts: (results[4] as List)
          .map((json) => accountFromRow(json as Map<String, dynamic>))
          .toList(),
      currencyCode: (profile?['currency'] as String?) ?? 'BRL',
    );
  }

  /// Rows fetched per request while paging the ledger.
  static const _pageSize = 1000;

  /// A ceiling that exists to stop an unbounded loop, not to bound the ledger.
  /// Reaching it sets [FinanceLedger.truncated], which the screen announces.
  static const _maxTransactions = 50000;

  @override
  Future<FinanceLedger> loadLedger() => _mapped(_loadLedger);

  Future<FinanceLedger> _loadLedger() async {
    final rows = <Map<String, dynamic>>[];
    var truncated = false;

    // Paged rather than capped. A fixed `.limit(2000)` silently dropped
    // everything past the two-thousandth row, and every figure the app derives
    // — totals, averages, the trailing baselines behind every insight — was
    // then computed on a partial history with nothing on screen to say so.
    while (true) {
      final page = await _client
          .from('transactions')
          .select('*, categories(name), cards(last_four)')
          .order('purchased_at', ascending: false)
          .range(rows.length, rows.length + _pageSize - 1);
      rows.addAll((page as List).cast<Map<String, dynamic>>());

      if ((page).length < _pageSize) break;
      if (rows.length >= _maxTransactions) {
        truncated = true;
        break;
      }
    }

    final rest = await Future.wait([
      _client
          .from('invoices')
          .select()
          .order('reference_month', ascending: false)
          .limit(24),
      _client.from('review_queue').select('id').eq('status', 'pending'),
    ]);

    return FinanceLedger(
      transactions: rows.map(transactionFromRow).toList(),
      invoices: (rest[0] as List)
          .map((json) => invoiceFromRow(json as Map<String, dynamic>))
          .toList(),
      pendingReviews: (rest[1] as List).length,
      truncated: truncated,
    );
  }
}
