import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:financeiro_ai/core/logging/logger.dart';
import 'package:financeiro_ai/features/imports/domain/statement_sheet.dart';

/// Reads the first worksheet of an XLSX file into cells.
///
/// This lived in `lib/domain`, which meant the rules layer imported
/// `package:excel` — a spreadsheet decoder is infrastructure by any reading.
/// The delimited-text reader beside it stayed in the domain, because parsing a
/// separator is plain Dart and depends on nothing.
List<List<String>> readXlsxCells(Uint8List bytes) {
  final Excel book;
  try {
    book = Excel.decodeBytes(bytes);
  } catch (error, stack) {
    appLogger.error('readXlsxCells', error, stack);
    throw const StatementParseException(
      'Não consegui abrir a planilha. Confira se o arquivo é um .xlsx válido.',
    );
  }

  final sheetName = book.tables.keys.firstOrNull;
  if (sheetName == null) {
    throw const StatementParseException('A planilha não tem nenhuma aba.');
  }

  return book.tables[sheetName]!.rows
      .map(
        (row) => row.map((cell) {
          final value = cell?.value;
          if (value == null) return '';
          // Dates arrive typed from XLSX, and turning them back into a string
          // the date parser understands beats asking it to guess a locale.
          if (value is DateCellValue) {
            return '${value.year.toString().padLeft(4, '0')}-'
                '${value.month.toString().padLeft(2, '0')}-'
                '${value.day.toString().padLeft(2, '0')}';
          }
          return value.toString();
        }).toList(),
      )
      .toList();
}
