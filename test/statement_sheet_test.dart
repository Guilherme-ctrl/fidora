import 'package:financeiro_ai/features/imports/domain/statement_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

List<List<String>> _sheet(List<List<String>> rows) => rows;

void main() {
  group('finding the table', () {
    test('reads a plain header', () {
      final parse = parseStatementSheet(
        _sheet([
          ['Data', 'Estabelecimento', 'Valor'],
          ['15/08/2026', 'PADARIA CENTRAL', '24,80'],
        ]),
      );

      expect(parse.headerRow, 0);
      expect(parse.rows, hasLength(1));
      expect(parse.rows.single.merchant, 'PADARIA CENTRAL');
      expect(parse.rows.single.amount, 24.80);
      expect(parse.rows.single.date, DateTime(2026, 8, 15));
    });

    test('finds the header below a title block', () {
      // Exports rarely start at A1: there is usually a title, the card number
      // and a blank line above the real table.
      final parse = parseStatementSheet(
        _sheet([
          ['Extrato de fatura'],
          ['Cartão final 1234'],
          [''],
          ['Data', 'Descrição', 'Valor'],
          ['15/08/2026', 'MERCADO', '100,00'],
        ]),
      );

      expect(parse.headerRow, 3);
      expect(parse.rows, hasLength(1));
    });

    test('accepts English headers', () {
      final parse = parseStatementSheet(
        _sheet([
          ['Date', 'Description', 'Amount'],
          ['2026-08-15', 'GROCERY', '100.00'],
        ]),
      );

      expect(parse.rows.single.amount, 100);
      expect(parse.rows.single.date, DateTime(2026, 8, 15));
    });

    test('ignores accents and case in the header', () {
      final parse = parseStatementSheet(
        _sheet([
          ['DATA', 'HISTÓRICO', 'VALOR'],
          ['15/08/2026', 'MERCADO', '10,00'],
        ]),
      );

      expect(parse.rows, hasLength(1));
    });

    test(
      'binds the amount column to the exact header, not a totals column',
      () {
        // "valor" is contained in "valor total"; a contains-first search would
        // read every row's amount from the wrong column.
        final parse = parseStatementSheet(
          _sheet([
            ['Data', 'Descrição', 'Valor total acumulado', 'Valor'],
            ['15/08/2026', 'MERCADO', '9999,00', '42,00'],
          ]),
        );

        expect(parse.rows.single.amount, 42);
      },
    );

    test('says what is missing when the columns are not there', () {
      expect(
        () => parseStatementSheet(
          _sheet([
            ['Coluna A', 'Coluna B'],
            ['x', 'y'],
          ]),
        ),
        throwsA(
          isA<StatementParseException>().having(
            (e) => e.message,
            'message',
            contains('data, estabelecimento e valor'),
          ),
        ),
      );
    });

    test('refuses a sheet whose rows are all unreadable', () {
      expect(
        () => parseStatementSheet(
          _sheet([
            ['Data', 'Descrição', 'Valor'],
            ['sem data', 'MERCADO', 'abc'],
          ]),
        ),
        throwsA(isA<StatementParseException>()),
      );
    });
  });

  group('dates', () {
    test('reads the formats issuers actually use', () {
      final parse = parseStatementSheet(
        _sheet([
          ['Data', 'Descrição', 'Valor'],
          ['15/08/2026', 'A', '1,00'],
          ['15/08/26', 'B', '1,00'],
          ['2026-08-15', 'C', '1,00'],
          ['15-08-2026', 'D', '1,00'],
        ]),
      );

      expect(parse.rows.map((r) => r.date).toSet(), {DateTime(2026, 8, 15)});
    });

    test('rejects a day the calendar does not have', () {
      // DateTime(2026, 2, 31) rolls forward to March in silence.
      final parse = parseStatementSheet(
        _sheet([
          ['Data', 'Descrição', 'Valor'],
          ['31/02/2026', 'MERCADO', '10,00'],
          ['15/08/2026', 'PADARIA', '10,00'],
        ]),
      );

      expect(parse.rows, hasLength(1));
      expect(parse.skipped.single, contains('data não reconhecida'));
    });
  });

  group('amounts', () {
    test('reads Brazilian and plain formats', () {
      final parse = parseStatementSheet(
        _sheet([
          ['Data', 'Descrição', 'Valor'],
          ['15/08/2026', 'A', 'R\$ 1.234,56'],
          ['15/08/2026', 'B', '1234.56'],
        ]),
      );

      expect(parse.rows.map((r) => r.amount).toList(), [1234.56, 1234.56]);
    });

    test('skips a zero and says so', () {
      final parse = parseStatementSheet(
        _sheet([
          ['Data', 'Descrição', 'Valor'],
          ['15/08/2026', 'AJUSTE', '0,00'],
          ['15/08/2026', 'PADARIA', '10,00'],
        ]),
      );

      expect(parse.rows, hasLength(1));
      expect(parse.skipped.single, contains('valor zerado'));
    });
  });

  group('payments', () {
    test('reads a negative amount as a payment, not a purchase', () {
      // Counted as a purchase it would double the month's spending.
      final parse = parseStatementSheet(
        _sheet([
          ['Data', 'Descrição', 'Valor'],
          ['10/08/2026', 'PAGAMENTO', '-1.500,00'],
          ['15/08/2026', 'PADARIA', '24,80'],
        ]),
      );

      expect(parse.rows.first.isPayment, isTrue);
      expect(parse.rows.first.amount, 1500);
      expect(parse.rows.last.isPayment, isFalse);
    });

    test('reads the wording even when the amount is positive', () {
      final parse = parseStatementSheet(
        _sheet([
          ['Data', 'Descrição', 'Valor'],
          ['10/08/2026', 'Pagamento recebido', '1.500,00'],
        ]),
      );

      expect(parse.rows.single.isPayment, isTrue);
    });

    test('keeps payments out of the total', () {
      final parse = parseStatementSheet(
        _sheet([
          ['Data', 'Descrição', 'Valor'],
          ['10/08/2026', 'PAGAMENTO RECEBIDO', '1.500,00'],
          ['15/08/2026', 'PADARIA', '24,80'],
          ['16/08/2026', 'MERCADO', '75,20'],
        ]),
      );

      expect(parse.total, 100);
    });
  });

  group('instalments', () {
    test('reads the compact form', () {
      final parse = parseStatementSheet(
        _sheet([
          ['Data', 'Descrição', 'Valor'],
          ['15/08/2026', 'MAGAZINE SOFA 3/10', '200,00'],
        ]),
      );

      expect(parse.rows.single.installmentCurrent, 3);
      expect(parse.rows.single.installmentTotal, 10);
      expect(parse.rows.single.isInstallment, isTrue);
    });

    test('reads the spelled-out form', () {
      final parse = parseStatementSheet(
        _sheet([
          ['Data', 'Descrição', 'Valor'],
          ['15/08/2026', 'TV SAMSUNG PARCELA 2 DE 12', '300,00'],
        ]),
      );

      expect(parse.rows.single.installmentCurrent, 2);
      expect(parse.rows.single.installmentTotal, 12);
    });

    test('leaves a single purchase alone', () {
      final parse = parseStatementSheet(
        _sheet([
          ['Data', 'Descrição', 'Valor'],
          ['15/08/2026', 'PADARIA CENTRAL', '24,80'],
        ]),
      );

      expect(parse.rows.single.isInstallment, isFalse);
      expect(parse.rows.single.installmentTotal, isNull);
    });

    test('does not read a total smaller than the current instalment', () {
      // "10/03" in a description is a date far more often than a tenth
      // instalment of three.
      final parse = parseStatementSheet(
        _sheet([
          ['Data', 'Descrição', 'Valor'],
          ['15/08/2026', 'COMPRA 10/03', '50,00'],
        ]),
      );

      expect(parse.rows.single.isInstallment, isFalse);
    });
  });

  group('what could not be read', () {
    test('is reported rather than dropped', () {
      // A silently skipped line is a purchase missing from the ledger, with
      // nothing on screen to say so.
      final parse = parseStatementSheet(
        _sheet([
          ['Data', 'Descrição', 'Valor'],
          ['15/08/2026', 'PADARIA', '24,80'],
          ['??', 'MERCADO', '10,00'],
          ['16/08/2026', '', '10,00'],
          ['17/08/2026', 'LOJA', 'ilegível'],
        ]),
      );

      expect(parse.rows, hasLength(1));
      expect(parse.skipped, hasLength(3));
      expect(parse.skipped[0], contains('Linha 3'));
      expect(parse.skipped[1], contains('sem estabelecimento'));
      expect(parse.skipped[2], contains('valor não reconhecido'));
    });

    test('blank lines are not reported as failures', () {
      final parse = parseStatementSheet(
        _sheet([
          ['Data', 'Descrição', 'Valor'],
          ['15/08/2026', 'PADARIA', '24,80'],
          ['', '', ''],
        ]),
      );

      expect(parse.skipped, isEmpty);
    });
  });

  test('every purchase arrives needing review', () {
    // The sheet carries no category, and guessing one would put a wrong
    // category into the ledger without anyone deciding it.
    final parse = parseStatementSheet(
      _sheet([
        ['Data', 'Descrição', 'Valor'],
        ['15/08/2026', 'PADARIA', '24,80'],
      ]),
    );

    expect(parse.rows.single.needsReview, isTrue);
    expect(parse.rows.single.reviewReason, contains('Categoria'));
  });
}
