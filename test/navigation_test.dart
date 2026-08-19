import 'package:financeiro_ai/application/providers.dart';
import 'package:financeiro_ai/core/breakpoints.dart';
import 'package:financeiro_ai/core/theme.dart';
import 'package:financeiro_ai/data/demo_finance_repository.dart';
import 'package:financeiro_ai/presentation/app_shell.dart';
import 'package:financeiro_ai/presentation/widgets/navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/golden.dart';

/// The navigation the remake replaced was the phone's, shown twice.
///
/// `NavigationRail` was handed the same five destinations as the bottom bar —
/// a Material maximum written for a 360pt screen — so a 27-inch monitor also
/// got a "Mais" menu holding eleven real destinations.
Future<void> _pumpShell(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        financeRepositoryProvider.overrideWithValue(DemoFinanceRepository()),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: MediaQuery(
          // Indeterminate: the shell shows a LinearProgressIndicator while the
          // snapshot loads, and `pumpAndSettle` never returns while one spins.
          data: MediaQueryData(size: size, disableAnimations: true),
          child: const AppShell(),
        ),
      ),
    ),
  );
  // The snapshot arrives asynchronously and `pumpAndSettle` cannot be used
  // while an indeterminate progress bar is on screen, so pump a bounded number
  // of frames instead.
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

late int pending;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
    // The sidebar footer reads the stored theme choice; without this the
    // platform channel is missing and the test hangs rather than failing.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final snapshot = await withGoldenClock(
      () => DemoFinanceRepository().loadSnapshot(),
    );
    pending = snapshot.pendingReviews;
    expect(
      pending,
      greaterThan(0),
      reason: 'the demo needs a pending review for the badge to mean anything',
    );
  });

  group('Breakpoints', () {
    test('one scale replaces eleven thresholds', () {
      expect(Breakpoint.forWidth(599), Breakpoint.compact);
      expect(Breakpoint.forWidth(600), Breakpoint.medium);
      expect(Breakpoint.forWidth(904), Breakpoint.medium);
      expect(Breakpoint.forWidth(905), Breakpoint.expanded);
      expect(Breakpoint.forWidth(1239), Breakpoint.expanded);
      expect(Breakpoint.forWidth(1240), Breakpoint.large);
    });

    test('an iPad in portrait is not handed the phone layout', () {
      // 768 used to fall below the shell's single `width >= 900`, so a tablet
      // and a resized browser window both got the bottom bar and the floating
      // button.
      expect(Breakpoint.forWidth(768).hasRail, isTrue);
      expect(Breakpoint.forWidth(768).isPhone, isFalse);
    });

    test('only the widest layout gets the side panel and the table', () {
      expect(Breakpoint.large.hasSidebar, isTrue);
      expect(Breakpoint.expanded.hasSidebar, isFalse);
      expect(Breakpoint.expanded.hasTable, isTrue);
      expect(Breakpoint.medium.hasTable, isFalse);
    });
  });

  group('The four spaces', () {
    test('every destination belongs to one', () {
      expect(destinations.map((d) => d.space).toSet().length, 4);
    });

    test('the review queue is a destination, not a menu entry', () {
      final first = destinations.first;
      expect(first.space, NavSpace.today);
      expect(first.withBadge(4).badge, 4);
    });

    test('projection left the junk drawer', () {
      final projection = destinations.firstWhere((d) => d.label == 'Projeção');
      expect(projection.space, NavSpace.future);
    });
  });

  testWidgets('a phone gets the tab bar and no sidebar', (tester) async {
    await withGoldenClock(() async {
      await _pumpShell(tester, const Size(390, 900));
      expect(find.byType(LedgerTabBar), findsOneWidget);
      expect(find.byType(LedgerSidebar), findsNothing);
    });
  });

  testWidgets('a tablet gets the icon rail, not the tab bar', (tester) async {
    await withGoldenClock(() async {
      await _pumpShell(tester, const Size(768, 1024));
      expect(find.byType(LedgerSidebar), findsOneWidget);
      expect(find.byType(LedgerTabBar), findsNothing);
    });
  });

  testWidgets('a desktop names every destination', (tester) async {
    await withGoldenClock(() async {
      await _pumpShell(tester, const Size(1440, 1000));
      expect(find.byType(LedgerSidebar), findsOneWidget);
      for (final item in destinations) {
        expect(
          find.text(item.label),
          findsWidgets,
          reason: '${item.label} is not visible on a desktop',
        );
      }
      // The four space labels head the groups.
      for (final space in NavSpace.values) {
        expect(find.text(space.label.toUpperCase()), findsWidgets);
      }
    });
  });

  testWidgets('the pending count reaches the navigation', (tester) async {
    // The count comes from the snapshot loaded in setUp, not from awaiting a
    // repository inside the test: a widget test runs in a fake-async zone, and
    // an unpumped future there never completes.
    await withGoldenClock(() async {
      await _pumpShell(tester, const Size(1440, 1000));
      expect(find.text('$pending'), findsWidgets);
    });
  });
}
