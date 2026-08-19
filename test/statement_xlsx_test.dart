import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:financeiro_ai/domain/statement_import.dart';
import 'package:financeiro_ai/domain/statement_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a real .xlsx in memory, so the reader is exercised against the actual
/// file format rather than against a hand-made list of cells.
Uint8List _xlsx(List<List<CellValue?>> rows) {
  final book = Excel.createExcel();
  final sheet = book[book.getDefaultSheet()!];
  for (final row in rows) {
    sheet.appendRow(row);
  }
  return Uint8List.fromList(book.encode()!);
}

void main() {
  test('reads a sheet the parser then understands', () {
    final bytes = _xlsx([
      [TextCellValue('Data'), TextCellValue('Descrição'), TextCellValue('Valor')],
      [
        TextCellValue('15/08/2026'),
        TextCellValue('PADARIA CENTRAL'),
        TextCellValue('24,80'),
      ],
    ]);

    final parse = parseStatementSheet(readXlsxCells(bytes));

    expect(parse.rows.single.merchant, 'PADARIA CENTRAL');
    expect(parse.rows.single.amount, 24.80);
    expect(parse.rows.single.date, DateTime(2026, 8, 15));
  });

  test('reads a typed date cell', () {
    // XLSX carries dates as a type, not a string. Handing the parser whatever
    // toString() produced would make it guess a locale.
    final bytes = _xlsx([
      [TextCellValue('Data'), TextCellValue('Descrição'), TextCellValue('Valor')],
      [
        DateCellValue(year: 2026, month: 8, day: 15),
        TextCellValue('MERCADO'),
        TextCellValue('100,00'),
      ],
    ]);

    final parse = parseStatementSheet(readXlsxCells(bytes));
    expect(parse.rows.single.date, DateTime(2026, 8, 15));
  });

  test('reads a numeric amount cell', () {
    final bytes = _xlsx([
      [TextCellValue('Data'), TextCellValue('Descrição'), TextCellValue('Valor')],
      [
        TextCellValue('15/08/2026'),
        TextCellValue('MERCADO'),
        DoubleCellValue(1234.56),
      ],
    ]);

    final parse = parseStatementSheet(readXlsxCells(bytes));
    expect(parse.rows.single.amount, 1234.56);
  });

  test('treats an empty cell as empty rather than as the word null', () {
    final bytes = _xlsx([
      [TextCellValue('Data'), TextCellValue('Descrição'), TextCellValue('Valor')],
      [TextCellValue('15/08/2026'), null, TextCellValue('10,00')],
      [
        TextCellValue('16/08/2026'),
        TextCellValue('PADARIA'),
        TextCellValue('10,00'),
      ],
    ]);

    final parse = parseStatementSheet(readXlsxCells(bytes));
    expect(parse.rows, hasLength(1));
    expect(parse.skipped.single, contains('sem estabelecimento'));
  });

  test('refuses a file that is not a spreadsheet, with a readable message', () {
    expect(
      () => readXlsxCells(Uint8List.fromList([1, 2, 3, 4, 5])),
      throwsA(
        isA<StatementParseException>().having(
          (e) => e.message,
          'message',
          contains('.xlsx'),
        ),
      ),
    );
  });
}
