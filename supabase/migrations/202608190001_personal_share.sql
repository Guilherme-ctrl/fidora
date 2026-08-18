-- The part of a purchase that is actually yours.
--
-- `include_in_totals` already answers this all-or-nothing: an item is yours or
-- it is not. A shared dinner is neither. `personal_amount` is the graduated
-- version — null keeps the existing meaning, that the whole charge is yours,
-- so every existing row stays correct without a backfill.
--
-- The statement total is deliberately not affected. `amount` remains what the
-- issuer charged, the invoice trigger keeps summing it, and the card limit
-- keeps counting it: the bank committed the full amount regardless of who
-- eventually pays you back. Only the personal figures — dashboards, budgets,
-- goals — use the share.
alter table public.transactions
  add column if not exists personal_amount numeric(14,2);

alter table public.transactions
  drop constraint if exists transactions_personal_amount_range;
alter table public.transactions
  add constraint transactions_personal_amount_range
  check (
    personal_amount is null
    or (personal_amount >= 0 and personal_amount <= amount)
  );

comment on column public.transactions.personal_amount is
  'Your share of the charge. Null means all of it. Never above amount.';
