import 'package:financeiro_ai/domain/catalog_drafts.dart';
import 'package:financeiro_ai/domain/merchant_rule.dart';
import 'package:financeiro_ai/domain/models.dart';
import 'package:financeiro_ai/domain/invoice_import.dart';
import 'package:financeiro_ai/domain/review_item.dart';
import 'package:financeiro_ai/domain/shortcut_token.dart';
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

  /// Recategorizes many rows at once. One call rather than one per row, so
  /// correcting an import does not mean a round trip per transaction.
  Future<void> recategorizeTransactions(List<String> ids, String categoryId);

  Future<List<ReviewItem>> loadReviewQueue();

  /// [status] is `resolved` when the entry was handled and `dismissed` when the
  /// person decided it needed no change.
  Future<void> settleReview(String id, {required String status});

  /// Settles an invoice or reopens it. Paying releases the committed limit,
  /// because [cardUsage] only counts invoices that are not paid.
  Future<void> setInvoicePaid(String invoiceId, {required bool paid});

  Future<void> saveCard(CardDraft draft);

  /// Cards are deactivated, never deleted: transactions point at them and the
  /// history would lose its card once the row went away.
  Future<void> setCardActive(String id, {required bool active});

  Future<void> saveCategory(CategoryDraft draft);
  Future<void> setCategoryActive(String id, {required bool active});

  Future<void> saveGoal(GoalDraft draft);
  Future<void> setGoalActive(String id, {required bool active});

  Future<void> saveHolder(HolderDraft draft);
  Future<void> deleteHolder(String id);

  Future<List<ShortcutToken>> loadShortcutTokens();

  /// Issues a token. The secret comes back once and is never stored in full.
  Future<IssuedShortcutToken> createShortcutToken(String name);

  Future<void> revokeShortcutToken(String id);

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
final shortcutTokensProvider = FutureProvider<List<ShortcutToken>>(
  (ref) => ref.watch(financeRepositoryProvider).loadShortcutTokens(),
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

Future<void> refreshShortcutTokens(WidgetRef ref) async {
  ref.invalidate(shortcutTokensProvider);
  await ref.read(shortcutTokensProvider.future);
}
