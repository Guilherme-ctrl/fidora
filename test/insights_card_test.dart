import 'package:financeiro_ai/core/theme.dart';
import 'package:financeiro_ai/domain/analytics.dart';
import 'package:financeiro_ai/domain/models.dart';
import 'package:financeiro_ai/presentation/widgets/insights_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

FinanceTransaction _tx({
  required DateTime date,
  required double amount,
  String category = 'Alimentação',
  String merchant = 'Mercado',
}) => FinanceTransaction(
  id: '$merchant-$date-$amount',
  date: date,
  merchant: merchant,
  category: category,
  amount: amount,
  cardLastFour: '1234',
  status: TransactionStatus.confirmed,
  source: 'test',
  movementType: 'purchase',
);

FinanceSnapshot _snapshot(List<FinanceTransaction> items) => FinanceSnapshot(
  transactions: items,
  categories: const [],
  cards: const [],
  invoices: const [],
  goals: const [],
  pendingReviews: 0,
);

/// Distinct merchants per month, so the fixture does not also look like a
/// subscription and add a price-change insight to what is being measured.
List<FinanceTransaction> _baseline() => [
  for (final month in [6, 7, 8])
    _tx(
      date: DateTime(2026, month, 10),
      amount: 400,
      merchant: 'Mercado $month',
    ),
];

Future<void> _pump(WidgetTester tester, FinanceSnapshot snapshot) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(brightness: Brightness.light),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              InsightsCard(
                snapshot: snapshot,
                period: FinancePeriod.month(DateTime(2026, 9)),
                now: DateTime(2026, 9, 10),
              ),
              const Text('marcador'),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  testWidgets('says nothing, and takes no space, when nothing changed', (
    tester,
  ) async {
    await _pump(tester, _snapshot(const []));

    expect(find.text('O que mudou'), findsNothing);
    // The card owns its own bottom gap, so an empty month must not leave one.
    expect(tester.getTopLeft(find.text('marcador')).dy, 0);
  });

  testWidgets('writes the change as a sentence with its numbers in it', (
    tester,
  ) async {
    await _pump(
      tester,
      _snapshot([..._baseline(), _tx(date: DateTime(2026, 9, 5), amount: 800)]),
    );

    expect(find.text('O que mudou'), findsOneWidget);
    expect(
      find.textContaining(
        // `\s` and not a literal space: intl separates the symbol with a
        // non-breaking space, which a plain space does not match.
        RegExp(r'Você gastou 100% a mais em Alimentação.*R\$\s400,00 acima'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('takes vertical space once it has something to say', (
    tester,
  ) async {
    await _pump(
      tester,
      _snapshot([..._baseline(), _tx(date: DateTime(2026, 9, 5), amount: 800)]),
    );

    expect(tester.getTopLeft(find.text('marcador')).dy, greaterThan(0));
  });

  testWidgets('points a spike up and a saving down', (tester) async {
    await _pump(
      tester,
      _snapshot([..._baseline(), _tx(date: DateTime(2026, 9, 5), amount: 800)]),
    );
    expect(find.byIcon(Icons.trending_up_rounded), findsOneWidget);

    await _pump(
      tester,
      _snapshot([..._baseline(), _tx(date: DateTime(2026, 9, 5), amount: 100)]),
    );
    expect(find.byIcon(Icons.trending_down_rounded), findsOneWidget);
  });

  testWidgets('keeps the direction out of the accessibility tree twice', (
    tester,
  ) async {
    await _pump(
      tester,
      _snapshot([..._baseline(), _tx(date: DateTime(2026, 9, 5), amount: 800)]),
    );

    // The arrow only restates the sentence; a screen reader announcing both
    // would read the direction twice.
    final semantics = tester.getSemantics(
      find.textContaining('Você gastou 100% a mais'),
    );
    expect(semantics.label, contains('Você gastou 100% a mais'));
  });

  testWidgets('declares where the numbers come from', (tester) async {
    await _pump(
      tester,
      _snapshot([..._baseline(), _tx(date: DateTime(2026, 9, 5), amount: 800)]),
    );

    expect(
      find.textContaining('Nada aqui é estimado por texto'),
      findsOneWidget,
    );
  });
}
