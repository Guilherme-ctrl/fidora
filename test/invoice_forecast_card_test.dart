import 'package:financeiro_ai/core/theme/theme.dart';
import 'package:financeiro_ai/features/ledger/domain/entities/models.dart';
import 'package:financeiro_ai/features/invoices/presenter/widgets/invoice_forecast_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

CreditCard _card({String lastFour = '1234', String name = 'Nubank'}) =>
    CreditCard(
      id: 'card-$lastFour',
      name: name,
      bank: 'Nu',
      lastFour: lastFour,
      limit: 10000,
      closingDay: 20,
      dueDay: 27,
      holder: 'Você',
    );

FinanceTransaction _tx({
  required DateTime date,
  required double amount,
  String merchant = 'Mercado',
  String lastFour = '1234',
  int? current,
  int? total,
}) => FinanceTransaction(
  id: '$merchant-$date-$amount',
  date: date,
  merchant: merchant,
  category: 'Alimentação',
  amount: amount,
  cardLastFour: lastFour,
  status: TransactionStatus.confirmed,
  source: 'test',
  movementType: 'purchase',
  installmentCurrent: current,
  installmentTotal: total,
);

FinanceSnapshot _snapshot(
  List<FinanceTransaction> items, {
  List<CreditCard>? cards,
}) => FinanceSnapshot(
  transactions: items,
  categories: const [],
  cards: cards ?? [_card()],
  invoices: const [],
  goals: const [],
  pendingReviews: 0,
);

Future<void> _pump(
  WidgetTester tester,
  FinanceSnapshot snapshot,
  DateTime now,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(brightness: Brightness.light),
      home: Scaffold(
        body: SingleChildScrollView(
          child: InvoiceForecastCard(snapshot: snapshot, now: now),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  final today = DateTime(2026, 9, 10);

  testWidgets('disappears entirely when there is nothing to forecast', (
    tester,
  ) async {
    await _pump(tester, _snapshot(const []), today);

    expect(find.text('Previsão de fechamento'), findsNothing);
  });

  testWidgets('names the card and the month it is forecasting', (tester) async {
    await _pump(
      tester,
      _snapshot([_tx(date: DateTime(2026, 9, 3), amount: 400)]),
      today,
    );

    expect(find.text('Previsão de fechamento'), findsOneWidget);
    expect(find.text('Nubank · setembro'), findsOneWidget);
  });

  testWidgets('shows the three parts separately, never one lump sum', (
    tester,
  ) async {
    await _pump(
      tester,
      _snapshot([
        _tx(date: DateTime(2026, 8, 1), amount: 610),
        _tx(date: DateTime(2026, 9, 3), amount: 400),
        _tx(
          date: DateTime(2026, 7, 5),
          amount: 200,
          merchant: 'Sofá',
          current: 1,
          total: 5,
        ),
      ]),
      today,
    );

    // Anchored on the legend chips, which carry a value: the explanatory
    // footnote below the card mentions the same words.
    expect(find.textContaining(RegExp(r'já lançado$')), findsOneWidget);
    expect(find.textContaining(RegExp(r'parcelas$')), findsOneWidget);
    expect(find.textContaining(RegExp(r'estimativa$')), findsOneWidget);
  });

  testWidgets('omits the parts that are zero rather than printing R\$ 0,00', (
    tester,
  ) async {
    // No past cycle and no instalment: only the committed part is real.
    await _pump(
      tester,
      _snapshot([_tx(date: DateTime(2026, 9, 3), amount: 400)]),
      today,
    );

    expect(find.textContaining(RegExp(r'já lançado$')), findsOneWidget);
    expect(find.textContaining(RegExp(r'parcelas$')), findsNothing);
    expect(find.textContaining(RegExp(r'estimativa$')), findsNothing);
  });

  testWidgets('says plainly when there is no baseline to project from', (
    tester,
  ) async {
    await _pump(
      tester,
      _snapshot([_tx(date: DateTime(2026, 9, 3), amount: 400)]),
      today,
    );

    expect(find.textContaining('Sem ciclo anterior'), findsOneWidget);
  });

  testWidgets('drops that warning once a baseline exists', (tester) async {
    await _pump(
      tester,
      _snapshot([
        _tx(date: DateTime(2026, 8, 1), amount: 610),
        _tx(date: DateTime(2026, 9, 3), amount: 400),
      ]),
      today,
    );

    expect(find.textContaining('Sem ciclo anterior'), findsNothing);
    expect(find.textContaining('base de 31 dias'), findsOneWidget);
  });

  testWidgets('counts down to the closing day', (tester) async {
    await _pump(
      tester,
      _snapshot([_tx(date: DateTime(2026, 9, 3), amount: 400)]),
      today,
    );

    expect(find.textContaining('Fecha em 10 dias, 20/09'), findsOneWidget);
  });

  testWidgets('says "amanhã" instead of "em 1 dias"', (tester) async {
    await _pump(
      tester,
      _snapshot([_tx(date: DateTime(2026, 9, 3), amount: 400)]),
      DateTime(2026, 9, 19),
    );

    expect(find.textContaining('Fecha amanhã'), findsOneWidget);
  });

  testWidgets('switches to past tense once the invoice has closed', (
    tester,
  ) async {
    await _pump(
      tester,
      _snapshot([_tx(date: DateTime(2026, 9, 3), amount: 400)]),
      DateTime(2026, 9, 20),
    );

    expect(find.textContaining('Fechada em 20/09'), findsOneWidget);
    expect(find.textContaining('Sem ciclo anterior'), findsNothing);
  });

  testWidgets('lists every card with history, heaviest first', (tester) async {
    await _pump(
      tester,
      _snapshot(
        [
          _tx(date: DateTime(2026, 9, 3), amount: 100),
          _tx(date: DateTime(2026, 9, 4), amount: 900, lastFour: '5678'),
        ],
        cards: [
          _card(),
          _card(lastFour: '5678', name: 'Itaú'),
        ],
      ),
      today,
    );

    final headings = tester
        .widgetList<Text>(find.textContaining('· setembro'))
        .map((t) => t.data)
        .toList();
    expect(headings, ['Itaú · setembro', 'Nubank · setembro']);
  });

  testWidgets('scales the bar to the three parts', (tester) async {
    // 400 committed, 200 scheduled, 100 estimated — 700 total. Asserted on
    // the flex values rather than pixels, so the check does not depend on the
    // width the test happens to run at.
    await _pump(
      tester,
      _snapshot([
        _tx(date: DateTime(2026, 8, 1), amount: 610),
        _tx(date: DateTime(2026, 9, 3), amount: 400),
        _tx(
          date: DateTime(2026, 7, 5),
          amount: 200,
          merchant: 'Sofá',
          current: 1,
          total: 5,
        ),
      ]),
      today,
    );

    final bar = find.byWidgetPredicate(
      (widget) => widget is SizedBox && widget.height == 8,
    );
    expect(bar, findsWidgets);

    final flexes = tester
        .widgetList<Expanded>(
          find.descendant(of: bar.first, matching: find.byType(Expanded)),
        )
        .map((e) => e.flex)
        .toList();
    expect(flexes, [571, 286, 143]);
    expect(flexes.reduce((a, b) => a + b), 1000);
  });

  testWidgets('carries the breakdown into the accessibility label', (
    tester,
  ) async {
    await _pump(
      tester,
      _snapshot([
        _tx(date: DateTime(2026, 8, 1), amount: 610),
        _tx(date: DateTime(2026, 9, 3), amount: 400),
      ]),
      today,
    );

    // The bar is colour alone; without this the split is invisible to a
    // screen reader.
    expect(
      find.bySemanticsLabel(RegExp(r'Fatura de setembro.*já lançado')),
      findsOneWidget,
    );
  });
}
