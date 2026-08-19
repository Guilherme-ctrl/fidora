-- Constraints the app relies on but never exercises.
--
-- Everything that talks to Supabase is covered only against the in-memory demo
-- repository, which cannot reach a check constraint. These run against a real
-- Postgres started by `supabase start`.

begin;
select plan(11);

create extension if not exists pgtap with schema extensions;

-- A user to own the rows. Inserting into auth.users directly is what the
-- Supabase CLI's own tests do; going through the Auth API would need a running
-- server and a network round trip per test.
insert into auth.users (id, email, encrypted_password, email_confirmed_at,
                        created_at, updated_at, aud, role)
values ('11111111-1111-1111-1111-111111111111', 'owner@finora.test', '',
        now(), now(), now(), 'authenticated', 'authenticated')
on conflict (id) do nothing;

insert into public.profiles (id, currency)
values ('11111111-1111-1111-1111-111111111111', 'BRL')
on conflict (id) do nothing;

insert into public.cards (id, user_id, name, bank, last_four, closing_day, due_day)
values ('22222222-2222-2222-2222-222222222222',
        '11111111-1111-1111-1111-111111111111',
        'Teste', 'Banco', '1234', 20, 27);

-- ---------------------------------------------------------------- invoices --

select lives_ok(
  $$insert into public.invoices (id, user_id, card_id, reference_month, total, due_date, status)
    values ('33333333-3333-3333-3333-333333333333',
            '11111111-1111-1111-1111-111111111111',
            '22222222-2222-2222-2222-222222222222',
            date '2026-08-01', 100, date '2026-09-09', 'open')$$,
  'an open invoice with no paid_at is accepted'
);

select throws_ok(
  $$update public.invoices set status = 'paid'
    where id = '33333333-3333-3333-3333-333333333333'$$,
  null,
  null,
  'marking an invoice paid without a paid_at is rejected'
);

select lives_ok(
  $$update public.invoices set status = 'paid', paid_at = now()
    where id = '33333333-3333-3333-3333-333333333333'$$,
  'paid with a paid_at is accepted'
);

select throws_ok(
  $$update public.invoices set status = 'open'
    where id = '33333333-3333-3333-3333-333333333333'$$,
  null,
  null,
  'reopening an invoice while keeping paid_at is rejected'
);

-- ------------------------------------------------------------ transactions --

select lives_ok(
  $$insert into public.transactions
      (user_id, dedup_key, purchased_at, competence, merchant_original,
       merchant_normalized, amount)
    values ('11111111-1111-1111-1111-111111111111', 'k1', now(),
            date '2026-08-01', 'PADARIA', 'padaria', 24.80)$$,
  'a plain transaction is accepted'
);

select throws_ok(
  $$insert into public.transactions
      (user_id, dedup_key, purchased_at, competence, merchant_original,
       merchant_normalized, amount)
    values ('11111111-1111-1111-1111-111111111111', 'k2', now(),
            date '2026-08-15', 'X', 'x', 10)$$,
  null,
  null,
  'a competence that is not the first of a month is rejected'
);

select throws_ok(
  $$insert into public.transactions
      (user_id, dedup_key, purchased_at, competence, merchant_original,
       merchant_normalized, amount, personal_amount)
    values ('11111111-1111-1111-1111-111111111111', 'k3', now(),
            date '2026-08-01', 'X', 'x', 10, 20)$$,
  null,
  null,
  'a personal share larger than the amount is rejected'
);

select lives_ok(
  $$insert into public.transactions
      (user_id, dedup_key, purchased_at, competence, merchant_original,
       merchant_normalized, amount, personal_amount)
    values ('11111111-1111-1111-1111-111111111111', 'k4', now(),
            date '2026-08-01', 'X', 'x', 100, 50)$$,
  'a personal share within the amount is accepted'
);

select throws_ok(
  $$insert into public.transactions
      (user_id, dedup_key, purchased_at, competence, merchant_original,
       merchant_normalized, amount)
    values ('11111111-1111-1111-1111-111111111111', 'k1', now(),
            date '2026-08-01', 'OUTRO', 'outro', 5)$$,
  null,
  null,
  'the same dedup key twice for one user is rejected'
);

-- ---------------------------------------------------------------- accounts --

select lives_ok(
  $$insert into public.accounts (user_id, name, bank)
    values ('11111111-1111-1111-1111-111111111111', 'Conta', 'Banco')$$,
  'an account without an opening balance is accepted'
);

select is(
  (select opening_balance from public.accounts
   where user_id = '11111111-1111-1111-1111-111111111111' limit 1),
  0::numeric,
  'the opening balance defaults to zero rather than null'
);

select * from finish();
rollback;
