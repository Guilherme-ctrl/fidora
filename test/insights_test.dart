import 'package:financeiro_ai/domain/analytics.dart';
import 'package:financeiro_ai/domain/insights.dart';
import 'package:financeiro_ai/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

FinanceTransaction charge(
  String merchant,
  double amount,
  DateTime date, {
  String category = 'Assinaturas',
  int? current,
  int? total,
  TransactionStatus status = TransactionStatus.confirmed,
}) => FinanceTransaction(
  id: '$merchant-${date.month}-$amount',
  date: date,
  merchant: merchant,
  amount: amount,
  category: category,
  cardLastFour: '----',
  installmentCurrent: current,
  installmentTotal: total,
  status: status,
);

FinanceCategory category(String name, {double? budget}) => FinanceCategory(
  id: name,
  name: name,
  iconName: 'category',
  colorHex: '#06485B',
  monthlyBudget: budget,
);

FinanceSnapshot snap(
  List<FinanceTransaction> items, {
  List<FinanceCategory> categories = const [],
}) => FinanceSnapshot(
  transactions: items,
  categories: categories,
  cards: const [],
  invoices: const [],
  goals: const [],
  pendingReviews: 0,
);

void main() {
  final august = FinancePeriod.month(DateTime(2026, 8));

  group('budgetAlerts', () {
    test('stays quiet below 80 per cent', () {
      final alerts = budgetAlerts(
        snap(
          [charge('LOJA', 70, DateTime(2026, 8, 5), category: 'Lazer')],
          categories: [category('Lazer', budget: 100)],
        ),
        august,
      );
      expect(alerts, isEmpty);
    });

    test('warns at 80 and flags an overrun', () {
      final approaching = budgetAlerts(
        snap(
          [charge('LOJA', 80, DateTime(2026, 8, 5), category: 'Lazer')],
          categories: [category('Lazer', budget: 100)],
        ),
        august,
      ).single;
      expect(approaching.level, BudgetLevel.approaching);
      expect(approaching.remaining, 20);

      final over = budgetAlerts(
        snap(
          [charge('LOJA', 130, DateTime(2026, 8, 5), category: 'Lazer')],
          categories: [category('Lazer', budget: 100)],
        ),
        august,
      ).single;
      expect(over.level, BudgetLevel.over);
      expect(over.remaining, -30);
    });

    test('ignores categories with no budget', () {
      expect(
        budgetAlerts(
          snap(
            [charge('LOJA', 999, DateTime(2026, 8, 5), category: 'Lazer')],
            categories: [category('Lazer')],
          ),
          august,
        ),
        isEmpty,
      );
    });

    test('says nothing for a custom range', () {
      // A monthly budget against an arbitrary window would report an overrun
      // that means nothing.
      final custom = FinancePeriod(
        start: DateTime(2026, 8, 1),
        endInclusive: DateTime(2026, 10, 31),
      );
      expect(
        budgetAlerts(
          snap(
            [charge('LOJA', 500, DateTime(2026, 8, 5), category: 'Lazer')],
            categories: [category('Lazer', budget: 100)],
          ),
          custom,
        ),
        isEmpty,
      );
    });

    test('orders the worst first', () {
      final alerts = budgetAlerts(
        snap(
          [
            charge('A', 90, DateTime(2026, 8, 5), category: 'Lazer'),
            charge('B', 300, DateTime(2026, 8, 5), category: 'Compras'),
          ],
          categories: [
            category('Lazer', budget: 100),
            category('Compras', budget: 100),
          ],
        ),
        august,
      );
      expect(alerts.first.category.name, 'Compras');
    });
  });

  group('detectRecurring', () {
    List<FinanceTransaction> monthly(
      String merchant,
      double amount,
      int months, {
      double? lastAmount,
    }) => List.generate(months, (index) {
      final isLast = index == months - 1;
      return charge(
        merchant,
        isLast ? (lastAmount ?? amount) : amount,
        DateTime(2026, index + 1, 10),
      );
    });

    test('finds a charge repeating across months', () {
      final found = detectRecurring(snap(monthly('NETFLIX', 39.9, 4)));
      expect(found, hasLength(1));
      expect(found.single.merchant, 'NETFLIX');
      expect(found.single.monthsSeen, 4);
      expect(found.single.priceChanged, isFalse);
    });

    test('needs enough months before calling it recurring', () {
      expect(detectRecurring(snap(monthly('NETFLIX', 39.9, 2))), isEmpty);
    });

    test('notices a price change and says how much', () {
      final found = detectRecurring(
        snap(monthly('SPOTIFY', 21.9, 5, lastAmount: 27.9)),
      ).single;
      expect(found.priceChanged, isTrue);
      expect(found.priceDelta, closeTo(6, 0.001));
      expect(found.monthlyCost, 27.9);
    });

    test(
      'a merchant visited often at random amounts is not a subscription',
      () {
        final erratic = [
          charge('PADARIA', 8, DateTime(2026, 1, 3), category: 'Alimentação'),
          charge('PADARIA', 45, DateTime(2026, 2, 9), category: 'Alimentação'),
          charge('PADARIA', 120, DateTime(2026, 3, 4), category: 'Alimentação'),
          charge('PADARIA', 15, DateTime(2026, 4, 7), category: 'Alimentação'),
        ];
        expect(detectRecurring(snap(erratic)), isEmpty);
      },
    );

    test('instalments are not subscriptions', () {
      // They repeat and then stop, which is the opposite.
      final plan = List.generate(
        4,
        (index) => charge(
          'MOVEIS',
          250,
          DateTime(2026, index + 1, 10),
          current: index + 1,
          total: 4,
        ),
      );
      expect(detectRecurring(snap(plan)), isEmpty);
    });

    test('ignored rows do not count', () {
      final ignored = List.generate(
        4,
        (index) => charge(
          'NETFLIX',
          39.9,
          DateTime(2026, index + 1, 10),
          status: TransactionStatus.ignored,
        ),
      );
      expect(detectRecurring(snap(ignored)), isEmpty);
    });

    test('matching folds accents, so one merchant is not counted twice', () {
      final mixed = [
        charge('ACADEMIA SÃO PAULO', 120, DateTime(2026, 1, 5)),
        charge('ACADEMIA SAO PAULO', 120, DateTime(2026, 2, 5)),
        charge('academia sao paulo', 120, DateTime(2026, 3, 5)),
      ];
      expect(detectRecurring(snap(mixed)), hasLength(1));
    });

    test('totals what the subscriptions cost per month', () {
      final found = detectRecurring(
        snap([...monthly('NETFLIX', 40, 3), ...monthly('SPOTIFY', 20, 3)]),
      );
      expect(recurringMonthlyTotal(found), 60);
      expect(found.first.merchant, 'NETFLIX', reason: 'costliest first');
    });
  });
}
