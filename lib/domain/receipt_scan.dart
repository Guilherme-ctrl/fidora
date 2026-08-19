import 'package:clock/clock.dart';

/// What could be read off a photographed receipt.
///
/// Every field is nullable, and that is the design. Prefilling a wrong amount
/// into a ledger is worse than prefilling nothing: the person confirms a form
/// that already looks right and the error becomes a fact. Nothing is guessed —
/// a field is either supported by something the receipt actually says, or it
/// comes back null and the form stays empty.
class ReceiptScan {
  const ReceiptScan({
    required this.rawText,
    this.amount,
    this.merchant,
    this.date,
  });

  const ReceiptScan.empty()
    : rawText = '',
      amount = null,
      merchant = null,
      date = null;

  /// The text the recognizer produced, kept so the form can show it when the
  /// reading looks wrong and the person wants to see what was actually read.
  final String rawText;

  final double? amount;
  final String? merchant;
  final DateTime? date;

  bool get hasAnything => amount != null || merchant != null || date != null;
}

/// Labels that introduce the figure actually charged.
///
/// Ordered by how specific they are: a receipt often prints a subtotal, a
/// discount and then the real total, so the more specific label wins over a
/// bare "TOTAL" no matter where each appears.
const _totalLabels = <String>[
  'valor total a pagar',
  'total a pagar',
  'valor a pagar',
  'valor cobrado',
  'valor total',
  'total geral',
  'vlr total',
  'total r\$',
  'total',
];

/// Labels that contain "total" but never a price.
///
/// Without these, a supermarket receipt reading "TOTAL DE ITENS 7" prefills
/// seven reais.
const _notATotal = <String>[
  'total de itens',
  'total itens',
  'qtd total',
  'quantidade total',
  'total de produtos',
  'itens total',
];

/// Reads amount, merchant and date out of recognized receipt text.
ReceiptScan parseReceipt(String text, {DateTime? now}) {
  final lines = text
      .split(RegExp(r'[\r\n]+'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  return ReceiptScan(
    rawText: text,
    amount: _findAmount(lines),
    merchant: _findMerchant(lines),
    date: _findDate(lines, now: now),
  );
}

double? _findAmount(List<String> lines) {
  for (final label in _totalLabels) {
    // Later lines win within a label: a receipt that prints the total twice
    // ends with the one that was actually charged.
    for (final line in lines.reversed) {
      final lower = _fold(line);
      if (!lower.contains(label)) continue;
      if (_notATotal.any(lower.contains)) continue;

      final after = lower.substring(lower.indexOf(label) + label.length);
      final value = _firstAmountIn(after) ?? _firstAmountIn(lower);
      if (value != null && value > 0) return value;
    }
  }
  // No labelled total means no amount. Taking the largest number on the page
  // would happily return a CNPJ fragment, a barcode or a card number.
  return null;
}

/// The first Brazilian-formatted number in [text].
double? _firstAmountIn(String text) {
  final match = RegExp(
    r'(\d{1,3}(?:\.\d{3})+|\d+)(?:,(\d{1,2}))?',
  ).firstMatch(text.replaceAll(RegExp(r'r\$|rs\b'), ' '));
  if (match == null) return null;
  return parseBrazilianAmount(match.group(0)!);
}

/// Parses `1.234,56`, `45,90` and `45.90` to the same number.
///
/// A comma always means the decimal separator here, and dots before it are
/// thousands. Without a comma, a dot followed by exactly two digits is a
/// decimal point — some card slips print that way — while three digits after
/// the dot is a thousands separator, so `1.234` is one thousand two hundred and
/// thirty-four rather than one and a bit.
double? parseBrazilianAmount(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;

  if (text.contains(',')) {
    return double.tryParse(text.replaceAll('.', '').replaceAll(',', '.'));
  }
  final decimalDot = RegExp(r'^\d+\.\d{2}$');
  if (decimalDot.hasMatch(text)) return double.tryParse(text);
  return double.tryParse(text.replaceAll('.', ''));
}

/// Lines that are structure rather than a name.
final _notAName = <RegExp>[
  RegExp(r'\d{2}\.?\d{3}\.?\d{3}/?\d{4}-?\d{2}'), // CNPJ
  RegExp(r'\d{3}\.?\d{3}\.?\d{3}-?\d{2}'), // CPF
  RegExp(r'^\d{2}/\d{2}/\d{2,4}'), // a date line
  RegExp(r'^(cnpj|cpf|ie|im|insc)\b'),
  RegExp(r'^(rua|av|avenida|travessa|rod|rodovia|estrada|praca|praça)\b'),
  RegExp(r'^(cupom|documento|extrato|comprovante|nota fiscal|nfc-?e|sat)\b'),
  RegExp(r'^(tel|fone|telefone|cep)\b'),
  RegExp(r'^\d+$'),
];

String? _findMerchant(List<String> lines) {
  // The name is at the top: below it come the tax id, the address and the
  // items. Scanning the whole page would pick up a product description.
  for (final line in lines.take(6)) {
    final lower = _fold(line);
    if (_notAName.any((pattern) => pattern.hasMatch(lower))) continue;
    // Needs letters, and enough of them to be a name rather than a code.
    final letters = line.replaceAll(RegExp(r'[^A-Za-zÀ-ÿ]'), '');
    if (letters.length < 3) continue;

    final cleaned = line
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[^A-Za-zÀ-ÿ0-9]+|[^A-Za-zÀ-ÿ0-9]+$'), '')
        .trim();
    if (cleaned.isEmpty) continue;
    return cleaned.length > 60 ? cleaned.substring(0, 60).trim() : cleaned;
  }
  return null;
}

DateTime? _findDate(List<String> lines, {DateTime? now}) {
  final today = now ?? clock.now();
  final pattern = RegExp(r'(\d{2})/(\d{2})/(\d{2,4})');

  for (final line in lines) {
    for (final match in pattern.allMatches(line)) {
      final day = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      final rawYear = int.parse(match.group(3)!);
      final year = rawYear < 100 ? 2000 + rawYear : rawYear;

      if (month < 1 || month > 12 || day < 1 || day > 31) continue;
      final date = DateTime(year, month, day);
      // Round-trip check: DateTime(2026, 2, 31) silently becomes 3 March.
      if (date.day != day || date.month != month) continue;

      // A receipt cannot be from the future, and one from before this decade
      // is a misread rather than a very old purchase.
      if (date.isAfter(today)) continue;
      if (date.isBefore(DateTime(today.year - 5))) continue;
      return date;
    }
  }
  return null;
}

/// Lowercase and accent-insensitive, so `SÃO` and `SAO` compare equal.
String _fold(String value) {
  const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const to = 'aaaaaeeeeiiiiooooouuuucn';
  final lower = value.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    final index = from.indexOf(char);
    buffer.write(index == -1 ? char : to[index]);
  }
  return buffer.toString();
}
