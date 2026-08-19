-- Quanto a normalização do nome junta?
--
-- Nenhum nome sai daqui: só contagens de distintos. O número que interessa é a
-- última coluna — quantos estabelecimentos deixam de ser tratados como vários.

with nomes as (
  select
    merchant_original as bruto,
    -- mesma normalização do app: tira o prefixo do agregador e a parcela
    trim(
      regexp_replace(
        regexp_replace(
          coalesce(
            nullif(regexp_replace(merchant_original,
              '^\s*[A-Za-z0-9\.]{2,14}\s*\*\s*', '', 'g'), ''),
            merchant_original
          ),
          '\s*[A-Za-z]?\d{1,2}\s*/\s*\d{1,2}\s*$', '', 'g'
        ),
        '\s+', ' ', 'g'
      )
    ) as normalizado
  from public.transactions
)
select
  count(*)                        as lancamentos,
  count(distinct bruto)           as nomes_hoje,
  count(distinct normalizado)     as nomes_normalizados,
  count(distinct bruto) - count(distinct normalizado) as colapsados,
  round(100.0 * (count(distinct bruto) - count(distinct normalizado))
        / nullif(count(distinct bruto), 0), 1) as pct_reduzido
from nomes;
