import 'dart:convert';

import 'package:financeiro_ai/features/imports/domain/invoice_import.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> fixture() => {
    'schema_version': '1.0',
    'request_id': 'test-itau-1234-2026-09',
    'source': 'chatgpt',
    'invoice': {
      'bank': 'Itaú',
      'card_last_four': '1234',
      'reference_month': '2026-09-01',
      'closing_date': null,
      'due_date': '2026-09-09',
      'statement_total': 94.5,
      'currency': 'BRL',
      'source_file': 'fixture.json',
    },
    'transactions': [
      {
        'external_id': 'purchase-1',
        'purchased_at': '2026-08-10',
        'merchant_original': 'LOJA TESTE',
        'merchant_normalized': 'LOJA TESTE',
        'amount': 100.0,
        'movement_type': 'purchase',
        'modality': 'installment',
        'installment': {
          'current': 1,
          'total': 2,
          'installment_amount': 100.0,
          'total_purchase_amount': null,
        },
        'category': 'Compras',
        'subcategory': null,
        'confidence': 0.98,
        'needs_review': false,
        'review_reason': null,
        'notes': null,
      },
      {
        'external_id': 'refund-1',
        'purchased_at': '2026-08-11',
        'merchant_original': 'ESTORNO TESTE',
        'merchant_normalized': 'ESTORNO TESTE',
        'amount': 5.5,
        'movement_type': 'refund',
        'modality': 'cash',
        'installment': null,
        'category': 'Compras',
        'subcategory': null,
        'confidence': 1.0,
        'needs_review': false,
        'review_reason': null,
        'notes': null,
      },
      {
        'external_id': 'payment-1',
        'purchased_at': '2026-08-12',
        'merchant_original': 'PAGAMENTO EFETUADO',
        'merchant_normalized': 'PAGAMENTO EFETUADO',
        'amount': 500.0,
        'movement_type': 'transfer',
        'modality': 'cash',
        'installment': null,
        'category': 'Financeiro',
        'subcategory': 'Pagamento de fatura',
        'confidence': 1.0,
        'needs_review': false,
        'review_reason': null,
        'notes': null,
      },
    ],
    'processing': {
      'reconcile_with_shortcut': true,
      'create_missing_categories': false,
      'send_uncertain_to_review': true,
    },
  };

  test('decodes a balanced invoice and excludes payments from total', () {
    final document = InvoiceImportDocument.decode(jsonEncode(fixture()));
    expect(document.transactions, hasLength(3));
    expect(document.computedTotal, 94.5);
    expect(document.paymentCount, 1);
    expect(document.installmentCount, 1);
  });

  test('rejects a statement whose movements do not reconcile', () {
    final payload = fixture();
    (payload['invoice'] as Map<String, dynamic>)['statement_total'] = 95.0;
    expect(
      () => InvoiceImportDocument.fromJson(payload),
      throwsA(isA<InvoiceImportException>()),
    );
  });

  test('rejects duplicate external identifiers', () {
    final payload = fixture();
    final transactions = payload['transactions'] as List<dynamic>;
    (transactions[1] as Map<String, dynamic>)['external_id'] = 'purchase-1';
    expect(
      () => InvoiceImportDocument.fromJson(payload),
      throwsA(isA<InvoiceImportException>()),
    );
  });

  test('preserves statement balance after an item-level personal decision', () {
    final document = InvoiceImportDocument.fromJson(fixture());
    final updated = document.transactions
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    updated.first['include_in_totals'] = false;
    updated.first['needs_review'] = false;

    final reviewed = document.withTransactions(updated);
    expect(reviewed.computedTotal, 94.5);
    expect(reviewed.transactions.first['include_in_totals'], isFalse);
  });

  test('parses per-item reconciliation dispositions', () {
    final preview = InvoiceImportPreview.fromJson({
      'rows': 1,
      'to_create': 0,
      'to_reconcile': 1,
      'duplicates': 0,
      'reviews': 0,
      'payments_ignored': 0,
      'missing_categories': <String>[],
      'already_imported': false,
      'items': [
        {'external_id': 'purchase-1', 'disposition': 'reconcile'},
      ],
    });
    expect(preview.itemsByExternalId['purchase-1']?.disposition, 'reconcile');
  });

  test('approves creation of unknown categories without renaming them', () {
    final payload = fixture();
    final template = Map<String, dynamic>.from(
      (payload['transactions'] as List).first as Map<String, dynamic>,
    );
    payload['transactions'] = [
      Map<String, dynamic>.from(template)
        ..['external_id'] = 'gift-1'
        ..['amount'] = 70.0
        ..['modality'] = 'cash'
        ..['installment'] = null
        ..['category'] = 'Presentes',
      Map<String, dynamic>.from(template)
        ..['external_id'] = 'gift-2'
        ..['amount'] = 30.0
        ..['modality'] = 'cash'
        ..['installment'] = null
        ..['category'] = 'Presentes',
    ];
    (payload['invoice'] as Map<String, dynamic>)['statement_total'] = 100.0;
    final document = InvoiceImportDocument.fromJson(payload);

    final approved = document.withCreateMissingCategories(true);

    expect(approved.transactions.map((item) => item['category']), [
      'Presentes',
      'Presentes',
    ]);
    expect(approved.createMissingCategories, isTrue);
    expect(approved.statementTotal, 100);
  });
}
