DateTime invoiceCompetence(DateTime purchaseDate, int closingDay) => DateTime(
  purchaseDate.year,
  purchaseDate.month + (purchaseDate.day > closingDay ? 1 : 0),
);

String normalizeMerchant(String value) => value
    .trim()
    .toUpperCase()
    .replaceAll(RegExp(r'[^A-Z0-9À-Ú ]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ');
