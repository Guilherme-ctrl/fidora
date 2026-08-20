import 'package:equatable/equatable.dart';
import 'package:financeiro_ai/core/errors/failure.dart';

/// The four shapes any loaded thing can be in.
///
/// One type rather than one per screen: every list in this app loads the same
/// way — nothing yet, working, here it is, it went wrong — and writing that
/// four times would be four chances for them to disagree about what "empty"
/// means.
///
/// [LoadFailed] carries a [Failure], not a message. The copy is chosen by the
/// widget, which is the arrangement unit 1 established and which this must not
/// quietly undo.
sealed class LoadState<T> extends Equatable {
  const LoadState();

  /// The data if there is any, null otherwise.
  ///
  /// Lets a screen keep showing the previous contents while a refresh is in
  /// flight, instead of blanking to a spinner on every pull.
  T? get dataOrNull => switch (this) {
    LoadSuccess<T>(:final data) => data,
    LoadReloading<T>(:final previous) => previous,
    _ => null,
  };

  bool get isBusy => this is LoadInProgress<T> || this is LoadReloading<T>;

  @override
  List<Object?> get props => [dataOrNull];
}

class LoadInitial<T> extends LoadState<T> {
  const LoadInitial();
}

class LoadInProgress<T> extends LoadState<T> {
  const LoadInProgress();
}

/// Working, but the previous contents are still worth drawing.
class LoadReloading<T> extends LoadState<T> {
  const LoadReloading(this.previous);
  final T previous;

  @override
  List<Object?> get props => [previous, 'reloading'];
}

class LoadSuccess<T> extends LoadState<T> {
  const LoadSuccess(this.data);
  final T data;

  @override
  List<Object?> get props => [data];
}

class LoadFailed<T> extends LoadState<T> {
  const LoadFailed(this.failure, this.stack);
  final Failure failure;
  final StackTrace stack;

  @override
  List<Object?> get props => [failure, 'failed'];
}
