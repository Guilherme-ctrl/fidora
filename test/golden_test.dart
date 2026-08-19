@Tags(['golden'])
library;

import 'package:financeiro_ai/application/providers.dart';
import 'package:financeiro_ai/core/theme.dart';
import 'package:financeiro_ai/data/demo_finance_repository.dart';
import 'package:financeiro_ai/domain/analytics.dart';
import 'package:financeiro_ai/domain/models.dart';
import 'package:financeiro_ai/presentation/pages/cards_page.dart';
import 'package:financeiro_ai/presentation/pages/categories_page.dart';
import 'package:financeiro_ai/presentation/pages/dashboard_page.dart';
import 'package:financeiro_ai/presentation/pages/more_page.dart';
import 'package:financeiro_ai/presentation/pages/projection_page.dart';
import 'package:financeiro_ai/presentation/pages/today_page.dart';
import 'package:financeiro_ai/presentation/pages/transactions_page.dart';
import 'package:financeiro_ai/presentation/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/golden.dart';

/// The reference images this remake is measured against.
///
/// They are not a correctness gate — every one of them is expected to change,
/// and that is the point: the diff between these files and the ones the design
/// system produces *is* the design review. Reading a 3,000-line diff of Dart
/// cannot tell anyone whether the spacing got better.
///
/// They are excluded from CI because a golden rendered on macOS does not match
/// one rendered on Linux. Run them locally:
///
/// ```sh
/// flutter test --tags golden                     # compare
/// flutter test --tags golden --update-goldens    # accept
/// ```
///
/// Text renders as boxes: the test environment has no real font loaded, and
/// the product has none bundled yet. So these record layout, spacing, colour
/// and hierarchy — which is most of what changes — and start recording
/// letterforms once the fonts land and `flutter_test_config.dart` loads them.
void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  late FinanceSnapshot snapshot;

  setUp(() async {
    await withGoldenClock(() async {
      snapshot = await DemoFinanceRepository().loadSnapshot();
    });
  });

  Widget page(String name) => switch (name) {
    'hoje' => TodayPage(
      snapshot: snapshot,
      period: goldenPeriod,
      onOpenInvoices: _nothing,
    ),
    'visao-geral' => DashboardPage(
      snapshot: snapshot,
      period: goldenPeriod,
      onPeriodChanged: _ignore,
    ),
    'historico' => TransactionsPage(
      snapshot: snapshot,
      period: goldenPeriod,
      onPeriodChanged: _ignore,
    ),
    'categorias' => CategoriesPage(
      snapshot: snapshot,
      period: goldenPeriod,
      onPeriodChanged: _ignore,
    ),
    'faturas' => CardsPage(snapshot: snapshot, period: goldenPeriod),
    'mais' => MorePage(snapshot: snapshot, period: goldenPeriod),
    'projecao' => ProjectionPage(
      snapshot: snapshot,
      period: goldenPeriod,
      onPeriodChanged: _ignore,
    ),
    _ => throw ArgumentError('unknown page $name'),
  };

  const pages = [
    'hoje',
    'visao-geral',
    'historico',
    'categorias',
    'faturas',
    'mais',
    'projecao',
  ];

  for (final name in pages) {
    for (final entry in goldenWidths.entries) {
      testWidgets('$name at ${entry.key} — light', (tester) async {
        await withGoldenClock(() async {
          await pumpGolden(tester, page(name), size: entry.value);
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/$name-${entry.key}-light.png'),
          );
        });
      });
    }

    // Dark is captured at one width only. It shares every layout decision with
    // light; what it can regress on its own is colour.
    testWidgets('$name at 1440 — dark', (tester) async {
      await withGoldenClock(() async {
        await pumpGolden(
          tester,
          page(name),
          size: goldenWidths['1440']!,
          brightness: Brightness.dark,
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/$name-1440-dark.png'),
        );
      });
    });
  }

  for (final entry in {
    '390': const Size(390, 900),
    '768': const Size(768, 1024),
    '1440': const Size(1440, 1000),
  }.entries) {
    testWidgets('shell at ${entry.key}', (tester) async {
      await withGoldenClock(() async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        await _pumpShell(tester, entry.value);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/shell-${entry.key}.png'),
        );
      });
    });
  }
}

/// The shell itself, which the page goldens cannot see.
///
/// PR 3's whole change is navigation, and every other golden pumps a page in
/// isolation — so without this the sidebar, the rail and the tab bar would have
/// no reference image at all.
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
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: MediaQuery(
          data: MediaQueryData(size: size, disableAnimations: true),
          child: const AppShell(),
        ),
      ),
    ),
  );
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void _ignore(FinancePeriod _) {}

void _nothing() {}
