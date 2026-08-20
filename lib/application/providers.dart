import 'package:financeiro_ai/core/platform/file_access.dart';
import 'package:financeiro_ai/core/platform/platform_services.dart';
import 'package:financeiro_ai/domain/auth_repository.dart';
import 'package:financeiro_ai/domain/repositories/repositories.dart';
import 'package:financeiro_ai/domain/merchant_rule.dart';
import 'package:financeiro_ai/domain/models.dart';
import 'package:financeiro_ai/domain/review_item.dart';
import 'package:financeiro_ai/domain/shortcut_token.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


/// One registration per contract.
///
/// Start-up hands the same object to all six, because the two implementations
/// satisfy all six. What changed is what a consumer can ask for: a screen that
/// edits categories now depends on [CatalogRepository] and cannot reach the
/// shortcut tokens.
Never _mustOverride() =>
    throw UnimplementedError('Repositories must be overridden at startup.');

final transactionRepositoryProvider = Provider<TransactionRepository>(
  (ref) => _mustOverride(),
);
final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => _mustOverride(),
);
final invoiceRepositoryProvider = Provider<InvoiceRepository>(
  (ref) => _mustOverride(),
);
final reviewRepositoryProvider = Provider<ReviewRepository>(
  (ref) => _mustOverride(),
);
final shortcutTokenRepositoryProvider = Provider<ShortcutTokenRepository>(
  (ref) => _mustOverride(),
);
final receiptStorageProvider = Provider<ReceiptStorage>(
  (ref) => _mustOverride(),
);
/// Overridden at start-up, beside the finance repository, so the two data
/// paths are composed in the same place.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => throw UnimplementedError(
    'AuthRepository must be overridden at startup.',
  ),
);

/// The three platform services, overridable in a test the same way the
/// repositories are.
final filePickerProvider = Provider<FilePicker>(
  (ref) => const SystemFilePicker(),
);
final imageCaptureProvider = Provider<ImageCapture>(
  (ref) => const SystemImageCapture(),
);
final shareServiceProvider = Provider<ShareService>(
  (ref) => const SystemShareService(),
);

/// Registers one object under all six contracts.
///
/// Both implementations satisfy all six, so composition names the object once.
/// Without this, every test and the app itself would repeat six lines that can
/// only ever be written together — and a seventh contract would mean editing
/// all of them.
// The return type cannot be written: Riverpod's `Override` is exported from
// `package:riverpod/misc.dart`, and `riverpod` is a transitive dependency here
// rather than a declared one. Declaring it to name one type is a worse trade
// than this line.
// ignore: strict_top_level_inference
financeOverrides(FinanceRepository repository) => [
  transactionRepositoryProvider.overrideWithValue(repository),
  catalogRepositoryProvider.overrideWithValue(repository),
  invoiceRepositoryProvider.overrideWithValue(repository),
  reviewRepositoryProvider.overrideWithValue(repository),
  shortcutTokenRepositoryProvider.overrideWithValue(repository),
  receiptStorageProvider.overrideWithValue(repository),
];

final financeCatalogProvider = FutureProvider<FinanceCatalog>(
  (ref) => ref.watch(catalogRepositoryProvider).loadCatalog(),
);
final financeLedgerProvider = FutureProvider<FinanceLedger>(
  (ref) => ref.watch(transactionRepositoryProvider).loadLedger(),
);

/// Composed from the two halves, so every screen keeps reading one object
/// while a capture only invalidates the half that actually changed.
final financeSnapshotProvider = FutureProvider<FinanceSnapshot>((ref) async {
  final catalog = await ref.watch(financeCatalogProvider.future);
  final ledger = await ref.watch(financeLedgerProvider.future);
  return FinanceSnapshot.compose(catalog: catalog, ledger: ledger);
});

/// Loaded when its screen opens rather than folded into the snapshot, so the
/// first paint does not wait on data most sessions never look at.
final reviewQueueProvider = FutureProvider<List<ReviewItem>>(
  (ref) => ref.watch(reviewRepositoryProvider).loadReviewQueue(),
);
final merchantRulesProvider = FutureProvider<List<MerchantRule>>(
  (ref) => ref.watch(reviewRepositoryProvider).loadMerchantRules(),
);
final shortcutTokensProvider = FutureProvider<List<ShortcutToken>>(
  (ref) => ref.watch(shortcutTokenRepositoryProvider).loadShortcutTokens(),
);
final importBatchesProvider = FutureProvider<List<ImportBatch>>(
  (ref) => ref.watch(invoiceRepositoryProvider).loadImportBatches(),
);

/// Reloads the snapshot and completes only when the new data has arrived, so a
/// `RefreshIndicator` keeps spinning for exactly as long as the reload takes.
Future<void> refreshFinanceSnapshot(WidgetRef ref) async {
  ref.invalidate(financeCatalogProvider);
  ref.invalidate(financeLedgerProvider);
  await ref.read(financeSnapshotProvider.future);
}

/// Reloads only what a captured, edited or deleted transaction can change.
///
/// Cards, categories, holders and accounts are edited from their own screens
/// and cannot move because a purchase was recorded, so refetching them on every
/// save was work with no possible effect on the result.
Future<void> refreshLedger(WidgetRef ref) async {
  ref.invalidate(financeLedgerProvider);
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
