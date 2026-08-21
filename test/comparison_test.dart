import 'package:financeiro_ai/features/ledger/domain/entities/finance_period.dart';
import 'package:financeiro_ai/features/overview/domain/comparison.dart';
import 'package:financeiro_ai/features/ledger/domain/entities/models.dart';
import 'package:flutter_test/flutter_test.dart';

FinanceTransaction installment(
  String id,
  double amount, {
  required int current,
  required int total,
  String card = '6902',
  String merchant = 'MERCADO LIVRE',
}) => FinanceTransaction(
  id: id,
  date: DateTime(2026, 8, 5),
  merchant: merchant,
  amount: amount,
  category: 'Compras',
  cardLastFour: card,
  installmentCurrent: current,
  installmentTotal: total,
);

FinanceTransaction spend(
  String id,
  DateTime date,
  double amount,
  String category,
) => FinanceTransaction(
  id: id,
  date: date,
  merchant: 'LOJA $id',
  amount: amount,
  category: category,
  cardLastFour: '----',
);

FinanceSnapshot snapshotWith(
  List<FinanceTransaction> transactions, {
  List<CreditCard> cards = const [],
  List<Invoice> invoices = const [],
}) => FinanceSnapshot(
  transactions: transactions,
  categories: const [],
  cards: cards,
  invoices: invoices,
  goals: const [],
  pendingReviews: 0,
);

void main() {
  group('FinancePeriod.previous', () {
    test('a month steps back one calendar month', () {
      final period = FinancePeriod.month(DateTime(2026, 8));
      expect(period.previous.start, DateTime(2026, 7));
      expect(period.previous.endInclusive, DateTime(2026, 7, 31));
    });

    test('january steps back into december', () {
      expect(
        FinancePeriod.month(DateTime(2026, 1)).previous.start,
        DateTime(2025, 12),
      );
    });

    test('a custom range keeps its length and ends the day before', () {
      final period = FinancePeriod(
        start: DateTime(2026, 8, 10),
        endInclusive: DateTime(2026, 8, 19),
      );
      expect(period.previous.endInclusive, DateTime(2026, 8, 9));
      expect(period.previous.start, DateTime(2026, 7, 31));
    });
  });

  group('comparePeriods', () {
    final snapshot = snapshotWith([
      spend('1', DateTime(2026, 8, 5), 300, 'Alimentação'),
      spend('2', DateTime(2026, 8, 9), 100, 'Transporte'),
      spend('3', DateTime(2026, 8, 12), 50, 'Lazer'),
      spend('4', DateTime(2026, 7, 5), 200, 'Alimentação'),
      spend('5', DateTime(2026, 7, 9), 250, 'Transporte'),
    ]);

    test('computes the total movement against the previous month', () {
      final result = comparePeriods(
        snapshot,
        FinancePeriod.month(DateTime(2026, 8)),
      );
      expect(result.previous.expenses, 450);
      expect(result.current.expenses, 450);
      expect(result.expenseDelta, 0);
      expect(result.spentMore, isFalse);
    });

    test('ranks categories by how much they moved', () {
      final result = comparePeriods(
        snapshot,
        FinancePeriod.month(DateTime(2026, 8)),
      );
      expect(result.categories.first.name, 'Transporte');
      expect(result.categories.first.delta, -150);
    });

    test('flags a category that did not exist before as new', () {
      final result = comparePeriods(
        snapshot,
        FinancePeriod.month(DateTime(2026, 8)),
      );
      final lazer = result.categories.firstWhere(
        (item) => item.name == 'Lazer',
      );
      expect(lazer.isNew, isTrue);
      expect(lazer.ratio, isNull, reason: 'no percentage change from zero');
    });

    test('flags a category that stopped as gone', () {
      final onlyBefore = snapshotWith([
        spend('1', DateTime(2026, 7, 5), 80, 'Assinaturas'),
        spend('2', DateTime(2026, 8, 5), 10, 'Alimentação'),
      ]);
      final result = comparePeriods(
        onlyBefore,
        FinancePeriod.month(DateTime(2026, 8)),
      );
      final gone = result.categories.firstWhere(
        (item) => item.name == 'Assinaturas',
      );
      expect(gone.isGone, isTrue);
    });

    test('reports no baseline when the previous period was empty', () {
      final result = comparePeriods(
        snapshotWith([spend('1', DateTime(2026, 8, 5), 100, 'Alimentação')]),
        FinancePeriod.month(DateTime(2026, 8)),
      );
      expect(result.hasBaseline, isFalse);
      expect(result.expenseRatio, isNull);
    });

    test('computes the ratio when there is a baseline', () {
      final result = comparePeriods(
        snapshotWith([
          spend('1', DateTime(2026, 8, 5), 150, 'Alimentação'),
          spend('2', DateTime(2026, 7, 5), 100, 'Alimentação'),
        ]),
        FinancePeriod.month(DateTime(2026, 8)),
      );
      expect(result.expenseRatio, closeTo(0.5, 0.0001));
      expect(result.spentMore, isTrue);
    });
  });

  group('trailingMonthlyAverage', () {
    test('averages only the months that had movement', () {
      final snapshot = snapshotWith([
        spend('1', DateTime(2026, 7, 5), 300, 'Alimentação'),
        spend('2', DateTime(2026, 5, 5), 100, 'Alimentação'),
      ]);
      final average = trailingMonthlyAverage(
        snapshot,
        FinancePeriod.month(DateTime(2026, 8)),
      );
      expect(average, 200, reason: 'june had no movement and is not counted');
    });

    test('returns null when nothing precedes the period', () {
      expect(
        trailingMonthlyAverage(
          snapshotWith([spend('1', DateTime(2026, 8, 5), 10, 'Lazer')]),
          FinancePeriod.month(DateTime(2026, 8)),
        ),
        isNull,
      );
    });
  });

  group('cardUsage', () {
    const card = CreditCard(
      id: 'c1',
      name: 'Uniclass',
      bank: 'Itaú',
      lastFour: '6902',
      limit: 1000,
      closingDay: 2,
      dueDay: 9,
      holder: 'Guilherme',
    );

    Invoice invoice(String id, double total, String status) => Invoice(
      id: id,
      cardId: 'c1',
      referenceMonth: DateTime(2026, 8),
      total: total,
      dueDate: DateTime(2026, 8, 9),
      status: status,
    );

    test('counts every invoice that is not paid', () {
      final usage = cardUsage(
        snapshotWith(
          const [],
          cards: const [card],
          invoices: [invoice('1', 300, 'open'), invoice('2', 200, 'closed')],
        ),
        card,
      );
      expect(usage.used, 500);
      expect(usage.available, 500);
      expect(usage.ratio, 0.5);
    });

    test('a paid invoice releases the limit', () {
      final usage = cardUsage(
        snapshotWith(
          const [],
          cards: const [card],
          invoices: [invoice('1', 300, 'paid'), invoice('2', 200, 'open')],
        ),
        card,
      );
      expect(usage.used, 200);
      expect(usage.available, 800);
    });

    test('ignores invoices from another card', () {
      final other = Invoice(
        id: '9',
        cardId: 'c2',
        referenceMonth: DateTime(2026, 8),
        total: 900,
        dueDate: DateTime(2026, 8, 9),
        status: 'open',
      );
      final usage = cardUsage(
        snapshotWith(const [], cards: const [card], invoices: [other]),
        card,
      );
      expect(usage.used, 0);
    });

    test('flags a card at or past 80 per cent as tight', () {
      final usage = cardUsage(
        snapshotWith(
          const [],
          cards: const [card],
          invoices: [invoice('1', 800, 'open')],
        ),
        card,
      );
      expect(usage.isTight, isTrue);
      expect(usage.isOver, isFalse);
    });

    test('never reports negative availability when over the limit', () {
      final usage = cardUsage(
        snapshotWith(
          const [],
          cards: const [card],
          invoices: [invoice('1', 1400, 'open')],
        ),
        card,
      );
      expect(usage.isOver, isTrue);
      expect(usage.available, 0);
      expect(usage.ratio, 1.0);
    });

    test('a card without a registered limit is not judged', () {
      const noLimit = CreditCard(
        id: 'c1',
        name: 'Sem limite',
        bank: 'Banco',
        lastFour: '0000',
        limit: 0,
        closingDay: 1,
        dueDay: 10,
        holder: 'Guilherme',
      );
      final usage = cardUsage(
        snapshotWith(
          const [],
          cards: const [noLimit],
          invoices: [invoice('1', 500, 'open')],
        ),
        noLimit,
      );
      expect(usage.hasLimit, isFalse);
      expect(usage.isTight, isFalse);
      expect(usage.ratio, 0);
    });
  });

  group('scheduledInstallments', () {
    const card = CreditCard(
      id: 'c1',
      name: 'Uniclass',
      bank: 'Itaú',
      lastFour: '6902',
      limit: 10000,
      closingDay: 2,
      dueDay: 9,
      holder: 'Guilherme',
    );

    test('counts only the instalments still to come', () {
      // 2 of 4 paid means two charges remain.
      final usage = cardUsage(
        snapshotWith(
          [installment('1', 100, current: 2, total: 4)],
          cards: const [card],
        ),
        card,
      );
      expect(usage.scheduled, 200);
    });

    test('collapses the repeated rows of one purchase', () {
      // A four-instalment purchase appears once per instalment billed; only
      // the furthest one describes what is left.
      final usage = cardUsage(
        snapshotWith(
          [
            installment('1', 100, current: 1, total: 4),
            installment('2', 100, current: 2, total: 4),
            installment('3', 100, current: 3, total: 4),
          ],
          cards: const [card],
        ),
        card,
      );
      expect(usage.scheduled, 100, reason: 'one charge left, not six');
    });

    test('a finished plan holds nothing', () {
      final usage = cardUsage(
        snapshotWith(
          [installment('1', 100, current: 4, total: 4)],
          cards: const [card],
        ),
        card,
      );
      expect(usage.scheduled, 0);
    });

    test('ignores instalments on another card', () {
      final usage = cardUsage(
        snapshotWith(
          [installment('1', 100, current: 1, total: 3, card: '4567')],
          cards: const [card],
        ),
        card,
      );
      expect(usage.scheduled, 0);
    });

    test('billed and scheduled add up, and availability reflects both', () {
      final snapshot = snapshotWith(
        [installment('1', 100, current: 1, total: 5)],
        cards: const [card],
        invoices: [
          Invoice(
            id: 'i1',
            cardId: 'c1',
            referenceMonth: DateTime(2026, 8),
            total: 500,
            dueDate: DateTime(2026, 8, 9),
            status: 'open',
          ),
        ],
      );
      final usage = cardUsage(snapshot, card);
      expect(usage.billed, 500);
      expect(usage.scheduled, 400, reason: 'four of five instalments remain');
      expect(usage.used, 900);
      expect(usage.available, 9100);
    });
  });
}
