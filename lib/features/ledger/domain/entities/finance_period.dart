import 'package:intl/intl.dart';

/// A window over the ledger.
///
/// It lived in `overview/domain/analytics.dart`, which made it a concept
/// belonging to one screen — and then eight other features and two files in
/// `core` imported it, because it is not: a period is what every screen in
/// this product filters by. `core/design_system` depending on the overview
/// feature was the clearest sign that it was in the wrong place.

class FinancePeriod {
  FinancePeriod({required DateTime start, required DateTime endInclusive})
    : start = DateTime(start.year, start.month, start.day),
      endExclusive = DateTime(
        endInclusive.year,
        endInclusive.month,
        endInclusive.day + 1,
      );

  FinancePeriod.month(DateTime month)
    : start = DateTime(month.year, month.month),
      endExclusive = DateTime(month.year, month.month + 1);

  final DateTime start;
  final DateTime endExclusive;

  DateTime get endInclusive => endExclusive.subtract(const Duration(days: 1));
  bool get isSingleMonth =>
      start.day == 1 &&
      endExclusive.day == 1 &&
      endExclusive == DateTime(start.year, start.month + 1);

  bool contains(DateTime date) =>
      !date.isBefore(start) && date.isBefore(endExclusive);

  FinancePeriod shiftMonth(int delta) =>
      FinancePeriod.month(DateTime(start.year, start.month + delta));

  /// The comparable window immediately before this one: the previous calendar
  /// month for a month, or a same-length range ending the day before [start].
  FinancePeriod get previous {
    if (isSingleMonth) return shiftMonth(-1);
    final days = endExclusive.difference(start).inDays;
    final end = start.subtract(const Duration(days: 1));
    return FinancePeriod(
      start: end.subtract(Duration(days: days - 1)),
      endInclusive: end,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FinancePeriod &&
      other.start == start &&
      other.endExclusive == endExclusive;

  @override
  int get hashCode => Object.hash(start, endExclusive);

  String get label {
    if (isSingleMonth) {
      return DateFormat('MMMM yyyy', 'pt_BR').format(start);
    }
    final formatter = DateFormat('dd/MM/yyyy', 'pt_BR');
    return '${formatter.format(start)} – ${formatter.format(endInclusive)}';
  }
}
