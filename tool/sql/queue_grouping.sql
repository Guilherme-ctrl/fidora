-- Quantas decisões a sua fila de revisão tem, de verdade?
--
-- A contagem que a fila mostrava era de *itens*. O que prevê quanto tempo aquilo
-- leva é o número de decisões depois de agrupar por estabelecimento — e o
-- agrupamento só funciona se o mesmo estabelecimento tiver um nome só.
--
-- A regra está escrita aqui dentro de propósito: assim a consulta responde
-- **antes** de a migration `202608200003_merchant_identity` ser aplicada, que é
-- exatamente quando você quer o número para decidir se aplica.
--
-- Só contagens saem daqui.--
-- A regra aparece embutida em três consultas deste diretório porque elas
-- precisam responder antes da migration existir. A definição de verdade está em
-- `supabase/migrations/202608200003_merchant_identity.sql`, e em
-- `lib/domain/merchant_identity.dart` e
-- `supabase/functions/capture-transaction/rules.ts` para o app. Se mudar, mude
-- nas cinco — ou a medição deixa de descrever o que o produto faz.

with pendentes as (
  select
    t.merchant_original as bruto,
    trim(
      regexp_replace(
        regexp_replace(
          coalesce(
            nullif(regexp_replace(t.merchant_original,
              '^\s*[A-Za-z0-9\.]{2,14}\s*\*\s*', '', 'g'), ''),
            t.merchant_original
          ),
          '\s*[A-Za-z]?\d{1,2}\s*/\s*\d{1,2}\s*$', '', 'g'
        ),
        '\s+', ' ', 'g'
      )
    ) as identidade
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
