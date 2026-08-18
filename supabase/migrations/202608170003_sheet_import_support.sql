-- Expand the domain to preserve every source field used by the master sheet.
alter table public.cards
  add column if not exists legacy_id text,
  add column if not exists payment_account text;
create unique index if not exists cards_user_legacy_id_idx
  on public.cards(user_id, legacy_id) where legacy_id is not null;

alter table public.invoices
  add column if not exists legacy_id text,
  add column if not exists closing_date date,
  add column if not exists statement_total numeric(14,2),
  add column if not exists paid_amount numeric(14,2),
  add column if not exists paid_at date,
  add column if not exists raw_status text,
  add column if not exists notes text;
create unique index if not exists invoices_user_legacy_id_idx
  on public.invoices(user_id, legacy_id) where legacy_id is not null;

alter table public.transactions drop constraint if exists transactions_amount_check;
alter table public.transactions
  add column if not exists legacy_id text,
  add column if not exists include_in_totals boolean not null default true,
  add column if not exists raw_modality text,
  add column if not exists raw_status text,
  add column if not exists raw_source text,
  add column if not exists raw_payload jsonb not null default '{}'::jsonb;
create unique index if not exists transactions_user_legacy_id_idx
  on public.transactions(user_id, legacy_id) where legacy_id is not null;

alter table public.import_batches
  add column if not exists legacy_id text,
  add column if not exists imported_at date,
  add column if not exists raw_payload jsonb not null default '{}'::jsonb;
create unique index if not exists import_batches_user_legacy_id_idx
  on public.import_batches(user_id, legacy_id) where legacy_id is not null;

alter table public.review_queue alter column transaction_id drop not null;
alter table public.review_queue
  add column if not exists legacy_id text,
  add column if not exists item_type text,
  add column if not exists description text,
  add column if not exists suggested_action text,
  add column if not exists raw_payload jsonb not null default '{}'::jsonb;
create unique index if not exists review_queue_user_legacy_id_idx
  on public.review_queue(user_id, legacy_id) where legacy_id is not null;

alter table public.goals
  add column if not exists weekly_amount numeric(14,2),
  add column if not exists kind text not null default 'objective',
  add column if not exists priority text,
  add column if not exists notes text,
  add column if not exists raw_payload jsonb not null default '{}'::jsonb;

create table public.accounts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  bank text,
  account_type text not null default 'checking',
  include_in_totals boolean not null default true,
  active boolean not null default true,
  unique(user_id, name)
);

alter table public.transactions
  add column if not exists account_id uuid references public.accounts(id) on delete set null;

create table public.installment_plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  transaction_id uuid references public.transactions(id) on delete set null,
  legacy_purchase_id text not null,
  description text not null,
  card_label text,
  total_amount numeric(14,2),
  installment_amount numeric(14,2) not null,
  current_installment integer not null,
  total_installments integer not null,
  remaining_installments integer not null,
  final_installment_month date,
  status text not null,
  raw_payload jsonb not null default '{}'::jsonb,
  unique(user_id, legacy_purchase_id)
);

create table public.financial_plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  reference_month date,
  planned_income numeric(14,2),
  planned_expenses numeric(14,2),
  raw_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(user_id, name)
);

-- The payload is staged through service_role and is never readable by clients.
create table public.legacy_import_payloads (
  email text primary key check (email = lower(email)),
  source_spreadsheet_id text not null,
  payload jsonb not null,
  claimed_by uuid references auth.users(id) on delete set null,
  claimed_at timestamptz,
  created_at timestamptz not null default now()
);
alter table public.legacy_import_payloads enable row level security;
revoke all on public.legacy_import_payloads from anon, authenticated;
grant all on public.legacy_import_payloads to service_role;

alter table public.accounts enable row level security;
alter table public.installment_plans enable row level security;
alter table public.financial_plans enable row level security;
create policy "owner access" on public.accounts for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "owner access" on public.installment_plans for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "owner access" on public.financial_plans for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

grant select, insert, update, delete on public.accounts, public.installment_plans, public.financial_plans to authenticated;
grant all privileges on public.accounts, public.installment_plans, public.financial_plans to service_role;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create or replace function private.parse_money(value text)
returns numeric language plpgsql immutable as $$
declare cleaned text;
begin
  cleaned := regexp_replace(coalesce(value, ''), '[^0-9,.-]', '', 'g');
  if cleaned = '' or cleaned = '-' then return null; end if;
  if position(',' in cleaned) > 0 then
    cleaned := replace(replace(cleaned, '.', ''), ',', '.');
  end if;
  return cleaned::numeric;
exception when invalid_text_representation then return null;
end;
$$;

create or replace function private.parse_date_pt(value text)
returns date language plpgsql stable as $$
begin
  if nullif(trim(value), '') is null then return null; end if;
  return to_date(value, 'DD/MM/YYYY');
exception when others then return null;
end;
$$;

create or replace function private.parse_month(value text)
returns date language plpgsql stable as $$
declare parts text[];
begin
  if nullif(trim(value), '') is null then return null; end if;
  if value ~ '^\d{4}-\d{2}$' then return to_date(value || '-01', 'YYYY-MM-DD'); end if;
  parts := regexp_split_to_array(value, '/');
  if array_length(parts, 1) = 2 then
    return make_date(parts[2]::integer, parts[1]::integer, 1);
  end if;
  return null;
exception when others then return null;
end;
$$;

create or replace function private.import_finance_sheet(target_user uuid, p_payload jsonb)
returns void language plpgsql security definer set search_path = public, private as $$
declare item jsonb;
declare target_transaction uuid;
begin
  if not exists (select 1 from public.profiles where id = target_user) then
    raise exception 'Target profile does not exist';
  end if;

  for item in select value from jsonb_array_elements(p_payload->'categories') loop
    insert into public.categories(user_id, name, sort_order, active)
    values(target_user, item->>'Chave', 100, true)
    on conflict(user_id, name) do update set active = true;
  end loop;
  for item in select value from jsonb_array_elements(p_payload->'transactions') loop
    if nullif(item->>'Categoria', '') is not null then
      insert into public.categories(user_id, name, sort_order, active)
      values(target_user, item->>'Categoria', 100, true)
      on conflict(user_id, name) do nothing;
    end if;
  end loop;

  for item in select value from jsonb_array_elements(p_payload->'holders') loop
    insert into public.holders(user_id, name, include_in_totals)
    values(target_user, item->>'Nome Normalizado', upper(coalesce(item->>'Incluir nas Finanças', 'SIM')) = 'SIM')
    on conflict(user_id, name) do update set include_in_totals = excluded.include_in_totals;
  end loop;

  for item in select value from jsonb_array_elements(p_payload->'cards') loop
    insert into public.cards(
      user_id, holder_id, holder_name, bank, name, last_four, closing_day,
      due_day, credit_limit, include_in_totals, active, legacy_id, payment_account
    ) values (
      target_user,
      (select id from public.holders where user_id=target_user and name=item->>'Portador'),
      item->>'Portador', item->>'Banco', item->>'Nome', lpad(item->>'Final', 4, '0'),
      (item->>'Fechamento')::integer, (item->>'Vencimento')::integer,
      coalesce(private.parse_money(item->>'Limite'), 0), upper(coalesce(item->>'Considerar','SIM'))='SIM',
      lower(coalesce(item->>'Status','Ativo'))='ativo', item->>'ID', item->>'Conta Pagamento'
    ) on conflict(user_id, last_four) do update set
      holder_id=excluded.holder_id, holder_name=excluded.holder_name, bank=excluded.bank,
      name=excluded.name, closing_day=excluded.closing_day, due_day=excluded.due_day,
      credit_limit=excluded.credit_limit, include_in_totals=excluded.include_in_totals,
      active=excluded.active, legacy_id=excluded.legacy_id, payment_account=excluded.payment_account;
  end loop;

  if exists(select 1 from jsonb_array_elements(p_payload->'transactions') e where nullif(e->>'Final Cartão','') is null) then
    insert into public.accounts(user_id, name, bank, account_type)
    values(target_user, 'Conta Itaú Uniclass', 'Itaú', 'checking')
    on conflict(user_id, name) do nothing;
  end if;

  for item in select value from jsonb_array_elements(p_payload->'invoices') loop
    insert into public.invoices(
      user_id, card_id, reference_month, due_date, total, status, source_file,
      legacy_id, closing_date, statement_total, paid_amount, paid_at, raw_status, notes
    ) values (
      target_user,
      (select id from public.cards where user_id=target_user and last_four=right(item->>'ID',4)),
      private.parse_month(item->>'Competência'), private.parse_date_pt(item->>'Vencimento'), 0,
      case when lower(coalesce(item->>'Status','')) like 'pago%' then 'paid'
           when private.parse_date_pt(item->>'Vencimento') < current_date then 'overdue' else 'closed' end,
      item->>'Arquivo', item->>'ID', private.parse_date_pt(item->>'Fechamento'),
      private.parse_money(item->>'Valor Fatura'), private.parse_money(item->>'Valor Pago'),
      private.parse_date_pt(item->>'Data Pagamento'), item->>'Status', item->>'Status'
    ) on conflict(user_id, legacy_id) where legacy_id is not null do update set
      statement_total=excluded.statement_total, paid_amount=excluded.paid_amount,
      paid_at=excluded.paid_at, status=excluded.status, raw_status=excluded.raw_status,
      source_file=excluded.source_file, closing_date=excluded.closing_date;
  end loop;

  for item in select value from jsonb_array_elements(p_payload->'merchant_rules') loop
    insert into public.merchant_rules(user_id, pattern, category_id, subcategory, notes)
    values(
      target_user, item->>'Chave',
      (select id from public.categories where user_id=target_user and name=item->>'Valor'),
      case when item->>'Observação' like 'Subcategoria %' then split_part(split_part(item->>'Observação','Subcategoria ',2),';',1) end,
      item->>'Observação'
    ) on conflict(user_id, pattern) do update set
      category_id=excluded.category_id, subcategory=excluded.subcategory, notes=excluded.notes;
  end loop;

  for item in select value from jsonb_array_elements(p_payload->'transactions') loop
    insert into public.transactions(
      user_id, dedup_key, purchased_at, competence, card_id, invoice_id, holder_id,
      merchant_original, merchant_normalized, amount, movement_type, modality,
      installment_current, installment_total, total_purchase_amount, category_id,
      subcategory, frequency, status, source, source_file, confidence, reviewed, notes,
      legacy_id, include_in_totals, raw_modality, raw_status, raw_source, raw_payload, account_id
    ) values (
      -- Legacy row IDs are authoritative. The sheet contains two legitimate,
      -- identical R$ 8 charges that intentionally share the same Dedup_ID.
      target_user, coalesce(nullif(item->>'ID',''), item->>'Dedup_ID'),
      (private.parse_date_pt(item->>'Data Compra')::timestamp + interval '12 hours') at time zone 'America/Sao_Paulo',
      private.parse_month(item->>'Competência'),
      (select id from public.cards where user_id=target_user and last_four=lpad(item->>'Final Cartão',4,'0')),
      (select i.id from public.invoices i join public.cards ic on ic.id=i.card_id
        where i.user_id=target_user and i.reference_month=private.parse_month(item->>'Competência')
          and (ic.last_four=lpad(item->>'Final Cartão',4,'0')
            or (ic.bank='Itaú' and item->>'Cartão' like 'Itaú%'))
        order by (ic.last_four=lpad(item->>'Final Cartão',4,'0')) desc limit 1),
      (select id from public.holders where user_id=target_user and name=item->>'Portador'),
      coalesce(item->>'Descrição Original',''), coalesce(item->>'Descrição Normalizada',item->>'Descrição Original',''),
      coalesce(private.parse_money(item->>'Valor'),0),
      case item->>'Tipo Movimento' when 'Compra' then 'purchase' when 'Crédito' then 'credit'
        when 'Estorno' then 'refund' when 'Transferência' then 'transfer' when 'Tarifa' then 'fee'
        when 'Juros' then 'interest' when 'IOF' then 'tax' when 'Pix no crédito' then 'credit_pix'
        else lower(coalesce(item->>'Tipo Movimento','other')) end,
      case when item->>'Modalidade'='Parcelada' then 'installment' else 'cash' end,
      nullif(item->>'Parcela Atual','')::integer, nullif(item->>'Total Parcelas','')::integer,
      private.parse_money(item->>'Valor Total Compra'),
      (select id from public.categories where user_id=target_user and name=item->>'Categoria'),
      item->>'Subcategoria', item->>'Frequência',
      case when upper(coalesce(item->>'Considerar','SIM'))='SIM' then 'confirmed' else 'ignored' end,
      'migration', item->>'Arquivo',
      case item->>'Confiança' when 'Média' then 'medium' when 'Baixa' then 'low' else 'high' end,
      upper(coalesce(item->>'Revisado',''))='SIM', item->>'Observações', item->>'ID',
      upper(coalesce(item->>'Considerar','SIM'))='SIM', item->>'Modalidade', item->>'Status', item->>'Origem', item,
      case when nullif(item->>'Final Cartão','') is null then
        (select id from public.accounts where user_id=target_user and name='Conta Itaú Uniclass') end
    ) on conflict(user_id, dedup_key) do update set
      category_id=excluded.category_id, subcategory=excluded.subcategory, status=excluded.status,
      include_in_totals=excluded.include_in_totals, raw_payload=excluded.raw_payload, updated_at=now();
  end loop;

  for item in select value from jsonb_array_elements(p_payload->'installments') loop
    insert into public.installment_plans(
      user_id, transaction_id, legacy_purchase_id, description, card_label, total_amount,
      installment_amount, current_installment, total_installments, remaining_installments,
      final_installment_month, status, raw_payload
    ) values (
      target_user, (select id from public.transactions where user_id=target_user and legacy_id=item->>'Compra_ID'),
      item->>'Compra_ID', item->>'Descrição', item->>'Cartão', private.parse_money(item->>'Valor Total'),
      coalesce(private.parse_money(item->>'Valor Parcela'),0), (item->>'Parcela Atual')::integer,
      (item->>'Total Parcelas')::integer, (item->>'Restantes')::integer,
      private.parse_month(item->>'Última Parcela'), item->>'Status', item
    ) on conflict(user_id, legacy_purchase_id) do update set
      current_installment=excluded.current_installment, remaining_installments=excluded.remaining_installments,
      status=excluded.status, raw_payload=excluded.raw_payload;
  end loop;

  for item in select value from jsonb_array_elements(p_payload->'import_batches') loop
    insert into public.import_batches(
      user_id, card_id, file_name, file_hash, rows_read, rows_created, rows_updated,
      rows_duplicated, rows_to_review, legacy_id, imported_at, raw_payload
    ) values (
      target_user,
      (select id from public.cards where user_id=target_user and position(last_four in coalesce(item->>'Cartão',''))>0 limit 1),
      item->>'Arquivo', item->>'Hash', coalesce(nullif(item->>'Lidos','')::integer,0),
      coalesce(nullif(item->>'Novos','')::integer,0), coalesce(nullif(item->>'Atualizados','')::integer,0),
      coalesce(nullif(item->>'Duplicados','')::integer,0), coalesce(nullif(item->>'Revisar','')::integer,0),
      item->>'Importação_ID', private.parse_date_pt(item->>'Data'), item
    ) on conflict(user_id, file_hash) do update set raw_payload=excluded.raw_payload;
  end loop;

  for item in select value from jsonb_array_elements(p_payload->'reviews') loop
    select id into target_transaction from public.transactions
      where user_id=target_user and legacy_id=substring(item->>'Descrição' from '(TX-[A-Za-z0-9-]+)') limit 1;
    insert into public.review_queue(
      user_id, transaction_id, reason, status, resolved_at, legacy_id, item_type,
      description, suggested_action, raw_payload
    ) values (
      target_user, target_transaction, item->>'Motivo',
      case when lower(coalesce(item->>'Status',''))='resolvido' then 'resolved' else 'pending' end,
      case when lower(coalesce(item->>'Status',''))='resolvido' then now() end,
      item->>'Item_ID', item->>'Tipo', item->>'Descrição', item->>'Ação Sugerida', item
    ) on conflict(user_id, legacy_id) where legacy_id is not null do update set
      transaction_id=excluded.transaction_id, reason=excluded.reason, status=excluded.status,
      description=excluded.description, suggested_action=excluded.suggested_action, raw_payload=excluded.raw_payload;
  end loop;

  for item in select value from jsonb_array_elements(p_payload->'goals_panel') loop
    if item->>0 in ('Alimentação','Lazer','Transporte','Vestuário','Outros') then
      update public.categories set monthly_budget=private.parse_money(item->>1)
        where user_id=target_user and name=item->>0;
    end if;
    if item->>0 in ('Reserva de emergência','Fundo de viagem','Seguro de vida') then
      insert into public.goals(user_id, name, target_amount, current_amount, weekly_amount, kind, notes, raw_payload)
      values(target_user, item->>0, coalesce(private.parse_money(item->>1),1),
        coalesce(private.parse_money(item->>2),0),
        case item->>0 when 'Seguro de vida' then 60.77 else 125 end,
        'monthly_objective', item->>5, item)
      on conflict do nothing;
    end if;
  end loop;

  insert into public.financial_plans(user_id, name, reference_month, planned_income, planned_expenses, raw_payload)
  values(target_user, 'Planejamento Financeiro — Julho 2026', date '2026-07-01', 7500, 7543.90,
    jsonb_build_object('metas',p_payload->'goals_sheet','painel',p_payload->'goals_panel'))
  on conflict(user_id, name) do update set raw_payload=excluded.raw_payload;
end;
$$;

create or replace function private.claim_finance_sheet_import(target_user uuid, target_email text)
returns boolean language plpgsql security definer set search_path = public, private as $$
declare source_payload jsonb;
begin
  select payload into source_payload from public.legacy_import_payloads
    where email=lower(target_email) and claimed_at is null for update;
  if source_payload is null then return false; end if;
  perform private.import_finance_sheet(target_user, source_payload);
  update public.legacy_import_payloads set claimed_by=target_user, claimed_at=now()
    where email=lower(target_email);
  return true;
end;
$$;

revoke all on function private.import_finance_sheet(uuid,jsonb) from public, anon, authenticated;
revoke all on function private.claim_finance_sheet_import(uuid,text) from public, anon, authenticated;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public, private as $$
begin
  insert into public.profiles(id, display_name)
  values(new.id, coalesce(new.raw_user_meta_data->>'name', new.email));
  insert into public.categories(user_id, name, sort_order) values
    (new.id,'Alimentação',10),(new.id,'Transporte',20),(new.id,'Moradia',30),
    (new.id,'Saúde',40),(new.id,'Educação',50),(new.id,'Lazer',60),
    (new.id,'Viagem',70),(new.id,'Compras',80),(new.id,'Assinaturas',90),
    (new.id,'Financeiro',100),(new.id,'Transferências',110),(new.id,'Vestuário',115),
    (new.id,'A revisar',118),(new.id,'Outros',120);
  perform private.claim_finance_sheet_import(new.id, new.email);
  return new;
end;
$$;
