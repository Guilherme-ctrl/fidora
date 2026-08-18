import 'package:financeiro_ai/data/demo_finance_repository.dart';
import 'package:financeiro_ai/domain/analytics.dart';
import 'package:financeiro_ai/domain/models.dart';
import 'package:financeiro_ai/domain/transaction_draft.dart';
import 'package:flutter_test/flutter_test.dart';

FinanceTransaction charge({
  String id = '1',
  double amount = 200,
  double? personal,
  String card = '1111',
  String? holderId,
  String movementType = 'purchase',
}) => FinanceTransaction(
  id: id,
  date: DateTime(2026, 8, 10),
  merchant: 'JANTAR',
  amount: amount,
  category: 'Alimentação',
  cardLastFour: card,
  competence: DateTime(2026, 8),
  personalAmount: personal,
  holderId: holderId,
  movementType: movementType,
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
  limit: 5000,
  closingDay: 2,
  dueDay: 9,
  holder: '',
  holderId: holderId,
  includeInTotals: include,
);

FinanceSnapshot snap({
  required List<FinanceTransaction> transactions,
  List<CreditCard> cards = const [],
  List<Holder> holders = const [],
  List<Invoice> invoices = const [],
}) => FinanceSnapshot(
  transactions: transactions,
  categories: const [],
  cards: cards,
  invoices: invoices,
  goals: const [],
  holders: holders,
  pendingReviews: 0,
);

void main() {
  final august = FinancePeriod.month(DateTime(2026, 8));

  group('Parte pessoal', () {
    test('null means the whole charge is yours', () {
      final item = charge();
      expect(item.personalShare, 200);
      expect(item.isShared, isFalse);
      expect(item.expenseImpact, 200);
    });

    test('only your share reaches the totals', () {
      final analytics = analyzePeriod(
        snap(transactions: [charge(personal: 80)], cards: [card()]),
        august,
      );
      expect(analytics.expenses, 80);
    });

    test('the audited amount is untouched', () {
      // The issuer charged the full amount and the invoice must keep saying so;
      // only the personal figures use the share.
      final item = charge(personal: 80);
      expect(item.amount, 200);
      expect(item.personalShare, 80);
      expect(item.isShared, isTrue);
    });

    test('a share equal to the total is not a split', () {
      expect(charge(personal: 200).isShared, isFalse);
    });

    test('a refund credits only your share back', () {
      final item = charge(personal: 80, movementType: 'refund');
      expect(item.expenseImpact, -80);
    });
  });

  group('Validação da parte', () {
    TransactionDraft draft({double amount = 100, double? personal}) =>
        TransactionDraft(
          purchasedAt: DateTime(2026, 8, 10),
          merchant: 'JANTAR',
          amount: amount,
          categoryId: '1',
          personalAmount: personal,
        );

    test('refuses a share above the total', () {
      expect(
        draft(personal: 150).validate().share,
        'A sua parte não pode passar do valor total',
      );
    });

    test('refuses a negative share', () {
      expect(draft(personal: -1).validate().share, isNotNull);
    });

    test('accepts a share equal to the total, and none at all', () {
      expect(draft(personal: 100).validate().isEmpty, isTrue);
      expect(draft().validate().isEmpty, isTrue);
    });
  });

  group('Portador por lançamento', () {
    test("a transaction's own holder excludes it", () {
      // The invoice import writes this from the statement's notes, and it was
      // being ignored entirely.
      final analytics = analyzePeriod(
        snap(
          transactions: [charge(holderId: 'h2')],
          cards: [card()],
          holders: const [
            Holder(id: 'h2', name: 'Outra pessoa', includeInTotals: false),
          ],
        ),
        august,
      );
      expect(analytics.expenses, 0);
    });

    test("it wins over the card's holder", () {
      // One card carries charges from several people, so the row is the more
      // precise statement.
      final analytics = analyzePeriod(
        snap(
          transactions: [charge(holderId: 'me')],
          cards: [card(holderId: 'other')],
          holders: const [
            Holder(id: 'me', name: 'Eu'),
            Holder(id: 'other', name: 'Outra', includeInTotals: false),
          ],
        ),
        august,
      );
      expect(analytics.expenses, 200, reason: 'the row says it is mine');
    });

    test('a card switched off still wins over everything', () {
      final analytics = analyzePeriod(
        snap(
          transactions: [charge(holderId: 'me')],
          cards: [card(include: false)],
          holders: const [Holder(id: 'me', name: 'Eu')],
        ),
        august,
      );
      expect(analytics.expenses, 0);
    });

    test('an unknown holder does not exclude anything', () {
      final analytics = analyzePeriod(
        snap(
          transactions: [charge(holderId: 'sumiu')],
          cards: [card()],
        ),
        august,
      );
      expect(analytics.expenses, 200);
    });
  });

  group('DemoFinanceRepository', () {
    test(
      'persists the share and keeps it through a recategorization',
      () async {
        final repository = DemoFinanceRepository();
        final snapshot = await repository.loadSnapshot();
        await repository.saveTransaction(
          TransactionDraft(
            purchasedAt: DateTime(2026, 8, 10),
            merchant: 'JANTAR COMPARTILHADO',
            amount: 200,
            categoryId: snapshot.categories.first.id,
            personalAmount: 80,
          ),
        );
        var saved = (await repository.loadSnapshot()).transactions.firstWhere(
          (item) => item.merchant == 'JANTAR COMPARTILHADO',
        );
        expect(saved.personalShare, 80);

        final lazer = snapshot.categories.firstWhere((i) => i.name == 'Lazer');
        await repository.recategorizeTransactions([saved.id], lazer.id);
        saved = (await repository.loadSnapshot()).transactions.firstWhere(
          (item) => item.id == saved.id,
        );
        expect(saved.category, 'Lazer');
        expect(saved.personalShare, 80, reason: 'the split survives the move');
      },
    );
  });
}
