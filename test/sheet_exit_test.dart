import 'package:financeiro_ai/core/theme/theme.dart';
import 'package:financeiro_ai/core/design_system/ledger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every form needs a visible way out.
///
/// `showResponsiveSurface` hands a form the surface and no chrome, and five of
/// the six then drew a title and nothing else. On a phone the drag handle hid
/// it; in a dialog and in the side panel there was no visible way to abandon a
/// half-typed transaction — only Escape or a tap on the barrier, and neither is
/// something a person can see.
void main() {
  Future<bool> openAndClose(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: MediaQuery(
          data: MediaQueryData(size: size, disableAnimations: true),
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  await showResponsiveSurface<void>(
                    context,
                    builder: (_) => const Padding(
                      padding: EdgeInsets.all(20),
                      child: SheetHeader(
                        title: 'Nova transação',
                        subtitle: 'Um formulário qualquer',
                      ),
                    ),
                  );
                  closed = true;
                },
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Nova transação'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    return closed;
  }

  for (final (name, size) in [
    ('telefone', Size(390, 844)),
    ('tablet', Size(834, 1112)),
    ('desktop', Size(1440, 900)),
  ]) {
    testWidgets('num $name dá para fechar sem salvar', (tester) async {
      expect(await openAndClose(tester, size), isTrue);
      expect(find.text('Nova transação'), findsNothing);
    });
  }

  testWidgets('a saída diz o que acontece com o que foi digitado', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const MediaQuery(
          data: MediaQueryData(size: Size(390, 844), disableAnimations: true),
          child: Scaffold(
            body: Padding(
              padding: EdgeInsets.all(20),
              child: SheetHeader(title: 'Nova transação'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // "Fechar" sozinho não diz o que acontece com o que já foi escrito, e num
    // formulário de lançamento essa é a única pergunta que importa.
    expect(find.bySemanticsLabel('Fechar sem salvar'), findsWidgets);
  });
}
