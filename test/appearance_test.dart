import 'package:financeiro_ai/application/appearance.dart';
import 'package:financeiro_ai/application/providers.dart';
import 'package:financeiro_ai/core/theme.dart';
import 'package:financeiro_ai/data/demo_finance_repository.dart';
import 'package:financeiro_ai/domain/models.dart';
import 'package:financeiro_ai/presentation/pages/more_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/golden.dart';

/// The product had two themes and, on a phone, no way to choose between them.
///
/// PR 3 put the control in the sidebar's footer, and the sidebar only exists at
/// 600pt and up. It reads as an oversight in a screenshot and it was one.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  late FinanceSnapshot snapshot;
  setUp(() async {
    await withGoldenClock(() async {
      snapshot = await DemoFinanceRepository().loadSnapshot();
    });
  });

  Future<ProviderContainer> pumpMore(WidgetTester tester, Size size) async {
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
            child: Scaffold(
              body: MorePage(snapshot: snapshot, period: goldenPeriod),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    // Ajustes is the last section on a long page; the control is real but below
    // the fold on a phone.
    await tester.scrollUntilVisible(
      find.text('Aparência'),
      300,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 60,
    );
    await tester.pump(const Duration(milliseconds: 100));
    return container;
  }

  testWidgets('a phone can reach the theme, and it is named', (tester) async {
    await withGoldenClock(() async {
      await pumpMore(tester, const Size(390, 900));
      expect(find.text('Aparência'), findsOneWidget);
      // Named choices, not an icon that rotates through states it cannot
      // explain. "Sistema" is a real answer, not the absence of one.
      for (final mode in ThemeMode.values) {
        expect(find.text(mode.label), findsOneWidget, reason: mode.name);
      }
    });
  });

  testWidgets('choosing one changes the app-wide mode', (tester) async {
    await withGoldenClock(() async {
      final container = await pumpMore(tester, const Size(390, 900));
      expect(container.read(appearanceProvider), ThemeMode.system);

      await tester.tap(find.text('Escuro'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(container.read(appearanceProvider), ThemeMode.dark);

      await tester.tap(find.text('Claro'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(container.read(appearanceProvider), ThemeMode.light);
    });
  });

  test('the choice survives a restart', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(appearanceProvider.notifier).set(ThemeMode.dark);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('appearance.themeMode'), 'dark');
  });

  test('every mode has a name and an icon', () {
    for (final mode in ThemeMode.values) {
      expect(mode.label, isNotEmpty);
      expect(mode.next, isNot(mode));
    }
  });
}
