import 'package:financeiro_ai/domain/finance_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('invoiceCompetence', () {
    test('keeps purchases before closing in the current competence', () {
      expect(invoiceCompetence(DateTime(2026, 8, 2), 2), DateTime(2026, 8));
    });

    test('moves purchases after closing to next competence', () {
      expect(invoiceCompetence(DateTime(2026, 8, 3), 2), DateTime(2026, 9));
    });

    test('rolls December purchases into January', () {
      expect(invoiceCompetence(DateTime(2026, 12, 31), 20), DateTime(2027, 1));
    });
  });

  test('normalizes merchant names for matching', () {
    expect(normalizeMerchant('  MP*Terabyte-shop  '), 'MP TERABYTE SHOP');
  });
}
