# AIDLC — Foundation

## Intent

Build a private personal-finance product for iOS and web that is faster to maintain than the current spreadsheet while preserving its financial model. The product must capture an Apple Pay purchase at the moment it happens, request a category, reconcile that capture with future card statements, and make spending understandable.

## Human-owned decisions

- Flutter targets iOS and web from one codebase.
- Supabase is the system of record.
- The iOS Transaction automation remains the Apple Pay trigger.
- TestFlight is the development distribution channel; production distribution is decided later.
- Portuguese (Brazil), BRL and America/Sao_Paulo are the initial locale defaults.

## Quality principles

- No silent duplicate charges.
- Totals are reproducible from transactions, not hand-maintained.
- Every imported or captured transaction retains its origin.
- Personal data is isolated with RLS.
- The app remains usable on narrow iPhone screens and wide web screens.

## Current gate

Approved by the initial user request for project initiation. Production data migration and release require explicit later approval.
