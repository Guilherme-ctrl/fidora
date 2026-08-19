-- O nome que o mesmo estabelecimento deve sempre ter.
--
-- Duas coisas quebram a identidade de um estabelecimento no extrato brasileiro,
-- e as duas são mecânicas:
--
--   a parcela vem escrita dentro do nome  -> LOJA X 03/10 e LOJA X 04/10 são
--                                            strings diferentes, então uma regra
--                                            de estabelecimento escrita numa
--                                            nunca casa com a outra e a fila de
--                                            revisão não consegue agrupá-las;
--
--   o adquirente se escreve na frente     -> PAYPAL*SPOTIFY é uma cobrança da
--                                            Spotify, não da PayPal.
--
-- Medido no razão real do dono: 311 de 897 lançamentos (35%) caem num dos dois,
-- e isso é piso, porque só as 25 formas mais comuns foram contadas.
--
-- ATENÇÃO AO QUE ESTA MIGRATION NÃO FAZ: ela não toca em `dedup_key`. A chave é
-- gravada por linha e derivada de outra normalização, na Edge Function. Mudá-la
-- faria uma captura repetida deixar de casar com a linha que ela mesma gravou —
-- ou seja, cobrança duplicada em silêncio. As duas normalizações são conceitos
-- diferentes de propósito.

-- A parcela primeiro: recuperar antes de apagar.
--
-- O leitor de planilha já extrai a parcela para as colunas e ainda assim deixa
-- o sufixo no nome, então na maioria das linhas isto não muda nada. Onde a
-- coluna estiver vazia e o nome tiver a parcela, o dado é recuperado em vez de
-- descartado junto com o texto.
update public.transactions
set
  installment_current = nullif(
    substring(merchant_original from '\s[A-Za-z]?(\d{1,2})\s*/\s*\d{1,2}\s*$'),
    ''
  )::int,
  installment_total = nullif(
    substring(merchant_original from '\s[A-Za-z]?\d{1,2}\s*/\s*(\d{1,2})\s*$'),
    ''
  )::int,
  modality = 'installment'
where installment_current is null
  and merchant_original ~ '\s[A-Za-z]?\d{1,2}\s*/\s*\d{1,2}\s*$'
  -- Um total abaixo de dois é data, não parcelamento.
  and substring(merchant_original from '\s[A-Za-z]?\d{1,2}\s*/\s*(\d{1,2})\s*$')::int >= 2
  -- E uma parcela acima do total também.
  and substring(merchant_original from '\s[A-Za-z]?(\d{1,2})\s*/\s*\d{1,2}\s*$')::int
      <= substring(merchant_original from '\s[A-Za-z]?\d{1,2}\s*/\s*(\d{1,2})\s*$')::int;

-- A identidade, na coluna que já existia para isso.
--
-- `merchant_normalized` guardava a forma de dedupe, que é serviçal e ilegível.
-- Passa a guardar o nome que o produto mostra e agrupa; `merchant_original`
-- continua intacto e é o que o painel de procedência exibe.
create or replace function public.merchant_identity(value text)
returns text
language sql
immutable
as $$
  select coalesce(
    nullif(
      trim(
        regexp_replace(
          regexp_replace(
            -- adquirente na frente
            coalesce(
              nullif(regexp_replace(value, '^\s*[A-Za-z0-9\.]{2,14}\s*\*\s*', '', 'g'), ''),
              value
            ),
            -- parcela no fim
            '\s*[A-Za-z]?\d{1,2}\s*/\s*\d{1,2}\s*$', '', 'g'
          ),
          '\s+', ' ', 'g'
        )
      ),
      ''
    ),
    trim(value)
  );
$$;

comment on function public.merchant_identity(text) is
  'Nome de exibição e agrupamento. Não é a normalização do dedup_key, que vive '
  'na Edge Function e não pode mudar.';

update public.transactions
set merchant_normalized = public.merchant_identity(merchant_original)
where merchant_normalized is distinct from public.merchant_identity(merchant_original);
