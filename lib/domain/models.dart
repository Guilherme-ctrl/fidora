import 'package:clock/clock.dart';

enum TransactionStatus { confirmed, pending, ignored }

class FinanceTransaction {
  const FinanceTransaction({
    required this.id,
    required this.date,
    required this.merchant,
    required this.amount,
    required this.category,
    required this.cardLastFour,
    this.competence,
    this.movementType = 'purchase',
    this.rawModality,
    this.installmentCurrent,
    this.installmentTotal,
    this.status = TransactionStatus.confirmed,
    this.source = 'manual',
    this.holderId,
    this.personalAmount,
    this.accountId,
    this.receiptPath,
    this.sourceFile,
    this.confidence,
    this.dedupKey,
  });
  final String id;
  final DateTime date;
  final String merchant;
  final double amount;
  final String category;
  final String cardLastFour;
  final DateTime? competence;
  final String movementType;
  final String? rawModality;
  final int? installmentCurrent;
  final int? installmentTotal;
  final TransactionStatus status;
  final String source;

  /// Who this charge belongs to, when it is not you. Set per transaction by
  /// the invoice import, which reads it from the statement's notes; more
  /// precise than the card's holder, because one card can carry both.
  final String? holderId;

  /// Your share of [amount]. Null means all of it.
  final double? personalAmount;

  /// Where the money moved, when it was not a card.
  final String? accountId;

  /// Object path of the attached receipt in the private `receipts`
  /// bucket. Only the path is stored: the image itself would bloat every
  /// snapshot load, and the ledger is read in full on each one.
  final String? receiptPath;

  /// Where this row came from, kept so a number can always be traced back.
  ///
  /// All three columns have existed since the first migration and the query
  /// already asks for them with `select('*')` — they were simply never mapped,
  /// so the app held the lineage and could not show it.

  /// The statement or invoice file an import read this from.
  final String? sourceFile;

  /// How sure the classifier was: `high`, `medium` or `low`.
  final String? confidence;

  /// What makes a repeated capture the same purchase. A Shortcut capture and a
  /// statement row that share one are the same charge, not two.
  final String? dedupKey;

  bool get hasReceipt => receiptPath != null;

  /// Whether anything is known about where this came from beyond [source].
  bool get hasLineage =>
      sourceFile != null || confidence != null || dedupKey != null;

  /// What counts as yours. The full [amount] stays the audited figure.
  double get personalShare => personalAmount ?? amount;

  bool get isShared => personalAmount != null && personalAmount! < amount;
  bool get isInstallment => installmentTotal != null && installmentTotal! > 1;
  bool get isCard => cardLastFour != '----';
  bool get isCardAdjustment =>
      isCard && (movementType == 'credit' || movementType == 'refund');
  bool get isIncome =>
      !isCard && (movementType == 'credit' || movementType == 'refund');
  double get expenseImpact {
    if (movementType == 'transfer' || isIncome) return 0;
    if (isCardAdjustment) return -personalShare;
    return personalShare;
  }

  bool get affectsExpenses => expenseImpact != 0;

}

class FinanceCategory {
  const FinanceCategory({
    required this.id,
    required this.name,
    required this.iconName,
    required this.colorHex,
    this.monthlyBudget,
  });
  final String id;
  final String name;

  /// The stored icon key, exactly as `categories.icon` holds it.
  ///
  /// A name rather than an `IconData`, and a hex string rather than a `Color`,
  /// because those are Flutter types and this is the rules layer. Two fields
  /// were enough to make the whole domain depend on the framework — and to
  /// force `lib/data` to import Material just to build a category.
  ///
  /// `presentation/category_visuals.dart` resolves both.
  final String iconName;

  /// `#RRGGBB`, as `categories.color` holds it.
  final String colorHex;

  final double? monthlyBudget;
}

class CreditCard {
  const CreditCard({
    required this.id,
    required this.name,
    required this.bank,
    required this.lastFour,
    required this.limit,
    required this.closingDay,
    required this.dueDay,
    required this.holder,
    this.holderId,
    this.includeInTotals = true,
  });
  final String id;
  final String name;
  final String bank;
  final String lastFour;
  final double limit;
  final int closingDay;
  final int dueDay;
  final String holder;
  final String? holderId;

  /// Whether this card's spending is your own. A card can also be excluded by
  /// its holder — see `cardCountsInTotals`.
  final bool includeInTotals;

}

class Invoice {
  const Invoice({
    required this.id,
    required this.cardId,
    required this.referenceMonth,
    required this.total,
    required this.dueDate,
    required this.status,
    this.paidAt,
  });
  final String id;
  final String cardId;
  final DateTime referenceMonth;
  final double total;
  final DateTime dueDate;
  final String status;

  /// When the invoice was settled; null while it is not.
  final DateTime? paidAt;

}


class Goal {
  const Goal({
    required this.id,
    required this.name,
    required this.current,
    required this.target,
    this.targetDate,
  });
  final String id;
  final String name;
  final double current;
  final double target;

  /// `goals.target_date` has existed since the first migration and never
  /// reached the app. Without a date, a goal is a number with no deadline.
  final DateTime? targetDate;

  double get progress => target == 0 ? 0 : (current / target).clamp(0, 1);
  double get remaining =>
      (target - current).clamp(0, double.infinity).toDouble();

  int? get daysLeft => targetDate?.difference(clock.now()).inDays;

  bool get isLate => (daysLeft ?? 1) < 0 && progress < 1;

}

/// One statement import: what came in, and what it produced.
class ImportBatch {
  const ImportBatch({
    required this.id,
    required this.fileName,
    required this.createdAt,
    this.rowsRead = 0,
    this.rowsCreated = 0,
    this.rowsUpdated = 0,
    this.rowsDuplicated = 0,
    this.rowsToReview = 0,
  });

  final String id;
  final String fileName;
  final DateTime createdAt;
  final int rowsRead;
  final int rowsCreated;
  final int rowsUpdated;
  final int rowsDuplicated;
  final int rowsToReview;

}

/// A place money sits: checking, savings, a wallet.
///
/// `accounts` and `transactions.account_id` have been in the schema since the
/// spreadsheet migration and had no code at all, so anything that was not a
/// card showed as the literal "----".
class Account {
  const Account({
    required this.id,
    required this.name,
    this.bank = '',
    this.type = 'checking',
    this.openingBalance = 0,
    this.includeInTotals = true,
  });

  final String id;
  final String name;
  final String bank;
  final String type;

  /// What the account held before the first recorded transaction.
  final double openingBalance;
  final bool includeInTotals;

  String get typeLabel => switch (type) {
    'savings' => 'Poupança',
    'wallet' => 'Carteira',
    'investment' => 'Investimento',
    _ => 'Conta corrente',
  };

}

/// A person whose card spending may or may not belong to your own finances.
class Holder {
  const Holder({
    required this.id,
    required this.name,
    this.includeInTotals = true,
  });
  final String id;
  final String name;
  final bool includeInTotals;

}

/// The parts of the ledger that change rarely.
///
/// Split from [FinanceLedger] so saving a transaction does not refetch every
/// card, category, holder and account. They are edited from their own screens,
/// a handful of times ever; the ledger changes on every capture.
class FinanceCatalog {
  const FinanceCatalog({
    required this.categories,
    required this.cards,
    required this.goals,
    this.holders = const [],
    this.accounts = const [],
    this.currencyCode = 'BRL',
  });

  final List<FinanceCategory> categories;
  final List<CreditCard> cards;
  final List<Goal> goals;
  final List<Holder> holders;
  final List<Account> accounts;
  final String currencyCode;
}

/// The parts that change on every write.
class FinanceLedger {
  const FinanceLedger({
    required this.transactions,
    required this.invoices,
    required this.pendingReviews,
    this.truncated = false,
  });

  final List<FinanceTransaction> transactions;
  final List<Invoice> invoices;
  final int pendingReviews;

  /// Whether the ledger was cut short of what the account holds.
  ///
  /// The loader used to stop at a fixed two thousand rows and say nothing, so
  /// every total, average and insight past that point was computed on a partial
  /// history and simply wrong, with nothing on screen to suggest it. It now
  /// pages through everything; this flag exists so that if a hard ceiling is
  /// ever reached, the screen can say so instead of quietly lying.
  final bool truncated;
}

class FinanceSnapshot {
  /// Assembles the view model the screens read from its two halves.
  factory FinanceSnapshot.compose({
    required FinanceCatalog catalog,
    required FinanceLedger ledger,
  }) => FinanceSnapshot(
    transactions: ledger.transactions,
    invoices: ledger.invoices,
    pendingReviews: ledger.pendingReviews,
    truncated: ledger.truncated,
    categories: catalog.categories,
    cards: catalog.cards,
    goals: catalog.goals,
    holders: catalog.holders,
    accounts: catalog.accounts,
    currencyCode: catalog.currencyCode,
  );

  const FinanceSnapshot({
    required this.transactions,
    required this.categories,
    required this.cards,
    required this.invoices,
    required this.goals,
    required this.pendingReviews,
    this.holders = const [],
    this.accounts = const [],
    this.currencyCode = 'BRL',
    this.truncated = false,
  });
  final List<FinanceTransaction> transactions;
  final List<FinanceCategory> categories;
  final List<CreditCard> cards;
  final List<Invoice> invoices;
  final List<Goal> goals;
  final List<Holder> holders;
  final List<Account> accounts;
  final int pendingReviews;

  /// From `profiles.currency`; drives the money formatter.
  final String currencyCode;

  /// See [FinanceLedger.truncated].
  final bool truncated;

  double get monthSpend => transactions
      .where((item) => item.status != TransactionStatus.ignored)
      .fold(0, (sum, item) => sum + item.expenseImpact);
  Map<String, double> get spendByCategory {
    final values = <String, double>{};
    for (final item in transactions) {
      if (item.status == TransactionStatus.ignored) continue;
      values.update(
        item.category,
        (value) => value + item.expenseImpact,
        ifAbsent: () => item.expenseImpact,
      );
    }
    return values;
  }
}
