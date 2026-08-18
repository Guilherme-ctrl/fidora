import 'package:financeiro_ai/application/providers.dart';
import 'package:financeiro_ai/core/theme.dart';
import 'package:financeiro_ai/domain/finance_rules.dart';
import 'package:financeiro_ai/core/category_visuals.dart';
import 'package:financeiro_ai/domain/catalog_drafts.dart';
import 'package:financeiro_ai/domain/merchant_rule.dart';
import 'package:financeiro_ai/domain/models.dart';
import 'package:financeiro_ai/domain/invoice_import.dart';
import 'package:financeiro_ai/domain/review_item.dart';
import 'package:financeiro_ai/domain/shortcut_token.dart';
import 'package:financeiro_ai/domain/transaction_draft.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

/// In-memory repository backing the demo mode. Writes are kept for the lifetime
/// of the process so the product can be exercised end to end without Supabase.
class DemoFinanceRepository implements FinanceRepository {
  static const _uuid = Uuid();
  final DateTime _now = DateTime.now();
  List<FinanceTransaction>? _ledger;

  List<FinanceTransaction> get _transactions => _ledger ??= _seedTransactions();

  late final List<Goal> _goals = [
    Goal(
      id: 'g1',
      name: 'Reserva de emergência',
      current: 18500,
      target: 30000,
      targetDate: DateTime(_now.year + 1, _now.month),
    ),
    Goal(id: 'g2', name: 'Viagem', current: 4200, target: 12000),
  ];

  final List<Holder> _holders = [const Holder(id: 'h1', name: 'Guilherme')];

  late final List<FinanceCategory> _categories = [..._seedCategories];
  late final List<CreditCard> _cards = [..._seedCards];

  late final List<Invoice> _invoices = [
    Invoice(
      id: '1',
      cardId: '1',
      referenceMonth: DateTime(_now.year, _now.month + 1),
      total: 2840.72,
      dueDate: DateTime(_now.year, _now.month + 1, 9),
      status: 'open',
    ),
    Invoice(
      id: '2',
      cardId: '2',
      referenceMonth: DateTime(_now.year, _now.month),
      total: 1296.35,
      dueDate: DateTime(_now.year, _now.month, 10),
      status: 'closed',
    ),
  ];

  late final List<ReviewItem> _reviews = [
    ReviewItem(
      id: 'r1',
      transactionId: '8',
      reason: 'Classificação com baixa confiança',
      status: 'pending',
      itemType: 'transaction',
      description: 'FARMÁCIA',
      suggestedAction: 'Confirmar categoria',
      createdAt: _now.subtract(const Duration(days: 1)),
    ),
    ReviewItem(
      id: 'r2',
      transactionId: '7',
      reason: 'Parcelamento sem plano correspondente',
      status: 'pending',
      itemType: 'transaction',
      description: 'AIRBNB',
      suggestedAction: 'Conferir número de parcelas',
      createdAt: _now.subtract(const Duration(days: 4)),
    ),
    ReviewItem(
      id: 'r3',
      reason: 'Lançamento da planilha sem transação correspondente',
      status: 'pending',
      itemType: 'legacy',
      description: 'MERCADO EXTRA 12/07',
      suggestedAction: 'Cadastrar manualmente ou descartar',
      createdAt: _now.subtract(const Duration(days: 9)),
    ),
  ];

  late final List<MerchantRule> _rules = [
    const MerchantRule(
      id: 'm1',
      pattern: 'IFOOD',
      categoryId: '1',
      categoryName: 'Alimentação',
      priority: 10,
    ),
    const MerchantRule(
      id: 'm2',
      pattern: 'UBER',
      categoryId: '2',
      categoryName: 'Transporte',
      priority: 20,
    ),
    const MerchantRule(
      id: 'm3',
      pattern: 'GOOGLE',
      categoryId: '9',
      categoryName: 'Assinaturas',
      priority: 30,
    ),
  ];

  @override
  Future<InvoiceImportPreview> previewInvoiceImport(
    InvoiceImportDocument document,
  ) async => InvoiceImportPreview(
    rows: document.transactions.length,
    toCreate: document.transactions.length - document.paymentCount,
    toReconcile: 0,
    duplicates: 0,
    reviews: document.reviewCount,
    paymentsIgnored: document.paymentCount,
    missingCategories: const [],
    alreadyImported: false,
    items: document.transactions
        .map(
          (item) => InvoiceImportItemPreview(
            externalId: item['external_id'] as String,
            disposition: item['movement_type'] == 'transfer'
                ? 'payment'
                : 'new',
          ),
        )
        .toList(),
  );

  @override
  Future<InvoiceImportResult> importInvoice(
    InvoiceImportDocument document,
  ) => throw const InvoiceImportException(
    'A importação somente grava dados quando o Finora está conectado ao Supabase.',
  );

  @override
  Future<void> saveTransaction(TransactionDraft draft) async {
    final errors = draft.validate();
    if (!errors.isEmpty) {
      throw FinanceWriteException(errors.firstMessage!);
    }
    final category = _categories
        .where((item) => item.id == draft.categoryId)
        .firstOrNull;
    if (category == null) {
      throw const FinanceWriteException(
        'A categoria escolhida não existe mais.',
      );
    }
    final card = _cards.where((item) => item.id == draft.cardId).firstOrNull;
    final saved = FinanceTransaction(
      id: draft.id ?? _uuid.v4(),
      date: draft.purchasedAt,
      merchant: draft.merchant.trim(),
      amount: draft.amount,
      category: category.name,
      cardLastFour: card?.lastFour ?? '----',
      competence: card == null
          ? null
          : invoiceCompetence(draft.purchasedAt, card.closingDay),
      movementType: draft.movementType,
      installmentCurrent: draft.installmentCurrent,
      installmentTotal: draft.installmentTotal,
      status: draft.status,
    );
    _transactions
      ..removeWhere((item) => item.id == saved.id)
      ..add(saved)
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  @override
  Future<void> deleteTransaction(String id) async {
    _transactions.removeWhere((item) => item.id == id);
  }

  @override
  Future<List<ReviewItem>> loadReviewQueue() async =>
      List.unmodifiable(_reviews.where((item) => item.isPending));

  @override
  Future<void> settleReview(String id, {required String status}) async {
    final index = _reviews.indexWhere((item) => item.id == id);
    if (index == -1) return;
    final item = _reviews[index];
    _reviews[index] = ReviewItem(
      id: item.id,
      reason: item.reason,
      status: status,
      transactionId: item.transactionId,
      itemType: item.itemType,
      description: item.description,
      suggestedAction: item.suggestedAction,
      createdAt: item.createdAt,
    );
  }

  @override
  Future<void> setInvoicePaid(String invoiceId, {required bool paid}) async {
    final index = _invoices.indexWhere((item) => item.id == invoiceId);
    if (index == -1) {
      throw const FinanceWriteException('Fatura não encontrada.');
    }
    final invoice = _invoices[index];
    _invoices[index] = Invoice(
      id: invoice.id,
      cardId: invoice.cardId,
      referenceMonth: invoice.referenceMonth,
      total: invoice.total,
      dueDate: invoice.dueDate,
      status: paid ? 'paid' : 'closed',
      paidAt: paid ? DateTime.now() : null,
    );
  }

  final List<ShortcutToken> _tokens = [];

  @override
  Future<void> saveCard(CardDraft draft) async {
    final errors = draft.validate();
    if (!errors.isEmpty) throw FinanceWriteException(errors.firstMessage!);
    final clash = _cards.any(
      (item) => item.id != draft.id && item.lastFour == draft.lastFour.trim(),
    );
    if (clash) {
      throw const FinanceWriteException('Já existe um cartão com esse final.');
    }
    final saved = CreditCard(
      id: draft.id ?? _uuid.v4(),
      name: draft.name.trim(),
      bank: draft.bank.trim(),
      lastFour: draft.lastFour.trim(),
      limit: draft.limit,
      closingDay: draft.closingDay,
      dueDay: draft.dueDay,
      holder: draft.holder.trim(),
      holderId: draft.holderId,
      includeInTotals: draft.includeInTotals,
    );
    final index = _cards.indexWhere((item) => item.id == saved.id);
    if (index == -1) {
      _cards.add(saved);
    } else {
      _cards[index] = saved;
    }
  }

  @override
  Future<void> setCardActive(String id, {required bool active}) async {
    // The demo snapshot only carries active cards, so deactivating removes it.
    if (!active) _cards.removeWhere((item) => item.id == id);
  }

  @override
  Future<void> saveCategory(CategoryDraft draft) async {
    final errors = draft.validate();
    if (!errors.isEmpty) throw FinanceWriteException(errors.firstMessage!);
    final clash = _categories.any(
      (item) =>
          item.id != draft.id &&
          item.name.toLowerCase() == draft.name.trim().toLowerCase(),
    );
    if (clash) {
      throw const FinanceWriteException(
        'Já existe uma categoria com esse nome.',
      );
    }
    final saved = FinanceCategory(
      id: draft.id ?? _uuid.v4(),
      name: draft.name.trim(),
      icon: categoryIconFor(draft.iconName),
      color: draft.color,
      monthlyBudget: draft.monthlyBudget,
    );
    final index = _categories.indexWhere((item) => item.id == saved.id);
    if (index == -1) {
      _categories.add(saved);
    } else {
      _categories[index] = saved;
    }
  }

  @override
  Future<void> setCategoryActive(String id, {required bool active}) async {
    if (!active) _categories.removeWhere((item) => item.id == id);
  }

  @override
  Future<void> saveGoal(GoalDraft draft) async {
    final errors = draft.validate();
    if (!errors.isEmpty) throw FinanceWriteException(errors.firstMessage!);
    final saved = Goal(
      id: draft.id ?? _uuid.v4(),
      name: draft.name.trim(),
      current: draft.current,
      target: draft.target,
      targetDate: draft.targetDate,
    );
    final index = _goals.indexWhere((item) => item.id == saved.id);
    if (index == -1) {
      _goals.add(saved);
    } else {
      _goals[index] = saved;
    }
  }

  @override
  Future<void> setGoalActive(String id, {required bool active}) async {
    if (!active) _goals.removeWhere((item) => item.id == id);
  }

  @override
  Future<void> saveHolder(HolderDraft draft) async {
    final errors = draft.validate();
    if (!errors.isEmpty) throw FinanceWriteException(errors.firstMessage!);
    final clash = _holders.any(
      (item) =>
          item.id != draft.id &&
          item.name.toLowerCase() == draft.name.trim().toLowerCase(),
    );
    if (clash) {
      throw const FinanceWriteException('Já existe um portador com esse nome.');
    }
    final saved = Holder(
      id: draft.id ?? _uuid.v4(),
      name: draft.name.trim(),
      includeInTotals: draft.includeInTotals,
    );
    final index = _holders.indexWhere((item) => item.id == saved.id);
    if (index == -1) {
      _holders.add(saved);
    } else {
      _holders[index] = saved;
    }
  }

  @override
  Future<void> deleteHolder(String id) async {
    _holders.removeWhere((item) => item.id == id);
  }

  @override
  Future<List<ShortcutToken>> loadShortcutTokens() async =>
      List.unmodifiable(_tokens);

  @override
  Future<IssuedShortcutToken> createShortcutToken(String name) async {
    final errors = validateTokenName(name);
    if (!errors.isEmpty) throw FinanceWriteException(errors.firstMessage!);
    final secret = generateShortcutSecret();
    final token = ShortcutToken(
      id: _uuid.v4(),
      name: name.trim(),
      createdAt: DateTime.now(),
    );
    _tokens.insert(0, token);
    return IssuedShortcutToken(secret: secret, token: token);
  }

  @override
  Future<void> revokeShortcutToken(String id) async {
    final index = _tokens.indexWhere((item) => item.id == id);
    if (index == -1) {
      throw const FinanceWriteException('Token não encontrado.');
    }
    final token = _tokens[index];
    _tokens[index] = ShortcutToken(
      id: token.id,
      name: token.name,
      createdAt: token.createdAt,
      lastUsedAt: token.lastUsedAt,
      revokedAt: DateTime.now(),
    );
  }

  @override
  Future<List<MerchantRule>> loadMerchantRules() async => List.unmodifiable(
    _rules..sort((a, b) => a.priority.compareTo(b.priority)),
  );

  @override
  Future<void> saveMerchantRule(MerchantRuleDraft draft) async {
    final errors = draft.validate();
    if (!errors.isEmpty) {
      throw FinanceWriteException(errors.firstMessage!);
    }
    final category = _categories
        .where((item) => item.id == draft.categoryId)
        .firstOrNull;
    if (category == null) {
      throw const FinanceWriteException(
        'A categoria escolhida não existe mais.',
      );
    }
    final pattern = draft.pattern.trim();
    final clash = _rules.any(
      (item) =>
          item.id != draft.id &&
          item.pattern.toLowerCase() == pattern.toLowerCase(),
    );
    if (clash) {
      throw const FinanceWriteException(
        'Já existe uma regra para esse trecho.',
      );
    }
    final saved = MerchantRule(
      id: draft.id ?? _uuid.v4(),
      pattern: pattern,
      categoryId: category.id,
      categoryName: category.name,
      subcategory: draft.subcategory,
      priority: draft.priority,
      active: draft.active,
    );
    _rules
      ..removeWhere((item) => item.id == saved.id)
      ..add(saved);
  }

  @override
  Future<void> deleteMerchantRule(String id) async {
    _rules.removeWhere((item) => item.id == id);
  }

  @override
  Future<FinanceSnapshot> loadSnapshot() async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    return FinanceSnapshot(
      transactions: List.unmodifiable(_transactions),
      categories: List.unmodifiable(_categories),
      cards: List.unmodifiable(_cards),
      invoices: List.unmodifiable(_invoices),
      goals: List.unmodifiable(_goals),
      holders: List.unmodifiable(_holders),
      pendingReviews: _reviews.where((item) => item.isPending).length,
      currencyCode: 'BRL',
    );
  }

  List<FinanceTransaction> _seedTransactions() => [
    FinanceTransaction(
      id: '1',
      date: _now,
      merchant: 'PADARIA CENTRAL',
      amount: 24.80,
      category: 'Alimentação',
      cardLastFour: '6902',
      source: 'apple_pay',
    ),
    FinanceTransaction(
      id: '2',
      date: _now.subtract(const Duration(days: 1)),
      merchant: 'UBER',
      amount: 31.40,
      category: 'Transporte',
      cardLastFour: '6902',
      source: 'apple_pay',
    ),
    FinanceTransaction(
      id: '3',
      date: _now.subtract(const Duration(days: 2)),
      merchant: 'UNIFIQUE TELECOM',
      amount: 197.50,
      category: 'Moradia',
      cardLastFour: '2780',
    ),
    FinanceTransaction(
      id: '4',
      date: _now.subtract(const Duration(days: 3)),
      merchant: 'GOOGLE YOUTUBE',
      amount: 16.90,
      category: 'Assinaturas',
      cardLastFour: '2780',
    ),
    FinanceTransaction(
      id: '5',
      date: _now.subtract(const Duration(days: 5)),
      merchant: 'MERCADO LIVRE',
      amount: 156.30,
      category: 'Compras',
      cardLastFour: '4567',
      installmentCurrent: 2,
      installmentTotal: 4,
    ),
    FinanceTransaction(
      id: '6',
      date: _now.subtract(const Duration(days: 7)),
      merchant: 'RESTAURANTE SAINT PETER',
      amount: 118.00,
      category: 'Alimentação',
      cardLastFour: '6902',
    ),
    FinanceTransaction(
      id: '7',
      date: _now.subtract(const Duration(days: 9)),
      merchant: 'AIRBNB',
      amount: 410.14,
      category: 'Viagem',
      cardLastFour: '2780',
      installmentCurrent: 3,
      installmentTotal: 6,
    ),
    FinanceTransaction(
      id: '8',
      date: _now.subtract(const Duration(days: 10)),
      merchant: 'FARMÁCIA',
      amount: 86.70,
      category: 'Saúde',
      cardLastFour: '0590',
      status: TransactionStatus.pending,
    ),
  ];

  static const _seedCategories = <FinanceCategory>[
    FinanceCategory(
      id: '1',
      name: 'Alimentação',
      icon: Icons.restaurant_rounded,
      color: coral,
      monthlyBudget: 1200,
    ),
    FinanceCategory(
      id: '2',
      name: 'Transporte',
      icon: Icons.directions_car_rounded,
      color: Color(0xFF377D71),
      monthlyBudget: 600,
    ),
    FinanceCategory(
      id: '3',
      name: 'Moradia',
      icon: Icons.home_rounded,
      color: Color(0xFF5D65A8),
      monthlyBudget: 2200,
    ),
    FinanceCategory(
      id: '4',
      name: 'Saúde',
      icon: Icons.favorite_rounded,
      color: Color(0xFFBF5C7A),
      monthlyBudget: 500,
    ),
    FinanceCategory(
      id: '5',
      name: 'Educação',
      icon: Icons.school_rounded,
      color: Color(0xFF7D63A8),
    ),
    FinanceCategory(
      id: '6',
      name: 'Lazer',
      icon: Icons.sports_soccer_rounded,
      color: gold,
      monthlyBudget: 700,
    ),
    FinanceCategory(
      id: '7',
      name: 'Viagem',
      icon: Icons.flight_rounded,
      color: Color(0xFF477D9B),
    ),
    FinanceCategory(
      id: '8',
      name: 'Compras',
      icon: Icons.shopping_bag_rounded,
      color: Color(0xFF98734E),
      monthlyBudget: 900,
    ),
    FinanceCategory(
      id: '9',
      name: 'Assinaturas',
      icon: Icons.subscriptions_rounded,
      color: Color(0xFF6B7B58),
      monthlyBudget: 250,
    ),
    FinanceCategory(
      id: '10',
      name: 'Financeiro',
      icon: Icons.account_balance_rounded,
      color: Color(0xFF4B6473),
    ),
    FinanceCategory(
      id: '11',
      name: 'Transferências',
      icon: Icons.swap_horiz_rounded,
      color: Color(0xFF718096),
    ),
    FinanceCategory(
      id: '12',
      name: 'Outros',
      icon: Icons.more_horiz_rounded,
      color: Color(0xFF8A8178),
    ),
  ];

  static const _seedCards = <CreditCard>[
    CreditCard(
      id: '1',
      name: 'Uniclass Black',
      bank: 'Itaú',
      lastFour: '6902',
      limit: 41470,
      closingDay: 2,
      dueDay: 9,
      holder: 'Guilherme',
    ),
    CreditCard(
      id: '2',
      name: 'Ourocard Platinum',
      bank: 'Banco do Brasil',
      lastFour: '4567',
      limit: 39418,
      closingDay: 30,
      dueDay: 10,
      holder: 'Guilherme',
    ),
  ];
}
