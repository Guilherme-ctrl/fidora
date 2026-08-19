-- Os formatos que o seu banco escreve, sem o conteúdo.
--
-- Troca todo dígito e toda palavra por marcador antes de agrupar, então o
-- resultado mostra a *forma* das descrições e nunca um nome ou um documento.
-- É o que responde "por que a cobertura deu baixa".

select
  regexp_replace(
    regexp_replace(merchant_original, '\d', '#', 'g'),
    '[[:alpha:]]{2,}', 'AAA', 'g'
  ) as formato,
  count(*) as vezes
from public.transactions
where user_id = auth.uid()
group by 1
order by vezes desc
limit 25;
