import 'package:financeiro_ai/core/errors/failure.dart';
import 'package:financeiro_ai/core/state/load_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// A cubit for a screen that loads one list and reloads it after a write.
///
/// Four screens do exactly this — the review queue, merchant rules, shortcut
/// tokens and import batches — and each was a `FutureProvider` plus a
/// hand-written `refreshX(ref)` helper. The four helpers were identical apart
/// from the provider they invalidated.
///
/// Subclasses supply the fetch and add their own writes; the loading, the
/// failure trapping and the reload-in-place are here once.
abstract class ListCubit<T> extends Cubit<LoadState<List<T>>> {
  ListCubit() : super(LoadInitial<List<T>>());

  Future<List<T>> fetch();

  Future<void> load() async {
    final previous = state.dataOrNull;
    emit(
      previous == null
          ? LoadInProgress<List<T>>()
          : LoadReloading<List<T>>(previous),
    );
    await _run();
  }

  /// Reloads after a write. Named apart from [load] so a call site says which
  /// of the two it meant.
  Future<void> reload() => load();

  /// Loads only if nothing has been loaded yet.
  ///
  /// The screens these back call this when they appear, which is what keeps
  /// the old promise that the review queue is fetched when someone opens it
  /// and not on the app's first paint. Two screens read the queue — Hoje peeks
  /// at the next item — so whichever appears first pays for it and the second
  /// finds it already there.
  Future<void> loadOnce() async {
    if (state is LoadInitial<List<T>>) await load();
  }

  Future<void> _run() async {
    try {
      emit(LoadSuccess<List<T>>(await fetch()));
    } on Failure catch (failure, stack) {
      emit(LoadFailed<List<T>>(failure, stack));
    } catch (error, stack) {
      emit(LoadFailed<List<T>>(asFailure(error, stack), stack));
    }
  }
}
