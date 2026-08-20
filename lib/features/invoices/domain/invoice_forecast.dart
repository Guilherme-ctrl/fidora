import 'package:clock/clock.dart';
import 'package:financeiro_ai/features/ledger/domain/finance_rules.dart';
import 'package:financeiro_ai/features/ledger/domain/entities/models.dart';

/// What the invoice still accumulating is likely to total when it closes.
///
/// Split into three parts on purpose, because they are known with very
/// different confidence: what was already captured is a fact, the instalments
/// still to land are a commitment already made to the issuer, and only the
/// third part is a guess. A single number would hide which is which.
class InvoiceForecast {
  const InvoiceForecast({
    required this.card,
    required this.competence,
    required this.closingDate,
    required this.committed,
    required this.scheduled,
    required this.estimated,
    required this.dailyRate,
    required this.daysRemaining,
    required this.daysObserved,
  });

  final CreditCard card;

  /// The month this invoice belongs to, by the closing-day rule.
  final DateTime competence;

  /// Last day a purchase still falls into this invoice.
  final DateTime closingDate;

  /// Already captured against this competence. A fact, not a guess.
  final double committed;

  /// Instalments that will land in this invoice but have not been captured
  /// yet. Agreed with the issuer, so they arrive whether or not anyone spends.
  final double scheduled;

  /// Expected further spending until closing, from this card's own recent
  /// rhythm. Zero once the cycle has closed, and zero without a baseline.
  final double estimated;

  /// Daily non-instalment spend over the observed cycles, or null when there
  /// were none to observe.
  final double? dailyRate;

  final int daysRemaining;

  /// How many days of past cycles the rate was drawn from. Reported so the
  /// screen can say how thin the evidence is instead of implying certainty.
  final int daysObserved;

  double get total => committed + scheduled + estimated;

  /// The part that does not depend on anyone's behaviour from here on.
  double get known => committed + scheduled;

  /// Whether there was any history to estimate from. Without it the forecast
  /// is just [known], and the screen should say so rather than present a
  /// coincidence as a projection.
  bool get hasBaseline => dailyRate != null;

  /// True once nothing more can land in this invoice.
  bool get isClosed => daysRemaining <= 0;
}

/// Forecasts the open invoice for [card].
///
/// Returns null when the card has no limit-bearing history at all — no
/// captured purchase and no instalment due — because a forecast of zero is
/// indistinguishable from a card nobody uses.
InvoiceForecast? forecastInvoice(
  FinanceSnapshot snapshot,
  CreditCard card, {
  DateTime? now,
  int cycles = 3,
}) {
  final moment = now ?? clock.now();
  final today = DateTime(moment.year, moment.month, moment.day);
  final competence = invoiceCompetence(today, card.closingDay);
  final closingDate = _closingDate(competence, card.closingDay);

  final onCard = snapshot.transactions
      .where(
        (item) =>
            item.status != TransactionStatus.ignored &&
            item.isCard &&
            item.cardLastFour == card.lastFour,
      )
      .toList();

  // The invoice is what the issuer will bill, so it uses the full amount and
  // ignores who the spend is attributed to. `personalShare` answers a
  // different question and would understate the bill.
  final committed = onCard
      .where((item) => _competenceOf(item, card) == competence)
      .fold<double>(0, (sum, item) => sum + item.amount);

  final scheduled = _scheduledFor(onCard, card, competence);

  final daysRemaining = closingDate.difference(today).inDays;
  final rate = _dailyRate(onCard, card, competence, cycles: cycles);

  if (committed == 0 && scheduled == 0 && rate == null) return null;

  return InvoiceForecast(
    card: card,
    competence: competence,
    closingDate: closingDate,
    committed: committed,
    scheduled: scheduled,
    estimated: rate == null || daysRemaining <= 0
        ? 0
        : rate.perDay * daysRemaining,
    dailyRate: rate?.perDay,
    daysRemaining: daysRemaining < 0 ? 0 : daysRemaining,
    daysObserved: rate?.days ?? 0,
  );
}

/// Every card's forecast, heaviest first, skipping cards with no history.
List<InvoiceForecast> forecastInvoices(
  FinanceSnapshot snapshot, {
  DateTime? now,
  int cycles = 3,
}) =>
    snapshot.cards
        .map(
          (card) => forecastInvoice(snapshot, card, now: now, cycles: cycles),
        )
        .whereType<InvoiceForecast>()
        .toList()
      ..sort((a, b) => b.total.compareTo(a.total));

class _Rate {
  const _Rate(this.perDay, this.days);
  final double perDay;
  final int days;
}

/// Daily spend drawn from complete past cycles of this same card.
///
/// Cycles rather than calendar months because an invoice *is* a cycle: a card
/// closing on the 20th collects the tail of one month and the head of the
/// next, and a calendar average would misplace roughly a third of the spend.
///
/// Instalments are excluded here and counted separately; folding them into the
/// rate would bill them twice, once as rhythm and once as commitment.
_Rate? _dailyRate(
  List<FinanceTransaction> onCard,
  CreditCard card,
  DateTime competence, {
  required int cycles,
}) {
  var total = 0.0;
  var days = 0;

  for (var index = 1; index <= cycles; index++) {
    final month = DateTime(competence.year, competence.month - index);
    final end = _closingDate(month, card.closingDay);
    final start = _closingDate(
      DateTime(month.year, month.month - 1),
      card.closingDay,
    );
    final spanDays = end.difference(start).inDays;
    if (spanDays <= 0) continue;

    // A cycle the data never covered is not evidence of thrift. A cycle that
    // was observed and holds only instalments is: it contributes its days with
    // zero rhythm, which correctly drags the rate down.
    if (!_hasCycle(onCard, card, month)) continue;

    total += onCard
        .where(
          (item) =>
              !item.isInstallment &&
              item.movementType == 'purchase' &&
              _competenceOf(item, card) == month,
        )
        .fold<double>(0, (sum, item) => sum + item.amount);
    days += spanDays;
  }

  return days == 0 ? null : _Rate(total / days, days);
}

/// Whether this cycle was observed at all, as opposed to predating the data.
///
/// Without this, months before the first import would each contribute thirty
/// days of zero spending and halve the rate.
bool _hasCycle(
  List<FinanceTransaction> onCard,
  CreditCard card,
  DateTime month,
) => onCard.any((item) => _competenceOf(item, card) == month);

/// Instalments landing in [competence] that have not been captured yet.
///
/// Collapses each purchase to its furthest captured instalment — the same key
/// the projection uses, deliberately, so the two cannot disagree about what is
/// outstanding. An offset of zero means this month's instalment is already
/// captured and therefore already inside `committed`.
double _scheduledFor(
  List<FinanceTransaction> onCard,
  CreditCard card,
  DateTime competence,
) {
  final furthest = <String, FinanceTransaction>{};
  for (final item in onCard) {
    if (!item.isInstallment ||
        item.movementType != 'purchase' ||
        item.installmentCurrent == null) {
      continue;
    }
    final key = '${item.merchant}|${item.amount}|${item.installmentTotal}';
    final existing = furthest[key];
    if (existing == null ||
        item.installmentCurrent! > existing.installmentCurrent!) {
      furthest[key] = item;
    }
  }

  var total = 0.0;
  for (final item in furthest.values) {
    final current = item.installmentCurrent ?? 0;
    final last = item.installmentTotal ?? 0;
    final from = _competenceOf(item, card);
    final offset =
        (competence.year - from.year) * 12 + competence.month - from.month;
    if (offset >= 1 && current + offset <= last) total += item.amount;
  }
  return total;
}

DateTime _competenceOf(FinanceTransaction item, CreditCard card) =>
    item.competence ?? invoiceCompetence(item.date, card.closingDay);

/// The last day a purchase still falls into the invoice for [competence].
///
/// Clamped to the length of the month, so a card closing on the 31st does not
/// silently roll into the first of the next month in February.
DateTime _closingDate(DateTime competence, int closingDay) {
  final lastDay = DateTime(competence.year, competence.month + 1, 0).day;
  return DateTime(
    competence.year,
    competence.month,
    closingDay > lastDay ? lastDay : closingDay,
  );
}
