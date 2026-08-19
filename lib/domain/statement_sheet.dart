import 'package:financeiro_ai/domain/finance_rules.dart';
import 'package:financeiro_ai/domain/receipt_scan.dart';

/// Turns a bank's spreadsheet export into the invoice-import payload.
///
/// The hard part is pure and works on already-extracted cells, so it can be
/// tested without a single fixture file. The XLSX and CSV readers are thin
/// adapters that only produce `List<List<String>>`.

/// One row the parser understood.
class StatementRow {
  const StatementRow({
    required this.date,
    required this.merchant,
    required this.amount,
    required this.isPayment,
    this.installmentCurrent,
    this.installmentTotal,
    this.needsReview = false,
    this.reviewReason,
  });

  final DateTime date;
  final String merchant;
  final double amount;

  /// A payment of the invoice rather than a purchase. It has to be told apart:
  /// counted as a purchase it would double the month's spending.
  final bool isPayment;

  final int? installmentCurrent;
  final int? installmentTotal;

  final bool needsReview;
  final String? reviewReason;

  bool get isInstallment => installmentTotal != null && installmentTotal! > 1;
}

/// What a sheet produced, including what could not be read.
class StatementParse {
  const StatementParse({
    required this.rows,
    required this.skipped,
    required this.headerRow,
  });

  final List<StatementRow> rows;

  /// Lines that were not understood, with the reason. Reported rather than
  /// dropped: a silently skipped line is a purchase missing from the ledger,
  /// and nothing on screen would say so.
  final List<String> skipped;

  /// Index of the row the headers were found on, for the error messages.
  final int headerRow;

  double get total => rows
      .where((row) => !row.isPayment)
      .fold<double>(0, (sum, row) => sum + row.amount);
}

class StatementParseException implements Exception {
  const StatementParseException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Header spellings seen across Brazilian issuers, folded and lowercased.
const _dateHeaders = ['data', 'data da compra', 'data compra', 'dt', 'date'];
const _merchantHeaders = [
  'estabelecimento',
  'descricao',
  'descrição',
  'historico',
  'histórico',
  'lancamento',
  'lançamento',
  'titulo',
  'título',
  'merchant',
  'description',
];
const _amountHeaders = [
  'valor',
  'valor (r\$)',
  'valor em r\$',
  'valor brl',
  'quantia',
  'amount',
  'value',
];

/// Words that mark a row as a payment of the invoice rather than a purchase.
const _paymentMarkers = [
  'pagamento recebido',
  'pagamento efetuado',
  'pgto recebido',
  'pagamento de fatura',
  'pagamento fatura',
  'saldo anterior',
  'estorno de pagamento',
];

/// Reads the cells of a statement sheet.
///
/// [cells] is the whole grid as text — the readers below do nothing but
/// produce it, so every rule about what a statement looks like lives here.
StatementParse parseStatementSheet(List<List<String>> cells) {
  final header = _findHeader(cells);
  if (header == null) {
    throw const StatementParseException(
      'Não encontrei as colunas de data, estabelecimento e valor. '
      'Confira se a planilha é o extrato exportado pelo banco.',
    );
  }

  final rows = <StatementRow>[];
  final skipped = <String>[];

  for (var index = header.row + 1; index < cells.length; index++) {
    final line = cells[index];
    final raw = line.join(' ').trim();
    if (raw.isEmpty) continue;

    final dateText = _cell(line, header.date);
    final merchant = _cell(line, header.merchant).trim();
    final amountText = _cell(line, header.amount);

    // A trailing totals line has an amount and no date. Skipping it silently
    // would be right; reporting it costs one line and proves the parser saw it.
    if (dateText.isEmpty && merchant.isEmpty) continue;

    final date = _parseDate(dateText);
    if (date == null) {
      skipped.add('Linha ${index + 1}: data não reconhecida ("$dateText")');
      continue;
    }
    if (merchant.isEmpty) {
      skipped.add('Linha ${index + 1}: sem estabelecimento');
      continue;
    }
    final amount = parseBrazilianAmount(_stripCurrency(amountText));
    if (amount == null) {
      skipped.add('Linha ${index + 1}: valor não reconhecido ("$amountText")');
      continue;
    }
    if (amount == 0) {
      skipped.add('Linha ${index + 1}: valor zerado');
      continue;
    }

    final folded = foldAccents(merchant.toLowerCase());
    // A negative amount on a credit-card export is a credit, and the payment
    // wording is the other half of the same signal.
    final isPayment =
        amount < 0 || _paymentMarkers.any((marker) => folded.contains(marker));

    final instalment = _installmentIn(merchant);

    rows.add(
      StatementRow(
        date: date,
        merchant: merchant,
        amount: amount.abs(),
        isPayment: isPayment,
        installmentCurrent: instalment?.$1,
        installmentTotal: instalment?.$2,
        // The parser never guesses a category, so every purchase arrives for
        // confirmation rather than landing categorised by accident.
        needsReview: true,
        reviewReason: 'Categoria não definida pela planilha',
      ),
    );
  }

  if (rows.isEmpty) {
    throw const StatementParseException(
      'Encontrei as colunas, mas nenhuma linha com data, estabelecimento e '
      'valor válidos.',
    );
  }

  return StatementParse(rows: rows, skipped: skipped, headerRow: header.row);
}

class _Header {
  const _Header({
    required this.row,
    required this.date,
    required this.merchant,
    required this.amount,
  });
  final int row;
  final int date;
  final int merchant;
  final int amount;
}

/// Finds the header row anywhere in the first stretch of the sheet.
///
/// Exports rarely start at A1: there is usually a title, the card number and a
/// blank line above the real table.
_Header? _findHeader(List<List<String>> cells) {
  for (var row = 0; row < cells.length && row < 25; row++) {
    final folded = cells[row]
        .map((cell) => foldAccents(cell.trim().toLowerCase()))
        .toList();

    final date = _columnFor(folded, _dateHeaders);
    final merchant = _columnFor(folded, _merchantHeaders);
    final amount = _columnFor(folded, _amountHeaders);
    if (date != null && merchant != null && amount != null) {
      return _Header(row: row, date: date, merchant: merchant, amount: amount);
    }
  }
  return null;
}

/// Exact match first, then a contained match.
///
/// Order matters: "valor" appears inside "valor total", and a contains-first
/// search would bind the amount column to a totals column when both exist.
int? _columnFor(List<String> header, List<String> names) {
  for (final name in names) {
    final folded = foldAccents(name);
    final exact = header.indexOf(folded);
    if (exact != -1) return exact;
  }
  for (final name in names) {
    final folded = foldAccents(name);
    for (var index = 0; index < header.length; index++) {
      if (header[index].isNotEmpty && header[index].contains(folded)) {
        return index;
      }
    }
  }
  return null;
}

String _cell(List<String> row, int index) =>
    index < row.length ? row[index] : '';

String _stripCurrency(String value) => value
    .replaceAll(RegExp(r'r\$|brl', caseSensitive: false), '')
    .replaceAll(RegExp(r'\s'), '')
    .trim();

/// `dd/MM/yyyy`, `dd/MM/yy`, `yyyy-MM-dd` and `dd-MM-yyyy`.
DateTime? _parseDate(String value) {
  final text = value.trim();
  if (text.isEmpty) return null;

  final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(text);
  if (iso != null) {
    return _build(
      int.parse(iso.group(1)!),
      int.parse(iso.group(2)!),
      int.parse(iso.group(3)!),
    );
  }

  final local = RegExp(
    r'^(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})',
  ).firstMatch(text);
  if (local != null) {
    final rawYear = int.parse(local.group(3)!);
    return _build(
      rawYear < 100 ? 2000 + rawYear : rawYear,
      int.parse(local.group(2)!),
      int.parse(local.group(1)!),
    );
  }
  return null;
}

/// Rejects a date the calendar does not have: `DateTime(2026, 2, 31)` rolls
/// forward to March in silence.
DateTime? _build(int year, int month, int day) {
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  final date = DateTime(year, month, day);
  return date.month == month && date.day == day ? date : null;
}

/// Reads `3/10`, `PARCELA 3 DE 10` and `03/10` out of a description.
(int, int)? _installmentIn(String merchant) {
  final folded = foldAccents(merchant.toLowerCase());

  final written = RegExp(
    r'parcela\s*(\d{1,2})\s*(?:/|de)\s*(\d{1,2})',
  ).firstMatch(folded);
  final match =
      written ??
      RegExp(r'(?<!\d)(\d{1,2})\s*/\s*(\d{1,2})(?!\d)').firstMatch(folded);
  if (match == null) return null;

  final current = int.parse(match.group(1)!);
  final total = int.parse(match.group(2)!);
  // A date fragment like 03/10 matches the same shape, so a "total" that could
  // be a month and a "current" that could be a day are both rejected unless
  // the instalment is spelled out.
  if (written == null && total <= 12 && current <= 31 && total < current) {
    return null;
  }
  if (total < 2 || current < 1 || current > total || total > 99) return null;
  return (current, total);
}
