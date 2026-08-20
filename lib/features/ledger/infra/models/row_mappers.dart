/// Postgres rows, turned into entities.
///
/// These were `fromJson` factories on the entities themselves, which meant the
/// rules layer knew the column names of the database — `card_id`,
/// `credit_limit`, `reference_month`, `paid_at`. Renaming a column in a
/// migration was a change to the domain.
///
/// Functions rather than factories, on purpose: an entity that has no
/// constructor taking a row cannot be built from one by accident.
library;

import 'package:financeiro_ai/features/review/domain/merchant_rule.dart';
import 'package:financeiro_ai/features/ledger/domain/entities/models.dart';
import 'package:financeiro_ai/features/review/domain/review_item.dart';
import 'package:financeiro_ai/features/settings/domain/shortcut_token.dart';


DateTime parseReferenceMonth(String value) {
  // PostgreSQL `date` values arrive as YYYY-MM-DD. Keeping support for the
  // earlier YYYY-MM contract makes cached/demo payloads safe as well.
  final normalized = RegExp(r'^\d{4}-\d{2}$').hasMatch(value)
      ? '$value-01'
      : value;
  return DateTime.parse(normalized);
}

FinanceTransaction transactionFromRow(Map<String, dynamic> json) =>
    FinanceTransaction(
      id: json['id'] as String,
      date: DateTime.parse(json['purchased_at'] as String).toLocal(),
      merchant:
          (json['merchant_normalized'] ?? json['merchant_original'])
              as String,
      amount: (json['amount'] as num).toDouble(),
      category: (json['categories']?['name'] ?? 'Sem categoria') as String,
      cardLastFour: (json['cards']?['last_four'] ?? '----') as String,
      competence: json['competence'] == null
          ? null
          : DateTime.parse(json['competence'] as String),
      movementType: (json['movement_type'] ?? 'purchase') as String,
      rawModality: json['raw_modality'] as String?,
      installmentCurrent: json['installment_current'] as int?,
      installmentTotal: json['installment_total'] as int?,
      source: (json['source'] ?? 'manual') as String,
      holderId: json['holder_id'] as String?,
      personalAmount: (json['personal_amount'] as num?)?.toDouble(),
      accountId: json['account_id'] as String?,
      receiptPath: json['receipt_path'] as String?,
      sourceFile: json['source_file'] as String?,
      confidence: json['confidence'] as String?,
      dedupKey: json['dedup_key'] as String?,
      status: switch (json['status']) {
        'pending' => TransactionStatus.pending,
        'ignored' => TransactionStatus.ignored,
        _ => TransactionStatus.confirmed,
      },
    );

CreditCard cardFromRow(Map<String, dynamic> json) => CreditCard(
  id: json['id'] as String,
  name: json['name'] as String,
  bank: json['bank'] as String,
  lastFour: json['last_four'] as String,
  limit: (json['credit_limit'] as num?)?.toDouble() ?? 0,
  closingDay: json['closing_day'] as int,
  dueDay: json['due_day'] as int,
  holder: (json['holder_name'] ?? '') as String,
  holderId: json['holder_id'] as String?,
  includeInTotals: (json['include_in_totals'] ?? true) as bool,
);

Invoice invoiceFromRow(Map<String, dynamic> json) => Invoice(
  id: json['id'] as String,
  cardId: json['card_id'] as String,
  referenceMonth: parseReferenceMonth(json['reference_month'] as String),
  total: (json['total'] as num).toDouble(),
  dueDate: DateTime.parse(json['due_date'] as String),
  status: json['status'] as String,
  paidAt: json['paid_at'] == null
      ? null
      : DateTime.parse(json['paid_at'] as String).toLocal(),
);

Goal goalFromRow(Map<String, dynamic> json) => Goal(
  id: json['id'] as String,
  name: json['name'] as String,
  current: (json['current_amount'] as num).toDouble(),
  target: (json['target_amount'] as num).toDouble(),
  targetDate: json['target_date'] == null
      ? null
      : DateTime.parse(json['target_date'] as String),
);

ImportBatch importBatchFromRow(Map<String, dynamic> json) => ImportBatch(
  id: json['id'] as String,
  fileName: json['file_name'] as String,
  createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
  rowsRead: (json['rows_read'] as num?)?.toInt() ?? 0,
  rowsCreated: (json['rows_created'] as num?)?.toInt() ?? 0,
  rowsUpdated: (json['rows_updated'] as num?)?.toInt() ?? 0,
  rowsDuplicated: (json['rows_duplicated'] as num?)?.toInt() ?? 0,
  rowsToReview: (json['rows_to_review'] as num?)?.toInt() ?? 0,
);

Account accountFromRow(Map<String, dynamic> json) => Account(
  id: json['id'] as String,
  name: json['name'] as String,
  bank: (json['bank'] ?? '') as String,
  type: (json['account_type'] ?? 'checking') as String,
  openingBalance: (json['opening_balance'] as num?)?.toDouble() ?? 0,
  includeInTotals: (json['include_in_totals'] ?? true) as bool,
);

Holder holderFromRow(Map<String, dynamic> json) => Holder(
  id: json['id'] as String,
  name: json['name'] as String,
  includeInTotals: (json['include_in_totals'] ?? true) as bool,
);

ReviewItem reviewItemFromRow(Map<String, dynamic> json) => ReviewItem(
  id: json['id'] as String,
  reason: (json['reason'] ?? 'Revisão pendente') as String,
  status: (json['status'] ?? 'pending') as String,
  transactionId: json['transaction_id'] as String?,
  itemType: json['item_type'] as String?,
  description: json['description'] as String?,
  suggestedAction: json['suggested_action'] as String?,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String).toLocal(),
);

ShortcutToken shortcutTokenFromRow(Map<String, dynamic> json) => ShortcutToken(
  id: json['id'] as String,
  name: json['name'] as String,
  createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
  lastUsedAt: json['last_used_at'] == null
      ? null
      : DateTime.parse(json['last_used_at'] as String).toLocal(),
  revokedAt: json['revoked_at'] == null
      ? null
      : DateTime.parse(json['revoked_at'] as String).toLocal(),
);

MerchantRule merchantRuleFromRow(Map<String, dynamic> json) => MerchantRule(
  id: json['id'] as String,
  pattern: json['pattern'] as String,
  categoryId: json['category_id'] as String,
  categoryName: (json['categories']?['name'] ?? 'Sem categoria') as String,
  subcategory: json['subcategory'] as String?,
  priority: (json['priority'] as num?)?.toInt() ?? 100,
  active: (json['active'] ?? true) as bool,
);
