create extension if not exists pgcrypto;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  currency text not null default 'BRL',
  timezone text not null default 'America/Sao_Paulo',
  created_at timestamptz not null default now()
);

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  color text not null default '#1F6B4F',
  icon text not null default 'category',
  monthly_budget numeric(14,2),
  sort_order integer not null default 0,
  active boolean not null default true,
  unique (user_id, name)
);

create table public.holders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  include_in_totals boolean not null default true,
  unique (user_id, name)
);

create table public.cards (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  holder_id uuid references public.holders(id) on delete set null,
  holder_name text,
  bank text not null,
  name text not null,
  last_four text not null check (last_four ~ '^\d{4}$'),
  closing_day integer not null check (closing_day between 1 and 31),
  due_day integer not null check (due_day between 1 and 31),
  credit_limit numeric(14,2) not null default 0,
  include_in_totals boolean not null default true,
  active boolean not null default true,
  unique (user_id, last_four)
);

create table public.invoices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  card_id uuid not null references public.cards(id) on delete cascade,
  reference_month date not null check (date_part('day', reference_month) = 1),
  due_date date not null,
  total numeric(14,2) not null default 0,
  status text not null default 'open' check (status in ('open', 'closed', 'paid', 'overdue')),
  source_file text,
  created_at timestamptz not null default now(),
  unique (card_id, reference_month)
);

create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  dedup_key text not null,
  purchased_at timestamptz not null,
  competence date not null check (date_part('day', competence) = 1),
  card_id uuid references public.cards(id) on delete set null,
  invoice_id uuid references public.invoices(id) on delete set null,
  holder_id uuid references public.holders(id) on delete set null,
  merchant_original text not null,
  merchant_normalized text not null,
  amount numeric(14,2) not null check (amount >= 0),
  movement_type text not null default 'purchase',
  modality text not null default 'cash' check (modality in ('cash', 'installment', 'recurring')),
  installment_current integer,
  installment_total integer,
  total_purchase_amount numeric(14,2),
  category_id uuid references public.categories(id) on delete set null,
  subcategory text,
  frequency text,
  status text not null default 'confirmed' check (status in ('confirmed', 'pending', 'ignored')),
  source text not null default 'manual' check (source in ('manual', 'apple_pay', 'invoice_import', 'migration')),
  source_file text,
  confidence text not null default 'high' check (confidence in ('high', 'medium', 'low')),
  reviewed boolean not null default false,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, dedup_key)
);

create table public.merchant_rules (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  pattern text not null,
  category_id uuid not null references public.categories(id) on delete cascade,
  subcategory text,
  priority integer not null default 100,
  active boolean not null default true,
  notes text,
  unique (user_id, pattern)
);

create table public.import_batches (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  card_id uuid references public.cards(id) on delete set null,
  file_name text not null,
  file_hash text not null,
  rows_read integer not null default 0,
  rows_created integer not null default 0,
  rows_updated integer not null default 0,
  rows_duplicated integer not null default 0,
  rows_to_review integer not null default 0,
  created_at timestamptz not null default now(),
  unique (user_id, file_hash)
);

create table public.review_queue (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  transaction_id uuid not null references public.transactions(id) on delete cascade,
  reason text not null,
  status text not null default 'pending' check (status in ('pending', 'resolved', 'dismissed')),
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  unique (transaction_id, reason)
);

create table public.goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  target_amount numeric(14,2) not null check (target_amount > 0),
  current_amount numeric(14,2) not null default 0,
  target_date date,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.shortcut_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  token_hash text not null unique,
  last_used_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);

create index transactions_user_date_idx on public.transactions(user_id, purchased_at desc);
create index transactions_invoice_idx on public.transactions(invoice_id);
create index invoices_user_month_idx on public.invoices(user_id, reference_month desc);
create index merchant_rules_user_priority_idx on public.merchant_rules(user_id, priority);

create or replace function public.refresh_invoice_total()
returns trigger language plpgsql security definer set search_path = public as $$
declare target_invoice uuid := coalesce(new.invoice_id, old.invoice_id);
begin
  if target_invoice is not null then
    update public.invoices
       set total = coalesce((select sum(amount) from public.transactions where invoice_id = target_invoice and status <> 'ignored'), 0)
     where id = target_invoice;
  end if;
  return coalesce(new, old);
end;
$$;

create trigger transactions_refresh_invoice_total
after insert or update of amount, status, invoice_id or delete on public.transactions
for each row execute function public.refresh_invoice_total();

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, display_name) values (new.id, coalesce(new.raw_user_meta_data->>'name', new.email));
  insert into public.categories (user_id, name, sort_order) values
    (new.id, 'Alimentação', 10), (new.id, 'Transporte', 20), (new.id, 'Moradia', 30),
    (new.id, 'Saúde', 40), (new.id, 'Educação', 50), (new.id, 'Lazer', 60),
    (new.id, 'Viagem', 70), (new.id, 'Compras', 80), (new.id, 'Assinaturas', 90),
    (new.id, 'Financeiro', 100), (new.id, 'Transferências', 110), (new.id, 'Outros', 120);
  return new;
end;
$$;

create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.categories enable row level security;
alter table public.holders enable row level security;
alter table public.cards enable row level security;
alter table public.invoices enable row level security;
alter table public.transactions enable row level security;
alter table public.merchant_rules enable row level security;
alter table public.import_batches enable row level security;
alter table public.review_queue enable row level security;
alter table public.goals enable row level security;
alter table public.shortcut_tokens enable row level security;

do $$
declare table_name text;
begin
  foreach table_name in array array['profiles','categories','holders','cards','invoices','transactions','merchant_rules','import_batches','review_queue','goals','shortcut_tokens']
  loop
    execute format('create policy "owner access" on public.%I for all using (auth.uid() = %s) with check (auth.uid() = %s)', table_name,
      case when table_name = 'profiles' then 'id' else 'user_id' end,
      case when table_name = 'profiles' then 'id' else 'user_id' end);
  end loop;
end $$;
