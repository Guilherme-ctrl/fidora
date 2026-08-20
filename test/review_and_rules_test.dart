import 'package:financeiro_ai/data/row_mappers.dart';
import 'package:financeiro_ai/core/errors/failure.dart';
import 'package:financeiro_ai/data/demo_finance_repository.dart';
import 'package:financeiro_ai/domain/finance_rules.dart';
import 'package:financeiro_ai/domain/merchant_rule.dart';
import 'package:financeiro_ai/domain/review_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReviewItem', () {
    test('prefers the description as its title', () {
      const item = ReviewItem(
        id: '1',
        reason: 'Classificação com baixa confiança',
        status: 'pending',
        description: 'FARMÁCIA',
      );
      expect(item.title, 'FARMÁCIA');
    });

    test('falls back to the reason when the description is blank', () {
      const item = ReviewItem(
        id: '1',
        reason: 'Classificação com baixa confiança',
        status: 'pending',
        description: '   ',
      );
      expect(item.title, 'Classificação com baixa confiança');
    });

    test('parses a row with no linked transaction', () {
      final item = reviewItemFromRow({
        'id': 'r9',
        'reason': 'Sem transação correspondente',
        'status': 'pending',
        'transaction_id': null,
      });
      expect(item.hasTransaction, isFalse);
      expect(item.isPending, isTrue);
    });
  });

  group('MerchantRule', () {
    test('matches case-insensitively on a substring', () {
      const rule = MerchantRule(
        id: '1',
        pattern: 'IFOOD',
        categoryId: '1',
        categoryName: 'Alimentação',
      );
      expect(rule.matches('IFOOD *RESTAURANTE'), isTrue);
      expect(rule.matches('ifood delivery'), isTrue);
      expect(rule.matches('UBER EATS'), isFalse);
    });

    test('matches across accents, like the capture path does', () {
      // The screen's preview and the Edge Function must agree, or the count it
      // shows before saving is a promise the capture path will not keep.
      const rule = MerchantRule(
        id: '1',
        pattern: 'farmácia',
        categoryId: '4',
        categoryName: 'Saúde',
      );
      expect(rule.matches('FARMACIA SAO JOAO'), isTrue);
      expect(rule.matches('FARMÁCIA SÃO JOÃO'), isTrue);
    });

    test('a pattern under three characters never matches', () {
      const rule = MerchantRule(
        id: '1',
        pattern: 'UB',
        categoryId: '2',
        categoryName: 'Transporte',
      );
      expect(rule.matches('UBER TRIP'), isFalse);
    });

    test('rejects a blank or too-short pattern', () {
      expect(
        const MerchantRuleDraft(
          pattern: '  ',
          categoryId: '1',
        ).validate().pattern,
        'Informe o trecho do nome do estabelecimento',
      );
      expect(
        const MerchantRuleDraft(
          pattern: 'UB',
          categoryId: '1',
        ).validate().pattern,
        'Use ao menos 3 caracteres para evitar acertos indesejados',
      );
    });

    test('requires a category', () {
      expect(
        const MerchantRuleDraft(
          pattern: 'IFOOD',
          categoryId: '',
        ).validate().category,
        'Escolha uma categoria',
      );
    });

    test('accepts a complete draft', () {
      expect(
        const MerchantRuleDraft(
          pattern: 'IFOOD',
          categoryId: '1',
        ).validate().isEmpty,
        isTrue,
      );
    });
  });

  group('DemoFinanceRepository — review queue', () {
    // Sizes are read, not written down. These tests are about behaviour, and
    // pinning the fixture's length meant that adding a group to the demo — so
    // the queue could show what grouping is for — broke three of them for no
    // reason.
    test('lists only pending entries', () async {
      final repository = DemoFinanceRepository();
      final queue = await repository.loadReviewQueue();
      expect(queue, isNotEmpty);
      expect(queue.every((item) => item.isPending), isTrue);
    });

    test('resolving removes the entry from the queue', () async {
      final repository = DemoFinanceRepository();
      final before = (await repository.loadReviewQueue()).length;
      await repository.settleReview('r1', status: 'resolved');
      final queue = await repository.loadReviewQueue();
      expect(queue.any((item) => item.id == 'r1'), isFalse);
      expect(queue, hasLength(before - 1));
    });

    test('dismissing also clears it', () async {
      final repository = DemoFinanceRepository();
      final before = (await repository.loadReviewQueue()).length;
      await repository.settleReview('r3', status: 'dismissed');
      expect(await repository.loadReviewQueue(), hasLength(before - 1));
    });

    test('the snapshot count follows the queue', () async {
      final repository = DemoFinanceRepository();
      final before = (await repository.loadSnapshot()).pendingReviews;
      expect(before, greaterThan(0));
      await repository.settleReview('r1', status: 'resolved');
      expect((await repository.loadSnapshot()).pendingReviews, before - 1);
    });

    test('settling an unknown id is a no-op', () async {
      final repository = DemoFinanceRepository();
      final before = (await repository.loadReviewQueue()).length;
      await repository.settleReview('nope', status: 'resolved');
      expect(await repository.loadReviewQueue(), hasLength(before));
    });

    test('the demo carries a group, so the queue can show grouping', () async {
      final repository = DemoFinanceRepository();
      final queue = await repository.loadReviewQueue();
      final snapshot = await repository.loadSnapshot();
      final byMerchant = <String, int>{};
      for (final item in queue) {
        final merchant = snapshot.transactions
            .where((row) => row.id == item.transactionId)
            .firstOrNull
            ?.merchant;
        if (merchant != null) {
          byMerchant[merchant] = (byMerchant[merchant] ?? 0) + 1;
        }
      }
      expect(
        byMerchant.values.any((count) => count > 1),
        isTrue,
        reason: 'sem repetição a fila nunca mostra o agrupamento',
      );
    });
  });

  group('DemoFinanceRepository — merchant rules', () {
    test('lists the seeded rules ordered by priority', () async {
      final repository = DemoFinanceRepository();
      final rules = await repository.loadMerchantRules();
      expect(rules.map((item) => item.pattern), ['IFOOD', 'UBER', 'GOOGLE']);
    });

    test('creates a rule and resolves the category name', () async {
      final repository = DemoFinanceRepository();
      await repository.saveMerchantRule(
        const MerchantRuleDraft(
          pattern: 'AIRBNB',
          categoryId: '7',
          priority: 5,
        ),
      );
      final rules = await repository.loadMerchantRules();
      final created = rules.firstWhere((item) => item.pattern == 'AIRBNB');
      expect(created.categoryName, 'Viagem');
      expect(rules.first.pattern, 'AIRBNB', reason: 'priority 5 sorts first');
    });

    test('refuses a duplicate pattern regardless of case', () async {
      final repository = DemoFinanceRepository();
      await expectLater(
        repository.saveMerchantRule(
          const MerchantRuleDraft(pattern: 'ifood', categoryId: '1'),
        ),
        throwsA(isA<DuplicateMerchantRule>()),
      );
      expect(await repository.loadMerchantRules(), hasLength(3));
    });

    test(
      'editing keeps its own pattern without clashing with itself',
      () async {
        final repository = DemoFinanceRepository();
        await repository.saveMerchantRule(
          const MerchantRuleDraft(id: 'm1', pattern: 'IFOOD', categoryId: '6'),
        );
        final rules = await repository.loadMerchantRules();
        expect(rules, hasLength(3));
        expect(
          rules.firstWhere((item) => item.id == 'm1').categoryName,
          'Lazer',
        );
      },
    );

    test('rejects an invalid draft before writing', () async {
      final repository = DemoFinanceRepository();
      await expectLater(
        repository.saveMerchantRule(
          const MerchantRuleDraft(pattern: 'AB', categoryId: '1'),
        ),
        throwsA(isA<ValidationFailure>()),
      );
      expect(await repository.loadMerchantRules(), hasLength(3));
    });

    test('deletes a rule', () async {
      final repository = DemoFinanceRepository();
      await repository.deleteMerchantRule('m2');
      final rules = await repository.loadMerchantRules();
      expect(rules.map((item) => item.pattern), ['IFOOD', 'GOOGLE']);
    });
  });

  group('normalizeMerchant parity with the Edge Function', () {
    test('strips accents, symbols and case', () {
      expect(normalizeMerchant('  farmácia  são joão '), 'FARMACIA SAO JOAO');
      expect(normalizeMerchant('IFOOD *RESTAURANTE'), 'IFOOD RESTAURANTE');
    });

    test('folds every accented character Portuguese uses', () {
      expect(foldAccents('ÁÀÂÃÉÊÍÓÔÕÚÜÇ'), 'AAAAEEIOOOUUC');
      expect(foldAccents('áàâãéêíóôõúüç'), 'aaaaeeiooouuc');
    });

    test('leaves unaccented text untouched', () {
      expect(foldAccents('UBER TRIP'), 'UBER TRIP');
    });
  });
}
