import 'package:financeiro_ai/features/ledger/infra/repositories/demo_finance_repository.dart';
import 'package:financeiro_ai/features/ledger/domain/entities/finance_period.dart';
import 'package:financeiro_ai/features/ledger/domain/entities/models.dart';
import 'package:financeiro_ai/features/transactions/domain/transaction_filter.dart';
import 'package:flutter_test/flutter_test.dart';

FinanceTransaction tx(
  String id, {
  String merchant = 'LOJA',
  String category = 'Compras',
  String card = '1111',
  double amount = 50,
  DateTime? date,
  TransactionStatus status = TransactionStatus.confirmed,
  int? current,
  int? total,
}) => FinanceTransaction(
  id: id,
  date: date ?? DateTime(2026, 8, 10),
  merchant: merchant,
  amount: amount,
  category: category,
  cardLastFour: card,
  status: status,
  installmentCurrent: current,
  installmentTotal: total,
);

FinanceSnapshot snap(List<FinanceTransaction> items) => FinanceSnapshot(
  transactions: items,
  categories: const [],
  cards: const [],
  invoices: const [],
  goals: const [],
  pendingReviews: 0,
);

void main() {
  final august = FinancePeriod.month(DateTime(2026, 8));

  group('filterTransactions', () {
    test('honours the period unless told otherwise', () {
      final snapshot = snap([
        tx('1', date: DateTime(2026, 8, 10)),
        tx('2', date: DateTime(2026, 5, 10)),
      ]);
      expect(
        filterTransactions(snapshot, august, const TransactionFilter()),
        hasLength(1),
      );
      expect(
        filterTransactions(
          snapshot,
          august,
          const TransactionFilter(ignorePeriod: true),
        ),
        hasLength(2),
      );
    });

    test('text matching folds accents, like the capture path', () {
      final snapshot = snap([tx('1', merchant: 'FARMÁCIA SÃO JOÃO')]);
      for (final query in ['farmacia', 'FARMÁCIA', 'sao joao']) {
        expect(
          filterTransactions(snapshot, august, TransactionFilter(query: query)),
          hasLength(1),
          reason: query,
        );
      }
    });

    test('filters by card, including account movements', () {
      final snapshot = snap([tx('1', card: '1111'), tx('2', card: '----')]);
      expect(
        filterTransactions(
          snapshot,
          august,
          const TransactionFilter(cardFinals: {'----'}),
        ).single.id,
        '2',
      );
    });

    test('filters by category and by status', () {
      final snapshot = snap([
        tx('1', category: 'Lazer'),
        tx('2', category: 'Compras', status: TransactionStatus.pending),
      ]);
      expect(
        filterTransactions(
          snapshot,
          august,
          const TransactionFilter(categories: {'Lazer'}),
        ).single.id,
        '1',
      );
      expect(
        filterTransactions(
          snapshot,
          august,
          const TransactionFilter(statuses: {TransactionStatus.pending}),
        ).single.id,
        '2',
      );
    });

    test('bounds by amount, inclusive at both ends', () {
      final snapshot = snap([
        tx('1', amount: 10),
        tx('2', amount: 50),
        tx('3', amount: 90),
      ]);
      final result = filterTransactions(
        snapshot,
        august,
        const TransactionFilter(minAmount: 10, maxAmount: 50),
      );
      expect(result.map((item) => item.id), containsAll(['1', '2']));
      expect(result, hasLength(2));
    });

    test('narrows to instalments only', () {
      final snapshot = snap([tx('1'), tx('2', current: 2, total: 4)]);
      expect(
        filterTransactions(
          snapshot,
          august,
          const TransactionFilter(onlyInstallments: true),
        ).single.id,
        '2',
      );
    });

    test('combines constraints rather than replacing them', () {
      final snapshot = snap([
        tx('1', merchant: 'IFOOD', category: 'Alimentação', amount: 30),
        tx('2', merchant: 'IFOOD', category: 'Alimentação', amount: 300),
        tx('3', merchant: 'UBER', category: 'Transporte', amount: 30),
      ]);
      final result = filterTransactions(
        snapshot,
        august,
        const TransactionFilter(
          query: 'ifood',
          categories: {'Alimentação'},
          maxAmount: 100,
        ),
      );
      expect(result.single.id, '1');
    });

    test('returns newest first', () {
      final snapshot = snap([
        tx('old', date: DateTime(2026, 8, 1)),
        tx('new', date: DateTime(2026, 8, 20)),
      ]);
      expect(
        filterTransactions(
          snapshot,
          august,
          const TransactionFilter(),
        ).first.id,
        'new',
      );
    });

    test('counts active constraints for the badge', () {
      expect(const TransactionFilter().activeCount, 0);
      expect(const TransactionFilter(query: 'x').isClear, isFalse);
      expect(
        const TransactionFilter(
          ignorePeriod: true,
          categories: {'Lazer'},
          minAmount: 10,
        ).activeCount,
        3,
      );
    });
  });

  group('suggestRulePattern', () {
    test('offers the brand rather than the whole statement line', () {
      expect(suggestRulePattern('IFOOD *RESTAURANTE 123'), 'IFOOD');
      expect(suggestRulePattern('UBER   TRIP'), 'UBER');
    });

    test('folds accents so the pattern matches either spelling', () {
      expect(suggestRulePattern('FARMÁCIA SÃO JOÃO'), 'FARMACIA');
    });

    test('falls back to the whole name when the first word is too short', () {
      // The rule editor refuses anything under three characters.
      expect(suggestRulePattern('7 ELEVEN'), '7 ELEVEN');
    });

    test('is empty for an empty merchant', () {
      expect(suggestRulePattern('  '), '');
    });
  });

  group('DemoFinanceRepository — recategorização em massa', () {
    test('moves every selected row in one call', () async {
      final repository = DemoFinanceRepository();
      final snapshot = await repository.loadSnapshot();
      final lazer = snapshot.categories.firstWhere(
        (item) => item.name == 'Lazer',
      );
      final ids = snapshot.transactions.take(3).map((item) => item.id).toList();

      await repository.recategorizeTransactions(ids, lazer.id);
      final after = await repository.loadSnapshot();
      for (final id in ids) {
        expect(
          after.transactions.firstWhere((item) => item.id == id).category,
          'Lazer',
        );
      }
    });

    test('leaves the rows that were not selected alone', () async {
      final repository = DemoFinanceRepository();
      final before = await repository.loadSnapshot();
      final lazer = before.categories.firstWhere((i) => i.name == 'Lazer');
      final untouched = before.transactions.last;

      await repository.recategorizeTransactions([
        before.transactions.first.id,
      ], lazer.id);
      final after = await repository.loadSnapshot();
      expect(
        after.transactions.firstWhere((i) => i.id == untouched.id).category,
        untouched.category,
      );
    });

    test('an unknown id is skipped, not fatal', () async {
      final repository = DemoFinanceRepository();
      final lazer = (await repository.loadSnapshot()).categories.firstWhere(
        (i) => i.name == 'Lazer',
      );
      await repository.recategorizeTransactions(['nao-existe'], lazer.id);
      expect(await repository.loadSnapshot(), isNotNull);
    });
  });
}
