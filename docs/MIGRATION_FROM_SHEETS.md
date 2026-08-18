# Mapeamento da planilha existente

| Aba atual | Destino Supabase |
|---|---|
| Config / Categoria | `categories` |
| Config / Regra | `merchant_rules` |
| Cartões | `cards` |
| Faturas | `invoices` |
| Transações | `transactions` |
| Parcelamentos | `installment_plans` + atributos em `transactions` |
| Importações | `import_batches` |
| Revisões | `review_queue` |
| Portadores | `holders` |
| Metas | `goals`, orçamentos em `categories` e `financial_plans` |
| Dashboard / Painel Metas | visualizações derivadas no Flutter |

## Estratégia de migração

1. Ler a planilha nativa em modo somente leitura e preservar os campos originais em `raw_payload`.
2. Enviar o payload diretamente ao Supabase com `service_role`, sem versionar dados financeiros.
3. Manter o payload sem política de leitura e sem privilégios para `anon`/`authenticated`.
4. Associar o payload ao e-mail do proprietário e reivindicá-lo uma única vez na criação da conta.
5. Criar perfil, categorias, portadores, cartões e contas antes dos lançamentos.
6. Importar faturas, transações, parcelamentos, lotes, revisões, regras e metas preservando IDs antigos.
7. Usar o ID original da transação como chave da migração; a planilha possui duas cobranças legítimas que compartilham o mesmo `Dedup_ID`.
8. Recalcular totais pessoais e manter o valor integral da fatura em `statement_total`.
9. Manter a planilha como arquivo somente leitura durante pelo menos dois fechamentos.

## Inventário reconciliado

| Entidade | Quantidade |
|---|---:|
| Transações | 847 |
| Cartões | 9 |
| Faturas | 10 |
| Parcelamentos | 31 |
| Importações | 13 |
| Revisões | 46 |
| Regras de estabelecimento | 22 |

Das transações, 804 compõem as finanças pessoais e 43 permanecem ignoradas conforme as regras da planilha. O total assinado dos itens considerados é R$ 114.049,28.
