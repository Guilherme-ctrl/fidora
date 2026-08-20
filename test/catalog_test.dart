import 'package:financeiro_ai/core/errors/failure.dart';
import 'package:financeiro_ai/features/catalog/presenter/category_visuals.dart';
import 'package:financeiro_ai/features/ledger/infra/repositories/demo_finance_repository.dart';
import 'package:financeiro_ai/features/catalog/domain/catalog_drafts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CardDraft cardDraft({
  String? id,
  String name = 'Uniclass',
  String bank = 'Itaú',
  String lastFour = '1234',
  int closingDay = 2,
  int dueDay = 9,
  double limit = 1000,
}) => CardDraft(
  id: id,
  name: name,
  bank: bank,
  lastFour: lastFour,
  closingDay: closingDay,
  dueDay: dueDay,
  limit: limit,
);

void main() {
  group('Cores e ícones de categoria', () {
    test('round-trips a colour through the hex the column stores', () {
      for (final color in categoryColors) {
        expect(parseCategoryColor(categoryColorHex(color)), color);
      }
    });

    test('accepts hex with and without the hash', () {
      expect(parseCategoryColor('#1F6B4F'), parseCategoryColor('1F6B4F'));
    });

    test('falls back instead of failing on nonsense', () {
      expect(parseCategoryColor(null), categoryColors.first);
      expect(parseCategoryColor('roxo'), categoryColors.first);
      expect(parseCategoryColor('#12'), categoryColors.first);
    });

    test('round-trips an icon name', () {
      for (final entry in categoryIcons.entries) {
        expect(categoryIconName(categoryIconFor(entry.key)), entry.key);
      }
    });

    test('an unknown icon name still renders something', () {
      expect(categoryIconFor('nao-existe'), Icons.category_rounded);
    });
  });

  group('CardDraft', () {
    test('accepts a complete draft', () {
      expect(cardDraft().validate().isEmpty, isTrue);
    });

    test('requires exactly four digits in the final', () {
      // The Shortcut matches on this, so a wrong final sends captures nowhere.
      expect(cardDraft(lastFour: '123').validate().lastFour, isNotNull);
      expect(cardDraft(lastFour: '12345').validate().lastFour, isNotNull);
      expect(cardDraft(lastFour: '12a4').validate().lastFour, isNotNull);
      expect(cardDraft(lastFour: '0012').validate().lastFour, isNull);
    });

    test('bounds the closing and due days to a real day of month', () {
      expect(cardDraft(closingDay: 0).validate().closingDay, isNotNull);
      expect(cardDraft(closingDay: 32).validate().closingDay, isNotNull);
      expect(cardDraft(dueDay: 31).validate().dueDay, isNull);
    });

    test('refuses a negative limit but allows none at all', () {
      expect(cardDraft(limit: -1).validate().limit, isNotNull);
      expect(cardDraft(limit: 0).validate().isEmpty, isTrue);
    });

    test('requires a name and a bank', () {
      expect(cardDraft(name: '  ').validate().name, isNotNull);
      expect(cardDraft(bank: '').validate().bank, isNotNull);
    });
  });

  group('CategoryDraft', () {
    CategoryDraft draft({String name = 'Mercado', double? budget}) =>
        CategoryDraft(
          name: name,
          colorHex: '#06485B',
          iconName: 'cart',
          monthlyBudget: budget,
        );

    test('accepts a category with no budget', () {
      expect(draft().validate().isEmpty, isTrue);
      expect(draft().monthlyBudget, isNull);
    });

    test('rejects a negative budget', () {
      expect(draft(budget: -5).validate().budget, isNotNull);
    });

    test('allows a zero budget explicitly set', () {
      expect(draft(budget: 0).validate().isEmpty, isTrue);
    });

    test('requires a usable name', () {
      expect(draft(name: ' ').validate().name, isNotNull);
      expect(draft(name: 'a').validate().name, 'Use ao menos 2 caracteres');
    });
  });

  group('DemoFinanceRepository — catálogo', () {
    test('creates a card and it reaches the snapshot', () async {
      final repository = DemoFinanceRepository();
      await repository.saveCard(cardDraft(name: 'Novo', lastFour: '9999'));
      final cards = (await repository.loadSnapshot()).cards;
      expect(cards.any((item) => item.lastFour == '9999'), isTrue);
    });

    test('refuses a duplicate final', () async {
      final repository = DemoFinanceRepository();
      final existing = (await repository.loadSnapshot()).cards.first;
      await expectLater(
        repository.saveCard(cardDraft(lastFour: existing.lastFour)),
        throwsA(isA<DuplicateCard>()),
      );
    });

    test('editing a card keeps its own final without clashing', () async {
      final repository = DemoFinanceRepository();
      final existing = (await repository.loadSnapshot()).cards.first;
      await repository.saveCard(
        cardDraft(
          id: existing.id,
          name: 'Renomeado',
          lastFour: existing.lastFour,
        ),
      );
      final cards = (await repository.loadSnapshot()).cards;
      expect(
        cards.firstWhere((item) => item.id == existing.id).name,
        'Renomeado',
      );
    });

    test('deactivating removes the card from the snapshot', () async {
      final repository = DemoFinanceRepository();
      final existing = (await repository.loadSnapshot()).cards.first;
      await repository.setCardActive(existing.id, active: false);
      final cards = (await repository.loadSnapshot()).cards;
      expect(cards.any((item) => item.id == existing.id), isFalse);
    });

    test('creates a category with its chosen colour and icon', () async {
      final repository = DemoFinanceRepository();
      await repository.saveCategory(
        CategoryDraft(
          name: 'Pets',
          colorHex: '#677B98',
          iconName: 'pets',
          monthlyBudget: 300,
        ),
      );
      final saved = (await repository.loadSnapshot()).categories.firstWhere(
        (item) => item.name == 'Pets',
      );
      // The stored form round-trips untouched, and still resolves to the
      // colour that was picked. Before, the entity carried a Color and the
      // hex existed only inside the repository.
      expect(saved.colorHex, '#677B98');
      expect(saved.color, categoryColors[4]);
      expect(saved.iconName, 'pets');
      expect(saved.icon, categoryIcons['pets']);
      expect(saved.monthlyBudget, 300);
    });

    test('refuses a duplicate name regardless of case', () async {
      final repository = DemoFinanceRepository();
      await expectLater(
        repository.saveCategory(
          CategoryDraft(
            name: 'alimentação',
            colorHex: '#06485B',
            iconName: 'restaurant',
          ),
        ),
        throwsA(isA<DuplicateCategory>()),
      );
    });
  });
}
