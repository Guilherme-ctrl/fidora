import 'package:financeiro_ai/features/overview/domain/analytics.dart';
import 'package:financeiro_ai/features/ledger/domain/entities/models.dart';
import 'package:financeiro_ai/core/design_system/common.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

FinanceSnapshot snapshotOf(
  List<FinanceTransaction> items, {
  String code = 'BRL',
}) => FinanceSnapshot(
  transactions: items,
  categories: const [],
  cards: const [],
  invoices: const [],
  goals: const [],
  pendingReviews: 0,
  currencyCode: code,
);

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  group('FinancePeriod equality', () {
    test('two periods over the same month are equal', () {
      expect(
        FinancePeriod.month(DateTime(2026, 8)),
        FinancePeriod.month(DateTime(2026, 8)),
      );
      expect(
        FinancePeriod.month(DateTime(2026, 8)).hashCode,
        FinancePeriod.month(DateTime(2026, 8)).hashCode,
      );
    });

    test('different months are not equal', () {
      expect(
        FinancePeriod.month(DateTime(2026, 8)),
        isNot(FinancePeriod.month(DateTime(2026, 9))),
      );
    });
  });

  group('analyzePeriod memo', () {
    test('returns the identical result for a repeated call', () {
      final snapshot = snapshotOf([
        FinanceTransaction(
          id: '1',
          date: DateTime(2026, 8, 5),
          merchant: 'LOJA',
          amount: 10,
          category: 'Lazer',
          cardLastFour: '----',
        ),
      ]);
      final period = FinancePeriod.month(DateTime(2026, 8));
      final first = analyzePeriod(snapshot, period);
      final second = analyzePeriod(
        snapshot,
        FinancePeriod.month(DateTime(2026, 8)),
      );
      expect(identical(first, second), isTrue);
    });

    test('a new snapshot is not served from the cache', () {
      final period = FinancePeriod.month(DateTime(2026, 8));
      final a = analyzePeriod(snapshotOf(const []), period);
      final b = analyzePeriod(
        snapshotOf([
          FinanceTransaction(
            id: '1',
            date: DateTime(2026, 8, 5),
            merchant: 'LOJA',
            amount: 40,
            category: 'Lazer',
            cardLastFour: '----',
          ),
        ]),
        period,
      );
      expect(a.expenses, 0);
      expect(b.expenses, 40);
    });
  });

  group('configureCurrency', () {
    tearDown(() => configureCurrency('BRL'));

    test('defaults to reais', () {
      expect(currency.format(1234.5), contains('R\$'));
    });

    test('switches the formatter when the profile says otherwise', () {
      configureCurrency('USD');
      final formatted = currency.format(1234.5);
      expect(formatted, contains('1,234.50'));
      expect(formatted, isNot(contains('R\$')));
    });

    test('an unmapped code still formats, using the code as symbol', () {
      configureCurrency('XOF');
      expect(currency.format(10), contains('XOF'));
    });

    test('is case-insensitive and ignores blanks', () {
      configureCurrency('usd');
      final afterLower = currency.format(1);
      configureCurrency('   ');
      expect(currency.format(1), afterLower, reason: 'blank must not reset it');
    });
  });
}
