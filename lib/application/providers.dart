import 'package:financeiro_ai/domain/merchant_rule.dart';
import 'package:financeiro_ai/domain/models.dart';
import 'package:financeiro_ai/domain/invoice_import.dart';
import 'package:financeiro_ai/domain/review_item.dart';
import 'package:financeiro_ai/domain/transaction_draft.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class FinanceRepository {
  Future<FinanceSnapshot> loadSnapshot();
  Future<InvoiceImportPreview> previewInvoiceImport(
    InvoiceImportDocument document,
  );
  Future<InvoiceImportResult> importInvoice(InvoiceImportDocument document);

  /// Creates the transaction when [draft] has no id, updates it otherwise.
  Future<void> saveTransaction(TransactionDraft draft);
  Future<void> deleteTransaction(String id);

  Future<List<ReviewItem>> loadReviewQueue();

  /// [status] is `resolved` when the entry was handled and `dismissed` when the
  /// person decided it needed no change.
  Future<void> settleReview(String id, {required String status});

  Future<List<MerchantRule>> loadMerchantRules();
  Future<void> saveMerchantRule(MerchantRuleDraft draft);
  Future<void> deleteMerchantRule(String id);
}

final financeRepositoryProvider = Provider<FinanceRepository>(
  (ref) => throw UnimplementedError(
    'FinanceRepository must be overridden at startup.',
  ),
);
final financeSnapshotProvider = FutureProvider<FinanceSnapshot>(
  (ref) => ref.watch(financeRepositoryProvider).loadSnapshot(),
);

/// Loaded when its screen opens rather than folded into the snapshot, so the
/// first paint does not wait on data most sessions never look at.
final reviewQueueProvider = FutureProvider<List<ReviewItem>>(
  (ref) => ref.watch(financeRepositoryProvider).loadReviewQueue(),
);
final merchantRulesProvider = FutureProvider<List<MerchantRule>>(
  (ref) => ref.watch(financeRepositoryProvider).loadMerchantRules(),
);

/// Reloads the snapshot and completes only when the new data has arrived, so a
/// `RefreshIndicator` keeps spinning for exactly as long as the reload takes.
Future<void> refreshFinanceSnapshot(WidgetRef ref) async {
  ref.invalidate(financeSnapshotProvider);
  await ref.read(financeSnapshotProvider.future);
}

Future<void> refreshReviewQueue(WidgetRef ref) async {
  ref.invalidate(reviewQueueProvider);
  await ref.read(reviewQueueProvider.future);
}

Future<void> refreshMerchantRules(WidgetRef ref) async {
  ref.invalidate(merchantRulesProvider);
  await ref.read(merchantRulesProvider.future);
}
