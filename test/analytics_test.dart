import 'package:financeiro_ai/features/ledger/domain/entities/finance_period.dart';
import 'package:financeiro_ai/features/overview/domain/analytics.dart';
import 'package:financeiro_ai/features/ledger/domain/entities/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final snapshot = FinanceSnapshot(
    transactions: [
      FinanceTransaction(
        id: 'expense',
        date: DateTime(2026, 8, 10),
        competence: DateTime(2026, 8),
        merchant: 'Mercado',
        amount: 200,
        category: 'Alimentação',
        cardLastFour: '6902',
      ),
      FinanceTransaction(
        id: 'income',
        date: DateTime(2026, 8, 5),
        merchant: 'Salário',
        amount: 1000,
        category: 'Financeiro',
        cardLastFour: '----',
        movementType: 'credit',
      ),
      FinanceTransaction(
        id: 'ignored',
        date: DateTime(2026, 8, 12),
        merchant: 'Ignorado',
        amount: 500,
        category: 'Outros',
        cardLastFour: '2137',
        status: TransactionStatus.ignored,
      ),
      FinanceTransaction(
        id: 'outside',
        date: DateTime(2026, 7, 31),
        merchant: 'Julho',
        amount: 50,
        category: 'Lazer',
        cardLastFour: '6902',
      ),
      FinanceTransaction(
        id: 'invoice-competence',
        date: DateTime(2026, 7, 18),
        competence: DateTime(2026, 8),
        merchant: 'Compra parcelada',
        amount: 80,
        category: 'Compras',
        cardLastFour: '6902',
        installmentCurrent: 2,
        installmentTotal: 6,
      ),
    ],
    categories: const [
      FinanceCategory(
        id: 'food',
        name: 'Alimentação',
        iconName: 'category',
        colorHex: '#06485B',
        monthlyBudget: 1000,
      ),
    ],
    cards: const [],
    invoices: const [],
    goals: const [],
    pendingReviews: 0,
  );

  test('analyzes only confirmed transactions inside the selected month', () {
    final result = analyzePeriod(
      snapshot,
      FinancePeriod.month(DateTime(2026, 8)),
    );

    expect(result.transactions, hasLength(3));
    expect(result.expenses, 280);
    expect(result.income, 1000);
    expect(result.balance, 720);
    expect(result.byCategory['Alimentação'], 200);
    expect(result.byCategory['Compras'], 80);
  });

  test('custom period includes its final day', () {
    final period = FinancePeriod(
      start: DateTime(2026, 7, 31),
      endInclusive: DateTime(2026, 8, 5),
    );

    expect(analyzePeriod(snapshot, period).transactions, hasLength(4));
  });

  test('uses invoice competence for card purchases', () {
    final installment = snapshot.transactions.firstWhere(
      (item) => item.id == 'invoice-competence',
    );

    expect(analyticsDate(installment), DateTime(2026, 8));
    expect(
      analyzePeriod(
        snapshot,
        FinancePeriod.month(DateTime(2026, 7)),
      ).transactions,
      isNot(contains(installment)),
    );
    expect(
      analyzePeriod(
        snapshot,
        FinancePeriod.month(DateTime(2026, 8)),
      ).transactions,
      contains(installment),
    );
  });
}
