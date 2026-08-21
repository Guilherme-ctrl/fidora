import 'dart:math' as math;

import 'package:financeiro_ai/features/ledger/domain/entities/finance_period.dart';
import 'package:financeiro_ai/features/overview/domain/analytics.dart';
import 'package:financeiro_ai/features/ledger/domain/entities/models.dart';

class CategoryDelta {
  const CategoryDelta({
    required this.name,
    required this.current,
    required this.previous,
  });

  final String name;
  final double current;
  final double previous;

  double get delta => current - previous;

  /// Null when the previous period spent nothing: there is no percentage
  /// increase from zero, and showing one would invent a number.
  double? get ratio => previous <= 0 ? null : delta / previous;

  bool get isNew => previous <= 0 && current > 0;
  bool get isGone => current <= 0 && previous > 0;
}

class PeriodComparison {
  const PeriodComparison({
    required this.period,
    required this.previousPeriod,
    required this.current,
    required this.previous,
    required this.categories,
  });

  final FinancePeriod period;
  final FinancePeriod previousPeriod;
  final PeriodAnalytics current;
  final PeriodAnalytics previous;

  /// Sorted by how much each category moved, largest movement first.
  final List<CategoryDelta> categories;

  double get expenseDelta => current.expenses - previous.expenses;
  double? get expenseRatio =>
      previous.expenses <= 0 ? null : expenseDelta / previous.expenses;

  bool get spentMore => expenseDelta > 0;
  bool get hasBaseline => previous.expenses > 0;
}

PeriodComparison comparePeriods(
  FinanceSnapshot snapshot,
  FinancePeriod period,
) {
  final previousPeriod = period.previous;
  final current = analyzePeriod(snapshot, period);
  final previous = analyzePeriod(snapshot, previousPeriod);

  final names = <String>{
    ...current.byCategory.keys,
    ...previous.byCategory.keys,
  };
  final categories =
      names
          .map(
            (name) => CategoryDelta(
              name: name,
              current: current.byCategory[name] ?? 0,
              previous: previous.byCategory[name] ?? 0,
            ),
          )
          .toList()
        ..sort((a, b) => b.delta.abs().compareTo(a.delta.abs()));

  return PeriodComparison(
    period: period,
    previousPeriod: previousPeriod,
    current: current,
    previous: previous,
    categories: categories,
  );
}

/// Mean monthly expense over the [months] calendar months before [period].
/// Returns null when none of those months has any movement, so the caller can
/// say "sem base" instead of printing a confident zero.
double? trailingMonthlyAverage(
  FinanceSnapshot snapshot,
  FinancePeriod period, {
  int months = 3,
}) {
  var total = 0.0;
  var counted = 0;
  for (var index = 1; index <= months; index++) {
    final window = FinancePeriod.month(
      DateTime(period.start.year, period.start.month - index),
    );
    final analytics = analyzePeriod(snapshot, window);
    if (analytics.transactions.isEmpty) continue;
    total += analytics.expenses;
    counted++;
  }
  return counted == 0 ? null : total / counted;
}

/// How much of a card's limit is committed.
///
/// Two things hold limit, and the interface used to count only the first:
/// invoices that have not been paid, and instalments already agreed with the
/// issuer that have not reached an invoice yet. Ignoring the second made the
/// available figure optimistic for anyone who uses instalments — the whole
/// point of the number is to be safe to spend against.
class CardUsage {
  const CardUsage({
    required this.card,
    required this.billed,
    required this.scheduled,
  });

  final CreditCard card;

  /// Sum of invoices that are not paid.
  final double billed;

  /// Instalments already committed but not yet billed.
  final double scheduled;

  double get used => billed + scheduled;

  bool get hasLimit => card.limit > 0;
  double get available => math.max(0, card.limit - used);
  double get ratio =>
      hasLimit ? (used / card.limit).clamp(0.0, 1.0).toDouble() : 0;
  bool get isTight => hasLimit && ratio >= .8;
  bool get isOver => hasLimit && used > card.limit;
}

CardUsage cardUsage(FinanceSnapshot snapshot, CreditCard card) {
  final billed = snapshot.invoices
      .where((item) => item.cardId == card.id && item.status != 'paid')
      .fold<double>(0, (sum, item) => sum + item.total);
  return CardUsage(
    card: card,
    billed: billed,
    scheduled: scheduledInstallments(snapshot, card),
  );
}

/// Instalments still to be charged on this card.
///
/// A purchase appears once per instalment already billed, so the same key is
/// collapsed to its furthest instalment — the same key the projection uses, on
/// purpose, so the two screens cannot disagree about what is outstanding. Only
/// the instalments beyond that one are counted; the ones already billed are
/// inside an invoice and would otherwise be counted twice.
double scheduledInstallments(FinanceSnapshot snapshot, CreditCard card) {
  final furthest = <String, FinanceTransaction>{};
  for (final item in snapshot.transactions) {
    if (item.status == TransactionStatus.ignored) continue;
    if (!item.isInstallment || item.movementType != 'purchase') continue;
    if (item.cardLastFour != card.lastFour) continue;
    if (item.installmentCurrent == null) continue;
    final key = '${item.merchant}|${item.amount}|${item.installmentTotal}';
    final existing = furthest[key];
    if (existing == null ||
        item.installmentCurrent! > existing.installmentCurrent!) {
      furthest[key] = item;
    }
  }
  return furthest.values.fold<double>(0, (sum, item) {
    final remaining = (item.installmentTotal! - item.installmentCurrent!).clamp(
      0,
      item.installmentTotal!,
    );
    return sum + remaining * item.amount;
  });
}
