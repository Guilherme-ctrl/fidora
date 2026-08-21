import 'package:financeiro_ai/features/ledger/domain/repositories/repositories.dart';
import 'package:financeiro_ai/features/ledger/presenter/cubits/list_cubit.dart';
import 'package:financeiro_ai/features/ledger/domain/entities/models.dart';

/// Moved out of `catalog`, where the mechanical modularisation had left it.
/// A file called `catalog_cubits.dart` holding the review queue, the shortcut
/// tokens and the import batches was five cross-feature edges that existed for
/// no reason but the name of the file they were in.

class ImportBatchesCubit extends ListCubit<ImportBatch> {
  ImportBatchesCubit(this._repository);
  final InvoiceRepository _repository;

  @override
  Future<List<ImportBatch>> fetch() => _repository.loadImportBatches();
}
