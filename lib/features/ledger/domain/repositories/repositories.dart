/// The data contracts, one per area of the product.
///
/// This was a single `FinanceRepository` with 31 methods covering nine areas —
/// transactions, invoices, cards, categories, goals, accounts, holders,
/// review, merchant rules, shortcut tokens and receipt storage. Every feature
/// depended on an interface that knew everything about all the others, every
/// double had to implement all 31, and adding one method anywhere broke every
/// implementer.
///
/// It also lived in `lib/application`, beside the dependency-injection
/// registrations, in a file that imports Riverpod. The central contract of the
/// system depended on the state-management package.
///
/// The implementations remain one class each: `SupabaseFinanceRepository` and
/// `DemoFinanceRepository` implement all six. The split that matters is on the
/// consuming side — a screen can now say which of the six it needs.
library;

import 'dart:typed_data';

import 'package:financeiro_ai/features/catalog/domain/catalog_drafts.dart';
import 'package:financeiro_ai/features/imports/domain/invoice_import.dart';
import 'package:financeiro_ai/features/review/domain/merchant_rule.dart';
import 'package:financeiro_ai/features/ledger/domain/entities/models.dart';
import 'package:financeiro_ai/features/review/domain/review_item.dart';
import 'package:financeiro_ai/features/settings/domain/shortcut_token.dart';
import 'package:financeiro_ai/features/transactions/domain/transaction_draft.dart';

/// The ledger: reading it, and changing it.
abstract interface class TransactionRepository {
  Future<FinanceSnapshot> loadSnapshot();

  /// The half that changes on every write. Pages through the whole ledger
  /// rather than stopping at a fixed count.
  Future<FinanceLedger> loadLedger();

  /// Creates the transaction when [draft] has no id, updates it otherwise.
  Future<void> saveTransaction(TransactionDraft draft);

  Future<void> deleteTransaction(String id);

  /// Recategorizes many rows at once. One call rather than one per row, so
  /// correcting an import does not mean a round trip per transaction.
  Future<void> recategorizeTransactions(List<String> ids, String categoryId);
}

/// The rarely-changing half: categories, cards, goals, holders and accounts.
abstract interface class CatalogRepository {
  /// Loaded separately from the ledger so a captured purchase does not refetch
  /// all of it.
  Future<FinanceCatalog> loadCatalog();

  Future<void> saveCard(CardDraft draft);

  /// Cards are deactivated, never deleted: transactions point at them and the
  /// history would lose its card once the row went away.
  Future<void> setCardActive(String id, {required bool active});

  Future<void> saveCategory(CategoryDraft draft);
  Future<void> setCategoryActive(String id, {required bool active});

  Future<void> saveGoal(GoalDraft draft);
  Future<void> setGoalActive(String id, {required bool active});

  Future<void> saveAccount(AccountDraft draft);

  /// Accounts are deactivated, never deleted: transactions point at them.
  Future<void> setAccountActive(String id, {required bool active});

  Future<void> saveHolder(HolderDraft draft);
  Future<void> deleteHolder(String id);
}

/// Invoices, and the imports that fill them.
abstract interface class InvoiceRepository {
  /// Settles an invoice or reopens it. Paying releases the committed limit,
  /// because [cardUsage] only counts invoices that are not paid.
  Future<void> setInvoicePaid(String invoiceId, {required bool paid});

  Future<InvoiceImportPreview> previewInvoiceImport(
    InvoiceImportDocument document,
  );
  Future<InvoiceImportResult> importInvoice(InvoiceImportDocument document);

  Future<List<ImportBatch>> loadImportBatches();
}

/// The queue of things needing a decision, and the rules that shrink it.
abstract interface class ReviewRepository {
  Future<List<ReviewItem>> loadReviewQueue();

  /// [status] is `resolved` when the entry was handled and `dismissed` when the
  /// person decided it needed no change.
  Future<void> settleReview(String id, {required String status});

  Future<List<MerchantRule>> loadMerchantRules();
  Future<void> saveMerchantRule(MerchantRuleDraft draft);
  Future<void> deleteMerchantRule(String id);
}

abstract interface class ShortcutTokenRepository {
  Future<List<ShortcutToken>> loadShortcutTokens();

  /// Issues a token. The secret comes back once and is never stored in full.
  Future<IssuedShortcutToken> createShortcutToken(String name);

  Future<void> revokeShortcutToken(String id);
}

abstract interface class ReceiptStorage {
  /// Stores a receipt image and returns its object path.
  ///
  /// Uploading before the transaction is written is deliberate: the row can
  /// then carry the path in the same insert, instead of depending on a second
  /// call that could fail after the transaction already exists.
  Future<String> uploadReceipt({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  });

  /// A short-lived URL for viewing a stored receipt. The bucket is private, so
  /// there is no permanent address to hand out.
  Future<String> receiptUrl(String path);

  Future<void> deleteReceipt(String path);
}

/// Everything at once.
///
/// The two implementations satisfy all six contracts, and start-up registers
/// one object under each. This alias exists so composition can name that
/// object without listing the six every time; nothing consumes it.
abstract interface class FinanceRepository
    implements
        TransactionRepository,
        CatalogRepository,
        InvoiceRepository,
        ReviewRepository,
        ShortcutTokenRepository,
        ReceiptStorage {}
