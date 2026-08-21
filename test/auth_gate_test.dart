import 'package:financeiro_ai/core/errors/failure.dart';
import 'package:financeiro_ai/core/theme/theme.dart';
import 'package:financeiro_ai/features/auth/infra/repositories/fake_auth_repository.dart';
import 'package:financeiro_ai/features/auth/domain/repositories/auth_repository.dart';
import 'package:financeiro_ai/features/auth/presenter/pages/auth_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

/// None of this was reachable before.
///
/// The sign-in surface talked to `Supabase.instance.client.auth` from inside
/// widgets, so exercising it needed a real Supabase project and a network.
/// Every test here exists because the call became an injected contract.
Future<void> pumpGate(WidgetTester tester, AuthRepository auth) async {
  await tester.pumpWidget(
    withDependencies(
      auth: auth,
      child: MaterialApp(
        theme: buildAppTheme(),
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const AuthGate(child: SizedBox.shrink()),
      ),
    ),
  );
  await tester.pump();
}

Future<void> signIn(
  WidgetTester tester, {
  required String email,
  required String password,
}) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'E-mail'), email);
  await tester.enterText(find.widgetWithText(TextFormField, 'Senha'), password);
  await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a signed-out person lands on the sign-in screen', (
    tester,
  ) async {
    await pumpGate(tester, FakeAuthRepository());
    expect(find.byType(AuthPage), findsOneWidget);
  });

  testWidgets('a signed-in person never sees it', (tester) async {
    await pumpGate(
      tester,
      FakeAuthRepository(
        session: const AuthSession(userId: 'u1', email: 'quem@exemplo.com'),
      ),
    );
    expect(find.byType(AuthPage), findsNothing);
  });

  testWidgets('a wrong password says so without naming which half', (
    tester,
  ) async {
    await pumpGate(tester, FakeAuthRepository(knownPassword: 'certa12345'));
    await signIn(tester, email: 'quem@exemplo.com', password: 'errada12345');

    expect(find.text('E-mail ou senha incorretos'), findsOneWidget);
    // The screen must not become a way to find out which addresses have
    // accounts, so neither field may be singled out.
    expect(find.textContaining('e-mail não'), findsNothing);
    expect(find.textContaining('senha incorreta'), findsNothing);
  });

  testWidgets('the right password gets past the gate', (tester) async {
    final auth = FakeAuthRepository(knownPassword: 'certa12345');
    await pumpGate(tester, auth);
    await signIn(tester, email: 'quem@exemplo.com', password: 'certa12345');

    expect(auth.currentSession?.email, 'quem@exemplo.com');
    expect(find.byType(AuthPage), findsNothing);
  });

  testWidgets('a recovery link opens the new-password screen', (tester) async {
    // This branch is why the gate watches a stream rather than a session. It
    // had no test, and getting one used to mean clicking a real e-mail.
    final auth = FakeAuthRepository();
    await pumpGate(tester, auth);
    expect(find.byType(AuthPage), findsOneWidget);

    auth.emitPasswordRecovery();
    await tester.pumpAndSettle();

    expect(find.byType(NewPasswordPage), findsOneWidget);
  });

  testWidgets('recovery answers the same for an unknown address', (
    tester,
  ) async {
    await pumpGate(tester, FakeAuthRepository());
    await tester.enterText(
      find.widgetWithText(TextFormField, 'E-mail'),
      'ninguem@exemplo.com',
    );
    await tester.tap(find.text('Esqueci minha senha'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Se houver uma conta para ninguem@exemplo.com'),
      findsOneWidget,
    );
  });

  test('signing up twice with the same address is refused', () async {
    final auth = FakeAuthRepository();
    await auth.signUp(email: 'quem@exemplo.com', password: 'sen ha1234');
    await expectLater(
      auth.signUp(email: 'quem@exemplo.com', password: 'sen ha1234'),
      throwsA(isA<EmailAlreadyRegistered>()),
    );
  });

  test('reusing the old password is refused', () async {
    final auth = FakeAuthRepository(knownPassword: 'antiga12345');
    await expectLater(
      auth.updatePassword('antiga12345'),
      throwsA(isA<PasswordUnchanged>()),
    );
  });
}
