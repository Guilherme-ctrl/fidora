-- A parcela escrita no nome poderia virar coluna?
--
-- Só conta; não escreve nada. O ponto é separar o que é parcelamento do que é
-- data, porque `03/10` serve para os dois e escrever parcelamento errado numa
-- compra à vista é pior do que deixar como está.

with alvo as (
  select
    source,
    substring(merchant_original from '\s[A-Za-z]?(\d{1,2})\s*/\s*\d{1,2}\s*$')::int as esquerda,
    substring(merchant_original from '\s[A-Za-z]?\d{1,2}\s*/\s*(\d{1,2})\s*$')::int as direita
  from public.transactions
  where installment_current is null
    and merchant_original ~ '\s[A-Za-z]?\d{1,2}\s*/\s*\d{1,2}\s*$'
)
select
  count(*)                                            as candidatas,
  count(*) filter (where esquerda > direita)          as certamente_data,
  count(*) filter (where direita < 2)                 as total_menor_que_dois,
  count(*) filter (where direita between 1 and 12
                     and esquerda <= direita)         as ambiguas_pode_ser_data,
  count(*) filter (where direita > 12
                     and esquerda <= direita)         as certamente_parcela,
  count(distinct source)                              as origens
from alvo;
