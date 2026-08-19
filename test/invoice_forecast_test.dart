import 'package:financeiro_ai/domain/invoice_forecast.dart';
import 'package:financeiro_ai/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

CreditCard _card({int closingDay = 20, String lastFour = '1234'}) => CreditCard(
  id: 'card-1',
  name: 'Nubank',
  bank: 'Nu',
  lastFour: lastFour,
  limit: 10000,
  closingDay: closingDay,
  dueDay: 27,
  holder: 'Você',
);

FinanceTransaction _tx({
  required DateTime date,
  required double amount,
  String merchant = 'Mercado',
  String lastFour = '1234',
  int? current,
  int? total,
  String movementType = 'purchase',
  TransactionStatus status = TransactionStatus.confirmed,
}) => FinanceTransaction(
  id: '$merchant-$date-$amount-$current',
  date: date,
  merchant: merchant,
  category: 'Alimentação',
  amount: amount,
  cardLastFour: lastFour,
  status: status,
  source: 'test',
  movementType: movementType,
  installmentCurrent: current,
  installmentTotal: total,
);

FinanceSnapshot _snapshot(
  List<FinanceTransaction> items, {
  List<CreditCard>? cards,
}) => FinanceSnapshot(
  transactions: items,
  categories: const [],
  cards: cards ?? [_card()],
  invoices: const [],
  goals: const [],
  pendingReviews: 0,
);

void main() {
  // Card closes on the 20th. On the 10th of September the open invoice is
  // September's, collecting purchases from 21 Aug through 20 Sep.
  final today = DateTime(2026, 9, 10);

  group('competence and closing', () {
    test('targets the invoice still accumulating', () {
      final forecast = forecastInvoice(
        _snapshot([_tx(date: DateTime(2026, 9, 5), amount: 100)]),
        _card(),
        now: today,
      )!;

      expect(forecast.competence, DateTime(2026, 9));
      expect(forecast.closingDate, DateTime(2026, 9, 20));
      expect(forecast.daysRemaining, 10);
    });

    test('a purchase after the closing day belongs to the next invoice', () {
      // The 25th is past the 20th, so this is October's invoice, not
      // September's — and on the 25th that is the one still open.
      final forecast = forecastInvoice(
        _snapshot([_tx(date: DateTime(2026, 9, 25), amount: 300)]),
        _card(),
        now: DateTime(2026, 9, 25),
      )!;

      expect(forecast.competence, DateTime(2026, 10));
      expect(forecast.committed, 300);
    });

    test('clamps the closing day to the length of the month', () {
      // A card closing on the 31st has no 31st in February.
      final forecast = forecastInvoice(
        _snapshot(
          [_tx(date: DateTime(2026, 2, 10), amount: 100)],
          cards: [_card(closingDay: 31)],
        ),
        _card(closingDay: 31),
        now: DateTime(2026, 2, 10),
      )!;

      expect(forecast.closingDate, DateTime(2026, 2, 28));
    });
  });

  group('committed', () {
    test('sums what is already captured for this invoice', () {
      final forecast = forecastInvoice(
        _snapshot([
          _tx(date: DateTime(2026, 8, 25), amount: 100),
          _tx(date: DateTime(2026, 9, 3), amount: 250),
          // Before the cycle opened: belongs to August's invoice.
          _tx(date: DateTime(2026, 8, 15), amount: 999),
        ]),
        _card(),
        now: today,
      )!;

      expect(forecast.committed, 350);
    });

    test('ignores transactions marked ignored and other cards', () {
      final forecast = forecastInvoice(
        _snapshot([
          _tx(date: DateTime(2026, 9, 3), amount: 100),
          _tx(
            date: DateTime(2026, 9, 4),
            amount: 500,
            status: TransactionStatus.ignored,
          ),
          _tx(date: DateTime(2026, 9, 5), amount: 700, lastFour: '9999'),
        ]),
        _card(),
        now: today,
      )!;

      expect(forecast.committed, 100);
    });

    test('bills the full amount, not the personal share', () {
      // The issuer charges the whole purchase regardless of who it is
      // attributed to; using personalShare would understate the bill.
      final split = FinanceTransaction(
        id: 'split',
        date: DateTime(2026, 9, 3),
        merchant: 'Jantar',
        category: 'Alimentação',
        amount: 200,
        personalAmount: 50,
        cardLastFour: '1234',
        status: TransactionStatus.confirmed,
        source: 'test',
        movementType: 'purchase',
      );

      final forecast = forecastInvoice(
        _snapshot([split]),
        _card(),
        now: today,
      )!;

      expect(forecast.committed, 200);
    });
  });

  group('scheduled instalments', () {
    test('counts an instalment that has not been captured yet', () {
      // Bought in July as 1/5; by September's invoice the third lands.
      final forecast = forecastInvoice(
        _snapshot([
          _tx(
            date: DateTime(2026, 7, 5),
            amount: 200,
            merchant: 'Sofá',
            current: 1,
            total: 5,
          ),
        ]),
        _card(),
        now: today,
      )!;

      expect(forecast.scheduled, 200);
    });

    test('does not count an instalment already captured for this month', () {
      // The September instalment is in the ledger, so it is committed, not
      // scheduled — counting both would bill it twice.
      final forecast = forecastInvoice(
        _snapshot([
          _tx(
            date: DateTime(2026, 7, 5),
            amount: 200,
            merchant: 'Sofá',
            current: 1,
            total: 5,
          ),
          _tx(
            date: DateTime(2026, 9, 5),
            amount: 200,
            merchant: 'Sofá',
            current: 3,
            total: 5,
          ),
        ]),
        _card(),
        now: today,
      )!;

      expect(forecast.committed, 200);
      expect(forecast.scheduled, 0);
    });

    test('stops once the instalments run out', () {
      // Bought in July as 2/2: the last one already landed.
      final forecast = forecastInvoice(
        _snapshot([
          _tx(
            date: DateTime(2026, 7, 5),
            amount: 200,
            merchant: 'Sofá',
            current: 2,
            total: 2,
          ),
        ]),
        _card(),
        now: today,
      )!;

      expect(forecast.scheduled, 0);
    });
  });

  group('estimate', () {
    test('projects the remaining days from past cycles', () {
      // Two complete past cycles, 300 each. August cycle: 21 Jul–20 Aug (31
      // days). July cycle: 21 Jun–20 Jul (30 days). 600 over 61 days.
      final forecast = forecastInvoice(
        _snapshot([
          _tx(date: DateTime(2026, 8, 1), amount: 300),
          _tx(date: DateTime(2026, 7, 1), amount: 300),
        ]),
        _card(),
        now: today,
      )!;

      expect(forecast.daysObserved, 61);
      expect(forecast.dailyRate, closeTo(600 / 61, 0.0001));
      expect(forecast.estimated, closeTo(600 / 61 * 10, 0.0001));
      expect(forecast.hasBaseline, isTrue);
    });

    test('says it has no baseline when no past cycle was observed', () {
      final forecast = forecastInvoice(
        _snapshot([_tx(date: DateTime(2026, 9, 3), amount: 100)]),
        _card(),
        now: today,
      )!;

      expect(forecast.hasBaseline, isFalse);
      expect(forecast.estimated, 0);
      expect(forecast.total, 100);
    });

    test('a month absent from the data does not pass as a frugal month', () {
      // Only July was observed. If August counted as a zero-spend cycle the
      // rate would be halved and the estimate would understate.
      final forecast = forecastInvoice(
        _snapshot([_tx(date: DateTime(2026, 7, 1), amount: 300)]),
        _card(),
        now: today,
      )!;

      expect(forecast.daysObserved, 30);
      expect(forecast.dailyRate, closeTo(10, 0.0001));
    });

    test('an observed cycle with only instalments drags the rate down', () {
      // August was observed but held nothing but an instalment: real evidence
      // of a quiet month, unlike a month with no data at all.
      final forecast = forecastInvoice(
        _snapshot([
          _tx(date: DateTime(2026, 7, 1), amount: 300),
          _tx(
            date: DateTime(2026, 8, 1),
            amount: 100,
            merchant: 'Sofá',
            current: 1,
            total: 12,
          ),
        ]),
        _card(),
        now: today,
      )!;

      expect(forecast.daysObserved, 61);
      expect(forecast.dailyRate, closeTo(300 / 61, 0.0001));
    });

    test('instalments never feed the rate', () {
      // Otherwise they would be billed twice: once as rhythm, once as
      // commitment.
      final withInstalment = forecastInvoice(
        _snapshot([
          _tx(date: DateTime(2026, 8, 1), amount: 300),
          _tx(
            date: DateTime(2026, 8, 2),
            amount: 500,
            merchant: 'TV',
            current: 1,
            total: 10,
          ),
          _tx(date: DateTime(2026, 7, 1), amount: 300),
        ]),
        _card(),
        now: today,
      )!;

      expect(withInstalment.dailyRate, closeTo(600 / 61, 0.0001));
    });

    test('estimates nothing once the cycle has closed', () {
      // On the 20th the invoice closes: nothing further can land in it.
      final forecast = forecastInvoice(
        _snapshot([
          _tx(date: DateTime(2026, 8, 1), amount: 300),
          _tx(date: DateTime(2026, 9, 3), amount: 100),
        ]),
        _card(),
        now: DateTime(2026, 9, 20),
      )!;

      expect(forecast.daysRemaining, 0);
      expect(forecast.isClosed, isTrue);
      expect(forecast.estimated, 0);
      expect(forecast.total, 100);
    });
  });

  group('total', () {
    test('separates what is known from what is guessed', () {
      final forecast = forecastInvoice(
        _snapshot([
          _tx(date: DateTime(2026, 8, 1), amount: 610),
          _tx(date: DateTime(2026, 9, 3), amount: 400),
          _tx(
            date: DateTime(2026, 7, 5),
            amount: 200,
            merchant: 'Sofá',
            current: 1,
            total: 5,
          ),
        ]),
        _card(),
        now: today,
      )!;

      expect(forecast.committed, 400);
      expect(forecast.scheduled, 200);
      expect(forecast.known, 600);
      expect(forecast.total, greaterThan(forecast.known));
    });
  });

  group('cards with nothing to forecast', () {
    test('returns null rather than a confident zero', () {
      expect(forecastInvoice(_snapshot(const []), _card(), now: today), isNull);
    });

    test('forecastInvoices skips them and sorts heaviest first', () {
      final cards = [
        _card(),
        _card(lastFour: '5678'),
        _card(lastFour: '0000'),
      ];
      final forecasts = forecastInvoices(
        _snapshot([
          _tx(date: DateTime(2026, 9, 3), amount: 100),
          _tx(date: DateTime(2026, 9, 4), amount: 900, lastFour: '5678'),
        ], cards: cards),
        now: today,
      );

      expect(forecasts, hasLength(2));
      expect(forecasts.first.card.lastFour, '5678');
      expect(forecasts.last.card.lastFour, '1234');
    });
  });
}
