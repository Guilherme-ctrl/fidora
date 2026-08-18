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
  bool get isInstallment => installmentTotal != null && installmentTotal! > 1;
  bool get isCard => cardLastFour != '----';
  bool get isCardAdjustment =>
      isCard && (movementType == 'credit' || movementType == 'refund');
  bool get isIncome =>
      !isCard && (movementType == 'credit' || movementType == 'refund');
  double get expenseImpact {
    if (movementType == 'transfer' || isIncome) return 0;
    if (isCardAdjustment) return -amount;
    return amount;
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
  });
  final String id;
  final String cardId;
  final DateTime referenceMonth;
  final double total;
  final DateTime dueDate;
  final String status;

  factory Invoice.fromJson(Map<String, dynamic> json) => Invoice(
    id: json['id'] as String,
    cardId: json['card_id'] as String,
    referenceMonth: _parseReferenceMonth(json['reference_month'] as String),
    total: (json['total'] as num).toDouble(),
    dueDate: DateTime.parse(json['due_date'] as String),
    status: json['status'] as String,
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
  const Goal({required this.name, required this.current, required this.target});
  final String name;
  final double current;
  final double target;
  double get progress => target == 0 ? 0 : (current / target).clamp(0, 1);
}

class FinanceSnapshot {
  const FinanceSnapshot({
    required this.transactions,
    required this.categories,
    required this.cards,
    required this.invoices,
    required this.goals,
    required this.pendingReviews,
  });
  final List<FinanceTransaction> transactions;
  final List<FinanceCategory> categories;
  final List<CreditCard> cards;
  final List<Invoice> invoices;
  final List<Goal> goals;
  final int pendingReviews;

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
