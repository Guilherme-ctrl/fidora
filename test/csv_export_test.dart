import 'package:financeiro_ai/features/imports/domain/csv_export.dart';
import 'package:financeiro_ai/features/ledger/domain/entities/models.dart';
import 'package:flutter_test/flutter_test.dart';

FinanceTransaction tx({
  String merchant = 'PADARIA',
  double amount = 24.8,
  double? personal,
  String card = '6902',
  String? accountId,
  String category = 'Alimentação',
  DateTime? date,
  DateTime? competence,
  int? current,
  int? total,
  TransactionStatus status = TransactionStatus.confirmed,
  String source = 'manual',
}) => FinanceTransaction(
  id: '1',
  date: date ?? DateTime(2026, 8, 5),
  merchant: merchant,
  amount: amount,
  category: category,
  cardLastFour: card,
  accountId: accountId,
  competence: competence,
  personalAmount: personal,
  installmentCurrent: current,
  installmentTotal: total,
  status: status,
  source: source,
);

FinanceSnapshot snap({List<Account> accounts = const []}) => FinanceSnapshot(
  transactions: const [],
  categories: const [],
  cards: const [],
  invoices: const [],
  goals: const [],
  accounts: accounts,
  pendingReviews: 0,
);

List<String> rowsOf(String csv) =>
    csv.replaceFirst('﻿', '').trim().split('\r\n');

void main() {
  group('buildTransactionsCsv', () {
    test('starts with a byte order mark so Excel keeps the accents', () {
      expect(buildTransactionsCsv(snap(), [tx()]).startsWith('﻿'), isTrue);
    });

    test(
      'uses semicolons and comma decimals, as pt-BR spreadsheets expect',
      () {
        final rows = rowsOf(buildTransactionsCsv(snap(), [tx(amount: 1234.5)]));
        expect(rows.first.split(';').first, 'Data');
        expect(rows[1], contains('1234,50'));
        expect(rows[1], contains('05/08/2026'));
      },
    );

    test('writes a header even with nothing to export', () {
      expect(rowsOf(buildTransactionsCsv(snap(), const [])), hasLength(1));
    });

    test('quotes a field holding the separator and doubles inner quotes', () {
      final rows = rowsOf(
        buildTransactionsCsv(snap(), [tx(merchant: 'LOJA; A "BOA"')]),
      );
      expect(rows[1], contains('"LOJA; A ""BOA"""'));
      // Still the same number of columns despite the separator inside.
      expect(rows[1].split(';').length, rows.first.split(';').length + 1);
    });

    test('quotes a merchant containing a line break', () {
      final csv = buildTransactionsCsv(snap(), [tx(merchant: 'LOJA\nFILIAL')]);
      expect(csv, contains('"LOJA\nFILIAL"'));
    });

    test('repeats the amount when nothing was split', () {
      final cells = rowsOf(
        buildTransactionsCsv(snap(), [tx(amount: 80)]),
      )[1].split(';');
      expect(cells[3], '80,00');
      expect(cells[4], '80,00', reason: 'the column stays summable');
    });

    test('carries the personal share when there is one', () {
      final cells = rowsOf(
        buildTransactionsCsv(snap(), [tx(amount: 200, personal: 80)]),
      )[1].split(';');
      expect(cells[3], '200,00');
      expect(cells[4], '80,00');
    });

    test('names the account instead of leaving the origin blank', () {
      final cells = rowsOf(
        buildTransactionsCsv(
          snap(
            accounts: const [Account(id: 'a1', name: 'Corrente')],
          ),
          [tx(card: '----', accountId: 'a1')],
        ),
      )[1].split(';');
      expect(cells[5], '', reason: 'no card');
      expect(cells[6], 'Corrente');
    });

    test('writes competence and instalments only when they apply', () {
      final plain = rowsOf(buildTransactionsCsv(snap(), [tx()]))[1].split(';');
      expect(plain[7], '');
      expect(plain[8], '');

      final full = rowsOf(
        buildTransactionsCsv(snap(), [
          tx(competence: DateTime(2026, 9), current: 2, total: 4),
        ]),
      )[1].split(';');
      expect(full[7], '09/2026');
      expect(full[8], '2/4');
    });

    test('translates the status', () {
      for (final entry in {
        TransactionStatus.confirmed: 'Confirmado',
        TransactionStatus.pending: 'Pendente',
        TransactionStatus.ignored: 'Ignorado',
      }.entries) {
        final cells = rowsOf(
          buildTransactionsCsv(snap(), [tx(status: entry.key)]),
        )[1].split(';');
        expect(cells[9], entry.value);
      }
    });

    test('every row has as many columns as the header', () {
      final csv = buildTransactionsCsv(snap(), [
        tx(),
        tx(merchant: 'OUTRA', card: '----'),
        tx(competence: DateTime(2026, 9), current: 1, total: 3),
      ]);
      final rows = rowsOf(csv);
      final columns = rows.first.split(';').length;
      for (final row in rows.skip(1)) {
        expect(row.split(';').length, columns, reason: row);
      }
    });

    test('ends with a line break so the last row is complete', () {
      expect(buildTransactionsCsv(snap(), [tx()]).endsWith('\r\n'), isTrue);
    });
  });

  group('csvFileName', () {
    test('sorts chronologically and says what it is', () {
      expect(csvFileName(DateTime(2026, 8, 19)), 'compasso-2026-08-19.csv');
    });
  });
}
