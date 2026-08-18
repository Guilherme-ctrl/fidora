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

- Presentation: responsive Flutter pages.
- Application: providers and use-case orchestration.
- Domain: financial entities and deterministic rules.
- Data: repository implementations.
- Ingestion: Edge Functions; never expose privileged keys to clients.

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
