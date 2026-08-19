import 'package:flutter/material.dart';

enum TransactionStatus { confirmed, pending, ignored }

class FinanceTransaction {
  const FinanceTransaction({
    required this.id,
    required this.date,
    required this.merchant,
    required this.amount,
    required this.category,
    required this.cardLastFour,
    this.competence,
    this.movementType = 'purchase',
    this.rawModality,
    this.installmentCurrent,
    this.installmentTotal,
    this.status = TransactionStatus.confirmed,
    this.source = 'manual',
    this.holderId,
    this.personalAmount,
    this.accountId,
  });
  final String id;
  final DateTime date;
  final String merchant;
  final double amount;
  final String category;
  final String cardLastFour;
  final DateTime? competence;
  final String movementType;
  final String? rawModality;
  final int? installmentCurrent;
  final int? installmentTotal;
  final TransactionStatus status;
  final String source;

  /// Who this charge belongs to, when it is not you. Set per transaction by
  /// the invoice import, which reads it from the statement's notes; more
  /// precise than the card's holder, because one card can carry both.
  final String? holderId;

  /// Your share of [amount]. Null means all of it.
  final double? personalAmount;

  /// Where the money moved, when it was not a card.
  final String? accountId;

  /// What counts as yours. The full [amount] stays the audited figure.
  double get personalShare => personalAmount ?? amount;

  bool get isShared => personalAmount != null && personalAmount! < amount;
  bool get isInstallment => installmentTotal != null && installmentTotal! > 1;
  bool get isCard => cardLastFour != '----';
  bool get isCardAdjustment =>
      isCard && (movementType == 'credit' || movementType == 'refund');
  bool get isIncome =>
      !isCard && (movementType == 'credit' || movementType == 'refund');
  double get expenseImpact {
    if (movementType == 'transfer' || isIncome) return 0;
    if (isCardAdjustment) return -personalShare;
    return personalShare;
  }

  bool get affectsExpenses => expenseImpact != 0;

  factory FinanceTransaction.fromJson(Map<String, dynamic> json) =>
      FinanceTransaction(
        id: json['id'] as String,
        date: DateTime.parse(json['purchased_at'] as String).toLocal(),
        merchant:
            (json['merchant_normalized'] ?? json['merchant_original'])
                as String,
        amount: (json['amount'] as num).toDouble(),
        category: (json['categories']?['name'] ?? 'Sem categoria') as String,
        cardLastFour: (json['cards']?['last_four'] ?? '----') as String,
        competence: json['competence'] == null
            ? null
            : DateTime.parse(json['competence'] as String),
        movementType: (json['movement_type'] ?? 'purchase') as String,
        rawModality: json['raw_modality'] as String?,
        installmentCurrent: json['installment_current'] as int?,
        installmentTotal: json['installment_total'] as int?,
        source: (json['source'] ?? 'manual') as String,
        holderId: json['holder_id'] as String?,
        personalAmount: (json['personal_amount'] as num?)?.toDouble(),
        accountId: json['account_id'] as String?,
        status: switch (json['status']) {
          'pending' => TransactionStatus.pending,
          'ignored' => TransactionStatus.ignored,
          _ => TransactionStatus.confirmed,
        },
      );
}

class FinanceCategory {
  const FinanceCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.monthlyBudget,
  });
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final double? monthlyBudget;
}

class CreditCard {
  const CreditCard({
    required this.id,
    required this.name,
    required this.bank,
    required this.lastFour,
    required this.limit,
    required this.closingDay,
    required this.dueDay,
    required this.holder,
    this.holderId,
    this.includeInTotals = true,
  });
  final String id;
  final String name;
  final String bank;
  final String lastFour;
  final double limit;
  final int closingDay;
  final int dueDay;
  final String holder;
  final String? holderId;

  /// Whether this card's spending is your own. A card can also be excluded by
  /// its holder — see `cardCountsInTotals`.
  final bool includeInTotals;

  factory CreditCard.fromJson(Map<String, dynamic> json) => CreditCard(
    id: json['id'] as String,
    name: json['name'] as String,
    bank: json['bank'] as String,
    lastFour: json['last_four'] as String,
    limit: (json['credit_limit'] as num?)?.toDouble() ?? 0,
    closingDay: json['closing_day'] as int,
    dueDay: json['due_day'] as int,
    holder: (json['holder_name'] ?? '') as String,
    holderId: json['holder_id'] as String?,
    includeInTotals: (json['include_in_totals'] ?? true) as bool,
  );
}

class Invoice {
  const Invoice({
    required this.id,
    required this.cardId,
    required this.referenceMonth,
    required this.total,
    required this.dueDate,
    required this.status,
    this.paidAt,
  });
  final String id;
  final String cardId;
  final DateTime referenceMonth;
  final double total;
  final DateTime dueDate;
  final String status;

  /// When the invoice was settled; null while it is not.
  final DateTime? paidAt;

  factory Invoice.fromJson(Map<String, dynamic> json) => Invoice(
    id: json['id'] as String,
    cardId: json['card_id'] as String,
    referenceMonth: _parseReferenceMonth(json['reference_month'] as String),
    total: (json['total'] as num).toDouble(),
    dueDate: DateTime.parse(json['due_date'] as String),
    status: json['status'] as String,
    paidAt: json['paid_at'] == null
        ? null
        : DateTime.parse(json['paid_at'] as String).toLocal(),
  );
}

DateTime _parseReferenceMonth(String value) {
  // PostgreSQL `date` values arrive as YYYY-MM-DD. Keeping support for the
  // earlier YYYY-MM contract makes cached/demo payloads safe as well.
  final normalized = RegExp(r'^\d{4}-\d{2}$').hasMatch(value)
      ? '$value-01'
      : value;
  return DateTime.parse(normalized);
}

class Goal {
  const Goal({
    required this.id,
    required this.name,
    required this.current,
    required this.target,
    this.targetDate,
  });
  final String id;
  final String name;
  final double current;
  final double target;

  /// `goals.target_date` has existed since the first migration and never
  /// reached the app. Without a date, a goal is a number with no deadline.
  final DateTime? targetDate;

  double get progress => target == 0 ? 0 : (current / target).clamp(0, 1);
  double get remaining =>
      (target - current).clamp(0, double.infinity).toDouble();

  int? get daysLeft => targetDate?.difference(DateTime.now()).inDays;

  bool get isLate => (daysLeft ?? 1) < 0 && progress < 1;

  factory Goal.fromJson(Map<String, dynamic> json) => Goal(
    id: json['id'] as String,
    name: json['name'] as String,
    current: (json['current_amount'] as num).toDouble(),
    target: (json['target_amount'] as num).toDouble(),
    targetDate: json['target_date'] == null
        ? null
        : DateTime.parse(json['target_date'] as String),
  );
}

/// A place money sits: checking, savings, a wallet.
///
/// `accounts` and `transactions.account_id` have been in the schema since the
/// spreadsheet migration and had no code at all, so anything that was not a
/// card showed as the literal "----".
class Account {
  const Account({
    required this.id,
    required this.name,
    this.bank = '',
    this.type = 'checking',
    this.openingBalance = 0,
    this.includeInTotals = true,
  });

  final String id;
  final String name;
  final String bank;
  final String type;

  /// What the account held before the first recorded transaction.
  final double openingBalance;
  final bool includeInTotals;

  String get typeLabel => switch (type) {
    'savings' => 'Poupança',
    'wallet' => 'Carteira',
    'investment' => 'Investimento',
    _ => 'Conta corrente',
  };

  factory Account.fromJson(Map<String, dynamic> json) => Account(
    id: json['id'] as String,
    name: json['name'] as String,
    bank: (json['bank'] ?? '') as String,
    type: (json['account_type'] ?? 'checking') as String,
    openingBalance: (json['opening_balance'] as num?)?.toDouble() ?? 0,
    includeInTotals: (json['include_in_totals'] ?? true) as bool,
  );
}

/// A person whose card spending may or may not belong to your own finances.
class Holder {
  const Holder({
    required this.id,
    required this.name,
    this.includeInTotals = true,
  });
  final String id;
  final String name;
  final bool includeInTotals;

  factory Holder.fromJson(Map<String, dynamic> json) => Holder(
    id: json['id'] as String,
    name: json['name'] as String,
    includeInTotals: (json['include_in_totals'] ?? true) as bool,
  );
}

class FinanceSnapshot {
  const FinanceSnapshot({
    required this.transactions,
    required this.categories,
    required this.cards,
    required this.invoices,
    required this.goals,
    required this.pendingReviews,
    this.holders = const [],
    this.accounts = const [],
    this.currencyCode = 'BRL',
  });
  final List<FinanceTransaction> transactions;
  final List<FinanceCategory> categories;
  final List<CreditCard> cards;
  final List<Invoice> invoices;
  final List<Goal> goals;
  final List<Holder> holders;
  final List<Account> accounts;
  final int pendingReviews;

  /// From `profiles.currency`; drives the money formatter.
  final String currencyCode;

  double get monthSpend => transactions
      .where((item) => item.status != TransactionStatus.ignored)
      .fold(0, (sum, item) => sum + item.expenseImpact);
  Map<String, double> get spendByCategory {
    final values = <String, double>{};
    for (final item in transactions) {
      if (item.status == TransactionStatus.ignored) continue;
      values.update(
        item.category,
        (value) => value + item.expenseImpact,
        ifAbsent: () => item.expenseImpact,
      );
    }
    return values;
  }
}
