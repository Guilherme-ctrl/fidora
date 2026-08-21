# Compasso

Controle financeiro pessoal em Flutter para iOS e web. O projeto replica a captura rápida do Brim usando uma automação de Transação do Atalhos, acrescentando histórico, dashboards, categorias, cartões, faturas, parcelas, importações, revisões e metas.

## Estado atual

- Interface responsiva iOS/web executável com dados demonstrativos.
- Cadastro, login e logout por e-mail no ambiente Supabase.
- Filtro compartilhado por mês ou período personalizado.
- Dashboard com entradas, saídas, saldo, categorias e metas versus realizado.
- Cartões apurados pela competência da fatura; conta, Pix e débito pela data real da movimentação.
- Aba de projeção para seis meses com ritmo mensal e parcelas futuras.
- Cards, gráficos, faturas, metas e transações com drill-down e tooltips.
- Domínio e repositórios separados; Supabase ativado por `dart-define`.
- Schema com RLS e todas as entidades da planilha existente.
- Payload da planilha reconciliado e preparado para importação automática da conta proprietária.
- Edge Function `capture-transaction` pronta para receber o Atalho.
- Importação de faturas no JSON Compasso com prévia, conciliação do Atalho, idempotência e fila de revisão.
- Artefatos AIDLC em `docs/aidlc`.

## Executar em modo demonstrativo

```bash
flutter pub get
flutter run -d chrome
```

Para iOS:

```bash
open ios/Runner.xcworkspace
flutter run -d <device-id>
```

## Conectar ao Supabase

O projeto remoto **Finora** está criado em São Paulo e vinculado ao ref
`ddmilzlinvpxfvzyigok`. As migrations e a Edge Function já estão publicadas.

> O nome do produto virou **Compasso** em 20/08/2026, mas três coisas mantêm o
> nome antigo de propósito, porque renomeá-las não é edição de marca: o projeto
> no Supabase (renomear muda referências publicadas), as funções
> `preview_finora_invoice_import` e `import_finora_invoice` (estão implantadas)
> e o prefixo `finora-json:` das chaves de deduplicação — esse último está
> **gravado em dado de produção**, e trocá-lo faria toda importação já feita
> parecer nova.

1. Crie seu arquivo local de configuração a partir do exemplo:

```bash
cp config/finora.production.example.json config/finora.production.json
```

   Preencha `SUPABASE_URL` e `SUPABASE_ANON_KEY` com os dados do seu projeto.
   Esse arquivo é ignorado pelo Git: a chave publicável foi feita para rodar no
   cliente e é protegida por RLS, mas ela identifica o projeto de produção e não
   deve ficar num repositório público. Nunca coloque a `service_role` no
   Flutter; ela existe somente no ambiente protegido da Edge Function.

2. Crie a conta pelo app; cartões, histórico, faturas, regras e metas serão
   importados automaticamente.
3. Gere o token para o Atalho conforme `docs/SHORTCUT.md` após a primeira entrada.
4. Execute:

```bash
flutter run -d chrome \
  --dart-define-from-file=config/finora.production.json
```

## Importar uma fatura classificada pelo ChatGPT

Na aba **Mais**, selecione **Importar JSON do ChatGPT** e escolha um arquivo no
contrato Compasso `1.0`. O app valida o total, apresenta novos lançamentos,
conciliações, duplicidades, pagamentos e revisões. Antes da confirmação, cada
item precisa ser validado: é possível corrigir categoria, subcategoria e tipo,
ou retirar uma compra das finanças pessoais (por exemplo, cartão adicional).
Categorias desconhecidas podem ser confirmadas e são criadas atomicamente com
a importação; cancelar o fluxo não deixa cadastros parciais.
O total bancário permanece auditável e o total pessoal alimenta dashboards e
metas. A gravação é atômica no Supabase: se algum total divergir, nada é
importado.

## Estrutura

```text
lib/
  application/       providers e casos de uso
  core/              tema e componentes fundamentais
  data/              repositórios demo e Supabase
  domain/            entidades e regras financeiras
  presentation/      shell responsivo, páginas e widgets
supabase/
  migrations/        banco, RLS, índices e triggers
  functions/         endpoint seguro para o Atalho
docs/
  aidlc/              intenção, decisões, especificação e evidências
```

## Próximos gates

Antes de produção ainda faltam parsers diretos de PDF, reivindicação do payload
legado pela conta, teste do Atalho em dispositivo real e distribuição.

Recuperação de senha e recategorização em lote constavam desta lista e já
estavam implementadas — a lista é que estava desatualizada.
# fidora
