-- Quantos lançamentos deixariam consultar o ramo de atuação de graça?
--
-- Rode no editor SQL do Supabase Studio. Devolve **só contagens** — nenhum nome
-- de estabelecimento e nenhum documento saem daqui, então o resultado é seguro
-- de colar em qualquer lugar.
--
-- Mede o razão inteiro, não um arquivo de extrato, que é a diferença entre uma
-- amostra e a resposta.
--
-- Sem filtro por usuário de propósito: o editor do Studio roda como `postgres`,
-- onde `auth.uid()` é nulo — a primeira versão desta consulta filtrava por ele
-- e por isso não devolvia nada. O produto tem um dono; se algum dia tiver mais,
-- acrescente o `where user_id = '...'` aqui.

with base as (
  select
    merchant_original as texto,
    source,
    card_id is null as sem_cartao
  from public.transactions
),
marcado as (
  select
    -- Um Pix não tem cartão e o banco escreve "pix" na descrição.
    (texto ~* '\mpix\M') as parece_pix,
    -- CNPJ pontuado: quase nunca é outra coisa.
    (texto ~ '\d{2}\.\d{3}\.\d{3}/\d{4}-\d{2}') as cnpj_pontuado,
    -- Catorze dígitos soltos: pode ser CNPJ, pode ser id de transação. Contado
    -- à parte de propósito — sem verificar dígito não dá para afirmar.
    (texto ~ '(^|\D)\d{14}(\D|$)') as talvez_cnpj,
    (texto ~ '\d{3}\.\d{3}\.\d{3}-\d{2}') as cpf_pontuado,
    (texto ~ '[•*]{2,3}\.?\d{3}\.\d{3}-?[•*]{2}') as documento_mascarado,
    sem_cartao,
    source
  from base
)
select
  count(*)                                             as lancamentos,
  count(*) filter (where parece_pix)                   as pix,
  count(*) filter (where cnpj_pontuado)                as com_cnpj_certo,
  count(*) filter (where talvez_cnpj and not cnpj_pontuado) as talvez_cnpj,
  count(*) filter (where cpf_pontuado)                 as pessoa_fisica,
  count(*) filter (where documento_mascarado)          as documento_mascarado,
  count(*) filter (where parece_pix and not cnpj_pontuado
                     and not cpf_pontuado
                     and not documento_mascarado
                     and not talvez_cnpj)              as pix_so_com_nome,
  count(*) filter (where not sem_cartao)               as no_cartao,
  round(100.0 * count(*) filter (where cnpj_pontuado) / nullif(count(*), 0), 1)
                                                       as pct_do_total,
  round(100.0 * count(*) filter (where cnpj_pontuado)
        / nullif(count(*) filter (where parece_pix), 0), 1)
                                                       as pct_dos_pix
from marcado;
