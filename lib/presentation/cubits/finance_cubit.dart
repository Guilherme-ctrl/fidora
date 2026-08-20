import 'package:financeiro_ai/core/errors/failure.dart';
import 'package:financeiro_ai/domain/models.dart';
import 'package:financeiro_ai/domain/repositories/repositories.dart';
import 'package:financeiro_ai/presentation/states/finance_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Owns the ledger every screen reads.
class FinanceCubit extends Cubit<FinanceState> {
  FinanceCubit({
    required CatalogRepository catalog,
    required TransactionRepository transactions,
  }) : _catalog = catalog,
       _transactions = transactions,
       super(const FinanceState());

  final CatalogRepository _catalog;
  final TransactionRepository _transactions;

  /// Both halves, in flight together.
  ///
  /// Splitting them is about what gets *refetched* after a write, not about
  /// making the first load serial.
  Future<void> load() async {
    emit(state.copyWith(busy: true, clearFailure: true));
    try {
      final results = await Future.wait([
        _catalog.loadCatalog(),
        _transactions.loadLedger(),
      ]);
      emit(
        FinanceState(
          catalog: results[0] as FinanceCatalog,
          ledger: results[1] as FinanceLedger,
        ),
      );
    } on Failure catch (failure, stack) {
      emit(state.failing(failure, stack));
    } catch (error, stack) {
      emit(state.failing(asFailure(error, stack), stack));
    }
  }

  /// Reloads only what a captured, edited or deleted transaction can change.
  ///
  /// Cards, categories, holders and accounts are edited from their own screens
  /// and cannot move because a purchase was recorded.
  Future<void> reloadLedger() async {
    emit(state.copyWith(busy: true, clearFailure: true));
    try {
      emit(
        state.copyWith(
          ledger: await _transactions.loadLedger(),
          busy: false,
          clearFailure: true,
        ),
      );
    } on Failure catch (failure, stack) {
      emit(state.failing(failure, stack));
    } catch (error, stack) {
      emit(state.failing(asFailure(error, stack), stack));
    }
  }

  /// Everything, for a pull-to-refresh that promises exactly that.
  Future<void> reloadAll() => load();
}
