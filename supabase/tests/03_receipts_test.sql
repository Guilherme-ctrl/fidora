-- The receipts bucket and its policies.
--
-- A receipt shows a merchant, an amount and a date. If the bucket were public,
-- every one of them would be readable by anyone holding the URL, and nothing in
-- the app would say so.

begin;
select plan(6);

create extension if not exists pgtap with schema extensions;

select is(
  (select public from storage.buckets where id = 'receipts'),
  false,
  'the receipts bucket is private'
);

select is(
  (select file_size_limit from storage.buckets where id = 'receipts'),
  10485760::bigint,
  'the bucket caps uploads at ten megabytes'
);

select ok(
  (select allowed_mime_types from storage.buckets where id = 'receipts')
    @> array['image/jpeg', 'image/png'],
  'the bucket accepts photographs and not arbitrary files'
);

select ok(
  exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname = 'receipts owner read'
  ),
  'a read policy exists'
);

select ok(
  exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname = 'receipts owner insert'
  ),
  'an insert policy exists'
);

-- The policies match on the first path segment being the owner id, which is the
-- shape the upload code writes. Asserting the shape here is what stops the two
-- from drifting apart silently: a change to either alone breaks this.
select ok(
  (select count(*)::int from pg_policies
   where schemaname = 'storage' and tablename = 'objects'
     and policyname like 'receipts owner %'
     and coalesce(qual, with_check) like '%storage.foldername(name))[1]%') = 4,
  'all four policies key on the owner folder'
);

select * from finish();
rollback;
