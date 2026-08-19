import 'package:financeiro_ai/application/providers.dart';
import 'package:financeiro_ai/core/theme.dart';
import 'package:financeiro_ai/data/demo_finance_repository.dart';
import 'package:financeiro_ai/domain/analytics.dart';
import 'package:financeiro_ai/domain/models.dart';
import 'package:financeiro_ai/presentation/pages/dashboard_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// The metric grid fixes its cell height, so anything that adds a line to a
/// card can overflow it. That is not hypothetical: the trend line only renders
/// once there is a previous month to compare against, and the demo used to
/// hold a single month — so the overflow shipped invisible until the ledger
/// grew. These pump the real dashboard at real sizes and fail on any overflow.
Future<void> _pump(
  WidgetTester tester,
  FinanceSnapshot snapshot, {
  required Size size,
  double textScale = 1,
}) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        financeRepositoryProvider.overrideWithValue(DemoFinanceRepository()),
      ],
      child: MaterialApp(
        theme: buildAppTheme(brightness: Brightness.light),
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(
            body: DashboardPage(
              snapshot: snapshot,
              period: FinancePeriod.month(DateTime.now()),
              onPeriodChanged: (_) {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  late FinanceSnapshot snapshot;

  setUp(() async {
    snapshot = await DemoFinanceRepository().loadSnapshot();
  });

  test('the demo ledger spans enough months to have a baseline', () {
    // The guard behind the guard: if the demo shrinks back to one month, the
    // layout tests below stop exercising the trend line and quietly pass.
    final months = snapshot.transactions
        .map((item) => '${item.date.year}-${item.date.month}')
        .toSet();
    expect(months.length, greaterThanOrEqualTo(3));
  });

  for (final (name, size) in [
    ('iPhone SE', Size(375, 667)),
    ('iPhone 15', Size(393, 852)),
    ('two columns', Size(760, 1024)),
    ('four columns', Size(1300, 900)),
  ]) {
    testWidgets('lays out without overflow at $name', (tester) async {
      await _pump(tester, snapshot, size: size);
      expect(tester.takeException(), isNull);
    });
  }

  // Rows that measure their own content should hold at any scale, not just at
  // the one that happened to be tuned for.
  for (final scale in [1.3, 1.6, 2.0]) {
    testWidgets('lays out without overflow at text scale $scale', (
      tester,
    ) async {
      await _pump(
        tester,
        snapshot,
        size: const Size(375, 667),
        textScale: scale,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('holds at the largest text on the widest layout', (tester) async {
    await _pump(tester, snapshot, size: const Size(1300, 900), textScale: 2);
    expect(tester.takeException(), isNull);
  });
}
