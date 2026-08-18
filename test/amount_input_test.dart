import 'package:financeiro_ai/domain/amount_input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseAmountInput', () {
    test('reads the Brazilian decimal comma', () {
      expect(parseAmountInput('24,80'), 24.80);
    });

    test('drops thousand separators when a comma is present', () {
      expect(parseAmountInput('1.234,56'), 1234.56);
      expect(parseAmountInput('12.345.678,90'), 12345678.90);
    });

    test('accepts a lone dot as a decimal point', () {
      expect(parseAmountInput('24.80'), 24.80);
    });

    test('ignores currency symbols and spaces', () {
      expect(parseAmountInput(r'R$ 1.999,90'), 1999.90);
    });

    test('reads a plain integer', () {
      expect(parseAmountInput('150'), 150);
    });

    test('returns null for empty or non-numeric input', () {
      expect(parseAmountInput(''), isNull);
      expect(parseAmountInput('   '), isNull);
      expect(parseAmountInput('abc'), isNull);
      expect(parseAmountInput(r'R$'), isNull);
    });

    test('returns null instead of a malformed number', () {
      expect(parseAmountInput('1,2,3'), isNull);
    });

    test('keeps a negative sign so validation can reject it', () {
      expect(parseAmountInput('-10'), -10);
    });
  });
}
