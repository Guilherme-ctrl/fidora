import 'package:financeiro_ai/core/errors/failure.dart';
import 'package:financeiro_ai/core/logging/logger.dart';
import 'package:financeiro_ai/core/state/submission_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

/// Six forms hand-rolled this: set busy, call, catch a Failure into a message,
/// catch everything else into a message and a log, clear busy. They were
/// identical apart from the draft and the log label, which is the kind of
/// repetition that lets two of them drift without anyone noticing.
void main() {
  setUp(() => appLogger = const SilentLogger());

  test('a write that succeeds reports it and clears busy', () async {
    final cubit = SubmissionCubit();
    addTearDown(cubit.close);

    final ok = await cubit.run('x', () async {});

    expect(ok, isTrue);
    expect(cubit.state, isA<SubmissionSucceeded>());
    expect(cubit.state.isBusy, isFalse);
  });

  test('a typed failure survives as a type, not a sentence', () async {
    final cubit = SubmissionCubit();
    addTearDown(cubit.close);

    final ok = await cubit.run('x', () async => throw const DuplicateCard());

    expect(ok, isFalse);
    expect(cubit.state.failure, isA<DuplicateCard>());
  });

  test('an unrecognised error is classified and logged, not discarded', () {
    final logged = <String>[];
    appLogger = _RecordingLogger(logged);
    final cubit = SubmissionCubit();
    addTearDown(cubit.close);

    return cubit.run('saveCard', () async => throw StateError('boom')).then((
      ok,
    ) {
      expect(ok, isFalse);
      expect(cubit.state.failure, isA<UnexpectedFailure>());
      // The habit this codebase had eight of, and has none of now.
      expect(logged, ['saveCard']);
    });
  });

  test('correcting the form clears the previous failure', () async {
    final cubit = SubmissionCubit();
    addTearDown(cubit.close);
    await cubit.run('x', () async => throw const DuplicateCard());

    cubit.reset();

    expect(cubit.state, isA<SubmissionIdle>());
    expect(cubit.state.failure, isNull);
  });

  test('it is busy while the write is in flight', () async {
    final cubit = SubmissionCubit();
    addTearDown(cubit.close);
    final seen = <bool>[];
    cubit.stream.listen((state) => seen.add(state.isBusy));

    await cubit.run('x', () async {});
    await Future<void>.delayed(Duration.zero);

    expect(seen, [true, false]);
  });
}

class _RecordingLogger implements Logger {
  _RecordingLogger(this.labels);
  final List<String> labels;

  @override
  void error(String context, Object cause, StackTrace stack) =>
      labels.add(context);
}
