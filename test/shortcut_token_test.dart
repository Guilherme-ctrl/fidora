import 'package:financeiro_ai/core/errors/failure.dart';
import 'package:financeiro_ai/features/ledger/infra/repositories/demo_finance_repository.dart';
import 'package:financeiro_ai/features/settings/domain/shortcut_token.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Geração do segredo', () {
    test('produces a distinct value every time', () {
      final secrets = List.generate(50, (_) => generateShortcutSecret());
      expect(secrets.toSet(), hasLength(50));
    });

    test('is URL-safe so it survives being pasted into a Shortcut', () {
      for (var i = 0; i < 20; i++) {
        expect(generateShortcutSecret(), matches(RegExp(r'^[A-Za-z0-9_-]+$')));
      }
    });

    test('carries enough entropy to resist guessing', () {
      // 32 bytes, base64url, padding stripped.
      expect(generateShortcutSecret().length, greaterThanOrEqualTo(42));
    });
  });

  group('Hash', () {
    test('matches the hex SHA-256 the Edge Function computes', () {
      // Independent reference vector, not this code's own output: the function
      // hex-encodes sha256 of the raw header value, and a drift here would
      // silently break every capture.
      expect(
        hashShortcutSecret('finora'),
        'd8132fbca081db45a8aa13378a762cea1ac6f0e04b8b002a63802bd3f7185de7',
      );
      expect(hashShortcutSecret('finora'), matches(RegExp(r'^[0-9a-f]{64}$')));
    });

    test('is stable and differs per input', () {
      expect(hashShortcutSecret('a'), hashShortcutSecret('a'));
      expect(hashShortcutSecret('a'), isNot(hashShortcutSecret('b')));
    });
  });

  group('Validação do nome', () {
    test('rejects blank and very short names', () {
      expect(validateTokenName('  ').name, isNotNull);
      expect(validateTokenName('ab').name, 'Use ao menos 3 caracteres');
    });

    test('accepts a real name', () {
      expect(validateTokenName('iPhone 15').isEmpty, isTrue);
    });
  });

  group('DemoFinanceRepository — tokens', () {
    test('starts with none', () async {
      expect(await DemoFinanceRepository().loadShortcutTokens(), isEmpty);
    });

    test('issuing returns the secret once and stores the row', () async {
      final repository = DemoFinanceRepository();
      final issued = await repository.createShortcutToken('iPhone');
      expect(issued.secret, isNotEmpty);
      final tokens = await repository.loadShortcutTokens();
      expect(tokens, hasLength(1));
      expect(tokens.single.name, 'iPhone');
      expect(tokens.single.isActive, isTrue);
      expect(tokens.single.everUsed, isFalse);
    });

    test('refuses an invalid name before issuing anything', () async {
      final repository = DemoFinanceRepository();
      await expectLater(
        repository.createShortcutToken('x'),
        throwsA(isA<ValidationFailure>()),
      );
      expect(await repository.loadShortcutTokens(), isEmpty);
    });

    test('revoking marks it inactive without deleting it', () async {
      final repository = DemoFinanceRepository();
      final issued = await repository.createShortcutToken('iPhone');
      await repository.revokeShortcutToken(issued.token.id);
      final tokens = await repository.loadShortcutTokens();
      expect(tokens, hasLength(1), reason: 'the audit trail is kept');
      expect(tokens.single.isActive, isFalse);
      expect(tokens.single.revokedAt, isNotNull);
    });

    test('revoking an unknown id is refused', () async {
      await expectLater(
        DemoFinanceRepository().revokeShortcutToken('nope'),
        throwsA(isA<RecordNotFound>()),
      );
    });
  });
}
