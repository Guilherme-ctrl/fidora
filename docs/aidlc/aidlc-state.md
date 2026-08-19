# AIDLC — Stage state

Workflow state for the current change. Artifacts live in `docs/aidlc/`; the
application code lives at the workspace root.

**Project type**: brownfield (existing Flutter + Supabase codebase)
**Current phase**: Construction
**Current unit**: `last-three-findings`

## Inception

| Stage | Status | Artifact |
|---|---|---|
| Workspace detection | Complete | Brownfield confirmed; reverse-engineering artifacts already present |
| Reverse engineering | Skipped | `docs/aidlc/00–04` already document the system |
| Requirements analysis | Complete | Published audit, 18 Aug 2026 — thirteen findings and a three-wave roadmap |
| User stories | Skipped | Single-owner product; acceptance criteria carried directly in `03-specification.md` |
| Workflow planning | Complete | Five-step sequence agreed with the owner; step 1 approved to start |
| Application design | Skipped | No new components; extends the existing repository contract |
| Units generation | Complete | Roadmap decomposed into five units; all five delivered |

## Construction — unit `write-path`

| Stage | Status | Notes |
|---|---|---|
| Functional design | Complete | Draft model, validation rules and competence resolution defined below |
| NFR requirements | Skipped | No new performance, security or scalability surface; RLS unchanged |
| NFR design | Skipped | NFR requirements skipped |
| Infrastructure design | Skipped | No schema migration and no new cloud resource |
| Code generation | Complete | See the checklist |

### Code generation checklist

- [x] `TransactionDraft` with per-field validation and `modality` derivation
- [x] `FinanceWriteException` carrying user-facing messages
- [x] `saveTransaction` and `deleteTransaction` on `FinanceRepository`
- [x] Supabase implementation: competence resolution, invoice reuse, error translation
- [x] Demo implementation: in-memory mutable ledger
- [x] `refreshFinanceSnapshot` helper that awaits the reload
- [x] Real `RefreshIndicator` in the shell, serving all six tabs
- [x] Remove the no-op `RefreshIndicator` from the dashboard
- [x] `AlwaysScrollableScrollPhysics` on all six page list views
- [x] 15 tests covering validation and the demo write path
- [x] Evidence recorded in `04-validation.md`

### Files changed

```text
lib/domain/transaction_draft.dart          new
lib/application/providers.dart             write methods + refresh helper
lib/data/supabase_finance_repository.dart  saveTransaction, deleteTransaction
lib/data/demo_finance_repository.dart      mutable ledger + writes
lib/presentation/app_shell.dart            RefreshIndicator
lib/presentation/pages/*.dart              scroll physics; dashboard no-op removed
test/transaction_draft_test.dart           new
```

### Design decisions taken in this unit

**Manual entries get their own dedup key.** The Edge Function derives
`dedup_key` from a SHA-256 of `date|last four|merchant|amount`, which is correct
for an automated sensor that may fire twice for one purchase. Applying it to
manual entry would silently swallow a second identical purchase on the same day.
Manual rows therefore use `manual:<uuid>`, keeping the unique constraint
satisfied without collapsing legitimate repeats.

**Existing invoices are reused, never upserted.** The Edge Function upserts the
invoice with `status: "open"`, which resets an invoice already closed or paid.
The client write selects first and inserts only when the competence has no
invoice, so adding a back-dated transaction cannot reopen a settled invoice.

**Reload after write, not optimistic mutation.** The snapshot is the single
source of truth and holds category and card names rather than ids, so an
optimistic local patch would have to duplicate the id-to-name mapping and would
drift from the database-side invoice-total trigger. Writes complete, then the
provider reloads.

## Construction — unit `transaction-form`

| Stage | Status | Notes |
|---|---|---|
| Functional design | Complete | Field set, income/expense split and competence hint defined below |
| NFR requirements | Skipped | No new performance, security or scalability surface |
| NFR design | Skipped | NFR requirements skipped |
| Infrastructure design | Skipped | No schema migration and no new cloud resource |
| Code generation | Complete | See the checklist |

### Code generation checklist

- [x] `parseAmountInput` mirroring the Edge Function's amount parsing
- [x] `showTransactionFormSheet` with create and edit modes
- [x] Per-field errors bound to `TransactionDraftErrors`
- [x] Income/expense segmented control; income hides the payment method
- [x] Invoice-competence hint while a card is selected
- [x] Floating action button in the shell below 900px
- [x] Header buttons re-gated to 900px so they no longer overlap it
- [x] Edit and delete on the history row, with confirmation for delete
- [x] Empty state on the history list
- [x] Shared `createTransaction` helper for both entry points
- [x] 14 tests (6 widget, 8 parser)

### Files changed

```text
lib/domain/amount_input.dart                        new
lib/presentation/widgets/transaction_form_sheet.dart new
lib/presentation/app_shell.dart                     FAB + createTransaction
lib/presentation/pages/transactions_page.dart       ConsumerStatefulWidget, edit/delete
lib/presentation/pages/dashboard_page.dart          ConsumerWidget, real form
lib/presentation/widgets/common.dart                longDate formatter
test/amount_input_test.dart                         new
test/transaction_form_test.dart                     new
```

### Design decisions taken in this unit

**The competence rule is shown while it can still be changed.** Selecting a card
reveals which invoice the purchase will land on and which closing day produced
that answer. The rule is the core concept of the product and was previously
invisible until after the transaction had been saved.

**One entry point per breakpoint.** The action button appears below 900px and
the pages' header buttons at 900px and above. Previously the header buttons cut
out between 540px and 600px depending on the page, leaving phones with no way to
create anything — the first finding of the audit.

**Income cannot carry a card.** `FinanceTransaction.isIncome` is defined as a
credit or refund with no card, so choosing Entrada hides the payment method
rather than letting the form produce a state the domain would not read back as
income.

## Construction — unit `review-and-rules`

| Stage | Status | Notes |
|---|---|---|
| Functional design | Complete | Queue actions and rule matching defined below |
| NFR requirements | Skipped | No new performance, security or scalability surface |
| NFR design | Skipped | NFR requirements skipped |
| Infrastructure design | Skipped | No schema migration; both tables already existed unused |
| Code generation | Complete | See the checklist |

### Code generation checklist

- [x] `ReviewItem` and `MerchantRule` / `MerchantRuleDraft` domain models
- [x] Repository contract: `loadReviewQueue`, `settleReview`, `loadMerchantRules`, `saveMerchantRule`, `deleteMerchantRule`
- [x] Supabase and demo implementations for all five
- [x] `reviewQueueProvider` and `merchantRulesProvider`, loaded on demand
- [x] Review queue screen with correct / accept / dismiss
- [x] Merchant rules screen with create, edit, delete and match preview
- [x] Both wired into the two placeholder tiles on the More screen
- [x] Empty, loading and error states on both screens
- [x] 18 tests

### Files changed

```text
lib/domain/review_item.dart                      new
lib/domain/merchant_rule.dart                    new
lib/presentation/pages/review_queue_page.dart    new
lib/presentation/pages/merchant_rules_page.dart  new
lib/application/providers.dart                   five methods + two providers
lib/data/supabase_finance_repository.dart        queue and rules
lib/data/demo_finance_repository.dart            mutable queue and rules
lib/presentation/pages/more_page.dart            tiles now navigate
test/review_and_rules_test.dart                  new
```

### Design decisions taken in this unit

**Correcting a review resolves it in the same gesture.** The queue reuses the
transaction form from the previous unit: if the edit is saved, the entry that
asked for it has been answered, so the review is settled in the same call rather
than leaving the person to mark it done afterwards.

**The queue and the rules load on their own, not inside the snapshot.** Both are
data most sessions never open. Keeping them out of `loadSnapshot` avoids making
the first paint wait on them and starts moving the codebase away from the single
monolithic query the audit flagged.

**The rule editor shows its blast radius.** Typing a pattern lists which existing
transactions it would match, before saving. A three-character minimum blocks the
patterns that would sweep up half the ledger.

**Deleting a rule does not touch past transactions.** The confirmation says so,
because the alternative — silently recategorizing history — is not something a
delete should ever do.

## Construction — unit `limit-and-comparison`

| Stage | Status | Notes |
|---|---|---|
| Functional design | Complete | Baseline selection and limit model defined below |
| NFR requirements | Skipped | Pure computation over data already in the snapshot |
| NFR design | Skipped | NFR requirements skipped |
| Infrastructure design | Skipped | No schema migration and no new query |
| Code generation | Complete | See the checklist |

### Code generation checklist

- [x] `FinancePeriod.previous` for months and for custom ranges
- [x] `comparePeriods` with per-category deltas ranked by movement
- [x] `trailingMonthlyAverage` skipping months with no movement
- [x] `cardUsage` with committed, available, tight and over states
- [x] Trend slot on `MetricCard`, neutral when there is no baseline
- [x] Month-over-month section on the dashboard with the biggest movers
- [x] Available limit and usage bar on the card face; breakdown in the detail
- [x] 20 tests

### Files changed

```text
lib/domain/comparison.dart                  new
lib/domain/analytics.dart                   FinancePeriod.previous
lib/presentation/widgets/common.dart        MetricCard trend slot
lib/presentation/pages/dashboard_page.dart  trend + month-over-month section
lib/presentation/pages/cards_page.dart      available limit and usage bar
test/comparison_test.dart                   new
```

### Design decisions taken in this unit

**No percentage change from zero.** When the previous period spent nothing,
`expenseRatio` and `CategoryDelta.ratio` return null and the interface says
“novo” or “sem base para comparar” instead of printing an invented figure. The
trend indicator goes neutral rather than green or red.

**The trailing average ignores empty months.** Averaging over three months when
only one had movement would divide by three and understate the baseline, so
months with no transactions are skipped and the mean is taken over the rest.
When none of them has movement the function returns null.

**Committed limit counts every invoice that is not paid.** An invoice that is
closed but unpaid still holds limit, so only `paid` releases it. Availability is
clamped at zero — a card past its limit reports zero available, never a negative
number.

**Cards without a registered limit are not judged.** `credit_limit` defaults to
zero in the schema, and treating that as “100% used” would paint a false alarm,
so those cards keep showing the limit field and no usage bar.

## Construction — unit `theme-and-accessibility`

| Stage | Status | Notes |
|---|---|---|
| Functional design | Complete | Palette contract and tooltip triage defined below |
| NFR requirements | Complete | Accessibility target: WCAG AA (4.5:1) for all body and caption text |
| NFR design | Complete | Solid secondary-text tokens per surface, verified by test |
| Infrastructure design | Skipped | No schema migration and no new cloud resource |
| Code generation | Complete | See the checklist |

### Code generation checklist

- [x] `FinoraPalette` theme extension with complete light and dark values
- [x] `context.palette` accessor
- [x] `buildAppTheme(brightness:)` producing both themes from one definition
- [x] `darkTheme` and `themeMode: system` on `MaterialApp`
- [x] 45 translucent-ink call sites replaced with solid tokens
- [x] ~170 named-colour references migrated to the palette
- [x] Hardcoded `Colors.white` on the two new app bars removed
- [x] 19 of 30 tooltips retired: whole-card wrappers to `Semantics`, icon-only controls to the `tooltip:` parameter
- [x] Three fixed heights now scale with `textScalerOf`
- [x] 17 tests, including a contrast assertion per token per theme

### Files changed

```text
lib/core/theme.dart                     rewritten: palette + both themes
lib/main.dart                           darkTheme + themeMode
lib/presentation/**/*.dart              palette migration, Semantics, scaling
lib/data/*_finance_repository.dart      category seeds kept theme-independent
test/theme_test.dart                    new
```

### Design decisions taken in this unit

**Secondary text is solid, not translucent.** `ink` at 50–58% opacity measured
3.2:1 and 4.0:1 against the page, below the 4.5:1 AA needs — and it was used on
11–12px captions. `inkMuted` and `inkSubtle` are solid values chosen to clear
the bar on both the page and the card surface, in both themes. The test suite
asserts the ratios so a future palette edit cannot quietly reintroduce the bug.

**Category colours stay theme-independent.** The demo and Supabase repositories
seed category colours as *data*; a category should not change colour when the
system switches to dark. Those call sites kept the fixed brand constants.

**Tooltips were triaged, not deleted.** A tooltip wrapping an entire card only
appears on long-press in touch, where it also competes with the gesture — those
19 became `Semantics` labels. Icon-only controls moved to Material's `tooltip:`
parameter, which feeds both the tooltip and the semantics tree. The 11 that
remain sit on controls where the hint is genuinely non-obvious, such as the
chip explaining that card purchases are counted by invoice competence.

**Fixed heights scale with the text scaler.** The card face and the two charts
keep a bounded height because their inner `Spacer`s require one, but the bound
now multiplies by the user's text scale, clamped so a very large setting cannot
push a chart off the screen.

## Construction — unit `audit-followups`

Closing the defects the five planned units did not cover, taken in the order of
user harm used by the audit.

| Stage | Status | Notes |
|---|---|---|
| Functional design | Complete | Derived invoice state and error taxonomy defined below |
| NFR requirements | Complete | History list must not lay out the whole ledger per keystroke |
| NFR design | Complete | Sliver recycling plus a 250 ms filter debounce |
| Infrastructure design | Skipped | No schema migration |
| Code generation | Complete | See the checklist |

### Code generation checklist

- [x] `invoiceState` deriving all four states, with `overdue` from the due date
- [x] Cards screen showing the four states with distinct colour, icon and label
- [x] Raw database status no longer shown to the person
- [x] `LoadFailure` translating load errors, with the raw text behind a disclosure
- [x] Trend chart plotted against the calendar instead of days-with-movement
- [x] Trend chart axis labels restored on both axes
- [x] History list converted to a recycling sliver list
- [x] Search debounced at 250 ms
- [x] 13 tests

### Files changed

```text
lib/domain/invoice_status.dart              new
lib/domain/load_failure.dart                new
lib/presentation/pages/cards_page.dart      four invoice states
lib/presentation/app_shell.dart             translated load error
lib/presentation/pages/dashboard_page.dart  calendar axis + labels
lib/presentation/pages/transactions_page.dart slivers + debounce
lib/presentation/widgets/common.dart        compact currency for axis labels
test/invoice_status_test.dart               new
```

### Design decisions taken in this unit

**Overdue is derived, not read.** The column exists but nothing writes it: no
job moves an invoice to `overdue`, so an unpaid one sits at `open` or `closed`
past its due date forever. The state shown is computed from the due date, with
`paid` always winning. The due date itself is not yet overdue.

**The calendar is the x axis.** Indexing by the days that happened to have
movement collapsed the gaps, drawing a purchase on the 3rd next to one on the
28th. The chart is named after pace, and the spacing between purchases was
exactly the information it was hiding. Days with no movement are now plotted at
zero, and the card reports "N de M dias" rather than only the days that moved.

**A test found a real ordering bug.** `Connection timed out` matched the
connection branch before reaching the timeout branch, so every timeout was
reported as "no connection". The specific diagnosis now runs first.

## Construction — unit `rules-at-capture`

| Stage | Status | Notes |
|---|---|---|
| Functional design | Complete | Resolution order and the no-loss rule below |
| NFR requirements | Complete | A capture must never be lost because a category could not be resolved |
| NFR design | Complete | Rule lookup joins the existing parallel query; one extra lookup only on fallback |
| Infrastructure design | Skipped | No schema migration; the tables and columns already existed |
| Code generation | Complete | See the checklist |

### Code generation checklist

- [x] `rules.ts` with `foldAccents`, `normalizeMerchant`, `matchesPattern`, `selectRule`, `decideCategory`
- [x] Handler resolves category: explicit choice, then rules, then a flagged fallback
- [x] `category_not_found` no longer rejects the capture
- [x] Unresolved captures create a `review_queue` row, feeding the screen built earlier
- [x] Provenance written to `transactions.notes`
- [x] Response reports `category_source` and `needs_review`
- [x] Dart `normalizeMerchant` folds accents, matching the function
- [x] `MerchantRule.matches` mirrors `matchesPattern`, so the preview and the capture agree
- [x] Rules screen states when rules apply and that an explicit choice wins
- [x] 12 Deno tests, 5 Dart tests

### Design decisions taken in this unit

**An explicit choice always wins over a rule.** The Shortcut asks the person to
pick a category at the moment of payment; a learned rule should not overrule a
deliberate decision made seconds earlier. Rules answer the case where nothing
was chosen, or where the chosen name no longer exists.

**A capture is never lost.** The function used to return 404 when the category
did not resolve, which threw the transaction away at the till — the one moment
the person cannot retry. It is now recorded with the fallback category, marked
low confidence, and queued for review. Filing something in the wrong place is
recoverable; losing it is not.

**Preview and capture share one matching rule.** The screen tells the person how
many existing transactions a pattern would catch. If the two sides matched
differently that number would be a promise the capture path does not keep, so
both fold accents, ignore case and refuse patterns under three characters.

**The accent divergence is closed.** Dart kept accents while the function
stripped them, so the same merchant normalized two ways depending on the
ingestion path. Dart now folds too. This is safe for deduplication because
manual entries key on `manual:<uuid>` rather than a content hash, so no existing
key changes meaning.

## Construction — unit `last-three-findings`

Closes the three audit findings still open after the rules unit.

### Code generation checklist

- [x] One period control in the shell; removed from the three pages that repeated it
- [x] Cards screen honours the period for its invoice list, with an empty state
- [x] Card availability deliberately **not** period-filtered — it is current state
- [x] Previous snapshot stays on screen during a reload; skeleton only on first load
- [x] `analyzePeriod` memoized on (snapshot identity, period); `FinancePeriod` gained value equality
- [x] Six destinations reduced to five; Projeção moved behind "Mais"
- [x] Currency resolved from `profiles.currency`, joining the existing parallel batch
- [x] 10 tests

### Design decisions taken in this unit

**Availability ignores the period on purpose.** Every unpaid invoice holds
limit regardless of which month is being viewed, so filtering it would print a
wrong number. Only the invoice list follows the period.

**The reload no longer blanks the app.** Because every write invalidates the
provider, the previous `state.when(loading:)` sent the whole app back to a
spinner after each saved transaction — a regression this work introduced in the
first unit. The last snapshot now stays put behind a thin progress bar.

**Projeção moved rather than merged.** Five is the Material maximum and the
sixth destination was crowding a 360pt bar. Projeção is derived data consulted
occasionally, which is what the overflow destination is for.

**The currency formatter is a mutable top-level.** Threading it through roughly
forty call sites would have cost more than it returns for a value fixed per
account and settled before the first frame. `configureCurrency` is idempotent
and called from the shell. A first attempt passed `name:` to `NumberFormat`,
which overrides the symbol — the whole app would have printed `BRL 1.234,50`
instead of `R$ 1.234,50`. A test caught it before it shipped.

## Scope

Finora is **online only** by the owner's decision of 18 August 2026. Local
caching and offline state are out of scope; connectivity may be assumed.

## Carried forward

- The history list still builds every row eagerly and the search has no
  debounce; both remain as recorded in the audit.
- Offering “create a rule for this merchant” right after a manual
  recategorization — the moment the intent is clearest — is designed for but
  not built. `editRule` already accepts a `suggestedPattern` for it.
- Password recovery and the real-device Shortcut test remain open gates from
  `04-validation.md`.

## Inception — unidade `ui-remake`

| Stage | Status | Notas |
|---|---|---|
| Requirements analysis | Completo | Sete documentos em `docs/design/`; 16 achados de auditoria priorizados |
| User stories | Pulado | Produto de um dono; critérios de aceite ficam no roadmap |
| Workflow planning | Completo | Cinco ondas em `docs/design/06-roadmap.md` |
| Application design | Pendente de aprovação | Direção visual no protótipo; nenhuma linha de Dart escrita |

### Artefatos

```text
docs/design/README.md                 índice e método
docs/design/00-market-and-bench.md    mercado, benchmark internacional e Brasil
docs/design/01-growth.md              funil, vazamentos, loops e métricas
docs/design/02-ux-audit.md            16 achados com arquivo e linha
docs/design/03-design-system.md       design system "Ledger": tokens e componentes
docs/design/04-ia-flows.md            quatro espaços, telas e estados
docs/design/05-naming.md              diagnóstico de "Finora" e alternativas
docs/design/06-roadmap.md             cinco ondas com critério de pronto
docs/design/prototipo/index.html      protótipo navegável (web + mobile)
```

### Decisões de design tomadas nesta unidade

**Saída deixa de ser vermelha.** Em 95% das linhas de um app de finanças pessoais
o lançamento é uma saída. Vermelho em todas destrói a hierarquia e vira ruído.
Vermelho passa a significar problema — saldo negativo, orçamento estourado, falha
de importação — e a saída comum é tinta com sinal `−`.

**A paleta atual é preservada, não substituída.** `FinoraPalette` já resolveu o
contraste do texto secundário com valores sólidos acima de 4.5:1. O trabalho é
organizar aqueles valores em rampas e acrescentar semântica de dinheiro, não
recomeçar.

**Web e mobile compartilham tokens e domínio, não layout.** É a raiz do problema
descrito pelo dono: hoje compartilham o shell.

**O nome fica para depois da direção visual.** Nome deve caber no visual, não o
contrário.
