import 'package:financeiro_ai/features/ledger/domain/entities/finance_period.dart';
import 'package:financeiro_ai/features/overview/domain/analytics.dart';
import 'package:financeiro_ai/features/overview/domain/insights.dart';
import 'package:financeiro_ai/features/invoices/domain/invoice_forecast.dart';
import 'package:financeiro_ai/features/ledger/domain/entities/models.dart';

/// Observations about the ledger, written as sentences.
///
/// Every one of these is derived arithmetic, not generated prose. The numbers
/// in the sentence are the numbers on the screens behind it, and a reader who
/// checks them will find them. Wording that cannot be backed by a computed
/// figure does not get written.
enum InsightTone { neutral, good, warning }

class Insight {
  const Insight({
    required this.id,
    required this.text,
    required this.tone,
    required this.weight,
    this.category,
  });

  /// Stable across rebuilds, so the list does not reshuffle under the reader.
  final String id;
  final String text;
  final InsightTone tone;

  /// How much money the observation is about. Ranking by this rather than by
  /// percentage keeps a 300% jump on a fifteen-real category from crowding out
  /// a real one.
  final double weight;

  final String? category;
}

typedef Money = String Function(double);

/// The observations worth showing, most consequential first.
///
/// Deliberately capped: a screen of twenty observations is a report again,
/// and the point of this one is that it says the few things that changed.
List<Insight> buildInsights(
  FinanceSnapshot snapshot,
  FinancePeriod period, {
  required Money money,
  DateTime? now,
  int max = 4,
  int baselineMonths = 3,
}) {
  final found = <Insight>[
    ..._categoryMoves(
      snapshot,
      period,
      money: money,
      baselineMonths: baselineMonths,
    ),
    ..._priceChanges(snapshot, money: money),
    ..._invoiceOutlook(snapshot, money: money, now: now),
  ]..sort((a, b) => b.weight.compareTo(a.weight));

  return found.take(max).toList();
}

/// Categories that moved against their own recent average.
///
/// Only for a single month: comparing an arbitrary range against a monthly
/// average produces a difference that means nothing, the same reason budget
/// alerts stay quiet on a custom period.
List<Insight> _categoryMoves(
  FinanceSnapshot snapshot,
  FinancePeriod period, {
  required Money money,
  required int baselineMonths,
  double minMove = 50,
  double minRatio = .25,
}) {
  if (!period.isSingleMonth) return const [];

  final current = analyzePeriod(snapshot, period);
  final baselines = <String, List<double>>{};
  var observed = 0;

  for (var index = 1; index <= baselineMonths; index++) {
    final month = FinancePeriod.month(
      DateTime(period.start.year, period.start.month - index),
    );
    final past = analyzePeriod(snapshot, month);
    // A month the data never covered is not a month of restraint. Counting it
    // as zero would invent an increase for every category the first time the
    // app is opened.
    if (past.transactions.isEmpty) continue;
    observed++;
    for (final entry in past.byCategory.entries) {
      baselines.putIfAbsent(entry.key, () => []).add(entry.value);
    }
  }

  // One month is an anecdote, not an average.
  if (observed < 2) return const [];

  final insights = <Insight>[];
  final names = {...current.byCategory.keys, ...baselines.keys};

  for (final name in names) {
    final spent = current.byCategory[name] ?? 0;
    final samples = baselines[name] ?? const [];
    // Absent from a month means zero in that month, now that we know the month
    // itself was observed.
    final average =
        samples.fold<double>(0, (sum, value) => sum + value) / observed;

    if (average <= 0) continue;
    final delta = spent - average;
    final ratio = delta / average;
    if (delta.abs() < minMove || ratio.abs() < minRatio) continue;

    insights.add(
      Insight(
        id: 'category:$name',
        category: name,
        tone: delta > 0 ? InsightTone.warning : InsightTone.good,
        weight: delta.abs(),
        text: delta > 0
            ? _spikeText(current, name, delta, ratio, average, observed, money)
            : 'Você gastou ${_percent(ratio.abs())} a menos em $name que a '
                  'média dos últimos $observed meses — '
                  '${money(delta.abs())} a menos.',
      ),
    );
  }

  return insights;
}

String _spikeText(
  PeriodAnalytics current,
  String name,
  double delta,
  double ratio,
  double average,
  int observed,
  Money money,
) {
  final opening =
      'Você gastou ${_percent(ratio)} a mais em $name que a média dos '
      'últimos $observed meses — ${money(delta)} acima dos '
      '${money(average)} de costume';

  final drivers = _driversOf(current, name, delta);
  if (drivers == null) return '$opening.';

  return drivers.concentrated
      ? '$opening, puxado por ${_count(drivers.count, 'compra', 'compras')} '
            'acima de ${money(drivers.floor)}.'
      : '$opening, diluído em ${_count(drivers.count, 'compra', 'compras')} '
            'em vez de concentrado em poucas.';
}

class _Drivers {
  const _Drivers(this.count, this.floor);
  final int count;
  final double floor;

  /// A handful of purchases explaining the whole increase is a fact the reader
  /// can act on; fourteen of them is a habit, and saying "puxado por" would be
  /// the wrong word for it.
  bool get concentrated => count <= 3;
}

/// The fewest purchases whose sum covers the increase.
_Drivers? _driversOf(PeriodAnalytics current, String name, double delta) {
  final amounts =
      current.transactions
          .where((item) => item.category == name && item.affectsExpenses)
          .map((item) => item.expenseImpact)
          .toList()
        ..sort((a, b) => b.compareTo(a));
  if (amounts.isEmpty) return null;

  var running = 0.0;
  for (var index = 0; index < amounts.length; index++) {
    running += amounts[index];
    if (running >= delta) return _Drivers(index + 1, amounts[index]);
  }
  return _Drivers(amounts.length, amounts.last);
}

/// Subscriptions whose price moved.
List<Insight> _priceChanges(
  FinanceSnapshot snapshot, {
  required Money money,
  double minChange = 1,
}) {
  final insights = <Insight>[];
  for (final charge in detectRecurring(snapshot)) {
    if (!charge.priceChanged) continue;
    final delta = charge.priceDelta;
    // A few cents of difference is rounding, not a price change.
    if (delta.abs() < minChange) continue;

    insights.add(
      Insight(
        id: 'price:${charge.merchant}',
        category: charge.category,
        tone: delta > 0 ? InsightTone.warning : InsightTone.good,
        // A monthly charge keeps costing the difference, so it is weighed
        // against a year rather than against a single month.
        weight: delta.abs() * 12,
        text: delta > 0
            ? '${charge.merchant} passou de ${money(charge.typicalAmount)} '
                  'para ${money(charge.latestAmount)} — '
                  '${money(delta.abs())} a mais por mês.'
            : '${charge.merchant} caiu de ${money(charge.typicalAmount)} '
                  'para ${money(charge.latestAmount)}.',
      ),
    );
  }
  return insights;
}

/// Invoices heading somewhere unusual.
List<Insight> _invoiceOutlook(
  FinanceSnapshot snapshot, {
  required Money money,
  DateTime? now,
  double minRatio = .2,
  int minPastInvoices = 2,
}) {
  final insights = <Insight>[];

  for (final forecast in forecastInvoices(snapshot, now: now)) {
    // Without a rate there is no forecast, only what is already committed —
    // and comparing that against past totals would call every open invoice a
    // saving.
    if (!forecast.hasBaseline || forecast.isClosed) continue;

    final past = snapshot.invoices
        .where(
          (invoice) =>
              invoice.cardId == forecast.card.id &&
              invoice.total > 0 &&
              invoice.referenceMonth.isBefore(forecast.competence),
        )
        .toList();
    if (past.length < minPastInvoices) continue;

    final average =
        past.fold<double>(0, (sum, invoice) => sum + invoice.total) /
        past.length;
    if (average <= 0) continue;

    final ratio = (forecast.total - average) / average;
    if (ratio.abs() < minRatio) continue;

    insights.add(
      Insight(
        id: 'invoice:${forecast.card.id}',
        tone: ratio > 0 ? InsightTone.warning : InsightTone.good,
        weight: (forecast.total - average).abs(),
        text: ratio > 0
            ? 'A fatura do ${forecast.card.name} deve fechar em torno de '
                  '${money(forecast.total)}, ${_percent(ratio)} acima da média '
                  'de ${money(average)}.'
            : 'A fatura do ${forecast.card.name} deve fechar em torno de '
                  '${money(forecast.total)}, ${_percent(ratio.abs())} abaixo '
                  'da média de ${money(average)}.',
      ),
    );
  }

  return insights;
}

/// Whole percents: the extra precision would imply the estimate is finer than
/// it is.
String _percent(double ratio) => '${(ratio * 100).round()}%';

String _count(int value, String one, String many) =>
    '$value ${value == 1 ? one : many}';
