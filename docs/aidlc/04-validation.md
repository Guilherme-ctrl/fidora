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
