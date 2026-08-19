-- Row level security is what makes the publishable key safe to ship in the
-- client. It has never been tested — the app's own suite cannot reach it, and
-- "the policies exist" is not the same claim as "they isolate".

begin;
select plan(8);

create extension if not exists pgtap with schema extensions;

insert into auth.users (id, email, encrypted_password, email_confirmed_at,
                        created_at, updated_at, aud, role)
values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'a@finora.test', '', now(), now(), now(), 'authenticated', 'authenticated'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'b@finora.test', '', now(), now(), now(), 'authenticated', 'authenticated')
on conflict (id) do nothing;

insert into public.profiles (id, currency) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'BRL'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'BRL')
on conflict (id) do nothing;

insert into public.transactions
  (user_id, dedup_key, purchased_at, competence, merchant_original,
   merchant_normalized, amount)
values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'a1', now(), date '2026-08-01', 'A', 'a', 10),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'b1', now(), date '2026-08-01', 'B', 'b', 20);

select ok(
  (select relrowsecurity from pg_class where oid = 'public.transactions'::regclass),
  'row level security is enabled on transactions'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.cards'::regclass),
  'row level security is enabled on cards'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.invoices'::regclass),
  'row level security is enabled on invoices'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.review_queue'::regclass),
  'row level security is enabled on review_queue'
);

-- Become user A. `request.jwt.claims` is what auth.uid() reads.
set local role authenticated;
set local request.jwt.claims = '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","role":"authenticated"}';

select is(
  (select count(*)::int from public.transactions),
  1,
  'a signed-in user sees only their own transactions'
);

select is(
  (select merchant_original from public.transactions limit 1),
  'A',
  'and the one they see is theirs'
);

-- Writing into someone else's account must fail rather than silently succeed.
select throws_ok(
  $$insert into public.transactions
      (user_id, dedup_key, purchased_at, competence, merchant_original,
       merchant_normalized, amount)
    values ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'a2', now(),
            date '2026-08-01', 'INTRUSO', 'intruso', 1)$$,
  '42501',
  null,
  'writing a row owned by another user is refused'
);

select is(
  (select count(*)::int from public.transactions
   where user_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
  0,
  'and the other user''s rows stay invisible'
);

reset role;
select * from finish();
rollback;
