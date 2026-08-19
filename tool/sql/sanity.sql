-- Antes de medir, confirme que há o que medir.
--
-- Se `lancamentos` vier zero, o problema não é a consulta: a tabela está vazia
-- neste projeto, e o razão está em outro lugar.

select
  count(*)                                    as lancamentos,
  count(distinct user_id)                     as donos,
  min(purchased_at)::date                     as mais_antigo,
  max(purchased_at)::date                     as mais_recente,
  count(*) filter (where card_id is null)     as sem_cartao,
  count(distinct source)                      as origens
from public.transactions;
