-- What the account held before the ledger starts.
--
-- Without it, summing the movements gives a delta, not a balance: an account
-- that already had money in it before the first imported transaction would
-- report far less than it holds. Defaulting to zero keeps every existing row
-- valid and makes the number mean "movement so far" until someone sets it,
-- which is the honest reading of a blank opening balance.
alter table public.accounts
  add column if not exists opening_balance numeric(14,2) not null default 0;

comment on column public.accounts.opening_balance is
  'Balance before the first recorded transaction. Added to movements to get the current balance.';

create index if not exists transactions_account_idx
  on public.transactions(user_id, account_id)
  where account_id is not null;
