import 'package:financeiro_ai/features/overview/domain/analytics.dart';
import 'package:financeiro_ai/features/shell/presenter/pages/app_shell.dart';
import 'package:financeiro_ai/features/auth/presenter/pages/auth_gate.dart';
import 'package:financeiro_ai/core/routing/routes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The router.
///
/// Every destination is a real address, and the period and the history filter
/// live in the query string — so a month, a search or a slice of the ledger is
/// a link, F5 returns to the same screen with the same selection, and the
/// browser's Back button moves inside the app instead of leaving it.
///
/// All seven destinations build the same [AppShell] under the same page key.
/// That is deliberate: with one key the element is reused across routes, so the
/// `IndexedStack` keeps each screen's scroll position, and there is no page
/// transition between tabs — which is what a sidebar should feel like.
GoRouter buildRouter({
  bool useSupabase = false,
  String initialLocation = Routes.today,
}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(path: '/', redirect: (_, _) => Routes.today),
    for (final path in Routes.inOrder)
      GoRoute(
        path: path,
        pageBuilder: (context, state) => _shell(state, useSupabase),
        routes: [
          if (path == Routes.transactions)
            GoRoute(
              path: ':id',
              pageBuilder: (context, state) => _shell(
                state,
                useSupabase,
                openTransactionId: state.pathParameters['id'],
              ),
            ),
        ],
      ),
  ],
  errorBuilder: (context, state) =>
      _UnknownRoute(location: state.uri.toString()),
);

NoTransitionPage<void> _shell(
  GoRouterState state,
  bool useSupabase, {
  String? openTransactionId,
}) {
  final params = state.uri.queryParameters;
  final shell = AppShell(
    index: Routes.indexOf(state.uri.path),
    period: PeriodCodec.decode(params),
    filter: FilterCodec.decode(params),
    openTransactionId: openTransactionId,
  );
  return NoTransitionPage(
    // One key for every destination: the shell element survives the change of
    // route, and with it the scroll position of each screen.
    key: const ValueKey('shell'),
    child: useSupabase ? AuthGate(child: shell) : shell,
  );
}

class _UnknownRoute extends StatelessWidget {
  const _UnknownRoute({required this.location});
  final String location;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Esse endereço não existe no Finora.'),
            const SizedBox(height: 12),
            Text(location, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go(Routes.today),
              child: const Text('Ir para Hoje'),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Where a destination lives, carrying the current period and filter with it.
///
/// Changing screen must not throw away the month someone selected, and it used
/// to: the period lived in the shell's state and every page had its own copy.
String locationFor(
  String path, {
  FinancePeriod? period,
  Map<String, String> extra = const {},
}) {
  final query = <String, String>{
    if (period != null && Routes.isPeriodAware(path))
      ...PeriodCodec.encode(period),
    ...extra,
  };
  return Uri(
    path: path,
    queryParameters: query.isEmpty ? null : query,
  ).toString();
}
