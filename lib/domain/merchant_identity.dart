/// What a statement line says about who was paid.
///
/// A Pix line carries a name; sometimes it also carries the document. When the
/// document is a CNPJ, the line of business is a free lookup away — the CNAE is
/// published by the Receita Federal. When it is a CPF, or when there is no
/// document at all, no lookup exists that would help.
///
/// Everything here is pure string work on the description a bank already gives
/// us. Nothing is fetched, and nothing leaves the device.
library;

enum PayeeKind {
  /// A CNPJ was found and it checks out: the line of business is knowable.
  business,

  /// A CPF was found. A person has no line of business.
  person,

  /// The bank masked the document — Nubank writes `•••.456.789-••`. It tells us
  /// this was a person, and nothing more.
  maskedPerson,

  /// Reads as a Pix but carries no document. Only the name is available, and
  /// matching a name to a company is a guess.
  pixNameOnly,

  /// Everything else: card purchases, fees, invoice payments.
  other,
}

class PayeeIdentity {
  const PayeeIdentity({required this.kind, this.cnpj, this.isPix = false});

  final PayeeKind kind;

  /// Fourteen digits, no punctuation, check digits verified.
  final String? cnpj;

  final bool isPix;

  bool get canLookUpActivity => cnpj != null;
}

/// Words the Brazilian banks use for a Pix in a statement description.
const _pixMarkers = [
  'pix',
  'transferencia pix',
  'transferência pix',
  'pix enviado',
  'pix recebido',
];

final _punctuatedCnpj = RegExp(r'\b\d{2}\.\d{3}\.\d{3}/\d{4}-\d{2}\b');
final _bareCnpj = RegExp(r'(?<!\d)\d{14}(?!\d)');
final _punctuatedCpf = RegExp(r'\b\d{3}\.\d{3}\.\d{3}-\d{2}\b');
final _bareCpf = RegExp(r'(?<!\d)\d{11}(?!\d)');

/// Nubank and others hide most of the digits: `•••.456.789-••`, `***.456.789-**`.
final _maskedCpf = RegExp(r'[•*]{2,3}\.?\d{3}\.\d{3}-?[•*]{2}');

/// Reads a statement description.
PayeeIdentity readPayee(String description) {
  final text = description.toLowerCase();
  final isPix = _pixMarkers.any(text.contains);

  final cnpj = extractCnpj(description);
  if (cnpj != null) {
    return PayeeIdentity(kind: PayeeKind.business, cnpj: cnpj, isPix: isPix);
  }

  if (_punctuatedCpf.hasMatch(description) ||
      _bareCpf.allMatches(description).any((m) => isValidCpf(m.group(0)!))) {
    return PayeeIdentity(kind: PayeeKind.person, isPix: isPix);
  }

  if (_maskedCpf.hasMatch(description)) {
    return PayeeIdentity(kind: PayeeKind.maskedPerson, isPix: isPix);
  }

  return PayeeIdentity(
    kind: isPix ? PayeeKind.pixNameOnly : PayeeKind.other,
    isPix: isPix,
  );
}

/// The first CNPJ in [text] whose check digits are right.
///
/// The verification matters: a fourteen-digit run in a statement is more often
/// a transaction id than a company, and counting those would make the coverage
/// number a lie.
String? extractCnpj(String text) {
  final candidates = <String>[
    ..._punctuatedCnpj.allMatches(text).map((m) => _digits(m.group(0)!)),
    ..._bareCnpj.allMatches(text).map((m) => m.group(0)!),
  ];
  for (final candidate in candidates) {
    if (isValidCnpj(candidate)) return candidate;
  }
  return null;
}

String _digits(String value) => value.replaceAll(RegExp(r'\D'), '');

bool isValidCnpj(String value) {
  final digits = _digits(value);
  if (digits.length != 14) return false;
  if (RegExp(r'^(\d)\1{13}$').hasMatch(digits)) return false;

  int check(int length) {
    var weight = length - 7;
    var sum = 0;
    for (var i = 0; i < length; i++) {
      sum += int.parse(digits[i]) * weight;
      weight -= 1;
      if (weight < 2) weight = 9;
    }
    final rest = sum % 11;
    return rest < 2 ? 0 : 11 - rest;
  }

  return check(12) == int.parse(digits[12]) &&
      check(13) == int.parse(digits[13]);
}

bool isValidCpf(String value) {
  final digits = _digits(value);
  if (digits.length != 11) return false;
  if (RegExp(r'^(\d)\1{10}$').hasMatch(digits)) return false;

  int check(int length) {
    var sum = 0;
    for (var i = 0; i < length; i++) {
      sum += int.parse(digits[i]) * (length + 1 - i);
    }
    final rest = (sum * 10) % 11;
    return rest == 10 ? 0 : rest;
  }

  return check(9) == int.parse(digits[9]) && check(10) == int.parse(digits[10]);
}

/// What a set of descriptions would let us classify automatically.
///
/// This is the number the spike exists to produce: if most lines carry a CNPJ,
/// a CNAE lookup is worth building; if most carry only a name, it is guesswork
/// dressed as data.
class PayeeCoverage {
  PayeeCoverage();

  final Map<PayeeKind, int> counts = {for (final k in PayeeKind.values) k: 0};
  int total = 0;
  int pix = 0;
  final Set<String> distinctCnpj = {};

  void add(String description) {
    total += 1;
    final payee = readPayee(description);
    counts[payee.kind] = counts[payee.kind]! + 1;
    if (payee.isPix) pix += 1;
    if (payee.cnpj != null) distinctCnpj.add(payee.cnpj!);
  }

  int get resolvable => counts[PayeeKind.business]!;

  double get shareOfAll => total == 0 ? 0 : resolvable / total;

  double get shareOfPix => pix == 0 ? 0 : resolvable / pix;
}
