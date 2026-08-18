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

## Open validation gates

- Real-device Shortcut test: requires a deployed Supabase project, token and selected Wallet card.
- Remote import claim: requires creating the matching Finora Auth account.
