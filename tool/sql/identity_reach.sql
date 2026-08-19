-- Quantos *lançamentos* a normalização toca — não quantos nomes.
--
-- 21,5% de redução em nomes distintos e a fatia do razão afetada são coisas
-- diferentes: um nome que colapsa costuma trazer várias linhas com ele.

select
  count(*)                                  as lancamentos,
  count(*) filter (
    where public.merchant_identity(merchant_original) is distinct from merchant_original
  )                                         as com_nome_corrigido,
  round(100.0 * count(*) filter (
    where public.merchant_identity(merchant_original) is distinct from merchant_original
  ) / nullif(count(*), 0), 1)               as pct_do_razao
from public.transactions;
