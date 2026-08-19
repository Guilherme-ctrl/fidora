import 'package:financeiro_ai/domain/invoice_import.dart';
import 'package:financeiro_ai/domain/statement_import.dart';
import 'package:financeiro_ai/domain/statement_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

StatementContext _context() => StatementContext(
  bank: 'Itaú',
  cardLastFour: '6902',
  referenceMonth: DateTime(2026, 8),
  dueDate: DateTime(2026, 9, 9),
  fileName: 'fatura.csv',
);

StatementParse _parse(String csv) =>
    parseStatementSheet(readDelimitedCells(csv));

void main() {
  group('reading delimited text', () {
    test('detects a semicolon export', () {
      // Brazilian exports use a semicolon precisely because the comma is the
      // decimal separator.
      final cells = readDelimitedCells(
        'Data;Descrição;Valor\r\n15/08/2026;PADARIA;24,80\r\n',
      );

      expect(cells.first, ['Data', 'Descrição', 'Valor']);
      expect(cells[1], ['15/08/2026', 'PADARIA', '24,80']);
    });

    test('detects a comma export', () {
      final cells = readDelimitedCells(
        'Date,Description,Amount\n2026-08-15,GROCERY,24.80\n',
      );

      expect(cells[1], ['2026-08-15', 'GROCERY', '24.80']);
    });

    test('detects a tab export', () {
      final cells = readDelimitedCells(
        'Data\tDescrição\tValor\n15/08/2026\tPADARIA\t24,80\n',
      );

      expect(cells[1], ['15/08/2026', 'PADARIA', '24,80']);
    });

    test('keeps a separator that sits inside quotes', () {
      final cells = readDelimitedCells(
        'Data;Descrição;Valor\n15/08/2026;"PADARIA, CENTRAL";24,80\n',
      );

      expect(cells[1][1], 'PADARIA, CENTRAL');
    });

    test('unescapes a doubled quote', () {
      final cells = readDelimitedCells(
        'Data;Descrição;Valor\n15/08/2026;"BAR ""DO ZE""";24,80\n',
      );

      expect(cells[1][1], 'BAR "DO ZE"');
    });

    test('drops the byte order mark Excel writes', () {
      // Left in place it becomes part of the first header and no column
      // matches.
      final cells = readDelimitedCells(
        '\u{FEFF}Data;Descrição;Valor\n15/08/2026;PADARIA;24,80\n',
      );

      expect(cells.first.first, 'Data');
    });
  });

  group('building the payload', () {
    test('produces a document the existing import path accepts', () {
      final document = buildStatementImport(
        _parse('''
Data;Descrição;Valor
15/08/2026;PADARIA CENTRAL;24,80
16/08/2026;MERCADO EXTRA;75,20
'''),
        _context(),
      );

      expect(document, isA<InvoiceImportDocument>());
      expect(document.bank, 'Itaú');
      expect(document.cardLastFour, '6902');
      expect(document.statementTotal, 100);
      expect(document.transactions, hasLength(2));
      expect(document.referenceMonth, DateTime(2026, 8));
    });

    test('marks a payment as a transfer and keeps it out of the total', () {
      final document = buildStatementImport(
        _parse('''
Data;Descrição;Valor
10/08/2026;PAGAMENTO RECEBIDO;-1.500,00
15/08/2026;PADARIA;24,80
'''),
        _context(),
      );

      expect(document.paymentCount, 1);
      expect(document.statementTotal, 24.80);
    });

    test('carries instalments through', () {
      final document = buildStatementImport(
        _parse('''
Data;Descrição;Valor
15/08/2026;SOFA 3/10;200,00
'''),
        _context(),
      );

      expect(document.installmentCount, 1);
      final instalment =
          document.transactions.single['installment'] as Map<String, dynamic>;
      expect(instalment['current'], 3);
      expect(instalment['total'], 10);
    });

    test('sends every purchase for review and no payment', () {
      // The sheet carries no category; claiming confidence would make a guess
      // look like a reading.
      final document = buildStatementImport(
        _parse('''
Data;Descrição;Valor
10/08/2026;PAGAMENTO RECEBIDO;-1.500,00
15/08/2026;PADARIA;24,80
'''),
        _context(),
      );

      expect(document.reviewCount, 1);
      expect(document.transactions.first['needs_review'], isFalse);
      expect(document.transactions.last['needs_review'], isTrue);
      expect(document.transactions.last['confidence'], 0.0);
    });

    test('never asks the import to invent categories', () {
      final document = buildStatementImport(
        _parse('Data;Descrição;Valor\n15/08/2026;PADARIA;24,80\n'),
        _context(),
      );

      expect(document.createMissingCategories, isFalse);
    });
  });

  group('identity', () {
    test('the same file twice produces the same keys', () {
      // What lets the existing duplicate check see a re-import as a re-import.
      const csv = '''
Data;Descrição;Valor
15/08/2026;PADARIA CENTRAL;24,80
16/08/2026;MERCADO EXTRA;75,20
''';
      final first = buildStatementImport(_parse(csv), _context());
      final second = buildStatementImport(_parse(csv), _context());

      expect(
        first.transactions.map((t) => t['external_id']),
        second.transactions.map((t) => t['external_id']),
      );
      expect(first.requestId, second.requestId);
    });

    test('two identical purchases on one day stay distinct', () {
      // They happen, and collapsing them would drop a real charge.
      final document = buildStatementImport(
        _parse('''
Data;Descrição;Valor
15/08/2026;PADARIA CENTRAL;24,80
15/08/2026;PADARIA CENTRAL;24,80
'''),
        _context(),
      );

      final ids = document.transactions
          .map((t) => t['external_id'] as String)
          .toList();
      // A pure content hash would give both the same key, and the payload
      // validator rejects duplicates — the whole file would fail because
      // someone bought the same coffee twice.
      expect(ids, hasLength(2));
      expect(ids.first, isNot(ids.last));
      expect(ids.last, endsWith('#2'));
    });

    test('a different card produces different keys for the same purchase', () {
      final csv = 'Data;Descrição;Valor\n15/08/2026;PADARIA;24,80\n';
      final itau = buildStatementImport(_parse(csv), _context());
      final other = buildStatementImport(
        _parse(csv),
        StatementContext(
          bank: 'BB',
          cardLastFour: '4567',
          referenceMonth: DateTime(2026, 8),
          dueDate: DateTime(2026, 9, 10),
          fileName: 'fatura.csv',
        ),
      );

      expect(
        itau.transactions.single['external_id'],
        isNot(other.transactions.single['external_id']),
      );
    });
  });
}
