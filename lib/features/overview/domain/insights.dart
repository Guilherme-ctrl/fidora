import 'package:financeiro_ai/features/ledger/domain/entities/finance_period.dart';
import 'package:financeiro_ai/features/overview/domain/analytics.dart';
import 'package:financeiro_ai/features/ledger/domain/finance_rules.dart';
import 'package:financeiro_ai/features/ledger/domain/entities/models.dart';

enum BudgetLevel { fine, approaching, over }

class BudgetAlert {
  const BudgetAlert({
    required this.category,
    required this.spent,
    required this.budget,
  });

  final FinanceCategory category;
  final double spent;
  final double budget;

  double get ratio => budget <= 0 ? 0 : spent / budget;
  double get remaining => budget - spent;

  BudgetLevel get level => switch (ratio) {
    >= 1 => BudgetLevel.over,
    >= .8 => BudgetLevel.approaching,
    _ => BudgetLevel.fine,
  };
}

/// Categories worth warning about, worst first.
///
/// Only for a single month: a monthly budget compared against an arbitrary
/// range would report an overrun that says nothing, so a custom period
/// deliberately produces no alerts rather than misleading ones.
List<BudgetAlert> budgetAlerts(FinanceSnapshot snapshot, FinancePeriod period) {
  if (!period.isSingleMonth) return const [];
  final analytics = analyzePeriod(snapshot, period);
  final alerts =
      snapshot.categories
          .where((category) => (category.monthlyBudget ?? 0) > 0)
          .map(
            (category) => BudgetAlert(
              category: category,
              spent: analytics.byCategory[category.name] ?? 0,
              budget: category.monthlyBudget!,
            ),
          )
          .where((alert) => alert.level != BudgetLevel.fine)
          .toList()
        ..sort((a, b) => b.ratio.compareTo(a.ratio));
  return alerts;
}

class RecurringCharge {
  const RecurringCharge({
    required this.merchant,
    required this.category,
    required this.typicalAmount,
    required this.latestAmount,
    required this.monthsSeen,
    required this.lastCharge,
  });

  final String merchant;
  final String category;

  /// The amount most of the charges share.
  final double typicalAmount;
  final double latestAmount;
  final int monthsSeen;
  final DateTime lastCharge;

  /// A change worth noticing rather than a rounding difference.
  bool get priceChanged => (latestAmount - typicalAmount).abs() > 0.01;
  double get priceDelta => latestAmount - typicalAmount;
  double get monthlyCost => latestAmount;
}

/// Charges that repeat month after month, found in the ledger itself.
///
/// The `frequency` column exists but carries free text copied from the
/// spreadsheet, so its values cannot be relied on. Repetition is the evidence
/// that actually holds: the same merchant, in at least [minMonths] distinct
/// months, at an amount that stays put. Instalments are excluded — they repeat
/// and then stop, which is the opposite of a subscription.
List<RecurringCharge> detectRecurring(
  FinanceSnapshot snapshot, {
  int minMonths = 3,
  double tolerance = 0.15,
}) {
  final byMerchant = <String, List<FinanceTransaction>>{};
  for (final item in snapshot.transactions) {
    if (item.status == TransactionStatus.ignored) continue;
    if (item.isInstallment || item.movementType != 'purchase') continue;
    if (!transactionCountsInTotals(snapshot, item)) continue;
    byMerchant
        .putIfAbsent(normalizeMerchant(item.merchant), () => [])
        .add(item);
  }

  final found = <RecurringCharge>[];
  for (final entry in byMerchant.entries) {
    final charges = entry.value..sort((a, b) => a.date.compareTo(b.date));
    final months = charges
        .map((item) => '${item.date.year}-${item.date.month}')
        .toSet();
    if (months.length < minMonths) continue;

    final amounts = charges.map((item) => item.amount).toList()..sort();
    final median = amounts[amounts.length ~/ 2];
    if (median <= 0) continue;
    // A merchant you simply visit often is not a subscription: the amount has
    // to stay roughly the same for it to be a recurring charge.
    final steady =
        charges
            .where((item) => (item.amount - median).abs() / median <= tolerance)
            .length /
        charges.length;
    if (steady < .6) continue;

    final latest = charges.last;
    found.add(
      RecurringCharge(
        merchant: latest.merchant,
        category: latest.category,
        typicalAmount: median,
        latestAmount: latest.amount,
        monthsSeen: months.length,
        lastCharge: latest.date,
      ),
    );
  }

  found.sort((a, b) => b.monthlyCost.compareTo(a.monthlyCost));
  return found;
}

double recurringMonthlyTotal(List<RecurringCharge> charges) =>
    charges.fold<double>(0, (sum, item) => sum + item.monthlyCost);

class AccountBalance {
  const AccountBalance({
    required this.account,
    required this.moved,
    required this.entries,
  });

  final Account account;

  /// Income minus expenses recorded on the account, all time.
  final double moved;
  final int entries;

  double get balance => account.openingBalance + moved;

  /// A balance with no opening figure is really just the movement so far, and
  /// the screen has to say which one it is showing.
  bool get isMovementOnly => account.openingBalance == 0;
}

/// Current balance per account, not scoped to the selected period: a balance is
/// state, the same reason card availability ignores the period.
List<AccountBalance> accountBalances(FinanceSnapshot snapshot) {
  final moved = <String, double>{};
  final counted = <String, int>{};
  for (final item in snapshot.transactions) {
    final id = item.accountId;
    if (id == null || item.status == TransactionStatus.ignored) continue;
    counted[id] = (counted[id] ?? 0) + 1;
    moved[id] =
        (moved[id] ?? 0) + (item.isIncome ? item.amount : -item.expenseImpact);
  }
  return snapshot.accounts
      .map(
        (account) => AccountBalance(
          account: account,
          moved: moved[account.id] ?? 0,
          entries: counted[account.id] ?? 0,
        ),
      )
      .toList();
}

/// What the accounts hold together — the closest the app gets to net worth,
/// and deliberately not including credit cards, which are debt rather than
/// something you own.
double totalAccountBalance(List<AccountBalance> balances) => balances
    .where((item) => item.account.includeInTotals)
    .fold<double>(0, (sum, item) => sum + item.balance);
