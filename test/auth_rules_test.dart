import 'package:financeiro_ai/domain/auth_rules.dart';
import 'package:flutter_test/flutter_test.dart';

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

  group('friendlyAuthMessage', () {
    test('translates the failures a person actually hits', () {
      expect(
        friendlyAuthMessage('Invalid login credentials'),
        'E-mail ou senha incorretos.',
      );
      expect(
        friendlyAuthMessage('Email not confirmed'),
        'Confirme seu e-mail antes de entrar.',
      );
      expect(
        friendlyAuthMessage('User already registered'),
        'Já existe uma conta com este e-mail.',
      );
      expect(
        friendlyAuthMessage(
          'For security purposes, you can only request this after 51 seconds.',
        ),
        'Muitas tentativas seguidas. Aguarde um minuto e tente de novo.',
      );
      expect(
        friendlyAuthMessage(
          'New password should be different from the old password.',
        ),
        'A nova senha precisa ser diferente da anterior.',
      );
    });

    test('passes through anything it does not recognise', () {
      expect(friendlyAuthMessage('Algo inesperado'), 'Algo inesperado');
    });
  });
}
