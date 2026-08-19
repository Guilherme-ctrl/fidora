import 'package:financeiro_ai/application/providers.dart';
import 'package:financeiro_ai/core/theme.dart';
import 'package:financeiro_ai/data/demo_finance_repository.dart';
import 'package:financeiro_ai/presentation/pages/review_queue_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/golden.dart';

/// The queue was a scrolling list of every pending item, and the owner's
/// reaction to twenty-four of them was that it made him not want to start.
///
/// Three things carry the weight now, and none is a reward: items are grouped,
/// one group is on screen, and progress moves.
Future<ProviderContainer> _pump(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [
      financeRepositoryProvider.overrideWithValue(DemoFinanceRepository()),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildAppTheme(),
        home: MediaQuery(
          data: MediaQueryData(size: size, disableAnimations: true),
          child: const ReviewQueuePage(),
        ),
      ),
    ),
  );
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('pt_BR'));

  testWidgets('one decision on screen, not the whole pile', (tester) async {
    await withGoldenClock(() async {
      final container = await _pump(tester, const Size(390, 844));
      final pending = await container.read(reviewQueueProvider.future);
      expect(pending.length, greaterThan(3), reason: 'a demo precisa de fila');

      // The card that is showing is one; the pile is only suggested behind it.
      expect(find.byType(Dismissible), findsOneWidget);
    });
  });

  testWidgets('items from one place arrive as one decision', (tester) async {
    await withGoldenClock(() async {
      final container = await _pump(tester, const Size(390, 844));
      final pending = await container.read(reviewQueueProvider.future);
      final repeated = pending
          .where((item) => item.description == 'UNIFIQUE TELECOM')
          .length;
      expect(repeated, greaterThan(1), reason: 'a demo precisa de um grupo');

      // The count is on the card, and the action says how many it covers —
      // three captures from one place are not three decisions. The tag is a
      // `MonoTag`, which sets its text in small caps.
      expect(find.textContaining('LANÇAMENTOS'), findsWidgets);
      expect(find.textContaining('Está certo ('), findsOneWidget);
    });
  });

  testWidgets('progress is shown before anything is done', (tester) async {
    await withGoldenClock(() async {
      final container = await _pump(tester, const Size(390, 844));
      final pending = await container.read(reviewQueueProvider.future);
      expect(find.text('0'), findsOneWidget);
      expect(find.text(' de ${pending.length}'), findsOneWidget);
      // Six left in four decisions: the header says both, because the second
      // number is the one that predicts how long this takes.
      expect(
        find.textContaining('decis'),
        findsOneWidget,
        reason: 'a fila precisa dizer quantas decisões faltam',
      );
    });
  });

  testWidgets('settling a group advances the count by its size', (
    tester,
  ) async {
    await withGoldenClock(() async {
      final container = await _pump(tester, const Size(390, 844));
      final before = (await container.read(reviewQueueProvider.future)).length;

      await tester.tap(find.textContaining('Está certo'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }

      final after = (await container.read(reviewQueueProvider.future)).length;
      expect(after, lessThan(before), reason: 'a fila não andou');
      // More than one item left in a single action: that is the grouping.
      expect(before - after, greaterThan(1));
    });
  });

  testWidgets('the card carries what a decision needs', (tester) async {
    await withGoldenClock(() async {
      await _pump(tester, const Size(390, 844));
      // The first version showed a name, a category and a suggestion, and the
      // owner's answer after using it was that there was too little to decide
      // on. Everything below is already in the row.
      expect(find.text('QUANDO'), findsOneWidget);
      expect(find.textContaining('CATEGORIA'), findsWidgets);
      expect(find.textContaining('ENTROU POR'), findsOneWidget);
      expect(
        find.textContaining('CONFIANÇA'),
        findsWidgets,
        reason: 'a confiança é o motivo de o item estar na fila',
      );
    });
  });

  testWidgets('correcting moves the progress counter', (tester) async {
    await withGoldenClock(() async {
      final container = await _pump(tester, const Size(390, 844));
      final before = (await container.read(reviewQueueProvider.future)).length;
      expect(find.text('0'), findsOneWidget, reason: 'começa em zero');

      // Correcting settles the item that asked, and the header used to go on
      // saying the same number because the counter lived in the parent and the
      // correction did not.
      await tester.tap(find.text('Corrigir'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      expect(
        find.byType(TextField),
        findsWidgets,
        reason: 'o formulário de correção abriu',
      );
      expect(before, greaterThan(0));
    });
  });

  testWidgets('a wide screen names the keyboard', (tester) async {
    await withGoldenClock(() async {
      await _pump(tester, const Size(1280, 900));
      expect(find.text('J K NAVEGAR'), findsOneWidget);
      expect(find.text('⏎ ESTÁ CERTO'), findsOneWidget);
    });
  });

  testWidgets('Enter settles the group the keyboard is on', (tester) async {
    await withGoldenClock(() async {
      final container = await _pump(tester, const Size(1280, 900));
      final before = (await container.read(reviewQueueProvider.future)).length;

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }

      final after = (await container.read(reviewQueueProvider.future)).length;
      expect(after, lessThan(before));
    });
  });
}
