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

-- O que esta migration deliberadamente NÃO faz, além de não tocar no dedup_key:
-- ela não tenta recuperar a parcela para as colunas.
--
-- A tentação era grande, porque o texto tem `03/10` e a coluna está vazia em
-- algumas linhas. Mas `03/10` no fim de uma descrição é tão frequentemente uma
-- data quanto uma parcela, e o filtro óbvio — total maior que a parcela — deixa
-- passar exatamente os casos ambíguos: `03/10` como 3 de outubro passa igual.
-- Escrever parcelamento errado numa compra à vista é pior do que não escrever
-- nada, e nada se perde ao adiar: `merchant_original` continua intacto, com o
-- texto inteiro, para sempre.
--
-- `tool/sql/instalment_candidates.sql` mede quantas linhas isso alcançaria e
-- quantas são ambíguas. Com esse número dá para decidir; sem ele seria chute.

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
