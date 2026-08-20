import 'package:financeiro_ai/features/imports/domain/invoice_import.dart';
import 'package:financeiro_ai/features/imports/domain/usecases/import_invoice.dart';
import 'package:flutter_test/flutter_test.dart';

/// The rule that decides whether money enters the ledger.
///
/// It lived inside `MorePage._runImport`, spelled out between two repository
/// calls, and had no test: reaching it meant pumping the settings page,
/// choosing a file and driving a review dialog. It is a static function now.
InvoiceImportPreview preview({
  List<String> missingCategories = const [],
  bool alreadyImported = false,
}) => InvoiceImportPreview(
  rows: 1,
  toCreate: 1,
  toReconcile: 0,
  duplicates: 0,
  reviews: 0,
  paymentsIgnored: 0,
  missingCategories: missingCategories,
  alreadyImported: alreadyImported,
  items: const [],
);

InvoiceImportDocument document({bool createMissingCategories = false}) =>
    InvoiceImportDocument.fromJson({
      'schema_version': '1.0',
      'request_id': 'r1',
      'source': 'sheet',
      'invoice': {
        'bank': 'Itaú',
        'card_last_four': '1234',
        'reference_month': '2026-09-01',
        'due_date': '2026-09-09',
        'statement_total': 10.0,
        'currency': 'BRL',
        'source_file': 'f.json',
      },
      // The document validates itself on construction, so a fixture cannot be
      // emptier than the rules allow.
      'transactions': const [
        {
          'external_id': 'p1',
          'purchased_at': '2026-08-10',
          'merchant_original': 'LOJA',
          'merchant_normalized': 'LOJA',
          'amount': 10.0,
          'movement_type': 'purchase',
          'modality': 'cash',
          'installment': null,
          'category': 'Outros',
          'subcategory': null,
          'confidence': 1.0,
          'needs_review': false,
          'review_reason': null,
          'notes': null,
        },
      ],
      if (createMissingCategories)
        'processing': {'create_missing_categories': true},
    });

void main() {
  group('ImportInvoiceUseCase.mayImport', () {
    test('a clean preview may be imported', () {
      expect(mayImport(document(), preview()), isTrue);
    });

    test('missing categories block the import', () {
      expect(
        mayImport(document(), preview(missingCategories: ['Pets'])),
        isFalse,
      );
    });

    test('unless the person asked for them to be created', () {
      expect(
        mayImport(
          document(createMissingCategories: true),
          preview(missingCategories: ['Pets']),
        ),
        isTrue,
      );
    });

    test('an already-imported batch never passes', () {
      // The promise the whole product rests on: a purchase is not counted
      // twice. This must hold even when every other signal says go — which is
      // the case the old inline condition got right and nothing verified.
      expect(
        mayImport(document(), preview(alreadyImported: true)),
        isFalse,
      );
    });

    test('and not even with categories approved', () {
      expect(
        mayImport(
          document(createMissingCategories: true),
          preview(missingCategories: ['Pets'], alreadyImported: true),
        ),
        isFalse,
      );
    });

    test('approving creation does nothing when nothing is missing', () {
      expect(
        mayImport(document(createMissingCategories: true), preview()),
        isTrue,
      );
    });
  });
}

bool mayImport(InvoiceImportDocument d, InvoiceImportPreview p) =>
    ImportInvoiceUseCase.mayImport(d, p);
