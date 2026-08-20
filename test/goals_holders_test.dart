import 'package:financeiro_ai/core/errors/failure.dart';
import 'package:financeiro_ai/data/demo_finance_repository.dart';
import 'package:financeiro_ai/domain/analytics.dart';
import 'package:financeiro_ai/domain/catalog_drafts.dart';
import 'package:financeiro_ai/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

FinanceTransaction onCard(String id, String lastFour, double amount) =>
    FinanceTransaction(
      id: id,
      date: DateTime(2026, 8, 5),
      merchant: 'LOJA',
      amount: amount,
      category: 'Compras',
      cardLastFour: lastFour,
      competence: DateTime(2026, 8),
    );

FinanceSnapshot snapshotWith({
  required List<FinanceTransaction> transactions,
  required List<CreditCard> cards,
  List<Holder> holders = const [],
}) => FinanceSnapshot(
  transactions: transactions,
  categories: const [],
  cards: cards,
  invoices: const [],
  goals: const [],
  holders: holders,
  pendingReviews: 0,
);

CreditCard card({
  String id = 'c1',
  String lastFour = '1111',
  bool include = true,
  String? holderId,
}) => CreditCard(
  id: id,
  name: 'Cartão',
  bank: 'Banco',
  lastFour: lastFour,
  limit: 1000,
  closingDay: 2,
  dueDay: 9,
  holder: '',
  holderId: holderId,
  includeInTotals: include,
);

void main() {
  group('Cartões fora dos totais', () {
    final period = FinancePeriod.month(DateTime(2026, 8));

    test('a card marked out of totals stops counting', () {
      // The flag was parsed into the model and never consulted by any
      // calculation, so the switch in the card form did nothing.
      final counted = analyzePeriod(
        snapshotWith(transactions: [onCard('1', '1111', 100)], cards: [card()]),
        period,
      );
      expect(counted.expenses, 100);

      final excluded = analyzePeriod(
        snapshotWith(
          transactions: [onCard('1', '1111', 100)],
          cards: [card(include: false)],
        ),
        period,
      );
      expect(excluded.expenses, 0);
    });

    test("a holder out of totals excludes that holder's cards", () {
      final analytics = analyzePeriod(
        snapshotWith(
          transactions: [onCard('1', '1111', 100)],
          cards: [card(holderId: 'h1')],
          holders: const [
            Holder(id: 'h1', name: 'Outra pessoa', includeInTotals: false),
          ],
        ),
        period,
      );
      expect(analytics.expenses, 0);
    });

    test('only the excluded card drops out, not the rest', () {
      final analytics = analyzePeriod(
        snapshotWith(
          transactions: [onCard('1', '1111', 100), onCard('2', '2222', 40)],
          cards: [
            card(),
            card(id: 'c2', lastFour: '2222', include: false),
          ],
        ),
        period,
      );
      expect(analytics.expenses, 100);
    });

    test('an unknown holder id does not exclude anything', () {
      final analytics = analyzePeriod(
        snapshotWith(
          transactions: [onCard('1', '1111', 100)],
          cards: [card(holderId: 'sumiu')],
        ),
        period,
      );
      expect(analytics.expenses, 100);
    });
  });

  group('GoalDraft', () {
    test('requires a positive target', () {
      expect(
        const GoalDraft(name: 'Reserva', target: 0).validate().target,
        'A meta precisa ser maior que zero',
      );
      expect(
        const GoalDraft(name: 'Reserva', target: 100).validate().isEmpty,
        isTrue,
      );
    });

    test('refuses a negative current amount', () {
      expect(
        const GoalDraft(
          name: 'Reserva',
          target: 100,
          current: -1,
        ).validate().current,
        isNotNull,
      );
    });

    test('requires a name', () {
      expect(
        const GoalDraft(name: '  ', target: 100).validate().name,
        isNotNull,
      );
    });
  });

  group('Goal', () {
    test('reports what is left and whether the deadline passed', () {
      final late = Goal(
        id: 'g',
        name: 'Viagem',
        current: 100,
        target: 1000,
        targetDate: DateTime.now().subtract(const Duration(days: 5)),
      );
      expect(late.remaining, 900);
      expect(late.isLate, isTrue);
    });

    test('a goal already reached is never late', () {
      final done = Goal(
        id: 'g',
        name: 'Viagem',
        current: 1000,
        target: 1000,
        targetDate: DateTime.now().subtract(const Duration(days: 5)),
      );
      expect(done.isLate, isFalse);
      expect(done.remaining, 0);
    });

    test('a goal with no deadline has no days left and is not late', () {
      const open = Goal(id: 'g', name: 'Viagem', current: 0, target: 10);
      expect(open.daysLeft, isNull);
      expect(open.isLate, isFalse);
    });
  });

  group('DemoFinanceRepository — metas e portadores', () {
    test('creates and edits a goal', () async {
      final repository = DemoFinanceRepository();
      await repository.saveGoal(
        const GoalDraft(name: 'Notebook', target: 6000, current: 500),
      );
      var goals = (await repository.loadSnapshot()).goals;
      final created = goals.firstWhere((item) => item.name == 'Notebook');
      expect(created.target, 6000);

      await repository.saveGoal(
        GoalDraft(id: created.id, name: 'Notebook novo', target: 7000),
      );
      goals = (await repository.loadSnapshot()).goals;
      expect(
        goals.firstWhere((item) => item.id == created.id).name,
        'Notebook novo',
      );
      expect(
        goals.where((item) => item.name.startsWith('Notebook')),
        hasLength(1),
      );
    });

    test('refuses a duplicate holder name', () async {
      final repository = DemoFinanceRepository();
      await expectLater(
        repository.saveHolder(const HolderDraft(name: 'guilherme')),
        throwsA(isA<DuplicateHolder>()),
      );
    });

    test('deleting a holder keeps the cards', () async {
      final repository = DemoFinanceRepository();
      final before = (await repository.loadSnapshot()).cards.length;
      final holder = (await repository.loadSnapshot()).holders.first;
      await repository.deleteHolder(holder.id);
      final after = await repository.loadSnapshot();
      expect(after.holders.any((item) => item.id == holder.id), isFalse);
      expect(after.cards, hasLength(before));
    });
  });
}
