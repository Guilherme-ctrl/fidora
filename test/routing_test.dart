import 'package:financeiro_ai/features/transactions/presenter/filter_codec.dart';
import 'package:financeiro_ai/features/ledger/presenter/period_codec.dart';
import 'package:financeiro_ai/core/theme/theme.dart';
import 'package:financeiro_ai/features/ledger/infra/repositories/demo_finance_repository.dart';
import 'package:financeiro_ai/features/ledger/domain/entities/finance_period.dart';
import 'package:financeiro_ai/features/ledger/domain/entities/models.dart';
import 'package:financeiro_ai/features/transactions/domain/transaction_filter.dart';
import 'package:financeiro_ai/core/routing/router.dart';
import 'package:financeiro_ai/core/routing/routes.dart';
import 'package:financeiro_ai/features/review/presenter/pages/review_queue_page.dart';
import 'package:financeiro_ai/features/catalog/presenter/pages/accounts_page.dart';
import 'package:financeiro_ai/features/catalog/presenter/pages/holders_page.dart';
import 'package:financeiro_ai/features/invoices/presenter/pages/subscriptions_page.dart';
import 'package:financeiro_ai/features/invoices/presenter/pages/projection_page.dart';
import 'package:financeiro_ai/features/review/presenter/pages/merchant_rules_page.dart';
import 'package:financeiro_ai/features/reminders/presenter/pages/reminders_page.dart';
import 'package:financeiro_ai/features/settings/presenter/pages/shortcut_tokens_page.dart';
import 'package:financeiro_ai/features/imports/presenter/pages/data_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/golden.dart';

/// The first finding of the audit, tested.
///
/// `MaterialApp(home:)` meant the address bar never changed, Back left the
/// application, and F5 returned to tab zero having thrown away the period and
/// the filters.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('PeriodCodec', () {
    test('a whole month is written as a month', () {
      final period = FinancePeriod.month(DateTime(2026, 8));
      expect(PeriodCodec.encode(period), {'mes': '2026-08'});
    });

    test('a custom range keeps both ends', () {
      final period = FinancePeriod(
        start: DateTime(2026, 8, 3),
        endInclusive: DateTime(2026, 8, 17),
      );
      expect(PeriodCodec.encode(period), {
        'de': '2026-08-03',
        'ate': '2026-08-17',
      });
    });

    test('round-trips both shapes', () {
      for (final period in [
        FinancePeriod.month(DateTime(2026, 1)),
        FinancePeriod(
          start: DateTime(2025, 12, 20),
          endInclusive: DateTime(2026, 1, 5),
        ),
      ]) {
        expect(PeriodCodec.decode(PeriodCodec.encode(period)), period);
      }
    });

    test('nonsense in the address does not crash the screen', () {
      for (final params in [
        <String, String>{},
        {'mes': 'agosto'},
        {'mes': '2026-13'},
        {'de': '2026-08-10', 'ate': '2026-08-01'},
        {'de': 'ontem'},
      ]) {
        expect(PeriodCodec.decode(params), isNull);
      }
    });
  });

  group('FilterCodec', () {
    test('a clear filter leaves the address clean', () {
      expect(FilterCodec.encode(const TransactionFilter()), isEmpty);
    });

    test('round-trips everything it carries', () {
      const filter = TransactionFilter(
        query: 'mercado',
        ignorePeriod: true,
        cardFinals: {'1847'},
        categories: {'Mercado', 'Casa'},
        statuses: {TransactionStatus.pending},
        minAmount: 10,
        maxAmount: 500.5,
        onlyInstallments: true,
      );
      final decoded = FilterCodec.decode(FilterCodec.encode(filter));
      expect(decoded.query, 'mercado');
      expect(decoded.ignorePeriod, isTrue);
      expect(decoded.cardFinals, {'1847'});
      expect(decoded.categories, {'Mercado', 'Casa'});
      expect(decoded.statuses, {TransactionStatus.pending});
      expect(decoded.minAmount, 10);
      expect(decoded.maxAmount, 500.5);
      expect(decoded.onlyInstallments, isTrue);
    });

    test('an unknown status is dropped, not fatal', () {
      expect(FilterCodec.decode({'estado': 'inventado'}).statuses, isEmpty);
    });
  });

  group('Routes', () {
    test('every destination has an address, in navigation order', () {
      expect(Routes.inOrder, hasLength(7));
      for (var i = 0; i < Routes.inOrder.length; i++) {
        expect(Routes.indexOf(Routes.inOrder[i]), i);
      }
    });

    test('a sub-route stays on its destination', () {
      expect(Routes.indexOf('/transacoes/abc'), 2);
    });

    test('the period only rides where it means something', () {
      expect(Routes.isPeriodAware(Routes.dashboard), isTrue);
      expect(Routes.isPeriodAware(Routes.today), isFalse);
      expect(Routes.isPeriodAware(Routes.more), isFalse);
    });

    test('locationFor carries the period and drops it where it does not', () {
      final period = FinancePeriod.month(DateTime(2026, 8));
      expect(
        locationFor(Routes.dashboard, period: period),
        '/visao-geral?mes=2026-08',
      );
      expect(locationFor(Routes.today, period: period), '/hoje');
    });
  });

  group('The address bar', () {
    Future<GoRouter> pump(
      WidgetTester tester, {
      String at = Routes.today,
    }) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 1000);
      addTearDown(tester.view.reset);
      final router = buildRouter(initialLocation: at);
      addTearDown(router.dispose);
      await tester.pumpWidget(
        withDependencies(
          repository: DemoFinanceRepository(),
          child: MaterialApp.router(
            theme: buildAppTheme(),
            routerConfig: router,
          ),
        ),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      return router;
    }

    String where(GoRouter router) =>
        router.routerDelegate.currentConfiguration.uri.toString();

    /// Nine screens had no address at all.
    ///
    /// They were `Navigator.push` with a `MaterialPageRoute`, so none could be
    /// linked, none survived a reload, and the browser's Back button left the
    /// app rather than leaving them. The review queue was the worst of the
    /// nine: a daily ritual with no URL.
    for (final entry in {
      Routes.review: ReviewQueuePage,
      Routes.accounts: AccountsPage,
      Routes.holders: HoldersPage,
      Routes.subscriptions: SubscriptionsPage,
      Routes.merchantRules: MerchantRulesPage,
      Routes.reminders: RemindersPage,
      Routes.shortcutTokens: ShortcutTokensPage,
      Routes.data: DataPage,
      Routes.projectionDetail: ProjectionPage,
    }.entries) {
      testWidgets('${entry.key} opens ${entry.value} directly', (tester) async {
        // Landing on the address is what a reload and a pasted link both do.
        final router = await pump(tester, at: entry.key);

        expect(where(router), entry.key);
        expect(find.byType(entry.value), findsOneWidget);
      });
    }

    testWidgets('every overlay address is routed', (tester) async {
      // A guard against adding a constant and forgetting the route: an
      // unrouted address falls through to the error screen.
      for (final path in Routes.overlays) {
        final router = await pump(tester, at: path);
        expect(
          find.textContaining('não existe no Compasso'),
          findsNothing,
          reason: path,
        );
        expect(where(router), path);
      }
    });

    testWidgets('opening a destination changes the address', (tester) async {
      await withGoldenClock(() async {
        final router = await pump(tester);
        expect(where(router), Routes.today);

        router.go(
          locationFor(
            Routes.invoices,
            period: FinancePeriod.month(DateTime(2026, 8)),
          ),
        );
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(where(router), '/faturas?mes=2026-08');
      });
    });

    testWidgets('the browser is told where it is, on every move', (
      tester,
    ) async {
      await withGoldenClock(() async {
        final router = await pump(tester);
        final seen = <String>[];
        router.routerDelegate.addListener(() => seen.add(where(router)));

        for (final path in [
          Routes.transactions,
          Routes.invoices,
          Routes.more,
        ]) {
          router.go(path);
          for (var i = 0; i < 3; i++) {
            await tester.pump(const Duration(milliseconds: 50));
          }
        }

        // Each move reports a new location, which is what the browser turns
        // into a history entry — and what Back then walks back through.
        //
        // `popRoute` is deliberately not asserted here: the seven destinations
        // are sibling routes under one page key, so the Navigator holds a
        // single page and has nothing to pop. On the web the history belongs to
        // the browser, and go_router receives Back through
        // `setNewRoutePath`. That path is exercised below, and for real in a
        // browser — see `docs/aidlc/04-validation.md`.
        expect(
          seen,
          containsAllInOrder([
            Routes.transactions,
            Routes.invoices,
            Routes.more,
          ]),
        );
      });
    });

    testWidgets('the app follows the browser back to a previous address', (
      tester,
    ) async {
      await withGoldenClock(() async {
        final router = await pump(tester);
        router.go('/faturas?mes=2026-08');
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(where(router), '/faturas?mes=2026-08');

        // Exactly what the platform delivers when someone presses Back.
        await router.routeInformationProvider.didPushRouteInformation(
          RouteInformation(uri: Uri.parse('/visao-geral?mes=2026-07')),
        );
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(where(router), '/visao-geral?mes=2026-07');
      });
    });

    testWidgets('a reload lands on the same screen with the same month', (
      tester,
    ) async {
      await withGoldenClock(() async {
        // What F5 does: the app starts again at the address it was on.
        final router = await pump(tester, at: '/transacoes?mes=2026-06&q=uber');
        expect(where(router), '/transacoes?mes=2026-06&q=uber');
        expect(find.text('Histórico'), findsWidgets);
      });
    });

    testWidgets('an unknown address explains itself', (tester) async {
      await withGoldenClock(() async {
        await pump(tester, at: '/inventado');
        expect(find.textContaining('não existe no Compasso'), findsOneWidget);
      });
    });
  });
}
