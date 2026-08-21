@Tags(['golden'])
library;

import 'package:financeiro_ai/core/design_system/brand.dart';
import 'package:financeiro_ai/core/theme/theme.dart';
import 'package:financeiro_ai/features/ledger/infra/repositories/demo_finance_repository.dart';
import 'package:financeiro_ai/features/ledger/domain/entities/finance_period.dart';
import 'package:financeiro_ai/features/ledger/domain/entities/models.dart';
import 'package:financeiro_ai/features/transactions/domain/transaction_filter.dart';
import 'package:financeiro_ai/features/invoices/presenter/pages/cards_page.dart';
import 'package:financeiro_ai/features/catalog/presenter/pages/categories_page.dart';
import 'package:financeiro_ai/features/overview/presenter/pages/dashboard_page.dart';
import 'package:financeiro_ai/features/settings/presenter/pages/more_page.dart';
import 'package:financeiro_ai/features/invoices/presenter/pages/projection_page.dart';
import 'package:financeiro_ai/features/review/presenter/pages/review_queue_page.dart';
import 'package:financeiro_ai/features/overview/presenter/pages/today_page.dart';
import 'package:financeiro_ai/features/transactions/presenter/pages/transactions_page.dart';
import 'package:financeiro_ai/features/shell/presenter/pages/app_shell.dart';
import 'dart:async';
import 'package:financeiro_ai/core/design_system/loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';
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
      filter: const TransactionFilter(),
      onFilterChanged: _ignoreFilter,
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

  // The review queue is a screen in its own right and had no reference image
  // at all — the surface the owner reacted to was the one nobody could see.
  for (final entry in {
    '390': const Size(390, 844),
    '1280': const Size(1280, 900),
  }.entries) {
    testWidgets('revisao at ${entry.key}', (tester) async {
      await withGoldenClock(() async {
        await _pumpQueue(tester, entry.value);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/revisao-${entry.key}.png'),
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

  /// A marca, fotografada.
  ///
  /// O logo é código — um `CustomPainter`, não um asset — o que resolve o
  /// problema de ter dois arquivos que discordam e cria outro: um desenho que
  /// pode mudar sem ninguém ver. Estas duas imagens são o que impede isso.
  for (final entry in {
    'claro': Brightness.light,
    'escuro': Brightness.dark,
  }.entries) {
    testWidgets('a marca — ${entry.key}', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 220);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(brightness: entry.value),
          // `Material`, não um `ColoredBox` cru: fora de um ancestral Material
          // o Flutter desenha todo texto com o sublinhado amarelo de depuração
          // — e a primeira versão desta imagem registrou exatamente isso.
          home: Builder(
            builder: (context) => Material(
              color: context.palette.canvas,
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CompassoMark(size: 64),
                      SizedBox(height: 20),
                      CompassoWordmark(markSize: 30, tagline: true),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 60));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/marca-${entry.key}.png'),
      );
    });
  }

  /// Waiting, photographed.
  ///
  /// These are the states nobody ever screenshots, which is exactly why they
  /// were eighteen bare spinners and one skeleton that matched no page on the
  /// screen — nothing was ever looking at them. They are photographable at all
  /// because the pulse honours reduced motion: under `disableAnimations` it
  /// renders at its resting value rather than mid-tween.
  group('carregando', () {
    for (final entry in {
      '390': const Size(390, 900),
      '1440': const Size(1440, 1000),
    }.entries) {
      // Dark as well as light, because dark is what the app opens in. The
      // shell goldens were light-only, and the project has already been caught
      // once shipping a defect that only the unphotographed surface had.
      for (final brightness in Brightness.values) {
        final tone = brightness == Brightness.dark ? 'dark' : 'light';
        testWidgets('shell skeleton at ${entry.key} — $tone', (tester) async {
          await withGoldenClock(() async {
            SharedPreferences.setMockInitialValues(<String, Object>{});
            await _pumpLoading(tester, entry.value, brightness);
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                'goldens/carregando-shell-${entry.key}-$tone.png',
              ),
            );
          });
        });
      }
    }

    testWidgets('a list waiting for its rows', (tester) async {
      await withGoldenClock(() async {
        await _pumpWidget(
          tester,
          const Size(390, 560),
          const Scaffold(body: SkeletonList()),
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/carregando-lista-390.png'),
        );
      });
    });
  });
}

/// The shell before the ledger arrives.
///
/// A repository that never answers, so the first paint is held still. The demo
/// one resolves in milliseconds, which is why this state had no reference
/// image: no test could stop on it.
class _NeverAnswers extends DemoFinanceRepository {
  @override
  Future<FinanceCatalog> loadCatalog() => Completer<FinanceCatalog>().future;

  @override
  Future<FinanceLedger> loadLedger() => Completer<FinanceLedger>().future;
}

Future<void> _pumpLoading(
  WidgetTester tester,
  Size size, [
  Brightness brightness = Brightness.light,
]) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    withDependencies(
      repository: _NeverAnswers(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(brightness: brightness),
        home: MediaQuery(
          data: MediaQueryData(size: size, disableAnimations: true),
          child: const AppShell(),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _pumpWidget(WidgetTester tester, Size size, Widget child) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: MediaQuery(
        data: MediaQueryData(size: size, disableAnimations: true),
        child: child,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
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
    withDependencies(
      repository: DemoFinanceRepository(),
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
  // Past the animation, not into it.
  //
  // Eight pumps of 50ms was 400ms, exactly `Motion.count` — but the demo
  // repository sleeps before answering, so the progress ring beside "Hoje"
  // had not even started its sweep when the image was taken. The reference
  // recorded a frame of a running animation, which is a golden that moves
  // whenever anything upstream lands a frame earlier or later. Three seconds
  // clears the sleep and the 400ms tween together.
  for (var i = 0; i < 60; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _pumpQueue(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    withDependencies(
      repository: DemoFinanceRepository(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: MediaQuery(
          data: MediaQueryData(size: size, disableAnimations: true),
          child: const ReviewQueuePage(),
        ),
      ),
    ),
  );
  // Long enough for the queue, the ledger and any transition between them to
  // finish: a reference image caught mid-animation is a reference image that
  // fails at random.
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void _ignore(FinancePeriod _) {}

void _nothing() {}

void _ignoreFilter(TransactionFilter _) {}
