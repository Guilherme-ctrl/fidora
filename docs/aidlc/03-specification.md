# AIDLC — Specification

## MVP acceptance criteria

### Capture

- Given a valid Shortcut token, known card final, valid category, merchant and positive amount, one confirmed transaction is created.
- The transaction is associated with the correct invoice competence from the card closing day.
- Repeating the same request does not create a second transaction.
- Invalid or revoked tokens cannot write data.

### History

- Transactions are sorted newest-first.
- Search matches merchant and category.
- Card final, category, amount, date, installment and review state are visible.

### Dashboard

- Shows period spend, invoice total, pending reviews and savings indicator.
- Shows trend, category allocation and recent transactions.
- Excludes transactions marked ignored from totals.

### Categories

- Lists the categories represented by the spreadsheet configuration.
- Shows current spend against optional monthly budget.

### Cards and invoices

- Shows limit, closing day, due day and last four digits.
- Shows invoice competence, due date, total and status.
- Supports one-time, installment and recurring modalities in the data model.

### Operational parity

- Schema represents merchant rules, imports, reviews, holders and goals.
- Statement imports retain filename/hash and counts.
- Ownership policies isolate every user's data.
- JSON statements use contract `1.0`, validate signed totals and show a preview before writing.
- Every statement item must be explicitly validated; safe items can be bulk-validated.
- Item review can change category, subcategory and movement type or exclude the item from personal totals.
- Unknown JSON categories trigger a confirmation prompt and are created atomically with the import; canceling the import creates nothing.
- Excluded personal items remain in the immutable statement audit trail but do not affect dashboards or goals.
- Reimporting the same `request_id` is idempotent.
- Statement rows reconcile with matching Shortcut captures instead of creating duplicates.
- Card refunds and credits reduce invoice/category spending; statement payments remain auditable but excluded.

## Deferred from first vertical slice

- UI authentication and account recovery.
- Real PDF/XLSX statement parser.
- CRUD forms beyond the capture demonstration.
- Spreadsheet migration command.
- Receipt OCR and attachment upload.
- App Intent implemented natively in Swift.
