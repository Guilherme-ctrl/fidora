# 04 — Arquitetura de informação e fluxos

## O problema de IA hoje

Cinco destinos no celular, os **mesmos cinco** no desktop, e nove funcionalidades
reais empilhadas dentro de "Mais": Metas, Projeção, Contas, Assinaturas,
Revisões, Importar JSON, Importar extrato, Dados, Portadores, Lembretes e Regras
(`lib/presentation/pages/more_page.dart`).

"Mais" virou o depósito do produto. E dentro dele estão duas coisas que deviam
ser centrais: **Revisões** (o ritual diário, ver `01-growth.md`) e **Projeção**
(a única tela que olha para frente).

## Nova IA — quatro espaços

Em vez de cinco abas planas, quatro espaços com significado:

```text
HOJE          o que exige ação agora
  ├── Fila de revisão            ← promovido de "Mais"
  ├── Faturas fechando           
  ├── Alertas de orçamento       
  └── Lançamento rápido          

DINHEIRO      o que aconteceu
  ├── Visão geral (dashboard)
  ├── Histórico
  ├── Categorias
  ├── Cartões e faturas
  └── Contas

FUTURO        o que vai acontecer
  ├── Projeção 6 meses           ← promovido de "Mais"
  ├── Metas
  ├── Assinaturas recorrentes
  └── Parcelas em aberto

AJUSTES       como o sistema pensa
  ├── Regras de estabelecimento
  ├── Portadores
  ├── Importações e dados
  ├── Automação Apple Pay
  ├── Lembretes
  └── Conta e tema
```

`Futuro` é o agrupamento que o produto merecia e não tinha: projeção, metas,
assinaturas e parcelas respondem à mesma pergunta — *quanto já está comprometido*
— e hoje estão em três lugares diferentes.

## Navegação por plataforma

### Mobile — 5 abas, uma delas nova

| Aba | Conteúdo |
|---|---|
| **Hoje** | Fila de revisão com badge, faturas fechando, ação rápida |
| **Visão** | Dashboard |
| **(+)** | Lançamento — ação central, não FAB flutuante |
| **Histórico** | Lista com busca e filtro |
| **Mais** | Categorias, cartões, futuro, ajustes |

"Hoje" substitui a entrada em dashboard vazio, resolve o vazamento V3 de
`01-growth.md` e dá um motivo diário de abrir o app.

### Desktop — sidebar com os quatro espaços

Sidebar fixa de 240px com as seções acima expandidas, contador na fila de
revisão, e um `⌘K` no topo. Nada de "Mais". Ao colapsar (≥905 e <1240) vira rail
de ícones com tooltip.

Área de conteúdo com `maxWidth 1440`, header contextual com o `PeriodBar`, e
painel lateral direito de 400px que abre para formulário, detalhe de transação
ou revisão — sem tirar a lista da tela.

## Telas — o que muda

### Hoje (nova)

Uma pergunta: *o que preciso resolver?* Em ordem:
1. `N lançamentos aguardando revisão` — card com o primeiro item já visível e
   ações de aprovar / corrigir / virar regra, sem entrar em outra tela.
2. `Fatura X fecha em 3 dias — R$ 2.340 previstos` — usa o `invoice_forecast`
   que já existe.
3. `Mercado passou de 90% da meta` — usa o `_BudgetWarning` já implementado.
4. Se nada exige ação: a narrativa do período (`domain/narrative.dart`) e um
   estado vazio que comemora, não que pede desculpa.

### Visão geral — hierarquia, não pilha

Hoje são sete blocos de mesmo peso (`02-ux-audit.md`, M1). Passa a ser:

```text
┌──────────────────────────────────────────┐
│  SALDO DO PERÍODO      R$ 3.482,10       │  display/hero
│  +12% vs julho    ▁▂▄▃▅▆▅ sparkline      │
├──────────────┬──────────────┬────────────┤
│ Entradas     │ Saídas       │ Faturas    │  MetricTile ×3
├──────────────┴──────────────┴────────────┤
│  Ritmo de gastos            [gráfico]    │
├──────────────────────┬───────────────────┤
│  Por categoria       │  Metas × realizado│  2 colunas ≥ 905
├──────────────────────┴───────────────────┤
│  Últimas transações              ver →   │
└──────────────────────────────────────────┘
```

Comparação mês a mês e variação por categoria saem para dentro do card de
categoria, como drill-down — não como blocos independentes.

### Histórico — dois modos

- **Mobile:** lista com swipe (editar / excluir), busca sticky, chips de filtro,
  agrupamento por dia com subtotal.
- **Desktop:** tabela. Colunas Data · Comerciante · Categoria · Cartão · Estado ·
  Valor. Ordenável, valores em `mono/amount` alinhados à direita, seleção
  múltipla → barra de ação em lote (recategorizar, ignorar, exportar). É o que
  destrava a "bulk recategorization" listada como diferida em
  `03-specification.md`.

Clicar numa linha abre o painel lateral com o detalhe e a linhagem (origem,
arquivo, confiança, chave de dedupe) — informação que o modelo guarda e que a
interface hoje não mostra.

### Fatura — o conceito do produto, explicado

A tela de fatura passa a mostrar o ciclo como linha do tempo:

```text
  fechou            hoje                   vence
    ●────────────────◆──────────────────────○
  28/jul                                  10/set
  R$ 2.180 lançados · R$ 2.340 previstos ao fechar
```

Com a explicação da competência em texto: *"compras entre 29/jul e 28/ago entram
nesta fatura"*. Hoje o usuário só descobre a regra no formulário de lançamento.

### Revisão — a tela que o Copilot provou

Um item por vez, grande. Comerciante, valor, categoria sugerida com o nível de
confiança, e três ações: **aprovar**, **corrigir categoria**, **sempre assim**
(cria a regra de estabelecimento). No mobile por swipe; no desktop por teclado
(`J/K` navega, `Enter` aprova, `R` vira regra).

### Onboarding — dados antes de configuração

Corrige o vazamento V1. Quatro passos, com o dashboard só no fim:

1. **Traga seus dados** — JSON do ChatGPT · extrato CSV/XLSX · começar do zero
2. **Confirme os cartões** — fechamento e vencimento, com a competência explicada
3. **Ative a captura** — token + Atalho, com verificação: o passo só fica verde
   quando a Edge Function recebe a primeira chamada (corrige V2)
4. **Pronto** — dashboard já populado

Cada passo pode ser pulado e volta como card em "Hoje".

## Estados

Para cada lista, quatro estados desenhados — hoje só o histórico tem estado vazio:

| Estado | Regra |
|---|---|
| Vazio de primeira vez | Explica o que aparecerá aqui + a ação que popula |
| Vazio por filtro | "Nada entre 1 e 15 de agosto em Mercado" + limpar filtro |
| Carregando | Skeleton com a forma do conteúdo, por card, não tela cheia |
| Erro | Já existe `LoadFailure` com mensagem humana — manter, adicionar retry por card |

## Teclado (desktop)

| Tecla | Ação |
|---|---|
| `⌘K` | Paleta de comandos |
| `N` | Novo lançamento |
| `/` | Focar busca |
| `J` / `K` | Navegar lista |
| `Enter` | Abrir / aprovar |
| `E` | Editar |
| `R` | Criar regra a partir do item |
| `⌘Enter` | Salvar |
| `Esc` | Fechar painel |
| `1`–`4` | Trocar de espaço |
