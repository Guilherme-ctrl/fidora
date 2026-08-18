DateTime invoiceCompetence(DateTime purchaseDate, int closingDay) => DateTime(
  purchaseDate.year,
  purchaseDate.month + (purchaseDate.day > closingDay ? 1 : 0),
);

/// Strips diacritics so `FARMÁCIA` and `FARMACIA` are the same merchant.
///
/// Dart has no built-in fold, and this used to be the divergence: the Edge
/// Function stripped accents via NFD while this side kept them, so the same
/// merchant normalized two different ways depending on how it was captured.
String foldAccents(String value) {
  const from = 'àáâãäåèéêëìíîïòóôõöùúûüçñÀÁÂÃÄÅÈÉÊËÌÍÎÏÒÓÔÕÖÙÚÛÜÇÑ';
  const to = 'aaaaaaeeeeiiiiooooouuuucnAAAAAAEEEEIIIIOOOOOUUUUCN';
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    final char = String.fromCharCode(rune);
    final index = from.indexOf(char);
    buffer.write(index == -1 ? char : to[index]);
  }
  return buffer.toString();
}

String normalizeMerchant(String value) => foldAccents(value)
    .replaceAll(RegExp(r'[^A-Za-z0-9 ]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim()
    .toUpperCase();
