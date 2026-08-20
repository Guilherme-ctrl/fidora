import 'package:financeiro_ai/core/errors/failure.dart';
import 'package:financeiro_ai/features/ledger/infra/repositories/demo_finance_repository.dart';
import 'package:financeiro_ai/features/ledger/domain/entities/models.dart';
import 'package:financeiro_ai/features/transactions/domain/transaction_draft.dart';
import 'package:flutter_test/flutter_test.dart';

TransactionDraft draft({
  String? id,
  String merchant = 'PADARIA CENTRAL',
  double amount = 24.80,
  String categoryId = '1',
  String? cardId,
  int? installmentCurrent,
  int? installmentTotal,
  DateTime? purchasedAt,
}) => TransactionDraft(
  id: id,
  purchasedAt: purchasedAt ?? DateTime(2026, 8, 15),
  merchant: merchant,
  amount: amount,
  categoryId: categoryId,
  cardId: cardId,
  installmentCurrent: installmentCurrent,
  installmentTotal: installmentTotal,
);

void main() {
  group('TransactionDraft validation', () {
    test('accepts a complete draft', () {
      expect(draft().validate().isEmpty, isTrue);
    });

    test('rejects a blank merchant and a non-positive amount', () {
      final errors = draft(merchant: '   ', amount: 0).validate();
      expect(errors.merchant, 'Informe o estabelecimento');
      expect(errors.amount, 'O valor precisa ser maior que zero');
    });

    test('rejects a missing category', () {
      expect(draft(categoryId: '').validate().category, isNotNull);
    });

    test('rejects an amount that is not a number', () {
      expect(draft(amount: double.nan).validate().amount, 'Informe um valor');
    });

    test('requires both installment fields together', () {
      expect(
        draft(installmentTotal: 4).validate().installment,
        'Informe a parcela atual e o total de parcelas',
      );
    });

    test('rejects an installment beyond the total', () {
      expect(
        draft(
          installmentCurrent: 5,
          installmentTotal: 4,
        ).validate().installment,
        'A parcela atual não pode ser maior que o total',
      );
    });

    test('rejects a single-instalment plan', () {
      expect(
        draft(
          installmentCurrent: 1,
          installmentTotal: 1,
        ).validate().installment,
        'Um parcelamento precisa de ao menos 2 parcelas',
      );
    });

    test('derives modality from the installment fields', () {
      expect(draft().modality, 'cash');
      expect(
        draft(installmentCurrent: 2, installmentTotal: 4).modality,
        'installment',
      );
    });
  });

  group('DemoFinanceRepository writes', () {
    test(
      'creates a card purchase with the invoice competence resolved',
      () async {
        final repository = DemoFinanceRepository();
        // Card '1' closes on day 2, so a purchase on 15 August belongs to the
        // September invoice.
        await repository.saveTransaction(
          draft(
            merchant: 'Livraria Cultura',
            amount: 89.90,
            cardId: '1',
            purchasedAt: DateTime(2026, 8, 15),
          ),
        );
        final snapshot = await repository.loadSnapshot();
        final saved = snapshot.transactions.firstWhere(
          (item) => item.merchant == 'Livraria Cultura',
        );
        expect(saved.competence, DateTime(2026, 9));
        expect(saved.cardLastFour, '6902');
        expect(saved.category, 'Alimentação');
      },
    );

    test('records an account movement without a card or competence', () async {
      final repository = DemoFinanceRepository();
      await repository.saveTransaction(draft(merchant: 'Pix aluguel'));
      final snapshot = await repository.loadSnapshot();
      final saved = snapshot.transactions.firstWhere(
        (item) => item.merchant == 'Pix aluguel',
      );
      expect(saved.cardLastFour, '----');
      expect(saved.competence, isNull);
    });

    test('editing replaces the row instead of duplicating it', () async {
      final repository = DemoFinanceRepository();
      final before = (await repository.loadSnapshot()).transactions.length;
      await repository.saveTransaction(
        draft(id: '1', merchant: 'PADARIA CENTRAL', amount: 31.50),
      );
      final snapshot = await repository.loadSnapshot();
      expect(snapshot.transactions.length, before);
      expect(
        snapshot.transactions.firstWhere((item) => item.id == '1').amount,
        31.50,
      );
    });

    test('rejects an invalid draft before touching the ledger', () async {
      final repository = DemoFinanceRepository();
      final before = (await repository.loadSnapshot()).transactions.length;
      await expectLater(
        repository.saveTransaction(draft(amount: -10)),
        throwsA(isA<ValidationFailure>()),
      );
      expect((await repository.loadSnapshot()).transactions.length, before);
    });

    test('deletes a transaction', () async {
      final repository = DemoFinanceRepository();
      await repository.deleteTransaction('1');
      final snapshot = await repository.loadSnapshot();
      expect(snapshot.transactions.any((item) => item.id == '1'), isFalse);
    });

    test('keeps the ledger sorted newest first after a write', () async {
      final repository = DemoFinanceRepository();
      await repository.saveTransaction(
        draft(merchant: 'Compra antiga', purchasedAt: DateTime(2020, 1, 1)),
      );
      final dates = (await repository.loadSnapshot()).transactions
          .map((item) => item.date)
          .toList();
      for (var i = 1; i < dates.length; i++) {
        expect(dates[i].isAfter(dates[i - 1]), isFalse);
      }
    });
  });

  group('TransactionStatus mapping', () {
    test('enum names match the database check constraint', () {
      expect(
        TransactionStatus.values.map((item) => item.name),
        containsAll(<String>['confirmed', 'pending', 'ignored']),
      );
    });
  });
}
