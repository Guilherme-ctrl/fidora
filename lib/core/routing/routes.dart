import 'package:financeiro_ai/features/overview/domain/analytics.dart';
import 'package:financeiro_ai/features/ledger/domain/entities/models.dart';
import 'package:financeiro_ai/features/transactions/domain/transaction_filter.dart';

/// The address of every screen, and the codec that puts state in it.
///
/// `MaterialApp(home:)` meant the address bar never changed: Back left the
/// application, F5 returned to tab zero and threw away the period and the
/// filters, and nothing — not a month, not a search, not an invoice — could be
/// linked or opened in a second tab.
///
/// Kept apart from the router itself so the encoding can be tested without
/// pumping a widget.
abstract final class Routes {
  static const today = '/hoje';
  static const dashboard = '/visao-geral';
  static const transactions = '/transacoes';
  static const categories = '/categorias';
  static const invoices = '/faturas';
  static const projection = '/projecao';
  static const more = '/mais';

  /// One transaction, by id. Opens on top of the history.
  static String transaction(String id) => '$transactions/$id';

  /// The screens that open on top of the shell.
  ///
  /// Nine of the sixteen screens had no address at all: they were reached with
  /// `Navigator.push` and a `MaterialPageRoute`, so they could not be linked,
  /// did not survive a reload, and the browser's Back button left the app
  /// instead of leaving them. The review queue is the worst of the nine — it
  /// is a daily ritual with no URL.
  ///
  /// They hang off `/mais` because that is where all but one are reached from,
  /// except the queue: it is also reached from Hoje and is a destination in its
  /// own right.
  static const review = '/revisao';
  static const accounts = '/mais/contas';
  static const holders = '/mais/titulares';
  static const subscriptions = '/mais/assinaturas';
  static const merchantRules = '/mais/regras';
  static const reminders = '/mais/lembretes';
  static const shortcutTokens = '/mais/tokens';
  static const data = '/mais/dados';
  static const projectionDetail = '/mais/projecao';

  /// Addresses that render over the shell rather than inside it.
  static const overlays = [
    review,
    accounts,
    holders,
    subscriptions,
    merchantRules,
    reminders,
    shortcutTokens,
    data,
    projectionDetail,
  ];

  /// In the order the navigation shows them, so an index and a path are two
  /// views of the same thing.
  static const inOrder = [
    today,
    dashboard,
    transactions,
    categories,
    invoices,
    projection,
    more,
  ];

  static int indexOf(String location) {
    final path = Uri.parse(location).path;
    for (var i = inOrder.length - 1; i >= 0; i--) {
      if (path == inOrder[i] || path.startsWith('${inOrder[i]}/')) return i;
    }
    return 0;
  }

  /// The screens whose contents depend on the selected period.
  static bool isPeriodAware(String location) =>
      indexOf(location) >= 1 && indexOf(location) <= 5;
}

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

/// The history filter, in the query string, so a slice of the ledger is a link.
///
/// Only what is set appears — a clear filter leaves the address clean.
abstract final class FilterCodec {
  static Map<String, String> encode(TransactionFilter filter) => {
    if (filter.query.trim().isNotEmpty) 'q': filter.query.trim(),
    if (filter.ignorePeriod) 'todoPeriodo': '1',
    if (filter.cardFinals.isNotEmpty) 'cartao': filter.cardFinals.join(','),
    if (filter.categories.isNotEmpty) 'categoria': filter.categories.join(','),
    if (filter.statuses.isNotEmpty)
      'estado': filter.statuses.map((s) => s.name).join(','),
    if (filter.minAmount != null) 'min': _amount(filter.minAmount!),
    if (filter.maxAmount != null) 'max': _amount(filter.maxAmount!),
    if (filter.onlyInstallments) 'parcelado': '1',
  };

  static TransactionFilter decode(Map<String, String> params) =>
      TransactionFilter(
        query: params['q'] ?? '',
        ignorePeriod: params['todoPeriodo'] == '1',
        cardFinals: _set(params['cartao']),
        categories: _set(params['categoria']),
        statuses: _set(params['estado'])
            .map(
              (name) => TransactionStatus.values
                  .where((value) => value.name == name)
                  .firstOrNull,
            )
            .whereType<TransactionStatus>()
            .toSet(),
        minAmount: double.tryParse(params['min'] ?? ''),
        maxAmount: double.tryParse(params['max'] ?? ''),
        onlyInstallments: params['parcelado'] == '1',
      );

  static Set<String> _set(String? value) => (value == null || value.isEmpty)
      ? const {}
      : value.split(',').where((part) => part.isNotEmpty).toSet();

  static String _amount(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';
}
