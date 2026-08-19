import 'package:financeiro_ai/core/theme.dart';
import 'package:financeiro_ai/presentation/widgets/command_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// There was not one `Shortcuts` widget in the codebase.
///
/// In a product built around entering and reviewing the same kinds of row over
/// and over, the keyboard is the desktop interface, and its absence changed how
/// the whole thing felt more than any single visual decision.
void main() {
  Future<List<String>> open(
    WidgetTester tester, {
    String type = '',
    List<LogicalKeyboardKey> then = const [],
  }) async {
    final ran = <String>[];
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showCommandPalette(
                context,
                commands: [
                  Command(
                    label: 'Ir para Histórico',
                    group: 'Dinheiro',
                    run: () => ran.add('historico'),
                  ),
                  Command(
                    label: 'Ir para Faturas',
                    group: 'Dinheiro',
                    run: () => ran.add('faturas'),
                  ),
                  Command(
                    label: 'Novo lançamento',
                    group: 'Ação',
                    hint: 'N',
                    run: () => ran.add('novo'),
                  ),
                ],
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    if (type.isNotEmpty) {
      await tester.enterText(find.byType(TextField), type);
      await tester.pumpAndSettle();
    }
    for (final key in then) {
      await tester.sendKeyEvent(key);
      await tester.pumpAndSettle();
    }
    return ran;
  }

  testWidgets('opens listing every command', (tester) async {
    await open(tester);
    expect(find.text('Ir para Histórico'), findsOneWidget);
    expect(find.text('Novo lançamento'), findsOneWidget);
  });

  testWidgets('filters by name', (tester) async {
    await open(tester, type: 'fatura');
    expect(find.text('Ir para Faturas'), findsOneWidget);
    expect(find.text('Novo lançamento'), findsNothing);
  });

  testWidgets('filters by the space a command belongs to', (tester) async {
    // Typing the space, not the command: someone who knows the thing is under
    // "Ação" should not have to remember what it is called.
    await open(tester, type: 'ação');
    expect(find.text('Novo lançamento'), findsOneWidget);
    expect(find.text('Ir para Faturas'), findsNothing);
  });

  testWidgets('Enter runs the highlighted command', (tester) async {
    final ran = await open(
      tester,
      type: 'faturas',
      then: [LogicalKeyboardKey.enter],
    );
    expect(ran, ['faturas']);
  });

  testWidgets('the arrows move the highlight before Enter runs it', (
    tester,
  ) async {
    final ran = await open(
      tester,
      then: [LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.enter],
    );
    expect(ran, ['faturas']);
  });

  testWidgets('Escape closes without running anything', (tester) async {
    final ran = await open(tester, then: [LogicalKeyboardKey.escape]);
    expect(ran, isEmpty);
    expect(find.text('Ir para Histórico'), findsNothing);
  });

  testWidgets('says nothing matched rather than showing an empty box', (
    tester,
  ) async {
    await open(tester, type: 'xyzzy');
    expect(find.text('Nada com esse nome.'), findsOneWidget);
  });
}
