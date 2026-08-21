import 'package:financeiro_ai/features/ledger/domain/entities/finance_period.dart';
import 'package:financeiro_ai/features/ledger/domain/entities/models.dart';
import 'package:financeiro_ai/features/overview/domain/narrative.dart';
import 'package:flutter_test/flutter_test.dart';

String _money(double value) =>
    'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';

FinanceTransaction _tx({
  required DateTime date,
  required double amount,
  String category = 'Alimentação',
  String merchant = 'Mercado',
  String lastFour = '1234',
  String movementType = 'purchase',
}) => FinanceTransaction(
  id: '$merchant-$date-$amount',
  date: date,
  merchant: merchant,
  category: category,
  amount: amount,
  cardLastFour: lastFour,
  status: TransactionStatus.confirmed,
  source: 'test',
  movementType: movementType,
);

FinanceSnapshot _snapshot(
  List<FinanceTransaction> items, {
  List<CreditCard> cards = const [],
  List<Invoice> invoices = const [],
}) => FinanceSnapshot(
  transactions: items,
  categories: const [],
  cards: cards,
  invoices: invoices,
  goals: const [],
  pendingReviews: 0,
);

/// Three months of steady spending before September, so a change in September
/// has something to be a change against.
///
/// Each month uses a different merchant on purpose. The same merchant at the
/// same amount every month is the app's own definition of a subscription, and
/// a fixture built that way would produce a price-change insight alongside the
/// category one and quietly change what these tests are measuring.
List<FinanceTransaction> _baseline({double perMonth = 400}) => [
  for (final month in [6, 7, 8])
    _tx(
      date: DateTime(2026, month, 10),
      amount: perMonth,
      merchant: 'Mercado $month',
    ),
];

void main() {
  final september = FinancePeriod.month(DateTime(2026, 9));

  group('category moves', () {
    test('reports a spike against the trailing average', () {
      final insights = buildInsights(
        _snapshot([
          ..._baseline(),
          _tx(date: DateTime(2026, 9, 5), amount: 800),
        ]),
        september,
        money: _money,
      );

      expect(insights, hasLength(1));
      expect(insights.single.tone, InsightTone.warning);
      expect(insights.single.category, 'Alimentação');
      expect(insights.single.text, startsWith('Você gastou 100% a mais em '));
      expect(insights.single.text, contains('R\$ 400,00 acima'));
    });

    test('names the purchases that explain a concentrated increase', () {
      final insights = buildInsights(
        _snapshot([
          ..._baseline(),
          _tx(date: DateTime(2026, 9, 1), amount: 300, merchant: 'A'),
          _tx(date: DateTime(2026, 9, 2), amount: 250, merchant: 'B'),
          _tx(date: DateTime(2026, 9, 3), amount: 250, merchant: 'C'),
          _tx(date: DateTime(2026, 9, 4), amount: 50, merchant: 'D'),
        ]),
        september,
        money: _money,
      );

      // The increase is 450; the two largest purchases already cover it.
      expect(insights.single.text, contains('puxado por 2 compras acima de'));
    });

    test('calls a diffuse increase diffuse instead of blaming a few buys', () {
      final insights = buildInsights(
        _snapshot([
          ..._baseline(),
          for (var day = 1; day <= 20; day++)
            _tx(date: DateTime(2026, 9, day), amount: 50, merchant: 'M$day'),
        ]),
        september,
        money: _money,
      );

      expect(insights.single.text, contains('diluído em'));
      expect(insights.single.text, isNot(contains('puxado por')));
    });

    test('reports a drop as good news', () {
      final insights = buildInsights(
        _snapshot([
          ..._baseline(),
          _tx(date: DateTime(2026, 9, 5), amount: 100),
        ]),
        september,
        money: _money,
      );

      expect(insights.single.tone, InsightTone.good);
      expect(insights.single.text, contains('75% a menos'));
    });

    test('stays quiet when the move is small in money', () {
      // 30 reais over a 40-real average is a big percentage and a meaningless
      // amount.
      final insights = buildInsights(
        _snapshot([
          for (final month in [6, 7, 8])
            _tx(
              date: DateTime(2026, month, 10),
              amount: 40,
              merchant: 'Mercado $month',
            ),
          _tx(date: DateTime(2026, 9, 5), amount: 70, merchant: 'Mercado 9'),
        ]),
        september,
        money: _money,
      );

      expect(insights, isEmpty);
    });

    test('stays quiet when the move is small in proportion', () {
      final insights = buildInsights(
        _snapshot([
          ..._baseline(perMonth: 1000),
          _tx(date: DateTime(2026, 9, 5), amount: 1060),
        ]),
        september,
        money: _money,
      );

      expect(insights, isEmpty);
    });

    test('needs at least two observed months before comparing', () {
      final insights = buildInsights(
        _snapshot([
          _tx(date: DateTime(2026, 8, 10), amount: 400),
          _tx(date: DateTime(2026, 9, 5), amount: 900),
        ]),
        september,
        money: _money,
      );

      expect(insights, isEmpty);
    });

    test('a month absent from the data is not a month of restraint', () {
      // July and August have data; June predates it. If June counted as zero
      // the average would drop and September would look like a spike.
      final insights = buildInsights(
        _snapshot([
          _tx(date: DateTime(2026, 7, 10), amount: 900),
          _tx(date: DateTime(2026, 8, 10), amount: 900),
          _tx(date: DateTime(2026, 9, 5), amount: 900),
        ]),
        september,
        money: _money,
      );

      expect(insights, isEmpty);
    });

    test('says nothing about a custom range', () {
      // A monthly average against an arbitrary window is a number that means
      // nothing, the same reason budget alerts stay quiet there.
      final insights = buildInsights(
        _snapshot([
          ..._baseline(),
          _tx(date: DateTime(2026, 9, 5), amount: 800),
        ]),
        FinancePeriod(
          start: DateTime(2026, 9, 1),
          endInclusive: DateTime(2026, 9, 14),
        ),
        money: _money,
      );

      expect(insights, isEmpty);
    });

    test(
      'does not invent a percentage from a category that was never used',
      () {
        final insights = buildInsights(
          _snapshot([
            ..._baseline(),
            _tx(date: DateTime(2026, 9, 5), amount: 400),
            _tx(date: DateTime(2026, 9, 6), amount: 900, category: 'Viagem'),
          ]),
          september,
          money: _money,
        );

        // Viagem has no baseline to be a percentage of, so it is left alone.
        expect(insights.where((e) => e.category == 'Viagem'), isEmpty);
      },
    );
  });

  group('price changes', () {
    test('reports a subscription that went up', () {
      final insights = buildInsights(
        _snapshot([
          for (final month in [6, 7, 8])
            _tx(
              date: DateTime(2026, month, 10),
              amount: 21.90,
              merchant: 'Spotify',
              category: 'Assinaturas',
            ),
          _tx(
            date: DateTime(2026, 9, 10),
            amount: 34.90,
            merchant: 'Spotify',
            category: 'Assinaturas',
          ),
        ]),
        september,
        money: _money,
      );

      final price = insights.firstWhere((e) => e.id == 'price:Spotify');
      expect(price.tone, InsightTone.warning);
      expect(price.text, contains('R\$ 13,00 a mais por mês'));
    });

    test('ignores a few cents of rounding', () {
      final insights = buildInsights(
        _snapshot([
          for (final month in [6, 7, 8])
            _tx(
              date: DateTime(2026, month, 10),
              amount: 21.90,
              merchant: 'Spotify',
            ),
          _tx(date: DateTime(2026, 9, 10), amount: 22.10, merchant: 'Spotify'),
        ]),
        september,
        money: _money,
      );

      expect(insights.where((e) => e.id.startsWith('price:')), isEmpty);
    });

    test('weighs a monthly increase against a year, not a month', () {
      // Thirteen reais a month is a hundred and fifty six a year, which is why
      // it should outrank a one-off category move of similar size.
      final insights = buildInsights(
        _snapshot([
          for (final month in [6, 7, 8])
            _tx(
              date: DateTime(2026, month, 10),
              amount: 21.90,
              merchant: 'Spotify',
              category: 'Assinaturas',
            ),
          _tx(
            date: DateTime(2026, 9, 10),
            amount: 34.90,
            merchant: 'Spotify',
            category: 'Assinaturas',
          ),
        ]),
        september,
        money: _money,
      );

      final price = insights.firstWhere((e) => e.id == 'price:Spotify');
      expect(price.weight, closeTo(13 * 12, 0.01));
    });
  });

  group('invoice outlook', () {
    CreditCard card() => CreditCard(
      id: 'card-1',
      name: 'Nubank',
      bank: 'Nu',
      lastFour: '1234',
      limit: 10000,
      closingDay: 20,
      dueDay: 27,
      holder: 'Você',
    );

    Invoice invoice(int month, double total) => Invoice(
      id: 'inv-$month',
      cardId: 'card-1',
      referenceMonth: DateTime(2026, month),
      total: total,
      dueDate: DateTime(2026, month, 27),
      status: 'paid',
      paidAt: DateTime(2026, month, 26),
    );

    test('warns when the open invoice is heading above the usual', () {
      final insights = buildInsights(
        _snapshot(
          [
            _tx(date: DateTime(2026, 8, 1), amount: 1000),
            _tx(date: DateTime(2026, 9, 3), amount: 1500),
          ],
          cards: [card()],
          invoices: [invoice(7, 900), invoice(8, 1000)],
        ),
        september,
        money: _money,
        now: DateTime(2026, 9, 10),
      );

      final outlook = insights.firstWhere((e) => e.id == 'invoice:card-1');
      expect(outlook.tone, InsightTone.warning);
      expect(outlook.text, contains('deve fechar em torno de'));
      expect(outlook.text, contains('acima da média'));
    });

    test('stays quiet without enough closed invoices to average', () {
      final insights = buildInsights(
        _snapshot(
          [
            _tx(date: DateTime(2026, 8, 1), amount: 1000),
            _tx(date: DateTime(2026, 9, 3), amount: 1500),
          ],
          cards: [card()],
          invoices: [invoice(8, 1000)],
        ),
        september,
        money: _money,
        now: DateTime(2026, 9, 10),
      );

      expect(insights.where((e) => e.id.startsWith('invoice:')), isEmpty);
    });

    test('stays quiet when the card has no rhythm to forecast from', () {
      // Only this month's spending exists, so the "forecast" is just what is
      // committed — calling that a saving against past invoices would be a lie.
      final insights = buildInsights(
        _snapshot(
          [_tx(date: DateTime(2026, 9, 3), amount: 100)],
          cards: [card()],
          invoices: [invoice(7, 900), invoice(8, 1000)],
        ),
        september,
        money: _money,
        now: DateTime(2026, 9, 10),
      );

      expect(insights.where((e) => e.id.startsWith('invoice:')), isEmpty);
    });
  });

  group('ranking', () {
    test('orders by how much money the observation is about', () {
      final insights = buildInsights(
        _snapshot([
          ..._baseline(),
          _tx(date: DateTime(2026, 9, 5), amount: 2000),
          for (final month in [6, 7, 8])
            _tx(
              date: DateTime(2026, month, 10),
              amount: 20,
              merchant: 'Spotify',
              category: 'Assinaturas',
            ),
          _tx(
            date: DateTime(2026, 9, 10),
            amount: 25,
            merchant: 'Spotify',
            category: 'Assinaturas',
          ),
        ]),
        september,
        money: _money,
      );

      expect(insights.first.category, 'Alimentação');
      expect(
        insights.map((e) => e.weight).toList(),
        orderedEquals(
          [for (final e in insights) e.weight]..sort((a, b) => b.compareTo(a)),
        ),
      );
    });

    test('caps the list rather than turning back into a report', () {
      final insights = buildInsights(
        _snapshot([
          for (final category in ['A', 'B', 'C', 'D', 'E', 'F'])
            for (final month in [6, 7, 8])
              _tx(
                date: DateTime(2026, month, 10),
                amount: 200,
                category: category,
                merchant: 'M$category',
              ),
          for (final category in ['A', 'B', 'C', 'D', 'E', 'F'])
            _tx(
              date: DateTime(2026, 9, 5),
              amount: 900,
              category: category,
              merchant: 'M$category',
            ),
        ]),
        september,
        money: _money,
        max: 3,
      );

      expect(insights, hasLength(3));
    });

    test('ids are stable so the list does not reshuffle under the reader', () {
      final snapshot = _snapshot([
        ..._baseline(),
        _tx(date: DateTime(2026, 9, 5), amount: 800),
      ]);

      expect(
        buildInsights(snapshot, september, money: _money).map((e) => e.id),
        buildInsights(snapshot, september, money: _money).map((e) => e.id),
      );
    });
  });

  test('says nothing at all on an empty ledger', () {
    expect(
      buildInsights(_snapshot(const []), september, money: _money),
      isEmpty,
    );
  });
}
