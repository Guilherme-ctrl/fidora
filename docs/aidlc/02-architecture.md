# AIDLC — Architecture

## System context

```text
Apple Pay transaction
  -> iOS Shortcut asks for category
  -> Supabase Edge Function authenticates token
  -> card/category lookup + competence + deduplication
  -> Postgres transaction and invoice
  -> Flutter iOS/web query through authenticated RLS session
```

## Boundaries

Two roots, since the architecture remake of 20 Aug 2026 — see
`reference-architecture.md` for the standard and `../arquitetura-auditoria.md`
for the audit that measured against it.

```text
lib/
├── core/      config, DI, errors, logging, platform, routing, theme,
│              design system — transversal, no feature owns it
└── features/  auth, ledger, overview, transactions, invoices, catalog,
               imports, review, reminders, settings, shell, shared
```

Inside a feature: `domain/` (entities, contracts, rules, use cases), `infra/`
(repository implementations, row mappers, external SDKs), `presenter/` (pages,
cubits, states, widgets). Not every feature has all three, and none is created
empty to satisfy the pattern.

- Domain defines contracts and depends on no framework: `lib/features/*/domain`
  imports `dart:`, `clock`, `crypto` and `intl`, nothing else.
- Infra implements them and is the only place that knows Supabase, ML Kit or a
  spreadsheet decoder.
- Presenter consumes the domain through Cubits and owns every user-facing
  sentence.
- Ingestion: Edge Functions; never expose privileged keys to clients.

### AD-006 — Failures are a sealed vocabulary

Business, technical and unexpected. Infra maps its own exceptions at its
boundary; presentation chooses the words. No layer below the screen writes what
the person reads.

### AD-007 — Bloc, by owner decision

`flutter_bloc` replaced Riverpod on 20 Aug 2026 for conformance with the
reference architecture, not to fix a defect. Recorded in `audit.md` with the
recommendation it overrode.

## Key decisions

### AD-001 — Shortcut as transaction sensor

The app does not poll Wallet. The Apple-supported Transaction automation sends a narrow payload to the backend. This is reliable across app termination and keeps the Flutter app out of the payment path.

### AD-002 — Server-side financial rules

Card lookup, invoice competence, token validation and deduplication happen in the Edge Function/database. Client calculations are previews only.

### AD-003 — Invoice totals are derived

A database trigger recalculates invoice totals from non-ignored transactions. This avoids drift from manual total updates.

### AD-004 — Replaceable repositories

The UI uses a repository contract. Demo data enables immediate product review; Supabase is enabled through compile-time configuration.

### AD-005 — Web deployment

The same Flutter build targets web. Vercel can host `build/web`; it does not hold the database or privileged secrets.
