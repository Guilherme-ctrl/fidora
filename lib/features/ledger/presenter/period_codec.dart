import 'package:financeiro_ai/features/ledger/domain/entities/finance_period.dart';

/// A period, in the query string.
///
/// A whole month is written as `?mes=2026-08` because that is what someone
/// pastes into a message; anything else keeps both ends.
abstract final class PeriodCodec {
  static Map<String, String> encode(FinancePeriod period) =>
      period.isSingleMonth
      ? {'mes': _month(period.start)}
      : {'de': _day(period.start), 'ate': _day(period.endInclusive)};

  static FinancePeriod? decode(Map<String, String> params) {
    final month = params['mes'];
    if (month != null) {
      final parsed = _parseMonth(month);
      if (parsed != null) return FinancePeriod.month(parsed);
    }
    final from = _parseDay(params['de']);
    final to = _parseDay(params['ate']);
    if (from != null && to != null && !to.isBefore(from)) {
      return FinancePeriod(start: from, endInclusive: to);
    }
    return null;
  }

  static String _month(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}';

  static String _day(DateTime date) =>
      '${_month(date)}-${date.day.toString().padLeft(2, '0')}';

  static DateTime? _parseMonth(String value) {
    final parts = value.split('-');
    if (parts.length != 2) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null || month < 1 || month > 12) return null;
    return DateTime(year, month);
  }

  static DateTime? _parseDay(String? value) {
    if (value == null) return null;
    final parts = value.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    return DateTime(year, month, day);
  }
}
