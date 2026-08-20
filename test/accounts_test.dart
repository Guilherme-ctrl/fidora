import 'package:financeiro_ai/core/errors/failure.dart';
import 'package:financeiro_ai/features/ledger/infra/repositories/demo_finance_repository.dart';
import 'package:financeiro_ai/features/catalog/domain/catalog_drafts.dart';
import 'package:financeiro_ai/features/overview/domain/insights.dart';
import 'package:financeiro_ai/features/ledger/domain/entities/models.dart';
import 'package:financeiro_ai/features/transactions/domain/transaction_draft.dart';
import 'package:flutter_test/flutter_test.dart';

FinanceTransaction move(
  String id,
  double amount, {
  required String accountId,
  bool income = false,
  TransactionStatus status = TransactionStatus.confirmed,
}) => FinanceTransaction(
  id: id,
  date: DateTime(2026, 8, 10),
  merchant: 'MOVIMENTO',
  amount: amount,
  category: 'Outros',
  cardLastFour: '----',
  accountId: accountId,
  movementType: income ? 'credit' : 'purchase',
  status: status,
);

FinanceSnapshot snap({
  List<FinanceTransaction> transactions = const [],
  List<Account> accounts = const [],
}) => FinanceSnapshot(
  transactions: transactions,
  categories: const [],
  cards: const [],
  invoices: const [],
  goals: const [],
  accounts: accounts,
  pendingReviews: 0,
);

void main() {
  group('accountBalances', () {
    const account = Account(id: 'a1', name: 'Corrente', openingBalance: 1000);

    test('adds income and subtracts expenses to the opening balance', () {
      final balance = accountBalances(
        snap(
          transactions: [
            move('1', 300, accountId: 'a1', income: true),
            move('2', 120, accountId: 'a1'),
          ],
          accounts: const [account],
        ),
      ).single;
      expect(balance.moved, 180);
      expect(balance.balance, 1180);
      expect(balance.entries, 2);
    });

    test('with no opening balance the figure is only the movement', () {
      // Saying so matters: otherwise the screen would claim an account holds
      // less than it does.
      final balance = accountBalances(
        snap(
          transactions: [move('1', 50, accountId: 'a1')],
          accounts: const [Account(id: 'a1', name: 'Corrente')],
        ),
      ).single;
      expect(balance.isMovementOnly, isTrue);
      expect(balance.balance, -50);
    });

    test('ignored rows do not move the balance', () {
      final balance = accountBalances(
        snap(
          transactions: [
            move('1', 90, accountId: 'a1', status: TransactionStatus.ignored),
          ],
          accounts: const [account],
        ),
      ).single;
      expect(balance.balance, 1000);
      expect(balance.entries, 0);
    });

    test('movements on another account are not counted', () {
      final balances = accountBalances(
        snap(
          transactions: [move('1', 90, accountId: 'a2')],
          accounts: const [account],
        ),
      );
      expect(balances.single.balance, 1000);
    });

    test('an account with no movement still reports its opening balance', () {
      expect(
        accountBalances(snap(accounts: const [account])).single.balance,
        1000,
      );
    });
  });

  group('totalAccountBalance', () {
    test('sums the accounts that count', () {
      final balances = accountBalances(
        snap(
          accounts: const [
            Account(id: 'a1', name: 'Corrente', openingBalance: 1000),
            Account(id: 'a2', name: 'Poupança', openingBalance: 500),
          ],
        ),
      );
      expect(totalAccountBalance(balances), 1500);
    });

    test('leaves out an account marked out of totals', () {
      final balances = accountBalances(
        snap(
          accounts: const [
            Account(id: 'a1', name: 'Corrente', openingBalance: 1000),
            Account(
              id: 'a2',
              name: 'Da empresa',
              openingBalance: 90000,
              includeInTotals: false,
            ),
          ],
        ),
      );
      expect(totalAccountBalance(balances), 1000);
    });
  });

  group('AccountDraft', () {
    test('requires a name', () {
      expect(const AccountDraft(name: '  ').validate().name, isNotNull);
    });

    test('allows a negative opening balance', () {
      // An overdraft is a legitimate starting point.
      expect(
        const AccountDraft(
          name: 'Corrente',
          openingBalance: -250,
        ).validate().isEmpty,
        isTrue,
      );
    });

    test('refuses a value that is not a number', () {
      expect(
        AccountDraft(
          name: 'Corrente',
          openingBalance: double.nan,
        ).validate().openingBalance,
        isNotNull,
      );
    });
  });

  group('DemoFinanceRepository — contas', () {
    test('creates an account and it reaches the snapshot', () async {
      final repository = DemoFinanceRepository();
      await repository.saveAccount(
        const AccountDraft(
          name: 'Poupança',
          type: 'savings',
          openingBalance: 800,
        ),
      );
      final saved = (await repository.loadSnapshot()).accounts.firstWhere(
        (item) => item.name == 'Poupança',
      );
      expect(saved.typeLabel, 'Poupança');
      expect(saved.openingBalance, 800);
    });

    test('refuses a duplicate name regardless of case', () async {
      final repository = DemoFinanceRepository();
      await expectLater(
        repository.saveAccount(const AccountDraft(name: 'conta corrente')),
        throwsA(isA<DuplicateAccount>()),
      );
    });

    test('archiving removes it from the list', () async {
      final repository = DemoFinanceRepository();
      final existing = (await repository.loadSnapshot()).accounts.first;
      await repository.setAccountActive(existing.id, active: false);
      expect((await repository.loadSnapshot()).accounts, isEmpty);
    });

    test('a transaction keeps the account it was saved with', () async {
      final repository = DemoFinanceRepository();
      final snapshot = await repository.loadSnapshot();
      await repository.saveTransaction(
        TransactionDraft(
          purchasedAt: DateTime(2026, 8, 12),
          merchant: 'ALUGUEL',
          amount: 1800,
          categoryId: snapshot.categories.first.id,
          accountId: snapshot.accounts.first.id,
        ),
      );
      final saved = (await repository.loadSnapshot()).transactions.firstWhere(
        (item) => item.merchant == 'ALUGUEL',
      );
      expect(saved.accountId, snapshot.accounts.first.id);
    });
  });
}
