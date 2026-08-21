import 'package:financeiro_ai/features/ledger/infra/repositories/demo_finance_repository.dart';
import 'package:financeiro_ai/features/ledger/domain/entities/models.dart';
import 'package:financeiro_ai/features/ledger/presenter/cubits/finance_cubit.dart';
import 'package:financeiro_ai/features/ledger/presenter/states/finance_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Counts how often each half is fetched, which is the whole point of the
/// split: a captured purchase must not refetch every card and category.
///
/// It does not delegate to the demo repository's loaders: those sleep, and a
/// `Future.delayed` cannot resolve while the test body is blocked on an await
/// rather than pumping the clock.
class _CountingRepository extends DemoFinanceRepository {
  int catalogLoads = 0;
  int ledgerLoads = 0;
  bool truncated = false;

  @override
  Future<FinanceCatalog> loadCatalog() async {
    catalogLoads++;
    return const FinanceCatalog(categories: [], cards: [], goals: []);
  }

  @override
  Future<FinanceLedger> loadLedger() async {
    ledgerLoads++;
    return FinanceLedger(
      transactions: const [],
      invoices: const [],
      pendingReviews: 0,
      truncated: truncated,
    );
  }
}

/// The cubit under test, wired to the counting repository.
///
/// This used to be driven through a widget, because Riverpod's refresh helpers
/// took a `WidgetRef` and there was no way to call them without one. A cubit
/// is an object, so the test is about the object.
FinanceCubit _cubit(_CountingRepository repo) =>
    FinanceCubit(catalog: repo, transactions: repo);

void main() {
  group('composition', () {
    test('joins both halves into the object the screens read', () {
      final snapshot = FinanceSnapshot.compose(
        catalog: const FinanceCatalog(
          categories: [],
          cards: [],
          goals: [],
          currencyCode: 'EUR',
        ),
        ledger: const FinanceLedger(
          transactions: [],
          invoices: [],
          pendingReviews: 3,
          truncated: true,
        ),
      );

      expect(snapshot.currencyCode, 'EUR');
      expect(snapshot.pendingReviews, 3);
      expect(snapshot.truncated, isTrue);
    });

    test('is not truncated by default', () {
      expect(
        FinanceSnapshot.compose(
          catalog: const FinanceCatalog(categories: [], cards: [], goals: []),
          ledger: const FinanceLedger(
            transactions: [],
            invoices: [],
            pendingReviews: 0,
          ),
        ).truncated,
        isFalse,
      );
    });
  });

  group('refreshing', () {
    test('the first load fetches each half exactly once', () async {
      final repo = _CountingRepository();
      final cubit = _cubit(repo);
      await cubit.load();

      expect(repo.catalogLoads, 1);
      expect(repo.ledgerLoads, 1);
      expect(cubit.state.snapshot, isNotNull);
    });

    test('a transaction write reloads the ledger and not the catalog', () async {
      final repo = _CountingRepository();
      final cubit = _cubit(repo);
      await cubit.load();

      await cubit.reloadLedger();

      expect(repo.ledgerLoads, 2);
      // The point of the split: cards, categories, holders and accounts cannot
      // move because a purchase was recorded.
      expect(repo.catalogLoads, 1);
    });

    test('a catalog write reloads both', () async {
      final repo = _CountingRepository();
      final cubit = _cubit(repo);
      await cubit.load();

      await cubit.reloadAll();

      expect(repo.catalogLoads, 2);
      expect(repo.ledgerLoads, 2);
    });

    test('the composed snapshot carries a truncated ledger through', () async {
      final repo = _CountingRepository()..truncated = true;
      final cubit = _cubit(repo);
      await cubit.load();

      expect(cubit.state.snapshot!.truncated, isTrue);
    });

    test('a half that has not arrived yields no snapshot', () async {
      // Composing a ledger with no catalogue would render transactions whose
      // categories cannot be resolved.
      expect(const FinanceState().snapshot, isNull);
    });
  });
}
