-- Record who produced an import instead of assuming ChatGPT did.
--
-- `raw_source` was written as the literal 'chatgpt' for every imported row.
-- True while ChatGPT-produced JSON was the only way in; with the spreadsheet
-- reader it became a factual error — a statement exported from the bank and
-- read by the app would be filed as if a model had transcribed it. The payload
-- now declares its own source, and the fallback keeps every existing producer
-- writing exactly what it wrote before.
--
-- The target is `import_finora_invoice_v1`, NOT `import_finora_invoice`.
-- Migration 202608170005 renamed the original body to `_v1` and made
-- `import_finora_invoice` a wrapper that adds item-level review on top of it.
-- The first version of this migration restated the *wrapper* with the old
-- body, which would have silently reverted that review in production. The
-- local suite passed anyway, because nothing in it covered what the wrapper
-- adds — see the assertions added to 04_import_test.sql.

create or replace function public.import_finora_invoice_v1(p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public, private as $$
declare
  target_user uuid := auth.uid();
  target_card uuid;
  target_invoice uuid;
  target_category uuid;
  target_holder uuid;
  target_transaction uuid;
  item jsonb;
  matched_ids uuid[] := array[]::uuid[];
  missing_categories text[];
  computed_total numeric := 0;
  invoice_total numeric;
  created_count integer := 0;
  reconciled_count integer := 0;
  duplicate_count integer := 0;
  review_count integer := 0;
  row_count integer := 0;
  payment_count integer := 0;
  request_id text := p_payload->>'request_id';
  allow_categories boolean := coalesce((p_payload->'processing'->>'create_missing_categories')::boolean, false);
  confidence_value text;
  transaction_status text;
begin
  if target_user is null then raise exception 'authentication_required'; end if;
  if p_payload->>'schema_version' <> '1.0' or nullif(request_id, '') is null then
    raise exception 'invalid_import_contract';
  end if;
  if p_payload->'transactions' is null or jsonb_array_length(p_payload->'transactions') = 0 then
    raise exception 'empty_invoice';
  end if;

  if exists(select 1 from public.import_batches where user_id = target_user and file_hash = request_id) then
    return jsonb_build_object('created', 0, 'reconciled', 0, 'reviews', 0, 'duplicate_batch', true);
  end if;

  select id into target_card from public.cards
   where user_id = target_user
     and last_four = p_payload->'invoice'->>'card_last_four'
     and active = true;
  if target_card is null then raise exception 'card_not_found:%', p_payload->'invoice'->>'card_last_four'; end if;

  select coalesce(array_agg(name order by name), '{}') into missing_categories
    from (
      select distinct value->>'category' as name
        from jsonb_array_elements(p_payload->'transactions')
       where nullif(value->>'category', '') is not null
      except
      select name from public.categories where user_id = target_user
    ) missing;
  if cardinality(missing_categories) > 0 and not allow_categories then
    raise exception 'missing_categories:%', array_to_string(missing_categories, ', ');
  end if;
  if allow_categories then
    insert into public.categories(user_id, name, sort_order, active)
      select target_user, value, 100, true from unnest(missing_categories) value
      on conflict(user_id, name) do update set active = true;
  end if;

  for item in select value from jsonb_array_elements(p_payload->'transactions') loop
    computed_total := computed_total + private.invoice_amount_impact((item->>'amount')::numeric, item->>'movement_type');
  end loop;
  if abs(computed_total - (p_payload->'invoice'->>'statement_total')::numeric) > 0.01 then
    raise exception 'statement_total_mismatch:%:%', computed_total, p_payload->'invoice'->>'statement_total';
  end if;

  insert into public.invoices(
    user_id, card_id, reference_month, due_date, total, status, source_file,
    closing_date, statement_total, raw_status
  ) values (
    target_user, target_card, (p_payload->'invoice'->>'reference_month')::date,
    (p_payload->'invoice'->>'due_date')::date, 0, 'open', p_payload->'invoice'->>'source_file',
    nullif(p_payload->'invoice'->>'closing_date', '')::date,
    (p_payload->'invoice'->>'statement_total')::numeric, 'Importada via JSON'
  ) on conflict(card_id, reference_month) do update set
    due_date = excluded.due_date,
    source_file = excluded.source_file,
    closing_date = coalesce(excluded.closing_date, public.invoices.closing_date),
    statement_total = excluded.statement_total
  returning id into target_invoice;

  for item in select value from jsonb_array_elements(p_payload->'transactions') loop
    row_count := row_count + 1;
    target_category := null;
    target_holder := null;
    target_transaction := null;
    if nullif(item->>'category', '') is not null then
      select id into target_category from public.categories
       where user_id = target_user and name = item->>'category';
    end if;
    if nullif(item->>'notes', '') like 'Portador:%' then
      select id into target_holder from public.holders
       where user_id = target_user
         and lower(name) = lower(trim(split_part(split_part(item->>'notes', 'Portador:', 2), '.', 1)))
       limit 1;
    end if;

    select id into target_transaction from public.transactions
     where user_id = target_user and dedup_key = 'finora-json:' || (item->>'external_id')
     limit 1;
    if target_transaction is not null then
      duplicate_count := duplicate_count + 1;
      continue;
    end if;

    if item->>'movement_type' <> 'transfer' then
      select t.id into target_transaction
        from public.transactions t
       where t.user_id = target_user
         and t.card_id = target_card
         and t.source = 'apple_pay'
         and t.status <> 'ignored'
         and abs(t.amount - (item->>'amount')::numeric) < 0.01
         and t.purchased_at::date between (item->>'purchased_at')::date - 1 and (item->>'purchased_at')::date + 1
         and not (t.id = any(matched_ids))
       order by (t.merchant_normalized = item->>'merchant_normalized') desc,
                abs(extract(epoch from (t.purchased_at - private.parse_import_timestamp(item->>'purchased_at'))))
       limit 1 for update;
    end if;

    confidence_value := case
      when (item->>'confidence')::numeric >= 0.9 then 'high'
      when (item->>'confidence')::numeric >= 0.7 then 'medium'
      else 'low'
    end;
    transaction_status := case
      when item->>'movement_type' = 'transfer' then 'ignored'
      when coalesce((item->>'needs_review')::boolean, false) then 'pending'
      else 'confirmed'
    end;

    if target_transaction is not null then
      update public.transactions set
        competence = (p_payload->'invoice'->>'reference_month')::date,
        invoice_id = target_invoice,
        holder_id = coalesce(target_holder, holder_id),
        merchant_original = item->>'merchant_original',
        merchant_normalized = item->>'merchant_normalized',
        movement_type = item->>'movement_type',
        modality = item->>'modality',
        installment_current = nullif(item->'installment'->>'current', '')::integer,
        installment_total = nullif(item->'installment'->>'total', '')::integer,
        total_purchase_amount = nullif(item->'installment'->>'total_purchase_amount', '')::numeric,
        category_id = coalesce(target_category, category_id),
        subcategory = coalesce(item->>'subcategory', subcategory),
        status = transaction_status,
        source_file = p_payload->'invoice'->>'source_file',
        confidence = confidence_value,
        reviewed = not coalesce((item->>'needs_review')::boolean, false),
        notes = coalesce(item->>'notes', notes),
        raw_source = 'apple_pay+invoice_import',
        raw_payload = raw_payload || jsonb_build_object('invoice_import', item),
        updated_at = now()
      where id = target_transaction;
      reconciled_count := reconciled_count + 1;
      matched_ids := array_append(matched_ids, target_transaction);
    else
      insert into public.transactions(
        user_id, dedup_key, purchased_at, competence, card_id, invoice_id, holder_id,
        merchant_original, merchant_normalized, amount, movement_type, modality,
        installment_current, installment_total, total_purchase_amount, category_id,
        subcategory, status, source, source_file, confidence, reviewed, notes,
        include_in_totals, raw_source, raw_payload
      ) values (
        target_user, 'finora-json:' || (item->>'external_id'), private.parse_import_timestamp(item->>'purchased_at'),
        (p_payload->'invoice'->>'reference_month')::date, target_card,
        case when item->>'movement_type' = 'transfer' then null else target_invoice end,
        target_holder, item->>'merchant_original', item->>'merchant_normalized',
        (item->>'amount')::numeric, item->>'movement_type', item->>'modality',
        nullif(item->'installment'->>'current', '')::integer,
        nullif(item->'installment'->>'total', '')::integer,
        nullif(item->'installment'->>'total_purchase_amount', '')::numeric,
        target_category, item->>'subcategory', transaction_status, 'invoice_import',
        p_payload->'invoice'->>'source_file', confidence_value,
        not coalesce((item->>'needs_review')::boolean, false), item->>'notes',
        item->>'movement_type' <> 'transfer', coalesce(p_payload->>'source', 'chatgpt'), item
      ) returning id into target_transaction;
      created_count := created_count + 1;
      if item->>'movement_type' = 'transfer' then payment_count := payment_count + 1; end if;
    end if;

    if coalesce((item->>'needs_review')::boolean, false) then
      insert into public.review_queue(
        user_id, transaction_id, reason, status, item_type, description, suggested_action, raw_payload
      ) values (
        target_user, target_transaction, coalesce(item->>'review_reason', 'Classificação pendente'),
        'pending', 'transaction', item->>'merchant_original', 'Confirmar categoria', item
      ) on conflict(transaction_id, reason) do update set
        status = 'pending', description = excluded.description, raw_payload = excluded.raw_payload;
      review_count := review_count + 1;
    end if;
  end loop;

  select total into invoice_total from public.invoices where id = target_invoice;
  if abs(invoice_total - (p_payload->'invoice'->>'statement_total')::numeric) > 0.01 then
    raise exception 'reconciled_total_mismatch:%:%', invoice_total, p_payload->'invoice'->>'statement_total';
  end if;

  insert into public.import_batches(
    user_id, card_id, file_name, file_hash, rows_read, rows_created, rows_updated,
    rows_duplicated, rows_to_review, imported_at, raw_payload
  ) values (
    target_user, target_card, p_payload->'invoice'->>'source_file', request_id,
    row_count, created_count, reconciled_count, duplicate_count, review_count, current_date, p_payload
  );

  return jsonb_build_object(
    'created', created_count,
    'reconciled', reconciled_count,
    'duplicates', duplicate_count,
    'reviews', review_count,
    'payments_ignored', payment_count,
    'duplicate_batch', false,
    'invoice_id', target_invoice
  );
end;
$$;
