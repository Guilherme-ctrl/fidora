-- Quantas decisões a sua fila de revisão tem, de verdade?
--
-- A contagem que a fila mostrava era de *itens*. O que prevê quanto tempo aquilo
-- leva é o número de decisões depois de agrupar por estabelecimento — e o
-- agrupamento só funciona se o mesmo estabelecimento tiver um nome só.
--
-- Só contagens saem daqui.

with pendentes as (
  select
    t.merchant_original                            as bruto,
    public.merchant_identity(t.merchant_original)  as identidade
  from public.review_queue r
  join public.transactions t on t.id = r.transaction_id
  where r.status = 'pending'
)
select
  count(*)                               as itens_na_fila,
  count(distinct bruto)                  as decisoes_sem_normalizar,
  count(distinct identidade)             as decisoes_agora,
  count(*) - count(distinct identidade)  as itens_absorvidos_por_grupo,
  round(100.0 * (count(*) - count(distinct identidade))
        / nullif(count(*), 0), 1)        as pct_a_menos
from pendentes;
