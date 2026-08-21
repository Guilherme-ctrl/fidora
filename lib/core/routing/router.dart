import 'package:financeiro_ai/features/transactions/presenter/filter_codec.dart';
import 'package:financeiro_ai/features/ledger/presenter/period_codec.dart';
import 'package:financeiro_ai/features/ledger/domain/entities/finance_period.dart';
import 'package:financeiro_ai/features/shell/presenter/pages/app_shell.dart';
import 'package:financeiro_ai/features/auth/presenter/pages/auth_gate.dart';
import 'package:clock/clock.dart';
import 'package:financeiro_ai/core/routing/routes.dart';
import 'package:financeiro_ai/features/catalog/presenter/pages/accounts_page.dart';
import 'package:financeiro_ai/features/catalog/presenter/pages/holders_page.dart';
import 'package:financeiro_ai/features/imports/presenter/pages/data_page.dart';
import 'package:financeiro_ai/features/invoices/presenter/pages/projection_page.dart';
import 'package:financeiro_ai/features/invoices/presenter/pages/subscriptions_page.dart';
import 'package:financeiro_ai/features/ledger/domain/entities/models.dart';
import 'package:financeiro_ai/features/ledger/presenter/cubits/finance_cubit.dart';
import 'package:financeiro_ai/features/reminders/presenter/pages/reminders_page.dart';
import 'package:financeiro_ai/features/review/presenter/pages/merchant_rules_page.dart';
import 'package:financeiro_ai/features/review/presenter/pages/review_queue_page.dart';
import 'package:financeiro_ai/features/settings/presenter/pages/shortcut_tokens_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:financeiro_ai/core/design_system/loading.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The router.
///
/// Every destination is a real address, and the period and the history filter
/// live in the query string — so a month, a search or a slice of the ledger is
/// a link, F5 returns to the same screen with the same selection, and the
/// browser's Back button moves inside the app instead of leaving it.
///
/// The seven shell destinations build the same [AppShell] under the same page
/// key. That is deliberate: with one key the element is reused across routes,
/// so the `IndexedStack` keeps each screen's scroll position, and there is no
/// page transition between tabs — which is what a sidebar should feel like.
///
/// The nine in [Routes.overlays] are full screens that open over it. They used
/// to be `Navigator.push` with a `MaterialPageRoute`, which is why nine of the
/// sixteen screens had no address, did not survive a reload and could not be
/// linked.
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
    for (final path in Routes.overlays)
      GoRoute(
        path: path,
        builder: (context, state) => _guard(_overlayFor(path), useSupabase),
      ),
  ],
  errorBuilder: (context, state) =>
      _UnknownRoute(location: state.uri.toString()),
);

/// The screen behind each overlay address.
///
/// Every one of them needs the ledger, which arrives asynchronously, so they
/// are wrapped in [_WithSnapshot] rather than handed a snapshot the route
/// cannot have yet.
Widget _overlayFor(String path) => _WithSnapshot(
  builder: (context, snapshot) => switch (path) {
    Routes.review => const ReviewQueuePage(),
    Routes.merchantRules => const MerchantRulesPage(),
    Routes.shortcutTokens => const ShortcutTokensPage(),
    Routes.accounts => AccountsPage(snapshot: snapshot),
    Routes.holders => HoldersPage(snapshot: snapshot),
    Routes.subscriptions => SubscriptionsPage(snapshot: snapshot),
    Routes.reminders => RemindersPage(snapshot: snapshot),
    Routes.data => DataPage(snapshot: snapshot),
    Routes.projectionDetail => Scaffold(
      appBar: AppBar(title: const Text('Projeção')),
      body: ProjectionPage(
        snapshot: snapshot,
        period: FinancePeriod.month(clock.now()),
        onPeriodChanged: (_) {},
      ),
    ),
    _ => const SizedBox.shrink(),
  },
);

Widget _guard(Widget child, bool useSupabase) =>
    useSupabase ? AuthGate(child: child) : child;

/// Waits for the ledger, then builds.
class _WithSnapshot extends StatelessWidget {
  const _WithSnapshot({required this.builder});

  final Widget Function(BuildContext, FinanceSnapshot) builder;

  @override
  Widget build(BuildContext context) {
    final snapshot = context.watch<FinanceCubit>().state.snapshot;
    if (snapshot == null) {
      return const Scaffold(body: SkeletonList());
    }
    return builder(context, snapshot);
  }
}

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
