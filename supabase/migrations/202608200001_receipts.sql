-- Receipt images attached to transactions.
--
-- The file lives in Storage and the row keeps only its path. Storing the image
-- in Postgres would bloat every snapshot query that selects transactions, and
-- the ledger is read in full on each load.

alter table public.transactions
  add column if not exists receipt_path text;

comment on column public.transactions.receipt_path is
  'Object path inside the private `receipts` bucket, or null. Always prefixed '
  'with the owner user id, which is what the storage policies match on.';

-- Private on purpose: a receipt carries a merchant, an amount and a date, and
-- a public bucket would make every one of them readable by anyone holding the
-- URL. Reads go through a signed URL minted per view.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'receipts',
  'receipts',
  false,
  10485760, -- 10 MB: a phone photo of a receipt, not a scan archive.
  array['image/jpeg', 'image/png', 'image/heic', 'image/webp']
)
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- Ownership is the first path segment. `storage.foldername` returns the path
-- split on slashes, so `foldername(name))[1]` is the user id folder — the same
-- shape the upload code writes.
drop policy if exists "receipts owner read" on storage.objects;
create policy "receipts owner read" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'receipts'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "receipts owner insert" on storage.objects;
create policy "receipts owner insert" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'receipts'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "receipts owner update" on storage.objects;
create policy "receipts owner update" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'receipts'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'receipts'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Deleting the row does not delete the object: Postgres cannot reach into
-- Storage. The app removes the file before clearing the column, and an
-- orphaned object stays private and unreferenced rather than becoming public.
drop policy if exists "receipts owner delete" on storage.objects;
create policy "receipts owner delete" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'receipts'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
