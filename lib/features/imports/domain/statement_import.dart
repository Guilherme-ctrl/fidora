import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:financeiro_ai/features/ledger/domain/finance_rules.dart';
import 'package:financeiro_ai/features/imports/domain/invoice_import.dart';
import 'package:financeiro_ai/features/imports/domain/statement_sheet.dart';

/// Reads a delimited text export into cells.
///
/// The separator is detected rather than assumed: Brazilian exports use a
/// semicolon because the comma is the decimal separator, but an English-locale
/// export of the same statement uses a comma.
List<List<String>> readDelimitedCells(String text) {
  final body = text.startsWith('\u{FEFF}') ? text.substring(1) : text;
  final separator = _detectSeparator(body);
  final rows = <List<String>>[];

  var field = StringBuffer();
  var row = <String>[];
  var quoted = false;

  for (var index = 0; index < body.length; index++) {
    final char = body[index];

    if (quoted) {
      if (char == '"') {
        // A doubled quote inside a quoted field is one literal quote.
        if (index + 1 < body.length && body[index + 1] == '"') {
          field.write('"');
          index++;
        } else {
          quoted = false;
        }
      } else {
        field.write(char);
      }
      continue;
    }

    if (char == '"') {
      quoted = true;
    } else if (char == separator) {
      row.add(field.toString());
      field = StringBuffer();
    } else if (char == '\n') {
      row.add(field.toString());
      rows.add(row);
      row = <String>[];
      field = StringBuffer();
    } else if (char != '\r') {
      field.write(char);
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }
  return rows;
}

String _detectSeparator(String text) {
  // Counted outside quotes would be stricter, but the first lines of a
  // statement are a title and a header, where quoting is rare and the winner
  // is unambiguous.
  final sample = text.split('\n').take(5).join('\n');
  final semicolons = ';'.allMatches(sample).length;
  final tabs = '\t'.allMatches(sample).length;
  final commas = ','.allMatches(sample).length;
  if (semicolons >= commas && semicolons >= tabs && semicolons > 0) return ';';
  if (tabs > commas && tabs > 0) return '\t';
  return ',';
}

/// Everything the sheet cannot tell us and the import needs.
class StatementContext {
  const StatementContext({
    required this.bank,
    required this.cardLastFour,
    required this.referenceMonth,
    required this.dueDate,
    required this.fileName,
    this.currency = 'BRL',
  });

  final String bank;
  final String cardLastFour;
  final DateTime referenceMonth;
  final DateTime dueDate;
  final String fileName;
  final String currency;
}

/// Builds the import payload the existing review-and-write path already takes.
///
/// Going through the same document type as the JSON import is deliberate: the
/// preview, the duplicate check and the writing are already proven there, and a
/// second path into the ledger would be a second place for them to diverge.
InvoiceImportDocument buildStatementImport(
  StatementParse parse,
  StatementContext context,
) {
  final transactions = <Map<String, dynamic>>[];

  // Two identical charges on one day are real — the same café twice at the
  // same price — and a pure content hash gives them the same key, which the
  // payload validator rejects outright. Numbering the repeats keeps them
  // distinct while a re-import of the same file still produces the same keys.
  final seen = <String, int>{};

  for (final row in parse.rows) {
    final normalized = normalizeMerchant(row.merchant);
    final seed = _seedFor(context, row, normalized);
    final occurrence = (seen[seed] = (seen[seed] ?? 0) + 1);

    transactions.add({
      'external_id': _externalId(seed, occurrence),
      'purchased_at': _isoDate(row.date),
      'merchant_original': row.merchant,
      'merchant_normalized': normalized,
      'amount': row.amount,
      'movement_type': row.isPayment ? 'transfer' : 'purchase',
      'modality': row.isInstallment ? 'installment' : 'cash',
      if (row.isInstallment)
        'installment': {
          'current': row.installmentCurrent,
          'total': row.installmentTotal,
        },
      // The sheet carries no category and no confidence. Claiming a high one
      // would make a guess look like a reading.
      'confidence': 0.0,
      'needs_review': !row.isPayment,
      if (row.reviewReason != null && !row.isPayment)
        'review_reason': row.reviewReason,
    });
  }

  return InvoiceImportDocument.fromJson({
    'schema_version': '1.0',
    'source': 'sheet',
    'request_id': _requestId(context, parse),
    'invoice': {
      'bank': context.bank,
      'card_last_four': context.cardLastFour,
      'reference_month': _isoDate(
        DateTime(context.referenceMonth.year, context.referenceMonth.month),
      ),
      'due_date': _isoDate(context.dueDate),
      'currency': context.currency,
      'source_file': context.fileName,
      'statement_total': parse.total,
    },
    'processing': {'create_missing_categories': false},
    'transactions': transactions,
  });
}

String _seedFor(
  StatementContext context,
  StatementRow row,
  String normalized,
) => [
  context.cardLastFour,
  _isoDate(row.date),
  normalized,
  row.amount.toStringAsFixed(2),
  '${row.installmentCurrent ?? 0}/${row.installmentTotal ?? 0}',
].join('|');

/// Stable across imports of the same file, and distinct between repeats of an
/// otherwise identical row.
String _externalId(String seed, int occurrence) {
  final digest = sha256.convert(utf8.encode(seed)).toString().substring(0, 24);
  return occurrence == 1 ? 'sheet:$digest' : 'sheet:$digest#$occurrence';
}

String _requestId(StatementContext context, StatementParse parse) {
  final seed =
      '${context.cardLastFour}|${_isoDate(context.referenceMonth)}|'
      '${parse.rows.length}|${parse.total.toStringAsFixed(2)}';
  return 'sheet:${sha256.convert(utf8.encode(seed)).toString().substring(0, 24)}';
}

String _isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
