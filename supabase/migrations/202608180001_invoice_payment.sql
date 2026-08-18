-- Marking an invoice paid needs somewhere to record when.
--
-- `status` already accepted 'paid', but nothing wrote it and there was no place
-- for the date, so an invoice that had been settled looked identical to one
-- still waiting. Additive and nullable: existing rows stay valid.
alter table public.invoices
  add column if not exists paid_at timestamptz;

-- Backfill runs before the constraint, not after: any row already marked paid
-- would fail the check on the way in. created_at is the closest defensible
-- stand-in for a payment date nobody recorded.
update public.invoices set paid_at = created_at
  where status = 'paid' and paid_at is null;

-- Paid means paid_at is set, and vice versa. Without this the two can drift and
-- the interface has to guess which one to trust.
alter table public.invoices
  drop constraint if exists invoices_paid_at_matches_status;
alter table public.invoices
  add constraint invoices_paid_at_matches_status
  check ((status = 'paid') = (paid_at is not null));

create index if not exists invoices_user_status_idx
  on public.invoices(user_id, status);
