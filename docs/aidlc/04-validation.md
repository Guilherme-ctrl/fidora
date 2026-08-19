# AIDLC — Validation evidence

This file is updated by the build workflow. A gate passes only with reproducible commands and recorded outcomes.

## Evidence — 17 August 2026

| Gate | Evidence | Result |
|---|---|---|
| Static quality | `flutter analyze` | Pass — no issues |
| Domain rules | `flutter test` | Pass — 12 tests |
| Web compilation | `flutter build web --release` | Pass |
| iOS compilation | `flutter build ios --simulator --debug` | Pass — `Runner.app` |
| Desktop visual QA | 1440 × 900 local build | Pass — dashboard hierarchy and navigation verified |
| Mobile visual QA | 390 × 844 local build | Pass — dashboard and cards/invoices verified |
| Browser runtime | Console warnings/errors | Pass — none observed |
| Database migrations | `supabase db reset` | Pass — schema and API grants migrations applied |
| Database quality | `supabase db lint --local --level warning` | Pass — no schema errors |
| Shortcut authentication | Local Edge Function request with an invalid token | Pass — HTTP 401 |
| Shortcut capture | Local Edge Function request with a valid token | Pass — transaction inserted |
| Capture idempotency | Repeat the same `request_id` twice | Pass — one ledger row; second response marked duplicate |
| Invoice rules | Purchase on 3 August with closing day 2 | Pass — competence 1 September and invoice total R$ 24.80 |
| Remote migrations | `supabase db push --linked` | Pass — versions `202608170001` through `202608170003` applied |
| Remote Edge deployment | `supabase functions deploy capture-transaction` | Pass — deployed to Finora |
| Remote Edge security | Request with an invalid Shortcut token | Pass — HTTP 401 with `invalid_token` |
| Production web build | `flutter build web --release --dart-define-from-file=config/finora.production.json` | Pass |
| Authentication visual QA | Production build at desktop and 390 × 844 | Pass — login layout responsive; no browser warnings/errors |
| Remote database quality | `supabase db lint --linked --level warning` | Pass — no schema errors |
| Production iOS build | `flutter build ios --simulator --debug --dart-define-from-file=config/finora.production.json` | Pass — `Runner.app` |
| Sheet inventory | Bounded reads from all 11 tabs | Pass — 847 transactions and all supporting entities mapped |
| Local import contract | Stage payload and create matching local Auth user | Pass — payload claimed atomically |
| Import reconciliation | Database counts versus source sheet | Pass — 847 transactions, 9 cards, 10 invoices, 31 installments, 13 imports, 46 reviews and 22 rules |
| Import totals | Considered transactions versus source | Pass — 804 rows totaling R$ 114,049.28; 43 ignored rows preserved |
| Import payload security | Public-key request to remote staging table | Pass — HTTP 401 |
| Remote import staging | Service-role upload without repository data file | Pass — payload staged and awaiting the matching Auth user |
| Supabase invoice date regression | `Invoice.fromJson` with `reference_month=2026-08-01` | Pass — parsed as 1 August 2026 |
| Period analytics | Unit tests for month boundaries, ignored rows, income, expenses and custom end date | Pass |
| Full history query | Supabase repository limit | Pass — raised from 100 to 2,000 rows for the current 847-row ledger |
| Interactive dashboard QA | Desktop production build | Pass — period controls, metrics, charts, budgets and drill-down verified |
| Projection QA | Desktop production build | Pass — six-month chart and composition modal verified |
| Responsive analytics QA | 390 × 844 production build | Pass — six destinations, filters and metric cards fit without runtime errors |
| Analytics browser runtime | Console warnings/errors | Pass — none observed |
| Updated production web build | `flutter build web --release --dart-define-from-file=config/finora.production.json` | Pass |
| Updated production iOS build | `flutter build ios --simulator --debug --dart-define-from-file=config/finora.production.json` | Pass |
| Card competence analytics | Remote August reconciliation | Pass — 83 card entries totaling R$ 5,667.37 by invoice competence, versus 2 by purchase date |
| Hybrid period rule | `flutter test` | Pass — card entries use invoice competence; account, Pix and debit entries use movement date |
| JSON contract | 15 automated tests with sanitized fixtures | Pass — balanced invoices accepted; mismatched totals, duplicate external IDs, per-item dispositions and category mapping covered |
| Real JSON preview | Supplied 67-row Itaú file against local Supabase | Pass — 66 new, 1 Shortcut reconciliation, 2 reviews and 1 excluded payment |
| Real JSON reconciliation | Derived invoice total versus statement total | Pass — R$ 5,484.85 equals R$ 5,484.85 |
| JSON import idempotency | Repeat the same `request_id` | Pass — second import returned `duplicate_batch` with zero writes |
| JSON import database quality | `supabase db reset` and `supabase db lint --local --level warning` | Pass — no schema errors |
| Item-level personal total | Supplied 67-row Itaú file against local Supabase | Pass — one excluded purchase produced personal total R$ 5,462.05 while the audited statement remained R$ 5,484.85 |
| Item-level atomicity | Local import with one excluded purchase | Pass — item persisted as `ignored` and `include_in_totals=false`, while statement balance gate remained active |
| JSON import remote migration | `supabase db push --linked` | Pass — migrations through `202608170005_item_level_invoice_review.sql` applied |
| JSON import remote quality | `supabase db lint --linked --level warning` | Pass — no schema errors |
| JSON import visual QA | Desktop and 390 × 844 local builds | Pass — item list, filters, safe bulk validation, individual edit and final confirmation fit both layouts |
| Unknown category creation | Desktop and 390 × 844 local builds | Pass — automatic prompt approved `Presentes` without renaming it; creation remains atomic with final import |

## Evidence — 18 August 2026 (toolchain and write path)

| Gate | Evidence | Result |
|---|---|---|
| Toolchain upgrade | `flutter upgrade` | Pass — 3.35.4 / Dart 3.9.2 to 3.47.0 / Dart 3.13.0 |
| Dependency resolution | `flutter pub get` against the unmodified `pubspec.yaml` | Pass — `sdk: ^3.11.5` satisfied; 6 transitive packages moved |
| Static quality | `flutter analyze` | Pass — no issues |
| Domain and write rules | `flutter test` | Pass — 30 tests, up from 15 |
| Draft validation | Unit tests for blank merchant, non-positive and NaN amounts, missing category, and four installment cases | Pass |
| Manual competence | Demo write of a 15 August purchase on a card closing day 2 | Pass — competence 1 September, card final 6902 |
| Account movement | Demo write with no card | Pass — no competence, card final `----` |
| Write idempotency | Demo edit of an existing row | Pass — row replaced, ledger length unchanged |
| Validation ordering | Demo write with a negative amount | Pass — `FinanceWriteException` raised, ledger untouched |
| Ledger ordering | Demo write back-dated to 2020 | Pass — newest-first order preserved |
| Production web build | `flutter build web --release --dart-define-from-file=config/finora.production.json` | Pass — `build/web` |
| Production iOS build | `flutter build ios --simulator --debug --dart-define-from-file=config/finora.production.json` | Pass — `Runner.app` |
| Toolchain side effects | `git status` after the upgrade and the iOS build | Recorded — Flutter rewrote `analysis_options.yaml`, `ios/Podfile` (minimum iOS 13.0 to 15.0), `ios/Podfile.lock`, the Xcode project and scheme, and `pubspec.lock` |

## Evidence — 18 August 2026 (transaction form)

| Gate | Evidence | Result |
|---|---|---|
| Static quality | `flutter analyze` | Pass — no issues |
| Full suite | `flutter test` | Pass — 44 tests, up from 30 |
| Amount parsing | 8 unit tests: `24,80`, `1.234,56`, `24.80`, `R$ 1.999,90`, integers, empty, malformed, negative | Pass |
| Form validation | Widget test submitting an empty form | Pass — three field messages shown, `onSave` never called |
| Form save | Widget test typing `1.234,56` | Pass — draft carries 1234.56 and `movement_type=purchase` |
| Income mode | Widget test selecting Entrada | Pass — payment method hidden, `movement_type=credit`, no card |
| Competence hint | Widget test selecting the card closing on day 2 | Pass — invoice month and closing day shown |
| Write failure | Widget test with a throwing `onSave` | Pass — message shown, form stays open |
| Edit prefill | Widget test opening an installment purchase | Pass — merchant, amount and installment switch restored |
| Mobile action button | Demo web build at 390 × 844 | Pass — action button renders above the navigation bar; the previous 540–600px gap is closed |
| Browser runtime | Console errors on the demo build | Pass — none |

## Evidence — 18 August 2026 (review queue and merchant rules)

| Gate | Evidence | Result |
|---|---|---|
| Static quality | `flutter analyze` | Pass — no issues |
| Full suite | `flutter test` | Pass — 62 tests, up from 44 |
| Review title fallback | Unit tests with description, blank description and no transaction | Pass |
| Queue lifecycle | Demo resolve and dismiss | Pass — entry leaves the pending queue either way |
| Pending count | Snapshot count after resolving one entry | Pass — 3 becomes 2 |
| Unknown review id | Demo settle with an id that does not exist | Pass — no-op, queue unchanged |
| Rule matching | Case-insensitive substring against three merchant strings | Pass |
| Rule validation | Blank, two-character and category-less drafts | Pass — each reports its own message |
| Duplicate pattern | Demo save of `ifood` against an existing `IFOOD` | Pass — refused, list unchanged |
| Rule edit | Demo save reusing the row's own pattern | Pass — no self-clash, category updated |
| Rule ordering | Demo create with priority 5 | Pass — sorts ahead of the seeded rules |
| Rule delete | Demo delete | Pass — remaining rules keep their order |
| Production web build | `flutter build web --release --dart-define-from-file=config/finora.production.json` | Pass — `build/web` |

## Evidence — 18 August 2026 (available limit and comparison)

| Gate | Evidence | Result |
|---|---|---|
| Static quality | `flutter analyze` | Pass — no issues |
| Full suite | `flutter test` | Pass — 79 tests, up from 62 |
| Previous month | Unit tests for August, January and a 10-day custom range | Pass — January steps into December 2025; the range keeps its length |
| Category ranking | Comparison over two months | Pass — ordered by absolute movement, Transporte first at −150 |
| New and gone categories | Category present in only one of the periods | Pass — flagged `isNew` / `isGone`, ratio null |
| Missing baseline | Previous period with no spending | Pass — `hasBaseline` false and `expenseRatio` null instead of a fabricated percentage |
| Ratio with baseline | 100 then 150 | Pass — 0.5 |
| Trailing average | Movement in two of the three prior months | Pass — 200, the empty month excluded from the divisor |
| Trailing average, no history | Nothing before the period | Pass — null |
| Committed limit | Open plus closed invoices | Pass — both count; a paid invoice releases its share |
| Cross-card isolation | Invoice belonging to another card | Pass — not counted |
| Tight card | 800 of a 1,000 limit | Pass — flagged tight, not over |
| Over the limit | 1,400 of a 1,000 limit | Pass — available clamped to zero, ratio 1.0 |
| Card without a limit | `credit_limit` zero | Pass — not judged; no usage bar and no tight flag |
| Production web build | `flutter build web --release --dart-define-from-file=config/finora.production.json` | Pass — `build/web` |

## Evidence — 18 August 2026 (theme and accessibility)

| Gate | Evidence | Result |
|---|---|---|
| Static quality | `flutter analyze` | Pass — no issues |
| Full suite | `flutter test` | Pass — 96 tests, up from 79 |
| Primary text contrast | Computed ratio against canvas and surface, both themes | Pass — at or above 4.5:1 in all four combinations |
| Secondary text contrast | Same, for `inkMuted` | Pass — replaces the 4.0:1 measured in the audit |
| Caption contrast | Same, for `inkSubtle` | Pass — replaces the 3.2:1 measured in the audit |
| Tint and status contrast | `onBrandSoft` on `brandSoft`; `danger` and `onWarning` on surface | Pass — all at or above 4.5:1 in both themes |
| Theme extension wiring | `buildAppTheme` for both brightnesses | Pass — each carries its palette; scaffold follows `canvas` |
| Palette resolution | Widget test reading `context.palette` under `ThemeMode.dark` | Pass — resolves the dark palette |
| Palette interpolation | `lerp` at t = 0.5 | Pass — stays a `FinoraPalette`, values move |
| Tooltip triage | Count in `lib/presentation` | 30 reduced to 11; the rest are icon-only controls or genuinely non-obvious hints |
| Dynamic Type | Card face and both charts | Heights now multiply by `textScalerOf`, clamped at 1.6 and 1.4 |
| Production web build | `flutter build web --release --dart-define-from-file=config/finora.production.json` | Pass — `build/web` |
| Dark rendering | Production build at 390 × 844 with the browser in dark | Pass — ground, card, text and brand all resolve to the dark palette |
| Light rendering | Same build reloaded in light | Pass — cream ground, white card, moss action |
| Input field affordance | Both themes, observed | **Defect found and fixed** — fields had no boundary: the fill matched the card surface, so they read as plain rows in both themes. Fields appear on the page ground on some screens and inside a card on others, so no single fill contrasts with both; a hairline outline plus a brand focus ring was the fix. Re-verified after rebuild. |

## Evidence — 18 August 2026 (rules at capture time)

| Gate | Evidence | Result |
|---|---|---|
| Function type check | `deno check index.ts` | Pass |
| Function lint | `deno lint index.ts rules.ts` | Pass |
| Rule matching | 12 Deno tests over `rules.ts` | Pass |
| Priority order | Two rules on the same merchant, priorities 10 and 50 | Pass — lowest number wins |
| Tie break | Same priority, patterns `IFOOD` and `IFOOD *MERCADO` | Pass — the longer, more specific pattern wins |
| Inactive rules | A rule with `active=false` | Pass — never selected |
| Explicit choice | Shortcut sends a valid category while a rule also matches | Pass — the person's choice wins, no review raised |
| Unknown category name | Shortcut sends a name that does not exist | Pass — falls through to the rules instead of failing |
| No resolution | No category, no matching rule | Pass — capture kept, confidence low, review queued |
| Accent parity | `FARMÁCIA` against pattern `farmacia` and the reverse | Pass — both match, on both sides |
| Dart/TypeScript parity | 5 Dart tests over `normalizeMerchant`, `foldAccents` and `matches` | Pass — the screen's preview and the capture path agree |
| Static quality | `flutter analyze` | Pass — no issues |
| Full Dart suite | `flutter test` | Pass — 113 tests |

## Evidence — 18 August 2026 (capture function deployed)

| Gate | Evidence | Result |
|---|---|---|
| CLI compatibility | `supabase link` with CLI 2.101.0 | Fail — `config.toml` uses `[local_smtp]`, a key that version does not know |
| CLI upgrade | `brew upgrade supabase` | Pass — 2.101.0 to 2.114.0; config parses. Node was pulled to 26.7.0 as a dependency |
| Project link | `supabase link --project-ref ddmilzlinvpxfvzyigok` | Pass — Finora, São Paulo, `ACTIVE_HEALTHY` |
| Remote schema | `supabase migration list --linked` | Pass — all five migrations applied; local and remote match, so every column the new function writes exists |
| Function deploy | `supabase functions deploy capture-transaction` | Pass — `index.ts` and the new `rules.ts` uploaded |
| Function boots | POST with an invalid token | Pass — HTTP 401 `invalid_token`, which proves the module initialises and the `rules.ts` import resolves; a bundling failure would answer 500 |
| Method guard | GET on the endpoint | Pass — HTTP 405 `method_not_allowed` |

## Evidence — 18 August 2026 (last three findings)

| Gate | Evidence | Result |
|---|---|---|
| Static quality | `flutter analyze` | Pass — no issues |
| Full suite | `flutter test` | Pass — 121 tests, up from 113 |
| Period equality | `FinancePeriod` value equality and hash | Pass — required to key the memo |
| Analysis memo | Repeated call with the same snapshot and period | Pass — identical instance returned; a new snapshot bypasses the cache |
| Currency default | Formatter with no profile override | Pass — `R$`, after a caught regression that printed `BRL` |
| Currency switch | `configureCurrency('USD')` | Pass — `1,234.50`, no `R$` |
| Unmapped currency | `configureCurrency('XOF')` | Pass — formats with the code as symbol |
| Blank currency | `configureCurrency('   ')` | Pass — ignored, keeps the previous formatter |
| Single period control | Demo build at 1280px | Pass — one bar in the shell, none inside the pages |
| Cards honour the period | Same build, August then July | Pass — August shows its invoice, July shows the empty state |
| Availability unfiltered | Same navigation | Pass — the two cards keep their figures across months |
| Five destinations | Navigation rail | Pass — Projeção reachable as the first item under "Mais" |

## Open validation gates

- Real-device Shortcut test: requires a deployed Supabase project, token and selected Wallet card.
- Remote import claim: requires creating the matching Finora Auth account.
- **Supabase write path against a live database**: `saveTransaction` and
  `deleteTransaction` are covered only through the demo repository. The
  Postgrest calls, the invoice-reuse branch, the RLS path and the
  `refresh_invoice_total` trigger interaction have not been exercised against
  Postgres. Requires a signed-in session.
- **Pull-to-refresh on device**: the indicator is wired to the provider reload
  but has not been observed on a running build.
- **Committed limit ignores unbilled installments.** Future instalments of a
  purchase already hold limit at the issuer but have no invoice yet, so the
  available figure is optimistic for heavily instalment-funded cards.
- **Only the sign-in screen has been seen in dark.** The production build opens
  on authentication, so the six main screens have not been observed in the dark
  palette — only the auth screen was. A demo-mode build would show the rest.
- **Dynamic Type has not been exercised at scale.** The three bounded heights
  now scale, but no run at a large text setting has confirmed the six screens
  hold together.
- **Interactive walkthrough of the form**: its behaviour is covered by widget
  tests, and the action button was confirmed to render at 390 × 844, but no one
  has driven the create, edit and delete flows by hand. The iOS Simulator
  integration needs `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`
  on this machine, and the browser pane cannot deliver clicks into the Flutter
  canvas.
- **The rule-firing path has not run end to end.** The function is deployed and
  boots, but no capture with a valid token has been made, so the rule lookup,
  the `Outros` fallback and the review-queue insert have still never executed
  against Postgres. Exercising them writes a real transaction to the production
  ledger, which is the owner's call to make — from the Shortcut on a real
  purchase, or from a deliberate test capture that is deleted afterwards.
- **The 404 removal is a behaviour change for the Shortcut.** A capture whose
  category cannot be resolved now returns 200 with `needs_review: true` rather
  than 404. Any Shortcut logic keyed on the old failure needs revisiting.
- **Supabase review and rule methods** have the same gap as the write path:
  covered only through the demo repository, never executed against Postgres.

## Invoice due-date reminders (2026-08-18)

Covered by tests: the reminder set itself. `test/reminders_test.dart` pins
that paid, empty and already-past invoices drop out, that ordering follows
the fire time, that the notification id is stable across reschedules, and
that the day count survives the hour offset. `test/reminders_page_test.dart`
drives the screen against a stubbed service: permission is requested only on
turning it on, a refusal leaves the switch off and schedules nothing, and
changing a knob reschedules without re-prompting.

Two defects were found by these tests before shipping:

- `daysBefore` was derived as `dueDate.difference(fireAt).inDays`, which
  truncates because the two differ by whole days *plus* the chosen hour. A
  reminder three days out measured as 2, and one day out measured as 0. The
  value is now carried from the caller, which knows it exactly.
- The v22 plugin API is all-named; the first cut was written against v18's
  positional `initialize` and `zonedSchedule`.

**Not verified — needs the device.** No part of the actual delivery has run:

- The iOS permission prompt has never been shown. `requestPermission` is
  covered only through a stub that returns a boolean.
- No notification has ever been scheduled or delivered. `zonedSchedule` has
  never been called with a live channel.
- The `AppDelegate` change (setting the `UNUserNotificationCenter` delegate so
  a reminder arriving with Finora open is not silent) **does compile and link**.
  `flutter build ios --no-codesign --debug` first failed here for an unrelated
  reason — the disk was full, 194 MiB free of 228 GiB, and `rsync` could not
  copy the framework. After clearing space the build succeeds, and
  `Runner.debug.dylib` carries `FlutterLocalNotifications`,
  `UNUserNotificationCenter` and a link against
  `UserNotifications.framework`. Note the binary to inspect: the top-level
  `Runner` is a 71 KB stub and contains none of this; in a debug device build
  the native code lives in `Runner.debug.dylib`.
- What compiling does **not** prove: that a notification is ever delivered.
  The permission prompt, the scheduling and the delivery still need a device.
- `America/Sao_Paulo` is hardcoded as the scheduling zone. Correct for the
  ledger today; wrong the moment the app is used from another timezone.

Reminder preferences live in `shared_preferences`, deliberately: whether this
phone buzzes is a property of the phone, not of the account.

## Invoice closing forecast (fase 4)

Covered by tests: 18 on the derivation, 12 on the widget. The ones that
carry real weight:

- **Instalments are never counted twice.** They feed `scheduled` and are
  excluded from the daily rate; an instalment already captured for the target
  month lands in `committed` and drops out of `scheduled`.
- **A month absent from the data is not a frugal month.** Without the
  `_hasCycle` guard, every cycle predating the first import would contribute
  thirty days of zero spend and halve the rate. A cycle that *was* observed
  and holds only instalments still counts, with zero rhythm — that one is
  genuine evidence.
- **The forecast uses `amount`, not `personalShare`.** The issuer bills the
  whole purchase regardless of who it is attributed to.
- **Cycles, not calendar months.** A card closing on the 20th collects the
  tail of one month and the head of the next; a calendar average would
  misplace roughly a third of the spend.
- **No baseline means no projection.** The card says so in words rather than
  presenting `committed` as if it were a forecast.

The bar's proportions are asserted on flex values, so the check does not
depend on the width the test runs at.

**Not verified:** the screen has not been driven by hand. The browser pane in
this environment does not deliver clicks into the Flutter canvas — the app
boots and renders, but the Faturas tab could not be reached by clicking.
A golden render was used to inspect layout and was discarded afterwards:
widget tests load no font, so every glyph renders as a box and line wrapping
in that image says nothing about the real app. Layout facts were recovered
from the render tree instead, which is font-independent.

## Natural-language insights (fase 4)

**Derived, not generated.** No model writes these sentences. Every figure in
them comes from the same arithmetic the other screens use, so a reader who
checks a number will find it. Wording that cannot be backed by a computed
figure is not written.

Covered by tests: 20 on the derivation, 6 on the widget. The guards that
carry the weight:

- **Two observed months minimum.** One month is an anecdote.
- **A month absent from the data is not a month of restraint** — the same trap
  as the invoice forecast. Without the guard, opening the app for the first
  time would report every category as a spike.
- **Both a money floor and a proportion floor.** 30 reais over a 40-real
  average is a large percentage and a meaningless amount; ranking is by money
  for the same reason.
- **No percentage from zero.** A category with no baseline is left alone
  rather than described as an infinite increase.
- **Custom ranges produce nothing**, as with budget alerts: a monthly average
  against an arbitrary window is a number that means nothing.
- **A price change is weighed against a year**, because a monthly charge keeps
  costing the difference every month.
- **Concentrated and diffuse increases are worded differently.** "Puxado por 3
  compras" is a fact to act on; the same phrase over fourteen purchases would
  be the wrong word for a habit.

A test fixture caught something worth recording: the same merchant at the same
amount every month is this app's own definition of a subscription, so a naive
fixture produced a price-change insight alongside the category one and changed
what the test was measuring. Fixtures now vary the merchant per month.

**Demo data cannot exercise either phase-4 feature.** `DemoFinanceRepository`
holds 8 transactions spanning 8–18 August 2026 — a single month. Insights
therefore produce nothing (correctly: no baseline), and the forecast shows
`hasBaseline: false` for both cards, so the estimate is always zero and the
card says "sem ciclo anterior". Both features are invisible in demo mode. The
guards are behaving; the demo fixture is what is too thin to show them.

**Not verified:** the screen has not been driven by hand, for the same reason
as the forecast — the browser pane here does not deliver clicks into the
Flutter canvas.

## Demo ledger extended to four months (fase 4)

`DemoFinanceRepository` held 8 transactions in a single month, which silently
disabled every feature that needs a baseline. It now carries three prior
months plus the current one, with past invoices and salary rows.

Two mistakes of mine in the first pass, both caught by running the derivations
against the seeded data rather than by reading it:

- **A malformed income row.** Written as `movementType: 'income'` on
  `cardLastFour: ''`. Neither is what the model checks: income is `credit` on
  something that is *not* a card, and `isCard` only excludes the literal
  `----`. The row became a 9.800 expense on a phantom card, and the insights
  panel reported "você gastou 100% a menos em Renda" as good news.
- **Amounts too uniform.** Derived from the loop index, so a bakery, a
  supermarket and a petrol station all passed the recurring detector's
  steadiness test and were reported as subscriptions. The detector was right;
  the fixture was fake. Amounts are now listed per month, and only Netflix and
  the telecom bill hold still.

Past invoice totals were also invented near 2.400 while the seeded ledger
spends about 500 per card, so the forecast reported every open invoice as
closing "76% abaixo da média" — correct arithmetic about data that
contradicted itself. The totals now track the ledger.

A guard test asserts the demo still spans at least three months. Without it, a
future trim back to one month would make the layout tests below stop
exercising the trend line and pass for the wrong reason.

## Metric grid overflow (found by extending the demo)

Extending the demo exposed a layout bug that had been shipping invisible: the
metric cards overflowed by 24 pixels once a trend line rendered, and the trend
line only renders when there is a previous month to compare against.

The cause was structural, not cosmetic. `GridView.count` sized every cell from
a fixed `childAspectRatio`, chosen for a card without a trend line. Two rounds
of tuning that number each left a smaller overflow at some other width, which
is the signature of the wrong approach. The grid is now rows of
`IntrinsicHeight`, which measure their own content, with
`CrossAxisAlignment.stretch` so values in a row share a baseline.

Two further defects surfaced at large Dynamic Type:

- the metric label could grow unbounded in a narrow column — now capped at two
  lines with an ellipsis;
- the caption beside the icon overflowed horizontally at 2× text — now
  `Flexible` so it gives way instead of pushing the row past the card.

`test/dashboard_layout_test.dart` pumps the real dashboard with the real demo
snapshot at four widths and three text scales, and fails on any overflow. This
is the first coverage of Dynamic Type in the project; the standing gate about
it is narrowed, not closed — only the dashboard is covered.

## Receipt attachment and OCR (fase 4)

Reading is **on device** — the photograph never leaves the phone. For a
document that shows a merchant, an amount and a date, that is the point, and
it also means no API key and no per-scan cost. Chosen by the owner on
2026-08-18 over a cloud recognizer.

Covered by tests: 30 on the parser, 8 on the field and its wiring into the
form. The design decisions the tests pin:

- **Nothing is guessed.** Every field of `ReceiptScan` is nullable, and a
  field is either supported by something the receipt says or comes back null.
  Prefilling a wrong amount is worse than prefilling nothing: it gets
  confirmed along with everything else and becomes a fact in the ledger.
- **No fallback to "the largest number on the page."** Without a labelled
  total there is no amount, because the largest number is as likely to be a
  CNPJ fragment, a barcode or a card number.
- **"TOTAL DE ITENS 7" is not seven reais.** Labels containing *total* that
  never carry a price are excluded explicitly.
- **A specific label beats a bare one** regardless of order, so a receipt
  printing both a subtotal and a total to pay reads the one charged.
- **`1.234` is one thousand.** With no comma, three digits after a dot is a
  thousands separator and two digits is a decimal point. Getting this
  backwards understates a purchase by a thousandfold.
- **Reading is offered, not applied.** The button says "preencher os campos
  vazios" and does exactly that; a typed value is never overwritten. The date
  is special-cased because it is never empty — it defaults to today — so only
  a date the person has not touched gives way.
- **A failed reading never loses the photograph.** The attachment is useful on
  its own.
- **Upload happens before the row is written**, so the transaction carries the
  path in the same call. Writing first and attaching after would leave a saved
  transaction with a lost receipt whenever the second call failed.

Storage: a private bucket, 10 MB limit, image mime types only. Policies match
on the first path segment being the owner's user id, which is the shape the
upload code writes. Reads go through a ten-minute signed URL — a public bucket
would make every receipt readable by anyone holding the URL.

Deleting a transaction does not delete its object: Postgres cannot reach into
Storage. An orphan stays private and unreferenced rather than becoming public.
A sweeper is not written.

**iOS deployment target raised 15.0 → 15.5**, required by `google_mlkit_commons`.
No device is lost: everything that runs 15.0 can run 15.5.

**Not verified, and this one cannot be verified here at all.** ML Kit ships no
arm64 simulator slices:

    MLImage, MLKitCommon, MLKitVision — no arm64 simulator support

On an Apple Silicon Mac the recognizer cannot run in the Simulator. The device
build compiles and links, and the permission strings are present in the built
`Info.plist`, but no receipt has been photographed or read. Everything up to
the recognizer call is covered by tests with a stubbed recognizer; the call
itself needs a real iPhone.

## Phase 5 — technical debt (2026-08-19)

### The snapshot split

The `.limit(2000)` was a correctness bug, not a performance choice: past that
row the ledger was silently short and every derived figure was wrong with
nothing on screen to say so. The loader pages through everything; the 50.000
ceiling exists only to bound the loop and raises a banner when reached.

The load is split into catalog and ledger and composed by the provider, so no
screen changed. Transaction writes refresh only the ledger.

A trap worth recording: the first version of these tests deadlocked. The fake
extended the demo repository, whose loaders sleep, and a `Future.delayed`
cannot resolve while the test body is blocked on an await instead of pumping
the clock.

### The spreadsheet reader

CSV and XLSX go in directly. The rules live in a pure function over extracted
cells, so they are tested without fixture files. **PDF is not done** — text
extraction in Dart needs a heavy, licence-encumbered dependency, and a wrong
number read off an invoice is worse than a manual step. The plan item is half
closed, deliberately.

Two defects found while wiring it: the payload validator rejects duplicate
external ids, so two identical charges on one day would have failed the whole
file; and `raw_source` recorded the literal `chatgpt` for every import, which
would file a bank export as if a model had transcribed it.

### Database tests — the standing gap is now closed

**32 pgTAP tests run against a real Postgres**, and `.github/workflows/ci.yml`
runs them on every push. This closes the gap recorded above since the first
audit: "everything that talks to Supabase is covered only through the demo
repository, never executed against Postgres."

Now demonstrated rather than assumed:

- The paid/`paid_at` invariant holds in both directions.
- Competence is pinned to the first of a month.
- A personal share larger than the amount is refused.
- **RLS isolates.** A signed-in user sees only their own rows and is refused
  when writing a row owned by someone else. This is what makes shipping the
  publishable key safe and it had never been shown.
- The receipts bucket is private, capped and image-only, and all four policies
  key on the owner folder — the same shape the upload code writes.
- The import RPC creates, queues for review, and recognises a re-import as a
  duplicate batch instead of writing it twice.
- The provenance fix records `sheet`, not `chatgpt`.

The CI also runs `supabase db reset`, proving the migrations replay from
scratch rather than only working against today's production database.

Every gate was run locally before committing. Two would have failed on first
push: fifteen unformatted files and one brace lint.

### What is still not verified

- **No receipt has been photographed or read.** ML Kit ships no arm64
  simulator slices, so on Apple Silicon the recognizer cannot run in the
  Simulator at all. Needs a real iPhone.
- **No invoice reminder has been delivered.** Same reason: needs a device.
- ~~The two new migrations have not been applied to production.~~
  **Applied on 2026-08-19 and verified afterwards**: the column exists, the
  bucket is private with its four policies, `import_finora_invoice` is still
  the wrapper that performs item-level review, and `import_finora_invoice_v1`
  carries the provenance fix. 897 transactions, 11 invoices and 9 cards
  untouched.

  Applying them nearly caused a regression. `202608200002` restated
  `import_finora_invoice` with the body from `202608170004` — but
  `202608170005` had renamed that body to `_v1` and made
  `import_finora_invoice` a wrapper adding item-level review. The local suite
  passed anyway, because nothing in it covered what the wrapper adds.
  Three assertions now pin the structure, and CI verified them before the
  migration was applied anywhere.
- **Dynamic Type is covered only on the dashboard.**
- **The app has not been driven by hand against the production Supabase.** The
  browser pane here does not deliver clicks into the Flutter canvas; the
  overview was driven with synthesised wheel events, no other screen was.

## PR 0 — rede de segurança do remake de UI (2026-08-19)

Antes de mudar qualquer coisa de design, uma linha de base. O objetivo era
tornar a mudança visível; o efeito colateral foi encontrar cinco overflows que
já estavam em produção.

### Costura de relógio

Um golden só vale se for determinístico, e a demo e quatro derivações do domínio
liam `DateTime.now()` direto — a fatura "fecha em N dias" mudaria de valor todo
dia. Todas passaram a ler `clock.now()` (`package:clock`), que é
`DateTime.now()` quando ninguém sobrescreve. Os cinco `DateTime.now()` que
sobraram estão em `supabase_finance_repository.dart` e escrevem carimbo real no
banco — esses devem mesmo seguir o relógio de parede.

### Defeitos encontrados e corrigidos

| Onde | Sintoma | Largura |
|---|---|---|
| `more_page.dart` `_Step` | rótulo do passo do Apple Pay estourava 66px | 390pt |
| `projection_page.dart` | par realizado/meta estourava 28px | 390pt |
| `more_page.dart` metas | `Spacer` entre dois valores rígidos, 66px | 390pt a 1.3x |
| `invoice_forecast_card.dart` `_Part` | legenda estourava 30px | 390pt a 1.3x |
| `invoice_forecast_card.dart` total | total previsto estourava 42px | 390pt a 2.0x |

Todos são conteúdo que não podia ser visto, em telefone. Nenhum tinha teste.

### Defeitos encontrados e adiados, com dono

Dois restam, e são da mesma classe já corrigida uma vez no dashboard — célula de
proporção fixa que não cresce com o texto:

- `common.dart:138` (`MetricCard`) — substituído no PR 2
- `categories_page.dart:82` (grade de proporção fixa) — substituído no PR 3

Estão marcados como `skip` com o motivo no nome do teste, não silenciados.

### O que passou a existir

| Arquivo | O que faz |
|---|---|
| `test/support/contrast.dart` | arnês WCAG extraído de `theme_test.dart`, reusável pelos tokens novos |
| `test/support/golden.dart` | pump com relógio, tamanho, escala de texto e densidade fixos |
| `test/golden_test.dart` | 24 imagens: 6 páginas × 3 larguras em claro + 6 em escuro |
| `test/page_overflow_test.dart` | 24 casos de layout + 12 de Dynamic Type, **rodando no CI** |
| `insights_card.dart` | chave por tom, para o teste não depender do glifo do ícone |

Densidade fixada em 1:1 em vez do 3× padrão do ambiente de teste: as mesmas 24
imagens caíram de 5,7 MB para 1,3 MB e a suíte de golden de 20s para 7s.

### Limite conhecido

O texto renderiza como retângulo — o ambiente de teste não tem fonte real
carregada e o produto ainda não empacota nenhuma. Os goldens registram layout,
espaço, cor e hierarquia, que é o que mais muda; passam a registrar as formas
das letras quando as fontes entrarem no PR 1.

Os goldens não rodam no CI: uma imagem gerada no macOS não bate com uma gerada
no Linux. Por isso os overflows têm teste próprio em `page_overflow_test.dart`,
que roda. Localmente: `flutter test --tags golden`.

### Evidência

| Verificação | Resultado |
|---|---|
| `dart format --set-exit-if-changed lib test` | 97 arquivos, 0 alterados |
| `flutter analyze --fatal-infos` | sem problemas |
| `flutter test --exclude-tags golden` | **457 passam, 6 adiados** |
| `flutter test --tags golden` | 24 passam, estáveis em duas execuções seguidas |

## PR 1 — tokens do design system Ledger (2026-08-19)

Nenhum valor de cor entrou no código sem ter sido medido antes. Três foram
reprovados na medição e reescritos.

### Reprovados antes de entrar

| Valor | Medida | Por quê |
|---|---|---|
| `inkSubtle` claro `#6B7476` | 4,34:1 | Contra `sunken`, o fundo zebrado que a linha do razão introduz. Passou a `#656D6E` (4,80:1) |
| Borda de campo `#C7CBC6` | ~1,5:1 | WCAG 1.4.11 pede 3:1 para o que identifica um controle. Virou `ruleStrong` `#767E7D` (3,77:1) |
| 1ª paleta categórica | ΔE 8,4 | Sob protanopia. Escrita de intuição |
| 2ª paleta categórica | ΔE 1,0 | Sob tritanopia — otimizada só para deuteranopia |

A paleta final foi buscada com simulação de Viénot–Brettel–Mollon e ΔE CIE76,
com a faixa amarela (matiz 30–120°) banida e separação mínima de 34° entre
matizes:

| | claro | escuro |
|---|---|---|
| ΔE mínimo — normal, deuteranopia, protanopia | 19,5 | 21,6 |
| ΔE mínimo — tritanopia | 17,1 | 19,9 |
| contraste mínimo com o fundo | 3,28:1 | 4,20:1 |

### Pontes de migração

197 avisos de depreciação, que são a worklist e não uma regressão:

| Token | Usos |
|---|---|
| `danger` | 73 |
| `brand` | 69 |
| `warning` | 20 |
| `onWarning` | 12 |
| `brandSoft` | 12 |
| `hairline` | 7 |
| `onBrandSoft` | 3 |
| `info` | 1 |

`brand` e `danger` somam 142, dentro das ~145 decisões semânticas que o plano
previu. O CI passou a `--no-fatal-infos` até o PR 5 apagar as pontes; erros e
warnings continuam falhando o build.

### Limite conhecido

As fontes não foram empacotadas — baixar binário precisa de autorização do dono.
`LedgerText` usa `fontFamilyFallback` para a serifa do sistema até lá, e
`FontFeature.tabularFigures()` já funciona com a fonte padrão, então o
alinhamento de coluna já vale.

### Evidência

| Verificação | Resultado |
|---|---|
| `dart format --set-exit-if-changed lib test` | sem alterações |
| `flutter analyze --no-fatal-infos` | 0 erros, 0 warnings, 197 infos de depreciação |
| `flutter test --exclude-tags golden` | **526 passam, 6 adiados** |
| `flutter test --tags golden` | 24 passam; todas as 24 imagens mudaram, como esperado |

## PR 2 — camada de componentes (2026-08-19)

O PR de maior alavancagem: `SectionCard` e `MetricCard` viraram cascas sobre
`RuledSection` e `LedgerTile`, então **21 chamadas mudaram de aparência sem que
nenhuma página fosse tocada**, e `DetailValue` levou o mesmo tratamento a 49
lugares.

### Defeitos encontrados e corrigidos

| Onde | Estouro | Origem |
|---|---|---|
| Face do cartão, `cards_page` | 13px a 1.3x | pré-existente — nome do banco em capitulares espaçadas ao lado de um ícone rígido |
| `MonoTag` | 21px a 2.0x | **introduzido neste PR** — a tag não podia quebrar linha |
| `PeriodFilterBar` | 50px a 375pt | **introduzido neste PR** — o grupo segmentado não encolhia |
| `LedgerRow` | assert de `Container` | **introduzido neste PR** — `color` e `decoration` juntos |

Dois dos quatro foram defeitos meus, pegos pela rede do PR 0 antes de sair da
máquina. É o argumento a favor de ter construído a rede primeiro.

### Correção de registro

A nota do PR 0 atribuía o estouro da página de faturas ao `MetricCard`. Estava
errada: era a face do cartão de crédito. O comentário em
`page_overflow_test.dart` foi corrigido em vez de apagado.

Sobrou **um** caso adiado por Dynamic Type — a grade de categorias, que fixa a
proporção da célula e é substituída no PR 3.

### Evidência

| Verificação | Resultado |
|---|---|
| `dart format --set-exit-if-changed lib test` | sem alterações |
| `flutter analyze --no-fatal-infos` | 0 erros, 0 warnings, 204 infos |
| `flutter test --exclude-tags golden` | **530 passam, 2 adiados** |
| `flutter test --tags golden` | 24 passam; as 24 imagens mudaram |

Depreciações 197 → 204: `SectionCard` (12) e `MetricCard` (7) entraram, enquanto
`brand` caiu de 69 para 66 e `danger` de 73 para 68 — os componentes começaram a
absorver chamadas em vez de migrá-las.

## PR 3 — shell, navegação e os quatro espaços (2026-08-19)

`NavigationRail` recebia os mesmos cinco destinos da barra inferior — um máximo
do Material escrito para uma tela de 360pt — e por isso um monitor de 27
polegadas também ganhava um menu "Mais" com onze destinos reais dentro. Agora
são sete destinos nomeados em quatro espaços, e "Mais" desaparece acima de
905pt.

### O que passou a existir

| Arquivo | O que faz |
|---|---|
| `widgets/navigation.dart` | `LedgerSidebar`, `LedgerTabBar`, os quatro espaços |
| `pages/today_page.dart` | a tela que não existia: revisões, fatura fechando, orçamento no limite, narrativa |
| `application/appearance.dart` | tema escolhido e persistido |
| `test/navigation_test.dart` | 10 casos, incluindo o iPad em retrato |
| `goldens/shell-*.png` | o shell, que as goldens de página não enxergam |

### Defeitos meus, pegos pela rede

| Onde | Sintoma |
|---|---|
| Cabeçalho da sidebar | `_Brand` é a barra do telefone; num trilho de 68pt estourava 200px |
| `navigation_test` | `pumpAndSettle` não retorna enquanto uma `LinearProgressIndicator` indeterminada está na tela — o teste **travava**, não falhava. Trocado por um número limitado de frames |

### Marco

A lista de casos adiados por Dynamic Type está **vazia pela primeira vez**. Eram
seis no PR 0, dois no PR 2, zero agora. O defeito era sempre a mesma forma —
célula de proporção fixa ou linha sem folga — em quatro lugares diferentes.

Números mágicos de largura na apresentação: **23 → 14**.

### Evidência

| Verificação | Resultado |
|---|---|
| `dart format --set-exit-if-changed lib test` | sem alterações |
| `flutter analyze --no-fatal-infos` | 0 erros, 0 warnings, 203 infos |
| `flutter test --exclude-tags golden` | **548 passam, 0 adiados** |
| `flutter test --tags golden` | 31 passam (7 páginas + 3 do shell) |

## PR 4 — roteamento (2026-08-19)

O primeiro achado da auditoria, fechado. `MaterialApp(home:)` significava que a
barra de endereço nunca mudava, Voltar saía do aplicativo, F5 devolvia à aba
zero jogando fora o período e os filtros, e nada — nem um mês, nem uma busca,
nem uma fatura — podia ser linkado ou aberto em outra aba.

### Os endereços

```text
/hoje
/visao-geral?mes=2026-08
/transacoes?mes=2026-08&q=uber&categoria=Transporte&cartao=1847
/categorias?mes=2026-08
/faturas?mes=2026-08
/projecao?mes=2026-08
/mais
/transacoes/:id          abre o lançamento e devolve o endereço ao fechar
```

Mês inteiro vira `?mes=2026-08` e intervalo mantém as duas pontas — o formato
curto é o que se cola numa mensagem.

### O que precisou sair do estado do widget

`TransactionsPage` guardava o `TransactionFilter` internamente. Agora ele vem do
endereço, então um recorte do histórico é um link e F5 o preserva.

### Uma decisão de arquitetura, e seu efeito colateral

Os sete destinos são rotas irmãs sob **uma única chave de página**. Com isso o
elemento é reaproveitado entre rotas, o `IndexedStack` mantém a posição de
rolagem de cada tela e não há transição entre abas — que é como uma sidebar deve
se comportar.

O efeito colateral é que o `Navigator` tem uma página só, então `popRoute` não
tem o que desempilhar. Isso **não** é o Voltar do navegador: na web o histórico
pertence ao navegador, e o Voltar chega ao app pelo `setNewRoutePath`. Escrevi
primeiro um teste sobre `popRoute`, ele falhou, e o teste estava errado, não o
código. Trocado por um que exercita o caminho real.

### Estratégia de URL

Flutter usa hash por padrão, e a primeira verificação no navegador mostrou
`localhost:8087/transacoes?mes=2026-07#/hoje` — o caminho era ignorado. Ligado o
caminho limpo, por import condicional, porque `flutter_web_plugins` só existe na
web e este app também compila para iOS.

**Requisito de hospedagem:** o servidor precisa devolver `index.html` para
qualquer caminho não encontrado, senão recarregar um endereço profundo dá 404.
No Vercel é uma reescrita de `/(.*)` para `/index.html`.

### Ficou de fora, com motivo

- **A tela de entrada não tem endereço próprio.** O `AuthGate` virou envelope da
  shell roteada em vez de virar `redirect`; um redirect de verdade precisa de um
  `refreshListenable` sobre o stream de autenticação, e o fluxo de recuperação de
  senha é sutil demais para mexer junto com roteamento. Vai no PR 5.
- **Deep link para fatura** — não existe tela de fatura para abrir. Vai no PR 6,
  com o painel lateral.

### Evidência

| Verificação | Resultado |
|---|---|
| `dart format --set-exit-if-changed lib test` | sem alterações |
| `flutter analyze --no-fatal-infos` | 0 erros, 0 warnings |
| `flutter test --exclude-tags golden` | **564 passam, 0 adiados** |
| `flutter test --tags golden` | 31 passam |

### No navegador, não só em teste

Build de desenvolvimento em `localhost:8087`, Chromium:

| O que | Resultado |
|---|---|
| Abrir `/transacoes?mes=2026-07&q=uber` direto | cai no Histórico, julho de 2026, filtrado — 1 lançamento, e **o campo de busca mostra "uber"** |
| Clicar em "Cartões e faturas" na sidebar | endereço vira `/faturas?mes=2026-08`, `history.length` cresce |
| Voltar do navegador | volta para `/hoje` **dentro do app**, com a sidebar marcando Hoje |
| F5 em endereço profundo | mesma tela, mesmo mês, mesmo filtro |
| Endereço inexistente | tela que explica, com saída para Hoje |

O campo de busca foi um achado desta verificação: o filtro vinha da URL e era
aplicado, mas o campo continuava vazio — filtro invisível sobre lista filtrada.
Passou a ser semeado do endereço.

## PR 5 — superfícies e limpeza (2026-08-19)

### A porta

`flutter analyze --fatal-infos` voltou ao CI, limpo. As 203 pontes
`@Deprecated` que o PR 1 criou foram resolvidas e apagadas do
`FinoraPalette`.

### A estimativa do plano estava errada, e para melhor

O plano previa ~145 decisões semânticas em `brand` e `danger`. Lendo as 134
ocorrências:

| Token | Usos | O que eram de fato |
|---|---|---|
| `danger` | 68 | **Erro de verdade em todas**: banner de falha, ação destrutiva, fatura vencida, saldo negativo, orçamento estourado, variação desfavorável. Renomeação, não decisão |
| `brand` | 66 | 8 eram dinheiro (toast de sucesso, fatura paga, preço que caiu, gasto abaixo da meta, tendência para baixo) → `income`. O resto era ênfase → `accent` |

A conclusão que eu tinha tirado no PR 2 — "as saídas continuam vermelhas nos 68
`danger` restantes" — estava errada. Nenhum deles pintava uma saída comum de
vermelho; isso já tinha sido resolvido quando o `AmountText` absorveu as linhas
de lançamento.

### Erro meu, e a correção

Usei uma expressão regular para remover `icon:` de dentro das chamadas de
`MetricCard`, e ela apagou também o ícone do `_OperationTile` em `more_page` —
widget que não tem nada a ver com métrica. Revertido e refeito varrendo o bloco
de cada chamada, contando parênteses, em vez de casar texto solto. O `git diff`
por arquivo foi o que expôs: três arquivos perdiam `icon:` quando só dois
deviam.

### O bottom sheet no desktop

Zero `showModalBottomSheet` fora do componente. Os dez formulários e o
recategorizar em lote passaram por `showResponsiveSurface`:

| Largura | Apresentação |
|---|---|
| < 600 | bottom sheet, que é o certo no telefone |
| 600–1239 | dialog centralizado |
| ≥ 1240 | painel deslizando da direita, deixando a lista visível atrás |

### Evidência

| Verificação | Resultado |
|---|---|
| `dart format --set-exit-if-changed lib test` | sem alterações |
| `flutter analyze --fatal-infos` | **sem problemas** |
| `flutter test --exclude-tags golden` | **567 passam, 0 adiados** |
| `flutter test --tags golden` | 31 passam |

## PR 6 — densidade do desktop (2026-08-19)

### Três colunas que o app lia e jogava fora

`source_file`, `confidence` e `dedup_key` existem em `transactions` desde a
primeira migration, e o repositório já as buscava com `select('*')`. Elas nunca
foram mapeadas no modelo — o app segurava a procedência inteira e não conseguia
mostrá-la. São três campos em `FinanceTransaction.fromJson`.

O painel de detalhe agora responde de onde veio o número: entrou pelo Atalho,
por importação ou digitado; de qual arquivo; com que confiança; e sob qual chave
de dedupe. **Um total que ninguém consegue rastrear é um total com que ninguém
consegue discutir.**

### A tabela

Acima de 905pt o histórico vira colunas — data, comerciante, categoria, cartão,
estado, valor — com cabeçalho de pauta pesada, zebra e a coluna de valor atrás
de uma pauta vertical. Abaixo continua a lista empilhada. Mesmos dados, mesma
seleção, mesmas ações.

### Um defeito latente que a tabela expôs

`CategoryMark` desenhava a barra da categoria como um **lado da borda**, e
`BoxDecoration` dispara assert quando um raio encontra uma borda de lados
diferentes em cor ou espessura. O componente é do PR 2 e nunca tinha estourado,
porque nenhuma tela punha a marca em todas as linhas de uma vez. A tabela pôs, e
apareceram doze exceções de uma vez. A barra virou filho dentro de um
`ClipRRect`, com a borda uniforme.

### Correção de documentação

`03-specification.md` listava "bulk recategorization" como adiada. O código a
tem — seleção múltipla, aplicação em lote e a oferta de virar regra logo após a
correção. A especificação estava desatualizada, não o código.

### Evidência

| Verificação | Resultado |
|---|---|
| `dart format --set-exit-if-changed lib test` | sem alterações |
| `flutter analyze --fatal-infos` | sem problemas |
| `flutter test --exclude-tags golden` | **574 passam, 0 adiados** |
| `flutter test --tags golden` | 31 passam |

## PR 7 — ritual de revisão e o fecho do remake (2026-08-19)

### A fila virou ritual

Teclado no desktop — `J`/`K` navegam, `⏎` resolve, `D` descarta — com a legenda
dos atalhos visível na barra, porque atalho que ninguém descobre é atalho que
ninguém usa. Swipe no telefone, com o que a direção vai fazer escrito atrás do
card. O produto não tinha um único `Dismissible`.

### Botões e chips: tema, não chamada a chamada

40 `FilledButton` em quatro formas, 22 `Chip`, mais `OutlinedButton` e
`TextButton`. Resolvidos em `buildAppTheme`. Alcança todos, inclusive os que uma
mudança futura acrescentar, e não deixa nenhum para trás — o que trocar um a um
inevitavelmente deixaria.

### Os 28 `Card` ficam, e isso é a regra sendo aplicada, não ignorada

Reler o que eles são mudou a conclusão: linha de assinatura, célula de
categoria, painel de conta, item de revisão. São **objetos**, e o sistema
reserva superfície e raio exatamente para isso. As seções que não eram objeto já
tinham virado `RuledSection` no PR 2.

### Terceira divergência de documentação

Recuperação de senha constava como adiada em `03-specification.md` e no
`README.md`, e está implementada. Com a recategorização em lote (PR 6) e esta,
são três casos em que a documentação estava **atrás** do código — nunca à
frente.

### Evidência

| Verificação | Resultado |
|---|---|
| `dart format --set-exit-if-changed lib test` | sem alterações |
| `flutter analyze --fatal-infos` | sem problemas |
| `flutter test --exclude-tags golden` | **578 passam, 0 adiados** |
| `flutter test --tags golden` | 31 passam |

### O remake, de ponta a ponta

| | PR 0 | PR 7 |
|---|---|---|
| Testes | 378 | **578** |
| Casos adiados por Dynamic Type | 6 | **0** |
| Depreciações de paleta | — | **0** |
| Porta do analisador | `--fatal-infos` | `--fatal-infos` |
| Endereços web | 0 | 7 + deep link |
| Atalhos de teclado | 0 | ⌘K, N, 1–4, J/K/⏎/D |
| `showModalBottomSheet` soltos | 11 | **0** |
| Números mágicos de largura | 23 | 14 |
| Overflows de produção conhecidos | 8 | **0** |

## As fontes, enfim (2026-08-19)

O último item conhecido do PR 1, que dependia de autorização para baixar
binário.

### O que entrou

Três famílias variáveis, OFL, de `github.com/google/fonts`, com as licenças ao
lado: **Inter**, **Source Serif 4** e **JetBrains Mono**. Um arquivo por
família — o eixo `wght` cobre todos os pesos, selecionado por `fontVariations`
em vez de empacotar um arquivo por peso.

### O tamanho, e onde minha estimativa errou

O plano dizia "≈ 250–350 KB em subconjunto latino". Os arquivos completos somam
**2,2 MB** — sete vezes isso. Subsetados para latim, latim estendido-A,
pontuação, moedas e os poucos símbolos que o produto usa de fato:

| | completo | subsetado |
|---|---|---|
| Inter | 856 KB | **176 KB** |
| Source Serif 4 | 1181 KB | **305 KB** |
| JetBrains Mono | 183 KB | **101 KB** |
| total | 2220 KB | **582 KB** |

582 KB, não 250–350. A estimativa estava otimista; o número real está
registrado.

Verifiquei o que sobreviveu ao corte: o eixo `wght` está nas três, e o recurso
`tnum` está no **Inter** — que é exatamente onde as colunas vivem. A serifa não
tem `tnum` e não precisa: ela nunca é usada em coluna.

### O que isso destravou

`test/flutter_test_config.dart` carrega as fontes antes de qualquer teste, então
**as imagens de referência passaram a registrar as letras**. O limite anunciado
no PR 0 — "texto renderiza como retângulo, e isso muda quando as fontes
entrarem" — deixou de existir.

E a primeira coisa que as letras de verdade fizeram foi reprovar um layout:
`faturas` a 2,0x estourou 141px por baixo. A face do cartão tinha **altura
fixa**, escalada com Dynamic Type mas limitada a 1,6x; os retângulos da fonte de
teste eram mais estreitos que as letras que representavam. A altura virou mínimo,
e os dois `Spacer` — que exigiam altura limitada — viraram espaços fixos.

`ThemeData.fontFamily` passou a apontar para Inter, porque cerca de 200
`TextStyle` literais ainda não pedem estilo ao `LedgerText`: sem essa linha o
produto empacotaria três famílias escolhidas e continuaria não sendo composto
nelas.

### Evidência

| Verificação | Resultado |
|---|---|
| `dart format --set-exit-if-changed lib test` | sem alterações |
| `flutter analyze --fatal-infos` | sem problemas |
| `flutter test --exclude-tags golden` | **578 passam, 0 adiados** |
| `flutter test --tags golden` | 31 passam, agora com tipografia |

## O telefone estava quebrado, e o golden dele existia (2026-08-19)

O dono mandou uma captura do app no iPhone: a barra de abas no meio da tela, os
ícones centralizados nela e **nenhum conteúdo**. Reproduzi no web a 375pt em
minutos — não era do iOS, era layout, e estava na `main`.

### A causa

`LedgerTabBar` ocupava **a tela inteira**: `Rect.fromLTRB(0, 0, 375, 812)`. A
`TodayPage` ficava com altura zero.

O botão "+" da barra tinha um `Center` sem `heightFactor`. `Center` se expande
até as restrições que recebe, e a `Row` da barra oferece a altura toda da tela.
A barra esticou para 812, centralizou os ícones no meio, e o corpo do `Scaffold`
ficou sem nada. `heightFactor: 1` resolve.

### Por que os testes não pegaram

`navigation_test` afirmava `find.byType(LedgerTabBar)` → `findsOneWidget`. **A
barra existia.** O que faltava era perguntar *onde ela estava*.

E é pior que isso: eu **gerei o golden do shell no telefone** no PR 3, com o
defeito dentro, e olhei apenas o de 1440 — a largura que não tem barra de abas.
A imagem que mostrava o bug esteve no repositório o tempo todo.

Duas asserções novas guardam isso: a barra termina no rodapé e mede menos de
120pt; a página ocupa mais de 60% da altura.

### Dois outros achados da mesma captura

- **A marca do topo do telefone nunca entrou no design system.** Quadrado azul
  arredondado com um glifo de gráfico e "finora" em caixa baixa pesada — o
  visual anterior, sobrevivendo aos sete PRs porque o trilho ganhou marca
  própria no PR 3 e essa só aparece no telefone, que é onde eu menos olhei.
- **O rótulo "Precisa de você" não cabe numa aba.** Ganhou rótulo curto — e a
  primeira correção só funcionou em quatro dos cinco destinos, porque
  `withBadge` recriava o objeto e descartava o rótulo curto. O único destino com
  contador é justamente a fila de revisão. Um teste passa por todos os destinos
  agora.

### Lição de processo

Gerar uma imagem de referência não é revisá-la. As 31 são regeradas a cada PR e
eu olhei talvez seis. O telefone é a superfície que eu menos verifiquei e é onde
o produto é usado.

### Evidência

| Verificação | Resultado |
|---|---|
| `flutter analyze --fatal-infos` | sem problemas |
| `flutter test --exclude-tags golden` | **581 passam, 0 adiados** |
| `flutter test --tags golden` | 31 passam |
| Navegador a 375pt | barra no rodapé, conteúdo na tela |

## A fila deixou de ser uma parede (2026-08-19)

O dono, com 24 pendências reais: *"a UX da fila é meio pesada, não me dá vontade
de resolver"*. É a reação certa a uma lista rolável de 24 decisões, e o peso não
é falta de recompensa — é volume sem fim visível.

Perguntei até onde levar a gamificação e a resposta foi **progresso e
fechamento**, sem pontos nem conquistas. Foi a escolha certa: das três coisas
que carregam o peso, só uma é motivação.

### Agrupar — a que remove trabalho

Itens do mesmo estabelecimento chegam como **uma** decisão. Três capturas do
mesmo lugar não são três decisões. A ação diz quantas cobre — "Está certo (3)" —
e o cabeçalho diz as duas coisas: **"6 em 4 decisões"**. O segundo número é o
que prevê quanto tempo aquilo vai levar.

### Um por vez, e progresso que anda

Um grupo na tela, o resto sugerido como baralho atrás. O contador viaja em vez
de saltar, a pauta preenche, e o card sai na direção da decisão — direita para
mantido, esquerda para descartado. Tudo nos tokens de `Motion` e desligado
quando a plataforma pede movimento reduzido.

Ao zerar, a tela diz o que a sessão custou: *"12 lançamentos revisados em 4
decisões"*. A distância entre os dois números é o que o agrupamento comprou.

### Dois defeitos que a imagem de referência expôs

A fila era uma tela grande **sem nenhuma imagem de referência** — a superfície a
que o dono reagiu era a que ninguém conseguia ver. Ao criar as duas primeiras:

- **O card trocava de identidade ao abrir.** Sem o razão carregado, o
  agrupamento cai para o motivo; quando o razão chega, reagrupa por
  estabelecimento. Via-se "Classificação com baixa confiança (4)" virar
  "UNIFIQUE TELECOM (3)". Agora espera o razão, que é a renderização honesta.
- **Os cards do baralho eram invisíveis.** Tinham altura fixa menor que o card
  da frente e sumiam atrás dele. `Positioned.fill` faz acompanharem o card.

### Correções de fixture

A demo não tinha repetição de estabelecimento, então a fila nunca mostrava o
agrupamento — e a descrição do item contradizia a transação ligada.
`review_and_rules_test` fixava o tamanho da fila em três, e três testes de
comportamento quebraram só porque a demo cresceu; eles leem o tamanho agora.

### Evidência

| Verificação | Resultado |
|---|---|
| `flutter analyze --fatal-infos` | sem problemas |
| `flutter test --exclude-tags golden` | **588 passam, 0 adiados** |
| `flutter test --tags golden` | 33 passam, com a fila entre elas |

## Spike — dá para descobrir o ramo pelo Pix? (2026-08-19)

Pergunta do dono: existe API grátis para pegar o nome do Pix e inferir o ramo de
atuação.

### A parte que a pesquisa fechou

**Chave Pix → nome não tem caminho grátis.** O DICT faz exatamente isso, mas o
acesso é restrito a participantes do arranjo, auditado transação a transação e
limitado por bucket de token por usuário final. O desenho é deliberadamente
hostil a quem quer montar base de nomes. Precisaria ser cliente de um PSP com
CNPJ.

**Nome → ramo, com CNPJ em mãos, é grátis e bom.** O CNAE vem da Receita
Federal, exposto por OpenCNPJ (sem autenticação, 50 req/s), BrasilAPI, ou
Minha Receita — este último auto-hospedável a partir do dump mensal da Receita,
que é a única forma de não contar a um terceiro quais empresas o dono paga.

### O que o spike construiu

A pergunta que decide tudo não é "existe API", é **"quantos lançamentos meus
trazem CNPJ"**. Sem esse número a discussão é opinião.

| Arquivo | O que faz |
|---|---|
| `lib/domain/merchant_identity.dart` | lê a descrição do extrato e classifica quem foi pago: empresa (CNPJ válido), pessoa (CPF), documento mascarado, Pix só com nome, ou outro |
| `tool/statement_coverage.dart` | roda num extrato CSV e imprime só percentuais |
| `test/merchant_identity_test.dart` | 10 casos nos formatos reais dos bancos |

**Os dígitos verificadores são o ponto.** Uma sequência de catorze dígitos num
extrato é mais frequentemente um id de transação do que uma empresa; contá-la
como CNPJ tornaria o número de cobertura mentira, que é a única coisa que este
spike não pode ser.

**Nenhum extrato real entrou no repositório**, e não deve entrar — `AGENTS.md`
proíbe. Os testes usam linhas sintéticas nos formatos reais, com documentos que
passam no próprio dígito verificador e não pertencem a ninguém. A ferramenta
roda na máquina do dono, imprime só contagem, e a amostra opcional troca dígitos
e nomes por `#` antes de mostrar formato.

### O número que ainda falta

O do dono. A ferramenta existe justamente porque eu não tenho — e não deveria
ter — o extrato dele.

### O que o spike já indica

O CNPJ, quando aparece, aparece **uma vez por empresa**. Duas compras na mesma
padaria são uma consulta, não duas. Isso encaixa com `merchant_rules`: a
sugestão de CNAE alimentaria a fila de revisão com confiança, e a regra aceita
faz aquele estabelecimento nunca mais voltar.

E há um caminho melhor para cartão que não depende de nada disso: o **MCC**, que
a bandeira já atribui. Vale conferir se o extrato traz antes de investir em
casar nome com empresa.

### O resultado do spike: não vale, e o que vale no lugar

O dono rodou as consultas no razão real. **897 lançamentos, 196 Pix, zero com
documento** — nem CNPJ, nem CPF, nem mascarado. O banco dele não escreve
documento na descrição.

Então a consulta de CNAE alcançaria **0%** do razão e não deve ser construída. O
spike custou pouco e evitou isso.

Mas a consulta de formatos, que existia para explicar uma cobertura baixa,
mostrou outra coisa. Nas 25 formas mais frequentes:

| Padrão | Lançamentos |
|---|---|
| `AAA*AAA` — prefixo de agregador | 157 |
| `AAA ##/##` — parcela dentro do nome | 154 |
| **somados** | **311, ou 35% do razão** |

E 35% é o piso, porque são só as 25 formas mais comuns.

Os dois são mecânicos e locais. A parcela escrita **dentro do nome** significa
que `LOJA X 03/10` e `LOJA X 04/10` são strings diferentes: uma regra de
estabelecimento escrita numa nunca casa com a outra, e a fila de revisão não
consegue agrupá-las. É boa parte do motivo de uma fila de 24 parecer 24 decisões
sem relação.

E `PAYPAL*SPOTIFY` é uma cobrança da Spotify, não da PayPal. Agrupar pelo texto
cru arquiva os clientes de cada agregador debaixo do agregador.

`normalizeMerchant` resolve os dois, e o agrupamento da fila passou a usá-lo.
`tool/sql/merchant_collapse.sql` mede quanto isso junta no razão real.

**A lição:** a pergunta que o dono fez tinha resposta negativa, e a consulta que
existia só para depurar a resposta negativa achou um problema maior — que já
estava atrapalhando a tela sobre a qual ele tinha reclamado dois dias antes.
