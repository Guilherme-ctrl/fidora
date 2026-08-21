import 'dart:convert';
import 'dart:typed_data';

import 'package:financeiro_ai/features/imports/domain/invoice_import.dart';
import 'package:financeiro_ai/features/imports/domain/statement_import.dart';
import 'package:financeiro_ai/features/imports/domain/statement_sheet.dart';
import 'package:financeiro_ai/features/ledger/domain/repositories/repositories.dart';

/// Bringing an invoice into the ledger.
///
/// This lived inside `MorePage` as a private method, interleaved with
/// `Navigator.pop` and `ScaffoldMessenger` — a 150-line orchestration with a
/// real business rule buried in it, reachable only by pumping a widget tree.
/// The rule had no unit test at all, and it is the rule that decides whether
/// money enters the ledger.
class ImportInvoiceUseCase {
  const ImportInvoiceUseCase(this._repository);

  final InvoiceRepository _repository;

  /// What would happen, without doing it. Shown to the person for review.
  Future<InvoiceImportPreview> preview(InvoiceImportDocument document) =>
      _repository.previewInvoiceImport(document);

  /// Re-checks the reviewed document and writes it only if it may be written.
  ///
  /// The second preview is not redundant: the review dialog can add categories
  /// and change item decisions, so the document that arrives here is not the
  /// one that was previewed. Writing on the strength of the first preview
  /// would import a document nothing had validated.
  Future<InvoiceImportResult> commit(InvoiceImportDocument reviewed) async {
    final preview = await _repository.previewInvoiceImport(reviewed);
    if (!mayImport(reviewed, preview)) {
      throw const InvoiceImportException(
        'Ainda existem categorias ou duplicidades que impedem a importação.',
      );
    }
    return _repository.importInvoice(reviewed);
  }

  /// Whether a reviewed document may enter the ledger.
  ///
  /// Static and free of the repository so the rule can be tested directly,
  /// which is the whole reason this class exists:
  ///
  /// * an already-imported batch never passes, whatever else is true — that is
  ///   the promise that a purchase is not counted twice;
  /// * otherwise the preview decides, unless the only thing standing in the
  ///   way is missing categories and the person asked for them to be created.
  static bool mayImport(
    InvoiceImportDocument document,
    InvoiceImportPreview preview,
  ) {
    if (preview.alreadyImported) return false;
    final missingCategoriesApproved =
        document.createMissingCategories &&
        preview.missingCategories.isNotEmpty;
    return preview.canImport || missingCategoriesApproved;
  }
}

/// Reads the JSON the app itself exports.
InvoiceImportDocument decodeInvoiceDocument(Uint8List bytes) =>
    InvoiceImportDocument.decode(utf8.decode(bytes));

/// Reads a bank's own spreadsheet export.
///
/// [readXlsx] is injected rather than imported: the XLSX decoder is
/// infrastructure, and the domain must not reach for it.
StatementParse parseStatementBytes({
  required Uint8List bytes,
  required String fileName,
  required List<List<String>> Function(Uint8List) readXlsx,
}) {
  final cells = fileName.toLowerCase().endsWith('.xlsx')
      ? readXlsx(bytes)
      : readDelimitedCells(decodeStatementText(bytes));
  return parseStatementSheet(cells);
}

/// UTF-8 when it decodes, Latin-1 otherwise.
///
/// A statement exported by an older banking site is not always UTF-8, and a
/// hard decode failure would surface as "arquivo ilegível" when the file is
/// perfectly readable in another encoding.
String decodeStatementText(Uint8List bytes) {
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return latin1.decode(bytes, allowInvalid: true);
  }
}
