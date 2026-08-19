-- A identidade do estabelecimento.
--
-- O que precisa ficar provado aqui não é a função de string: é que ela **não
-- toca no dedup_key**. A chave é gravada por linha e vem de outra normalização,
-- na Edge Function; se alguém um dia "melhorar" as duas juntas, uma captura
-- repetida deixa de casar com a linha que ela mesma gravou e vira cobrança
-- duplicada em silêncio.

begin;
select plan(12);

create extension if not exists pgtap with schema extensions;

insert into auth.users (id, email, encrypted_password, email_confirmed_at,
                        created_at, updated_at, aud, role)
values ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'identity@finora.test', '',
        now(), now(), now(), 'authenticated', 'authenticated')
on conflict (id) do nothing;

insert into public.profiles (id, currency)
values ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'BRL')
on conflict (id) do nothing;

-- A função, nas formas que o extrato realmente escreve.
select is(public.merchant_identity('LOJA X 03/10'), 'LOJA X',
          'a parcela sai do nome');
select is(public.merchant_identity('MAGAZINE LUIZA D03/12'), 'MAGAZINE LUIZA',
          'a parcela com letra na frente também');
select is(public.merchant_identity('PAYPAL*SPOTIFY'), 'SPOTIFY',
          'o adquirente sai e a loja fica');
select is(public.merchant_identity('PAG    *PADARIA CENTRAL'), 'PADARIA CENTRAL',
          'com espaço entre o adquirente e o asterisco');
select is(public.merchant_identity('PAYPAL*LOJA X 02/06'), 'LOJA X',
          'os dois de uma vez');
select is(public.merchant_identity('MERCADO EXTRA'), 'MERCADO EXTRA',
          'um nome comum passa intacto');
select is(public.merchant_identity('03/10'), '03/10',
          'nunca devolve vazio');

select is(public.merchant_identity('LOJA X 03/10'),
          public.merchant_identity('LOJA X 07/10'),
          'duas parcelas da mesma compra viram o mesmo nome');

-- E o que a migration não pode ter feito.
insert into public.transactions
  (user_id, dedup_key, purchased_at, competence, merchant_original,
   merchant_normalized, amount)
values
  ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'chave-que-nao-muda',
   now(), date_trunc('month', now())::date, 'LOJA X 03/10', 'LOJA X 03 10', 10);

update public.transactions
set merchant_normalized = public.merchant_identity(merchant_original)
where user_id = 'dddddddd-dddd-dddd-dddd-dddddddddddd';

select is(
  (select dedup_key from public.transactions
   where user_id = 'dddddddd-dddd-dddd-dddd-dddddddddddd'),
  'chave-que-nao-muda',
  'reescrever o nome de exibição não mexe na chave de dedupe');

select is(
  (select merchant_original from public.transactions
   where user_id = 'dddddddd-dddd-dddd-dddd-dddddddddddd'),
  'LOJA X 03/10',
  'o texto do banco continua intacto para a procedência');

select is(
  (select merchant_normalized from public.transactions
   where user_id = 'dddddddd-dddd-dddd-dddd-dddddddddddd'),
  'LOJA X',
  'e o nome de exibição é o da identidade');

-- Idempotente: rodar de novo não muda nada.
update public.transactions
set merchant_normalized = public.merchant_identity(merchant_original)
where user_id = 'dddddddd-dddd-dddd-dddd-dddddddddddd';

select is(
  (select merchant_normalized from public.transactions
   where user_id = 'dddddddd-dddd-dddd-dddd-dddddddddddd'),
  'LOJA X',
  'rodar duas vezes dá o mesmo resultado');

select * from finish();
rollback;
