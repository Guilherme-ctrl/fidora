# AIDLC — Discovery

## Existing system observed

The spreadsheet `Financeiro AI — Controle Mestre` contains the tabs Config, Cartões, Faturas, Transações, Parcelamentos, Dashboard, Painel Metas, Importações, Revisões, Portadores and Metas.

The transaction ledger includes identity and deduplication, purchase date, invoice competence, card/final/holder, original and normalized descriptions, value, movement type, installment attributes, category/subcategory, frequency, status, origin, source file, confidence, review state and notes.

## Actors

- Owner: manages all personal finance data.
- Additional holder: can have charges ignored or included by policy.
- iOS Shortcut: trusted ingestion client with a revocable token.
- Statement importer: batch ingestion client with source lineage.

## Primary journeys

1. Pay with Apple Pay, choose category, see the transaction in history and the correct invoice.
2. Review monthly spending and category distribution.
3. Open a card and understand open/closed invoices and installments.
4. Import a statement without duplicating Shortcut captures.
5. Resolve low-confidence classification and teach a merchant rule.
6. Track savings goals.

## Risks surfaced

- Apple Pay cannot be listened to directly by an ordinary Flutter process; the Shortcut is required.
- Merchant name and amount formats vary by issuer and locale.
- Shortcut capture and statement import can describe the same purchase differently.
- TestFlight builds expire, so it is a development channel rather than permanent product distribution.
- Financial data needs recoverability, access isolation and an auditable source.
