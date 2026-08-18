# Project intelligence

Read `docs/aidlc/00-foundation.md`, `01-discovery.md`, `02-architecture.md`, and `03-specification.md` before changing product behavior.

Rules:

- Supabase is the source of truth; never write financial data only to local UI state.
- A personal Apple Pay transaction enters through the iOS Shortcut and the `capture-transaction` Edge Function.
- Never ship a service-role key, Shortcut token, or financial fixture containing real personal data.
- Every table containing user data must have RLS and an ownership policy.
- Money uses decimal storage in Postgres and `double` only at the presentation boundary until a decimal value object is introduced.
- Invoice competence is determined by the card closing day and must have unit tests.
- Importing a statement must be idempotent and preserve source lineage.
- Update `docs/aidlc/04-validation.md` with evidence after meaningful validation.
