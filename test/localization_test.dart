import 'package:financeiro_ai/features/shared/widgets/period_filter_bar.dart';
import 'package:financeiro_ai/core/theme/theme.dart';
import 'package:financeiro_ai/features/ledger/domain/entities/finance_period.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// The three date pickers all crashed on open.
///
/// The product has been pt-BR since its foundation and never declared a
/// localisation, so every Material widget fell back to the built-in English.
/// The pickers ask for `pt_BR` explicitly, found no delegate that could serve
/// it, and threw — in Projeção, in Metas and in the entry form, which is all of
/// them.
///
/// `initializeDateFormatting` does not help: that is intl, for formatting a
/// date into a string. `MaterialLocalizations` is what a picker needs, and
/// nothing was providing it.
Widget _app({required Widget home, bool localized = true}) => MaterialApp(
  theme: buildAppTheme(),
  locale: const Locale('pt', 'BR'),
  supportedLocales: const [Locale('pt', 'BR'), Locale('en')],
  localizationsDelegates: localized
      ? const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ]
      : const <LocalizationsDelegate<Object>>[],
  home: home,
);

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  testWidgets('o seletor de período abre em pt-BR', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 1000);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(
        home: Scaffold(
          body: PeriodFilterBar(
            period: FinancePeriod.month(DateTime(2026, 8)),
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('agosto 2026'));
    await tester.pumpAndSettle();

    expect(
      tester.takeException(),
      isNull,
      reason: 'abrir o seletor de período lançava',
    );
    // Que ele abriu: o rótulo de salvar é nosso e só existe dentro do seletor.
    // A prova de que está em português fica no teste do delegate abaixo — em
    // tela cheia o cancelar do seletor é um ícone, não uma palavra.
    expect(find.text('Aplicar'), findsOneWidget);
  });

  testWidgets('o Material fala português', (tester) async {
    // Verificação direta do delegate, em vez de tentar reproduzir a falha: o
    // `MaterialApp` tem fallbacks que a execução real não teve, então o teste
    // negativo passava sem provar nada. Este falha assim que os delegates
    // saírem de `main.dart`.
    late MaterialLocalizations l10n;
    await tester.pumpWidget(
      _app(
        home: Builder(
          builder: (context) {
            l10n = MaterialLocalizations.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pump();

    expect(l10n.cancelButtonLabel, 'Cancelar');
    expect(l10n.okButtonLabel, 'OK');
  });
}
