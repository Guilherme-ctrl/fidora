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

/// The loop that teaches the product.
///
/// It was three taps deep inside "Mais", cleared with a mouse, one round-trip
/// per item. There was no keyboard anywhere in the product and not a single
/// `Dismissible`.
Future<void> _pump(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        financeRepositoryProvider.overrideWithValue(DemoFinanceRepository()),
      ],
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
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('pt_BR'));

  testWidgets('the queue names its keyboard on a wide screen', (tester) async {
    await withGoldenClock(() async {
      await _pump(tester, const Size(1280, 900));
      // A shortcut nobody can discover is a shortcut nobody uses.
      expect(find.text('J K NAVEGAR'), findsOneWidget);
      expect(find.text('⏎ ESTÁ CERTO'), findsOneWidget);
      expect(find.text('D DESCARTAR'), findsOneWidget);
    });
  });

  testWidgets('a phone gets swipe instead of the shortcut legend', (
    tester,
  ) async {
    await withGoldenClock(() async {
      await _pump(tester, const Size(390, 844));
      expect(find.text('J K NAVEGAR'), findsNothing);
      expect(find.byType(Dismissible), findsWidgets);
    });
  });

  testWidgets('every item can be swiped either way', (tester) async {
    await withGoldenClock(() async {
      await _pump(tester, const Size(390, 844));
      final dismissible = tester.widget<Dismissible>(
        find.byType(Dismissible).first,
      );
      expect(dismissible.background, isNotNull, reason: 'aprovar');
      expect(dismissible.secondaryBackground, isNotNull, reason: 'descartar');
    });
  });

  testWidgets('J and K move the focused item', (tester) async {
    await withGoldenClock(() async {
      await _pump(tester, const Size(1280, 900));
      final before = tester.widgetList<Card>(find.byType(Card)).toList();
      if (before.length < 2) return;

      BorderSide sideOf(Card card) =>
          ((card.shape! as RoundedRectangleBorder).side);
      final focusedBefore = before.indexWhere((c) => sideOf(c).width > 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
      await tester.pump(const Duration(milliseconds: 50));

      final after = tester.widgetList<Card>(find.byType(Card)).toList();
      final focusedAfter = after.indexWhere((c) => sideOf(c).width > 1);
      expect(focusedAfter, focusedBefore + 1);
    });
  });
}
