-- Quantos *lançamentos* a normalização toca — não quantos nomes.
--
-- 21,5% de redução em nomes distintos e a fatia do razão afetada são coisas
-- diferentes: um nome que colapsa costuma trazer várias linhas com ele.
--
-- Regra embutida, pelo mesmo motivo: responde antes da migration.--
-- A regra aparece embutida em três consultas deste diretório porque elas
-- precisam responder antes da migration existir. A definição de verdade está em
-- `supabase/migrations/202608200003_merchant_identity.sql`, e em
-- `lib/domain/merchant_identity.dart` e
-- `supabase/functions/capture-transaction/rules.ts` para o app. Se mudar, mude
-- nas cinco — ou a medição deixa de descrever o que o produto faz.

with nomes as (
  select
    merchant_original as bruto,
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
    ) as identidade
  from public.transactions
)
select
  count(*)                                          as lancamentos,
  count(*) filter (where identidade is distinct from bruto) as com_nome_corrigido,
  round(100.0 * count(*) filter (where identidade is distinct from bruto)
        / nullif(count(*), 0), 1)                   as pct_do_razao
from nomes;
