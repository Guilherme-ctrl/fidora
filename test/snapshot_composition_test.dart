import 'package:financeiro_ai/application/providers.dart';
import 'package:financeiro_ai/data/demo_finance_repository.dart';
import 'package:financeiro_ai/domain/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// Riverpod's refresh helpers take a WidgetRef, so the container is driven
/// through a real widget rather than a bare ProviderContainer.
class _Probe extends ConsumerWidget {
  const _Probe({required this.onRef});
  final void Function(WidgetRef) onRef;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    onRef(ref);
    final snapshot = ref.watch(financeSnapshotProvider);
    return MaterialApp(
      home: Scaffold(
        body: Text(
          snapshot.hasValue
              ? 'carregado:${snapshot.value!.transactions.length}'
              : 'carregando',
        ),
      ),
    );
  }
}

Future<WidgetRef> _pump(WidgetTester tester, _CountingRepository repo) async {
  late WidgetRef captured;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [financeRepositoryProvider.overrideWithValue(repo)],
      child: _Probe(onRef: (ref) => captured = ref),
    ),
  );
  await tester.pumpAndSettle();
  return captured;
}

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
    testWidgets('the first load fetches each half exactly once', (
      tester,
    ) async {
      final repo = _CountingRepository();
      await _pump(tester, repo);

      expect(repo.catalogLoads, 1);
      expect(repo.ledgerLoads, 1);
      expect(find.textContaining('carregado:'), findsOneWidget);
    });

    testWidgets('a transaction write reloads the ledger and not the catalog', (
      tester,
    ) async {
      final repo = _CountingRepository();
      final ref = await _pump(tester, repo);

      await refreshLedger(ref);
      await tester.pumpAndSettle();

      expect(repo.ledgerLoads, 2);
      // The point of the split: cards, categories, holders and accounts cannot
      // move because a purchase was recorded.
      expect(repo.catalogLoads, 1);
    });

    testWidgets('a catalog write reloads both', (tester) async {
      final repo = _CountingRepository();
      final ref = await _pump(tester, repo);

      await refreshFinanceSnapshot(ref);
      await tester.pumpAndSettle();

      expect(repo.catalogLoads, 2);
      expect(repo.ledgerLoads, 2);
    });

    testWidgets('the composed snapshot carries a truncated ledger through', (
      tester,
    ) async {
      final repo = _CountingRepository()..truncated = true;
      final ref = await _pump(tester, repo);

      final snapshot = await ref.read(financeSnapshotProvider.future);
      expect(snapshot.truncated, isTrue);
    });
  });
}
