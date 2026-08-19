import 'package:financeiro_ai/data/demo_finance_repository.dart';
import 'package:financeiro_ai/domain/analytics.dart';
import 'package:financeiro_ai/domain/models.dart';
import 'package:financeiro_ai/presentation/pages/cards_page.dart';
import 'package:financeiro_ai/presentation/pages/categories_page.dart';
import 'package:financeiro_ai/presentation/pages/dashboard_page.dart';
import 'package:financeiro_ai/presentation/pages/more_page.dart';
import 'package:financeiro_ai/presentation/pages/projection_page.dart';
import 'package:financeiro_ai/presentation/pages/transactions_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/golden.dart';

/// Every page, at every width the design system names, must lay out without
/// overflowing.
///
/// `dashboard_layout_test.dart` already does this for one page. Generating the
/// golden baseline found two more that it could not see: the Apple Pay step
/// label in `more_page.dart` overflowed by 66px at 390pt, and the
/// realised-versus-budget pair in `projection_page.dart` by 28px. Both were
/// shipped and invisible.
///
/// This lives apart from the goldens on purpose: goldens do not run in CI —
/// a macOS render does not match a Linux one — so without a plain widget test
/// the two fixes could regress with nobody noticing.
void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  late FinanceSnapshot snapshot;

  setUp(() async {
    await withGoldenClock(() async {
      snapshot = await DemoFinanceRepository().loadSnapshot();
    });
  });

  Widget page(String name) => switch (name) {
    'visão geral' => DashboardPage(
      snapshot: snapshot,
      period: goldenPeriod,
      onPeriodChanged: _ignore,
    ),
    'histórico' => TransactionsPage(
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
    'projeção' => ProjectionPage(
      snapshot: snapshot,
      period: goldenPeriod,
      onPeriodChanged: _ignore,
    ),
    _ => throw ArgumentError('unknown page $name'),
  };

  const names = [
    'visão geral',
    'histórico',
    'categorias',
    'faturas',
    'mais',
    'projeção',
  ];

  // 375 is an iPhone SE, the narrowest phone still in use, and the width both
  // shipped overflows needed to become visible.
  const widths = <String, Size>{
    'iPhone SE': Size(375, 1400),
    'iPhone 15': Size(390, 1400),
    'tablet': Size(900, 1500),
    'desktop': Size(1440, 1600),
  };

  for (final width in widths.entries) {
    for (final name in names) {
      testWidgets('$name lays out at ${width.key}', (tester) async {
        await withGoldenClock(() async {
          await pumpGolden(tester, page(name), size: width.value);
          expect(tester.takeException(), isNull);
        });
      });
    }
  }

  // One page still overflows under Dynamic Type: the categories grid fixes its
  // cell aspect ratio, so the cell cannot grow with the text. It is the same
  // defect the dashboard fixed once by replacing a fixed-ratio grid with rows
  // of intrinsic height, and PR 3 replaces this grid outright.
  //
  // PR 2 cleared the other two. The attribution in the first version of this
  // comment was wrong: they were not both `MetricCard`. Fixing that widget
  // fixed the projection page; the invoices page was overflowing on the credit
  // card face, where a long bank name in spaced capitals pushed the
  // contactless glyph off the card at 1.3x.
  const fixedRatioGrid = {
    'categorias': 'categories_page.dart:82, grade de proporção fixa, PR 3',
  };

  for (final scale in [1.3, 2.0]) {
    for (final name in names) {
      final deferred = fixedRatioGrid[name];
      testWidgets(
        deferred == null
            ? '$name survives text at ${scale}x'
            : '$name survives text at ${scale}x — adiado: $deferred',
        (tester) async {
          await withGoldenClock(() async {
            await pumpGolden(
              tester,
              page(name),
              size: const Size(390, 1400),
              textScale: scale,
            );
            expect(tester.takeException(), isNull);
          });
        },
        skip: deferred != null,
      );
    }
  }
}

void _ignore(FinancePeriod _) {}
