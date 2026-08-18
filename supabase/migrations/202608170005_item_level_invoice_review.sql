-- Add item-level import decisions without weakening the balanced-statement gate.

alter function public.preview_finora_invoice_import(jsonb)
  rename to preview_finora_invoice_import_v1;
alter function public.import_finora_invoice(jsonb)
  rename to import_finora_invoice_v1;

revoke all on function public.preview_finora_invoice_import_v1(jsonb) from public, anon, authenticated;
revoke all on function public.import_finora_invoice_v1(jsonb) from public, anon, authenticated;

create or replace function public.preview_finora_invoice_import(p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public, private as $$
declare
  target_user uuid := auth.uid();
  target_card uuid;
  item jsonb;
  existing_id uuid;
  matched_ids uuid[] := array[]::uuid[];
  summary jsonb;
  item_results jsonb := '[]'::jsonb;
  missing_categories text[] := array[]::text[];
  included_reviews integer := 0;
  disposition text;
begin
  if target_user is null then raise exception 'authentication_required'; end if;
  summary := public.preview_finora_invoice_import_v1(p_payload);

  select id into target_card from public.cards
   where user_id = target_user
     and last_four = p_payload->'invoice'->>'card_last_four'
     and active = true;

  select coalesce(array_agg(name order by name), '{}') into missing_categories
    from (
      select distinct value->>'category' as name
        from jsonb_array_elements(p_payload->'transactions')
       where nullif(value->>'category', '') is not null
         and value->>'movement_type' <> 'transfer'
         and coalesce((value->>'include_in_totals')::boolean, true)
      except
      select name from public.categories where user_id = target_user
    ) missing;

  for item in select value from jsonb_array_elements(p_payload->'transactions') loop
    if coalesce((item->>'needs_review')::boolean, false)
       and coalesce((item->>'include_in_totals')::boolean, true)
       and item->>'movement_type' <> 'transfer' then
      included_reviews := included_reviews + 1;
    end if;

    select id into existing_id from public.transactions
     where user_id = target_user
       and dedup_key = 'finora-json:' || (item->>'external_id')
     limit 1;
    if existing_id is not null then
      disposition := 'duplicate';
    elsif item->>'movement_type' = 'transfer' then
      disposition := 'payment';
    else
      existing_id := null;
      select t.id into existing_id
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
       limit 1;
      if existing_id is null then
        disposition := 'new';
      else
        disposition := 'reconcile';
        matched_ids := array_append(matched_ids, existing_id);
      end if;
    end if;
    item_results := item_results || jsonb_build_array(jsonb_build_object(
      'external_id', item->>'external_id',
      'disposition', disposition
    ));
  end loop;

  return summary || jsonb_build_object(
    'missing_categories', to_jsonb(missing_categories),
    'reviews', included_reviews,
    'items', item_results
  );
end;
$$;

create or replace function public.import_finora_invoice(p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public, private as $$
declare
  target_user uuid := auth.uid();
  processed_payload jsonb;
  processed_transactions jsonb;
  item jsonb;
  result jsonb;
  target_card uuid;
  target_invoice uuid;
  target_transaction uuid;
  expected_personal_total numeric := 0;
  actual_personal_total numeric;
  included boolean;
  review_count integer := 0;
begin
  if target_user is null then raise exception 'authentication_required'; end if;

  select coalesce(jsonb_agg(
    case
      when not coalesce((value->>'include_in_totals')::boolean, true)
        then value || jsonb_build_object(
          'original_category', value->'category',
          'category', null,
          'needs_review', false
        )
      else value
    end
  ), '[]'::jsonb) into processed_transactions
  from jsonb_array_elements(p_payload->'transactions');

  processed_payload := jsonb_set(p_payload, '{transactions}', processed_transactions);
  result := public.import_finora_invoice_v1(processed_payload);
  if coalesce((result->>'duplicate_batch')::boolean, false) then return result; end if;

  select id into target_card from public.cards
   where user_id = target_user
     and last_four = p_payload->'invoice'->>'card_last_four';
  select id into target_invoice from public.invoices
   where user_id = target_user
     and card_id = target_card
     and reference_month = (p_payload->'invoice'->>'reference_month')::date;

  for item in select value from jsonb_array_elements(p_payload->'transactions') loop
    included := item->>'movement_type' <> 'transfer'
      and coalesce((item->>'include_in_totals')::boolean, true);
    if included then
      expected_personal_total := expected_personal_total
        + private.invoice_amount_impact((item->>'amount')::numeric, item->>'movement_type');
      if coalesce((item->>'needs_review')::boolean, false) then
        review_count := review_count + 1;
      end if;
    end if;

    select id into target_transaction from public.transactions
     where user_id = target_user
       and (
         raw_payload->>'external_id' = item->>'external_id'
         or raw_payload->'invoice_import'->>'external_id' = item->>'external_id'
       )
     order by updated_at desc
     limit 1 for update;
    if target_transaction is null then
      raise exception 'imported_transaction_not_found:%', item->>'external_id';
    end if;

    update public.transactions set
      include_in_totals = included,
      status = case
        when not included then 'ignored'
        when coalesce((item->>'needs_review')::boolean, false) then 'pending'
        else 'confirmed'
      end,
      raw_payload = raw_payload || jsonb_build_object('item_review', item),
      updated_at = now()
    where id = target_transaction;

    if not included then
      delete from public.review_queue
       where user_id = target_user and transaction_id = target_transaction;
    end if;
  end loop;

  select total into actual_personal_total from public.invoices where id = target_invoice;
  if abs(actual_personal_total - expected_personal_total) > 0.01 then
    raise exception 'personal_total_mismatch:%:%', actual_personal_total, expected_personal_total;
  end if;

  update public.import_batches set rows_to_review = review_count
   where user_id = target_user and file_hash = p_payload->>'request_id';
  return result || jsonb_build_object(
    'reviews', review_count,
    'personal_total', actual_personal_total
  );
end;
$$;

revoke all on function public.preview_finora_invoice_import(jsonb) from public, anon;
revoke all on function public.import_finora_invoice(jsonb) from public, anon;
grant execute on function public.preview_finora_invoice_import(jsonb) to authenticated;
grant execute on function public.import_finora_invoice(jsonb) to authenticated;
