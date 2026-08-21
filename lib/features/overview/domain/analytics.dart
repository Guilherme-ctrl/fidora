import 'package:financeiro_ai/features/ledger/domain/entities/finance_period.dart';
import 'package:financeiro_ai/features/ledger/domain/entities/models.dart';

class PeriodAnalytics {
  const PeriodAnalytics({
    required this.transactions,
    required this.expenses,
    required this.income,
    required this.balance,
    required this.byCategory,
  });

  final List<FinanceTransaction> transactions;
  final double expenses;
  final double income;
  final double balance;
  final Map<String, double> byCategory;

  double get savingsRate => income <= 0 ? 0 : (balance / income) * 100;
}

bool isCardTransaction(FinanceTransaction transaction) =>
    transaction.cardLastFour != '----';

/// Card expenses belong to the invoice competence. Account movements keep
/// their actual posting date so the dashboard reflects both financial worlds.
DateTime analyticsDate(FinanceTransaction transaction) {
  if (isCardTransaction(transaction) && transaction.competence != null) {
    return transaction.competence!;
  }
  return transaction.date;
}

/// Small memo so the six screens do not each recompute the same period.
///
/// Every page called this in `build`, and the projection screen called it twice
/// per frame. The key is the snapshot's identity — a reload produces a new
/// object, which invalidates the cache exactly when the data changed.
final _analysisCache = <(FinanceSnapshot, FinancePeriod), PeriodAnalytics>{};

PeriodAnalytics analyzePeriod(FinanceSnapshot snapshot, FinancePeriod period) {
  final key = (snapshot, period);
  final cached = _analysisCache[key];
  if (cached != null) return cached;
  final computed = _analyzePeriod(snapshot, period);
  // Bounded: a handful of periods are in play at once, and a new snapshot
  // makes older entries unreachable anyway.
  if (_analysisCache.length > 12) _analysisCache.clear();
  _analysisCache[key] = computed;
  return computed;
}

/// Whether a card's spending belongs to your own finances.
///
/// Two switches can exclude it and both were dead: `cards.include_in_totals`
/// was parsed into the model and never consulted by any calculation, and
/// `holders.include_in_totals` had no model at all. A card is counted only when
/// the card says so and its holder does too.
bool cardCountsInTotals(FinanceSnapshot snapshot, CreditCard card) {
  if (!card.includeInTotals) return false;
  final holder = snapshot.holders
      .where((item) => item.id == card.holderId)
      .firstOrNull;
  return holder?.includeInTotals ?? true;
}

/// Whether a single transaction belongs to your own finances.
///
/// A transaction can name its own holder — the invoice import writes it from
/// the statement's notes — and that is more precise than the card's, because
/// one card carries charges from several people. The transaction's holder wins
/// when present; otherwise the card's answer stands.
bool transactionCountsInTotals(
  FinanceSnapshot snapshot,
  FinanceTransaction item,
) {
  final card = snapshot.cards
      .where((entry) => entry.lastFour == item.cardLastFour)
      .firstOrNull;
  if (card != null && !card.includeInTotals) return false;

  final holderId = item.holderId ?? card?.holderId;
  if (holderId == null) return true;
  final holder = snapshot.holders
      .where((entry) => entry.id == holderId)
      .firstOrNull;
  return holder?.includeInTotals ?? true;
}

PeriodAnalytics _analyzePeriod(FinanceSnapshot snapshot, FinancePeriod period) {
  final transactions = snapshot.transactions
      .where(
        (item) =>
            item.status != TransactionStatus.ignored &&
            transactionCountsInTotals(snapshot, item) &&
            period.contains(analyticsDate(item)),
      )
      .toList();
  var expenses = 0.0;
  var income = 0.0;
  final byCategory = <String, double>{};
  for (final item in transactions) {
    if (item.isIncome) {
      income += item.amount;
      continue;
    }
    final impact = item.expenseImpact;
    if (impact == 0) continue;
    expenses += impact;
    byCategory.update(
      item.category,
      (value) => value + impact,
      ifAbsent: () => impact,
    );
  }
  return PeriodAnalytics(
    transactions: transactions,
    expenses: expenses,
    income: income,
    balance: income - expenses,
    byCategory: byCategory,
  );
}

class MonthlyProjection {
  const MonthlyProjection({
    required this.month,
    required this.baseline,
    required this.installments,
  });

  final DateTime month;
  final double baseline;
  final double installments;
  double get total => baseline + installments;
}

List<MonthlyProjection> buildProjection(
  FinanceSnapshot snapshot,
  FinancePeriod sourcePeriod, {
  int monthCount = 6,
}) {
  final source = analyzePeriod(snapshot, sourcePeriod);
  final periodDays = sourcePeriod.endExclusive
      .difference(sourcePeriod.start)
      .inDays
      .clamp(1, 3660);
  final baseline =
      source.transactions
          .where((item) => item.affectsExpenses && !item.isInstallment)
          .fold<double>(0, (sum, item) => sum + item.expenseImpact) /
      periodDays *
      30.44;

  final latestInstallments = <String, FinanceTransaction>{};
  for (final item in snapshot.transactions.where(
    (item) =>
        item.status != TransactionStatus.ignored &&
        item.isInstallment &&
        item.movementType == 'purchase' &&
        item.installmentCurrent != null,
  )) {
    final key =
        '${item.merchant}|${item.cardLastFour}|${item.amount}|${item.installmentTotal}';
    final existing = latestInstallments[key];
    if (existing == null ||
        (item.installmentCurrent ?? 0) > (existing.installmentCurrent ?? 0)) {
      latestInstallments[key] = item;
    }
  }

  final firstMonth = DateTime(
    sourcePeriod.endExclusive.year,
    sourcePeriod.endExclusive.month,
  );
  return List.generate(monthCount, (index) {
    final month = DateTime(firstMonth.year, firstMonth.month + index);
    var installmentTotal = 0.0;
    for (final item in latestInstallments.values) {
      final current = item.installmentCurrent ?? 0;
      final total = item.installmentTotal ?? 0;
      final competence =
          item.competence ?? DateTime(item.date.year, item.date.month);
      final monthOffset =
          (month.year - competence.year) * 12 + month.month - competence.month;
      if (monthOffset >= 1 && current + monthOffset <= total) {
        installmentTotal += item.amount;
      }
    }
    return MonthlyProjection(
      month: month,
      baseline: baseline,
      installments: installmentTotal,
    );
  });
}
