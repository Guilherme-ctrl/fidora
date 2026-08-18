/// Parses what a person types into an amount field.
///
/// Deliberately mirrors `parseAmount` in the `capture-transaction` Edge
/// Function so a value typed by hand and a value sent by the Shortcut are read
/// the same way: a comma marks the decimals and dots are thousand separators,
/// but a lone dot is accepted as a decimal point for anyone typing `24.80`.
double? parseAmountInput(String raw) {
  var text = raw.replaceAll(RegExp(r'[^\d,.-]'), '');
  if (text.isEmpty) return null;
  if (text.contains(',')) {
    text = text.replaceAll('.', '').replaceAll(',', '.');
  }
  final value = double.tryParse(text);
  if (value == null || value.isNaN || value.isInfinite) return null;
  return value;
}
