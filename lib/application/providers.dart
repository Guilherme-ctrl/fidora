import 'package:financeiro_ai/domain/models.dart';
import 'package:financeiro_ai/domain/invoice_import.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class FinanceRepository {
  Future<FinanceSnapshot> loadSnapshot();
  Future<InvoiceImportPreview> previewInvoiceImport(
    InvoiceImportDocument document,
  );
  Future<InvoiceImportResult> importInvoice(InvoiceImportDocument document);
}

final financeRepositoryProvider = Provider<FinanceRepository>(
  (ref) => throw UnimplementedError(
    'FinanceRepository must be overridden at startup.',
  ),
);
final financeSnapshotProvider = FutureProvider<FinanceSnapshot>(
  (ref) => ref.watch(financeRepositoryProvider).loadSnapshot(),
);
