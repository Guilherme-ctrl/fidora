
/// The address of every screen.
///
/// Paths only. The codecs that put a period and a filter into the query string
/// moved to the features that own those types: `core` may not depend on
/// `features`, and encoding a `FinancePeriod` is knowledge about the ledger,
/// not about routing.
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
