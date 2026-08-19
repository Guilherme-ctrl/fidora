-- The invoice import RPC.
--
-- This is the largest piece of untested logic in the system: several hundred
-- lines of PL/pgSQL that create, reconcile, deduplicate and queue for review,
-- reached only through a network call that no test has ever made.

begin;
select plan(10);

create extension if not exists pgtap with schema extensions;

insert into auth.users (id, email, encrypted_password, email_confirmed_at,
                        created_at, updated_at, aud, role)
values ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'import@finora.test', '',
        now(), now(), now(), 'authenticated', 'authenticated')
on conflict (id) do nothing;

insert into public.profiles (id, currency)
values ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'BRL')
on conflict (id) do nothing;

insert into public.cards (user_id, name, bank, last_four, closing_day, due_day)
values ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'Cartão', 'Banco', '1234', 20, 27);

-- Creating a profile seeds a default category set, so this is an upsert
-- rather than an insert. A plain insert collided and took the whole file down.
insert into public.categories (user_id, name, sort_order)
values ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'Alimentação', 1)
on conflict (user_id, name) do nothing;

set local role authenticated;
set local request.jwt.claims = '{"sub":"cccccccc-cccc-cccc-cccc-cccccccccccc","role":"authenticated"}';

create temporary table payload_holder (payload jsonb) on commit drop;
insert into payload_holder values ($json${
  "schema_version": "1.0",
  "source": "sheet",
  "request_id": "sheet:test-0001",
  "invoice": {
    "bank": "Banco",
    "card_last_four": "1234",
    "reference_month": "2026-08-01",
    "due_date": "2026-09-09",
    "currency": "BRL",
    "source_file": "extrato.csv",
    "statement_total": 124.80
  },
  "processing": {"create_missing_categories": false},
  "transactions": [
    {
      "external_id": "sheet:aaa",
      "purchased_at": "2026-08-15",
      "merchant_original": "PADARIA CENTRAL",
      "merchant_normalized": "padaria central",
      "amount": 24.80,
      "movement_type": "purchase",
      "modality": "cash",
      "confidence": 0.0,
      "needs_review": true,
      "review_reason": "Categoria não definida pela planilha"
    },
    {
      "external_id": "sheet:bbb",
      "purchased_at": "2026-08-16",
      "merchant_original": "MERCADO",
      "merchant_normalized": "mercado",
      "amount": 100.00,
      "movement_type": "purchase",
      "modality": "cash",
      "confidence": 0.0,
      "needs_review": true
    }
  ]
}$json$::jsonb);

-- --------------------------------------------------------------- preview --

select is(
  (select (public.preview_finora_invoice_import((select payload from payload_holder))->>'rows')::int),
  2,
  'the preview counts every row'
);

select is(
  (select (public.preview_finora_invoice_import((select payload from payload_holder))->>'already_imported')::boolean),
  false,
  'a first import is not reported as already imported'
);

-- ---------------------------------------------------------------- import --

select is(
  (select (public.import_finora_invoice((select payload from payload_holder))->>'created')::int),
  2,
  'both rows are created'
);

select is(
  (select count(*)::int from public.transactions
   where user_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'),
  2,
  'and they are in the ledger'
);

-- Every row declared needs_review, so every row should be queued. A row that
-- arrives unreviewed and is not queued is a purchase nobody will ever look at.
select is(
  (select count(*)::int from public.review_queue
   where user_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc' and status = 'pending'),
  2,
  'each row needing review is queued'
);

-- The provenance fix: the payload said "sheet", so the ledger must not claim a
-- model transcribed it.
select is(
  (select distinct raw_source from public.transactions
   where user_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'),
  'sheet',
  'the declared source is recorded, not the literal chatgpt'
);

-- ------------------------------------------------------- the two functions --

-- Migration 005 renamed the original body to `_v1` and made
-- `import_finora_invoice` a wrapper that adds item-level review. Nothing here
-- covered that, so a later migration restating the wrapper with the old body
-- passed the whole suite while quietly reverting the review. These three
-- assertions are what would have caught it.

select has_function(
  'public', 'import_finora_invoice_v1', array['jsonb'],
  'the original body still exists under its renamed identity'
);

select ok(
  pg_get_functiondef('public.import_finora_invoice(jsonb)'::regprocedure)
    like '%import_finora_invoice_v1%',
  'import_finora_invoice is still the wrapper, not a copy of the old body'
);

select ok(
  pg_get_functiondef('public.import_finora_invoice(jsonb)'::regprocedure)
    like '%item_review%',
  'and it still performs the item-level review'
);

-- ------------------------------------------------------------- duplicates --

select is(
  (select (public.import_finora_invoice((select payload from payload_holder))->>'duplicate_batch')::boolean),
  true,
  'importing the same file twice is recognised instead of duplicating it'
);

reset role;
select * from finish();
rollback;
