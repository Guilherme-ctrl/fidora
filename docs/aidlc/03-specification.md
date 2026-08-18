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

### Manual entry — write path

- The repository contract exposes create, update and delete for transactions.
- A draft is rejected before any write when the merchant is blank, the amount is
  not a positive number, no category is chosen, or the installment fields are
  incoherent (only one of the pair supplied, fewer than two instalments, or a
  current instalment past the total).
- Validation reports one message per field so a form can bind them directly.
- A card purchase resolves its invoice competence from the card closing day and
  is attached to that competence's invoice, creating the invoice only when it
  does not yet exist; an invoice already closed or paid is never reopened.
- An account, Pix or debit movement is stored without a card, without an invoice
  and with the competence set to its own month.
- Manual rows carry `source = 'manual'` and a dedup key that is unique per row,
  so two identical purchases on the same day are both kept.
- Editing replaces the existing row rather than creating a second one.
- Write failures surface a message written for the person using the app, never a
  raw database error.
- Pulling down on any of the six tabs reloads the snapshot, and the indicator
  stays visible until the new data has arrived.

### Manual entry — form

- A create/edit form is reachable from every screen width: an action button
  below 900px, header buttons at 900px and above, never both at once.
- Amounts accept `24,80`, `1.234,56`, `24.80` and `R$ 1.999,90`, and are read
  the same way as the Shortcut reads them.
- Each invalid field reports its own message; the form stays open and keeps
  what was typed when a write fails.
- Choosing a card states which invoice the purchase will land on and which
  closing day produced that answer, before the transaction is saved.
- Marking a movement as income hides the payment method, because income is
  defined as a credit with no card.
- A history row can be edited or deleted; deleting asks for confirmation and
  names the transaction being removed.

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

- Account recovery.
- Real PDF/XLSX statement parser.
- CRUD **forms**. The transaction write path exists in the repository contract
  and is covered by tests, but no screen calls it yet; card, category, goal and
  holder writes are not started.
- Spreadsheet migration command.
- Receipt OCR and attachment upload.
- App Intent implemented natively in Swift.
