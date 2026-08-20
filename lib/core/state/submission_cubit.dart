import 'package:equatable/equatable.dart';
import 'package:financeiro_ai/core/errors/failure.dart';
import 'package:financeiro_ai/core/logging/logger.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// One write in flight.
///
/// Six forms had the same `_submit`: set busy, call the repository, catch
/// [Failure] into a message, catch everything else into a message and a log,
/// clear busy. They were identical apart from the draft being built and the
/// label in the log line — which is exactly the kind of repetition that lets
/// two of them drift and nobody notice.
///
/// [SubmissionFailed] carries the [Failure], not a sentence. `core` must not
/// know how the product phrases things, and the widget already resolves copy.
sealed class SubmissionState extends Equatable {
  const SubmissionState();

  bool get isBusy => this is SubmissionInProgress;

  /// The failure to show, or null when there is nothing to say.
  Failure? get failure =>
      this is SubmissionFailed ? (this as SubmissionFailed).cause : null;

  @override
  List<Object?> get props => [runtimeType, failure];
}

class SubmissionIdle extends SubmissionState {
  const SubmissionIdle();
}

class SubmissionInProgress extends SubmissionState {
  const SubmissionInProgress();
}

class SubmissionSucceeded extends SubmissionState {
  const SubmissionSucceeded();
}

class SubmissionFailed extends SubmissionState {
  const SubmissionFailed(this.cause);
  final Failure cause;

  @override
  List<Object?> get props => [cause];
}

class SubmissionCubit extends Cubit<SubmissionState> {
  SubmissionCubit() : super(const SubmissionIdle());

  /// Runs [action], reporting the outcome as state.
  ///
  /// Returns whether it succeeded, so a caller that has to do something with
  /// the widget tree afterwards — closing a sheet, almost always — can do it
  /// without subscribing to the state to find out.
  ///
  /// [label] names the operation in the log. It is the only thing the six
  /// copies of this actually varied.
  Future<bool> run(String label, Future<void> Function() action) async {
    emit(const SubmissionInProgress());
    try {
      await action();
      if (!isClosed) emit(const SubmissionSucceeded());
      return true;
    } on Failure catch (failure) {
      if (!isClosed) emit(SubmissionFailed(failure));
      return false;
    } catch (error, stack) {
      // The cause is logged rather than discarded — the habit this codebase
      // had eight of, and has none of now.
      appLogger.error(label, error, stack);
      if (!isClosed) emit(SubmissionFailed(asFailure(error, stack)));
      return false;
    }
  }

  /// Clears a previous failure, so a form that is being corrected stops
  /// showing the error from the attempt before.
  void reset() {
    if (!isClosed && state is! SubmissionIdle) emit(const SubmissionIdle());
  }
}
