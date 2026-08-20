import 'package:financeiro_ai/core/theme/theme.dart';
import 'package:financeiro_ai/core/design_system/ledger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A bottom sheet is a thumb gesture. There were 22 of them, and on a monitor
/// they rose from the bottom edge of the screen — the clearest single tell that
/// a phone app had been stretched onto the web.
Future<void> _open(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: MediaQuery(
        data: MediaQueryData(size: size, disableAnimations: true),
        child: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showResponsiveSurface<void>(
                context,
                builder: (_) => const SizedBox(
                  height: 200,
                  child: Text('conteúdo do formulário'),
                ),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('a phone still gets a bottom sheet', (tester) async {
    await _open(tester, const Size(390, 844));
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('conteúdo do formulário'), findsOneWidget);
  });

  testWidgets('a tablet gets a centred dialog', (tester) async {
    await _open(tester, const Size(834, 1112));
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('conteúdo do formulário'), findsOneWidget);
  });

  testWidgets('a desktop gets a panel on the right, not a sheet', (
    tester,
  ) async {
    await _open(tester, const Size(1440, 900));
    expect(find.byType(BottomSheet), findsNothing);

    // The panel is against the right edge and leaves the list visible behind
    // it, which is the whole point of the change.
    final panel = tester.getRect(find.text('conteúdo do formulário'));
    expect(panel.center.dx, greaterThan(1440 * 0.6));
  });
}
