import 'package:equatable/equatable.dart';
import 'package:financeiro_ai/core/errors/failure.dart';
import 'package:financeiro_ai/features/ledger/domain/entities/models.dart';

/// The ledger, in the two halves it is actually loaded in.
///
/// The split is not cosmetic and predates this rewrite: the catalogue —
/// categories, cards, goals, holders, accounts — changes when someone edits a
/// screen, and the ledger changes on every captured purchase. Refetching the
/// catalogue after recording a coffee was work that could not change the
/// result. [reloadLedger] is what keeps that true.
class FinanceState extends Equatable {
  const FinanceState({
    this.catalog,
    this.ledger,
    this.failure,
    this.stack,
    this.busy = false,
  });

  final FinanceCatalog? catalog;
  final FinanceLedger? ledger;
  final Failure? failure;
  final StackTrace? stack;

  /// A load is in flight. Both halves report through one flag because the
  /// screen has one spinner.
  final bool busy;

  /// The single object every screen reads, composed from the two halves.
  ///
  /// Null until both have arrived — a snapshot with a ledger and no catalogue
  /// would render transactions whose categories cannot be resolved.
  FinanceSnapshot? get snapshot {
    final catalog = this.catalog;
    final ledger = this.ledger;
    if (catalog == null || ledger == null) return null;
    return FinanceSnapshot.compose(catalog: catalog, ledger: ledger);
  }

  bool get hasFailure => failure != null;

  FinanceState copyWith({
    FinanceCatalog? catalog,
    FinanceLedger? ledger,
    bool? busy,
    bool clearFailure = false,
  }) => FinanceState(
    catalog: catalog ?? this.catalog,
    ledger: ledger ?? this.ledger,
    failure: clearFailure ? null : failure,
    stack: clearFailure ? null : stack,
    busy: busy ?? this.busy,
  );

  FinanceState failing(Failure failure, StackTrace stack) => FinanceState(
    catalog: catalog,
    ledger: ledger,
    failure: failure,
    stack: stack,
  );

  @override
  List<Object?> get props => [catalog, ledger, failure, busy];
}
