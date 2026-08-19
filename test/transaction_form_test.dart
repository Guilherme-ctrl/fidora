import 'package:financeiro_ai/data/demo_finance_repository.dart';
import 'package:financeiro_ai/domain/models.dart';
import 'package:financeiro_ai/domain/transaction_draft.dart';
import 'package:financeiro_ai/presentation/widgets/transaction_form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> pumpForm(
  WidgetTester tester, {
  required FinanceSnapshot snapshot,
  required Future<void> Function(TransactionDraft) onSave,
  FinanceTransaction? existing,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showTransactionFormSheet(
              context,
              snapshot: snapshot,
              onSave: onSave,
              existing: existing,
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

/// The sheet is taller than the test viewport, so the submit button has to be
/// scrolled into view before it can receive a tap.
Future<void> tapSave(
  WidgetTester tester, [
  String label = 'Salvar transação',
]) async {
  final button = find.text(label);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  late FinanceSnapshot snapshot;
  setUp(() async {
    snapshot = await DemoFinanceRepository().loadSnapshot();
  });

  testWidgets('reports the empty fields instead of saving', (tester) async {
    var saves = 0;
    await pumpForm(tester, snapshot: snapshot, onSave: (_) async => saves++);

    await tapSave(tester);

    expect(saves, 0);
    expect(find.text('Informe o estabelecimento'), findsOneWidget);
    expect(find.text('Informe um valor'), findsOneWidget);
    expect(find.text('Escolha uma categoria'), findsOneWidget);
  });

  testWidgets('saves a draft with the typed amount parsed', (tester) async {
    TransactionDraft? captured;
    await pumpForm(
      tester,
      snapshot: snapshot,
      onSave: (draft) async => captured = draft,
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Estabelecimento'),
      'Livraria Cultura',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Valor'), '1.234,56');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Viagem').last);
    await tester.pumpAndSettle();

    await tapSave(tester);

    expect(captured, isNotNull);
    expect(captured!.merchant, 'Livraria Cultura');
    expect(captured!.amount, 1234.56);
    expect(captured!.movementType, 'purchase');
    expect(captured!.cardId, isNull);
  });

  testWidgets('income hides the payment method and marks a credit', (
    tester,
  ) async {
    TransactionDraft? captured;
    await pumpForm(
      tester,
      snapshot: snapshot,
      onSave: (draft) async => captured = draft,
    );

    expect(find.text('Forma de pagamento'), findsOneWidget);
    await tester.tap(find.text('Entrada'));
    await tester.pumpAndSettle();
    expect(find.text('Forma de pagamento'), findsNothing);
    expect(find.text('Origem'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Origem'), 'Salário');
    await tester.enterText(find.widgetWithText(TextField, 'Valor'), '8500');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Financeiro').last);
    await tester.pumpAndSettle();
    await tapSave(tester);

    expect(captured!.movementType, 'credit');
    expect(captured!.cardId, isNull);
  });

  testWidgets('shows the invoice competence for the chosen card', (
    tester,
  ) async {
    await pumpForm(tester, snapshot: snapshot, onSave: (_) async {});

    // Two nullable dropdowns exist now — payment method and account — so the
    // finder has to name the one under test.
    await tester.tap(
      find.widgetWithText(
        DropdownButtonFormField<String?>,
        'Conta, Pix ou débito',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Uniclass Black').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Entra na fatura de'), findsOneWidget);
    expect(find.textContaining('fecha dia 2'), findsOneWidget);
  });

  testWidgets('surfaces a write failure without closing the form', (
    tester,
  ) async {
    await pumpForm(
      tester,
      snapshot: snapshot,
      onSave: (_) async =>
          throw const FinanceWriteException('Sua sessão expirou.'),
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Estabelecimento'),
      'Padaria',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Valor'), '10,00');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lazer').last);
    await tester.pumpAndSettle();
    await tapSave(tester);

    expect(find.text('Sua sessão expirou.'), findsOneWidget);
    expect(find.text('Salvar transação'), findsOneWidget);
  });

  testWidgets('prefills the form when editing', (tester) async {
    await pumpForm(
      tester,
      snapshot: snapshot,
      onSave: (_) async {},
      existing: snapshot.transactions.firstWhere(
        (item) => item.merchant == 'MERCADO LIVRE',
      ),
    );

    expect(find.text('Editar transação'), findsOneWidget);
    expect(find.text('MERCADO LIVRE'), findsOneWidget);
    expect(find.text('156,30'), findsOneWidget);
    expect(find.text('Compra parcelada'), findsOneWidget);
  });
}
