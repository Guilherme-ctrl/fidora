import 'package:financeiro_ai/core/errors/failure.dart';
import 'package:financeiro_ai/data/supabase_failures.dart';
import 'package:financeiro_ai/domain/auth_rules.dart';
import 'package:financeiro_ai/presentation/failure_copy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Failure failureFor(String message) =>
    AuthException(message).toFailure(StackTrace.current);

void main() {
  group('validateEmail', () {
    test('accepts ordinary addresses', () {
      expect(validateEmail('alguem@exemplo.com'), isNull);
      expect(validateEmail('  alguem+tag@exemplo.com.br  '), isNull);
    });

    test('rejects what is clearly not an address', () {
      expect(validateEmail(''), 'Informe seu e-mail');
      expect(validateEmail('   '), 'Informe seu e-mail');
      expect(validateEmail('alguem'), 'Informe um e-mail válido');
      expect(validateEmail('alguem@'), 'Informe um e-mail válido');
      expect(validateEmail('alguem@exemplo'), 'Informe um e-mail válido');
      expect(validateEmail('a b@exemplo.com'), 'Informe um e-mail válido');
    });
  });

  group('validatePassword', () {
    test('requires eight characters', () {
      expect(validatePassword(''), 'Informe uma senha');
      expect(validatePassword('1234567'), 'Use pelo menos 8 caracteres');
      expect(validatePassword('12345678'), isNull);
    });
  });

  group('validateNewPassword', () {
    test('requires the two fields to agree', () {
      final errors = validateNewPassword('senhaboa1', 'outracoisa');
      expect(errors.confirmation, 'As senhas não coincidem');
      expect(errors.isEmpty, isFalse);
    });

    test('asks for the repetition when it is missing', () {
      expect(
        validateNewPassword('senhaboa1', '').confirmation,
        'Repita a nova senha',
      );
    });

    test('accepts a matching pair that meets the rule', () {
      expect(validateNewPassword('senhaboa1', 'senhaboa1').isEmpty, isTrue);
    });

    test('reports the password problem before the confirmation one', () {
      final errors = validateNewPassword('curta', 'curta');
      expect(errors.firstMessage, 'Use pelo menos 8 caracteres');
    });

    test('uses the same rule as sign-up, so the two cannot drift', () {
      expect(
        validateNewPassword('1234567', '1234567').password,
        validatePassword('1234567'),
      );
    });
  });

  group('Falhas de autenticação', () {
    // This classification used to live in `domain/auth_rules.dart`, matching
    // substrings of Supabase's English inside the domain layer. It now happens
    // where knowing Supabase is the job, and the result is a type rather than
    // a sentence — so these assert both halves.
    test('names the failures a person actually hits', () {
      expect(failureFor('Invalid login credentials'), isA<InvalidCredentials>());
      expect(failureFor('Email not confirmed'), isA<EmailNotConfirmed>());
      expect(
        failureFor('User already registered'),
        isA<EmailAlreadyRegistered>(),
      );
      expect(
        failureFor(
          'For security purposes, you can only request this after 51 seconds.',
        ),
        isA<TooManyAttempts>(),
      );
      expect(
        failureFor('New password should be different from the old password.'),
        isA<PasswordUnchanged>(),
      );
    });

    test('a wrong pair says nothing about which half was wrong', () {
      // The screen must not become a way to discover which addresses have
      // accounts, so the copy names neither field.
      final copy = FailureCopy.of(failureFor('Invalid login credentials'));
      expect(copy.message, 'E-mail ou senha incorretos');
    });

    test('rate limiting is business, not a broken server', () {
      expect(failureFor('rate limit exceeded'), isA<BusinessFailure>());
      expect(FailureCopy.of(failureFor('rate limit exceeded')).canRetry, isTrue);
    });

    test('an expired token is a session problem, not a credential one', () {
      expect(failureFor('JWT expired'), isA<SessionExpired>());
    });

    test('passes through anything it does not recognise', () {
      final failure = failureFor('Algo inesperado');
      expect(failure, isA<AuthenticationFailure>());
      expect(FailureCopy.of(failure).message, 'Algo inesperado');
    });
  });
}
