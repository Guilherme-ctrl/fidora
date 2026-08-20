import 'package:financeiro_ai/data/row_mappers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('invoiceFromRow', () {
    test('parses the PostgreSQL date returned by Supabase', () {
      final invoice = invoiceFromRow({
        'id': 'invoice-id',
        'card_id': 'card-id',
        'reference_month': '2026-08-01',
        'total': 123.45,
        'due_date': '2026-08-09',
        'status': 'paid',
      });

      expect(invoice.referenceMonth, DateTime(2026, 8, 1));
      expect(invoice.dueDate, DateTime(2026, 8, 9));
    });

    test('keeps compatibility with a YYYY-MM payload', () {
      final invoice = invoiceFromRow({
        'id': 'invoice-id',
        'card_id': 'card-id',
        'reference_month': '2026-08',
        'total': 123.45,
        'due_date': '2026-08-09',
        'status': 'paid',
      });

      expect(invoice.referenceMonth, DateTime(2026, 8, 1));
    });
  });
}
