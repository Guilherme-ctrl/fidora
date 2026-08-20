# 02 — Auditoria de UX e UI

Cada achado tem severidade, evidência no código e correção proposta. Severidade:
**A** = quebra a experiência, **B** = custa uso diário, **C** = polimento.

---

## Parte 1 — Web: o diagnóstico do "app convertido"

A percepção do dono está correta e tem causa técnica identificável. São seis
sintomas, e todos vêm da mesma raiz: **o web reusa o shell do mobile em vez de
ter um shell próprio.**

### W1 — Não existe URL. Severidade A

`lib/main.dart:46` usa `MaterialApp(home: ...)`, não `MaterialApp.router`. O app
inteiro é um único `Scaffold` com `int index` em estado local
(`lib/presentation/app_shell.dart:26`).

Consequências, todas fatais para a percepção de "web app":

- `/faturas` não existe. A barra de endereço nunca muda.
- O botão Voltar do navegador sai do aplicativo.
- F5 devolve o usuário à aba 0, perdendo período e filtros selecionados.
- Nada é linkável — nem uma transação, nem uma fatura, nem um relatório.
- Abrir em nova aba é impossível.

Um usuário de web percebe isso em cinco segundos, mesmo sem saber nomear.

**Correção:** `go_router` com rotas nomeadas, período e filtros como query
params (`/transacoes?de=2026-08-01&ate=2026-08-31&cat=mercado`), deep link para
entidade (`/faturas/2026-08`, `/transacoes/:id`).

### W2 — A navegação do desktop é a do celular, traduzida. Severidade A

`app_shell.dart:29-58` declara cinco `NavigationDestination` e
`app_shell.dart:92-113` **mapeia as mesmas cinco** para `NavigationRail`. O
comentário no próprio código admite a origem da restrição: *"Cinco destinos, o
máximo do Material"* — um limite de barra inferior de celular, aplicado a um
monitor de 27 polegadas.

O resultado: "Mais" existe no desktop. Um menu "Mais" numa tela com 900px de
altura livre é a assinatura de um app portado. Projeção, Metas, Contas,
Assinaturas, Portadores, Regras, Revisões, Importações e Dados — nove destinos
reais — ficam escondidos atrás de um item de menu criado para caber num iPhone.

**Correção:** sidebar do desktop com seções e todos os destinos visíveis; "Mais"
deixa de existir acima de 1024px. Ver `04-ia-flows.md`.

### W3 — Bottom sheets no desktop. Severidade A

22 ocorrências de `showModalBottomSheet`/`showDialog` em `lib/`. O formulário de
transação (`widgets/transaction_form_sheet.dart`), os filtros
(`widgets/filter_sheet.dart`) e o contexto de extrato
(`widgets/statement_context_sheet.dart`) sobem da borda inferior — gesto de
polegar, numa tela onde não há polegar.

**Correção:** o mesmo conteúdo em três apresentações por breakpoint: bottom
sheet no celular, `Dialog` centralizado no tablet, **painel lateral persistente
à direita** no desktop (o formulário fica aberto enquanto se navega a lista —
padrão de Stripe e Linear).

### W4 — Conteúdo sem largura máxima. Severidade B

`ConstrainedBox(maxWidth:)` aparece só em `auth_gate.dart` e em um card de
`app_shell.dart:322`. As páginas usam `EdgeInsets.symmetric(horizontal: width < 600 ? 18 : 32)`
(`dashboard_page.dart:52`, `transactions_page.dart:64`, `categories_page.dart:34`,
`projection_page.dart:41`) — ou seja, em 1920px o conteúdo ocupa 1856px. Linhas
de tabela de 1800px de largura são ilegíveis: o olho perde a linha entre o
comerciante e o valor.

**Correção:** container de conteúdo com `maxWidth` de 1280–1440 e grid de 12
colunas com gutter fixo.

### W5 — Histórico é uma lista de cards, não uma tabela. Severidade B

`transactions_page.dart` renderiza linhas em card. No desktop, o usuário quer
**tabela**: colunas ordenáveis, seleção múltipla, ação em lote, valores
alinhados à direita com numeral tabular. A própria especificação já pede ação em
lote — "Bulk recategorization" está listada como diferida em
`03-specification.md`, e é exatamente o tipo de operação que só faz sentido numa
tabela.

**Correção:** `DataTable2` (ou tabela própria) acima de 1024px; card list abaixo.
Mesmos dados, apresentação diferente. Seleção múltipla habilita recategorização
em lote.

### W6 — Nenhuma afordância de teclado. Severidade B

Zero `Shortcuts`/`Actions` no código. Não há `⌘K`, não há `N` para novo
lançamento, não há navegação por seta na lista, não há `Esc` padronizado.

Num produto de lançamento e revisão repetitiva, teclado **é** a interface do
desktop. Isto sozinho muda a sensação do produto mais do que qualquer ajuste
visual.

**Correção mínima:** `⌘K` paleta de comandos, `N` novo lançamento, `/` busca,
`J/K` navegar lista, `E` editar, `Esc` fechar, `⌘Enter` salvar.

---

## Parte 2 — Mobile

### M1 — Seis blocos de conteúdo empilhados como resposta a tudo. Severidade B

O dashboard (`dashboard_page.dart`) empilha saldo, ritmo, categorias, metas,
recentes, comparação mês a mês e avisos de orçamento. Num iPhone isso é uma
rolagem longa de cards de peso visual idêntico. Não há hierarquia: o saldo do
mês e a variação por categoria têm o mesmo tamanho de card e o mesmo raio.

**Correção:** uma **hero metric** dominante (o número que importa hoje), depois
no máximo dois cards de ação, e o resto atrás de "ver mais". Ver
`04-ia-flows.md`.

### M2 — O FAB diz "Transação" e é o único caminho. Severidade B

`app_shell.dart:169-175`: abaixo de 900px o `FloatingActionButton.extended` é a
única entrada de criação. Mas o app cria mais que transação — cartão, meta,
categoria, portador, regra. E o rótulo cobre conteúdo na base da lista.

**Correção:** FAB com ação primária (lançar) e long-press/expansão para as
demais; ou uma ação central na tab bar. E `padding` inferior nas listas para o
FAB não cobrir a última linha.

### M3 — Não há gesto em lugar nenhum. Severidade B

Nenhum `Dismissible` no código. Editar e excluir uma transação exigem abrir menu.
Aprovar um item da fila de revisão exige toque em botão pequeno.

**Correção:** swipe na linha do histórico (esquerda = excluir com confirmação,
direita = editar); na fila de revisão, o padrão de swipe do Copilot —
direita aprova, esquerda manda para correção.

### M4 — Um único breakpoint governa tudo, e ele está errado. Severidade B

`app_shell.dart:81`: `width >= 900` decide navegação, entrada de criação e
cabeçalho ao mesmo tempo. Entre 600 e 900px — iPad retrato, celular em paisagem,
janela de navegador reduzida — o usuário recebe a interface de celular numa tela
larga: barra inferior, FAB, coluna única em 880px.

Pior: as páginas usam breakpoints próprios e inconsistentes — 470
(`categories_page.dart:27`), 600, 650, 680, 700, 850, 900, 1100, 1180, 1200,
1250. Onze valores diferentes, nenhum documentado.

**Correção:** uma escala única de breakpoints em `core/breakpoints.dart`
(`compact < 600 ≤ medium < 905 ≤ expanded < 1240 ≤ large`), alinhada às janelas
do Material 3, e nenhum número mágico nas páginas.

### M5 — Estados de carregamento e vazio. Severidade B

O shell já preserva o snapshot anterior durante o reload
(`app_shell.dart:83-84`) — boa decisão, documentada. Mas o primeiro carregamento
é `_SnapshotSkeleton` de tela cheia, e a própria especificação reconhece o
problema: *"seis queries num único bloco atrás de um spinner de tela cheia ainda
vale a pena melhorar"* (`03-specification.md`, seção Out of scope).

Estados vazios: o histórico tem um; o dashboard vazio não tem tratamento
desenhado, e é exatamente a primeira tela do usuário novo (ver V1 em
`01-growth.md`).

**Correção:** skeleton por card, carregando na ordem de importância; e um estado
vazio de dashboard que é o onboarding, não um card em branco.

---

## Parte 3 — Design system e visual

### D1 — Fonte padrão do sistema, sem numeral tabular. Severidade A para um app de dinheiro

`pubspec.yaml` não declara nenhuma fonte. `fontFamily` aparece uma única vez no
código, e é `'monospace'` num token
(`shortcut_tokens_page.dart:137`). O app inteiro roda em Roboto com numerais
proporcionais.

Numeral proporcional significa que `R$ 1.111,00` e `R$ 8.888,00` têm larguras
diferentes. Numa coluna de valores, os dígitos não alinham verticalmente — a
diferença mais visível entre uma interface financeira e uma interface qualquer.

**Correção:** família com numerais tabulares para valores (Archivo com
`font-feature-settings: "tnum"`, ou IBM Plex Sans). Texto em proporcional,
**todo número financeiro em tabular**, alinhado à direita.

### D2 — A paleta não é uma paleta de marca; é o tema padrão do Material. Severidade A

> Revisado em 19 ago 2026 após avaliação do dono: *"essa cor bege no fundo do
> web, os widgets muito flutter default, design system sem graça, o app está sem
> alma"*. A avaliação está certa e esta seção foi corrigida — a versão anterior
> classificava o problema como B e mandava preservar os valores.

O `#F5F3EC` de `canvas` não é uma decisão de marca: é o *surface tint* do
Material 3 numa temperatura quente. Combinado com `cardTheme` de raio 22 e
`elevation: 0`, ele produz o padrão que qualquer app Flutter gerado produz —
fundo tingido com cards brancos boiando. Some-se `ColorScheme.fromSeed`, que
torna o botão primário um tonal na cor da semente, e a aparência fica definida
antes de qualquer tela ser desenhada.

Três widgets carregam sozinhos essa aparência: `Card`, `NavigationBar` e
`NavigationRail`. Substituí-los é a maior parte do trabalho visual.

A nova direção está em [03-design-system.md](03-design-system.md): o fundo passa
a ser a superfície, o que separa é pauta, a ação primária é tinta e o raio máximo
cai de 22 para 10.

### D2b — As escalas não existem. Severidade B

O **método** de `core/theme.dart` é a melhor parte do sistema atual e se
preserva: `FinoraPalette` é uma `ThemeExtension` com light e dark completos, e o
comentário documenta a correção de contraste já feita — texto secundário deixou
de ser `ink` com opacidade (3.2:1 e 4.0:1, abaixo do AA) e virou valor sólido
acima de 4.5:1. É o rigor que se mantém; os valores é que mudam.

O que falta:

- **Escala de cor**, não valores avulsos. Hoje são 15 cores nomeadas sem rampa;
  não há como pedir "o verde dois passos mais claro".
- **Escala de espaçamento.** Os paddings são literais espalhados (18, 20, 12, 32,
  28, 8) — sem base de 4/8pt.
- **Escala tipográfica.** Não há tokens de texto; os widgets pedem
  `TextStyle` por conta.
- **Raio.** `22` no `cardTheme`, `16` nos inputs, sem escala.
- **Elevação.** `elevation: 0` em tudo, e `hairline` como único separador. É uma
  decisão defensável (visual calmo), mas precisa virar regra escrita, senão a
  primeira sombra que alguém adicionar quebra a consistência.

### D3 — Semântica de cor incompleta para dinheiro. Severidade B

Existe `danger`, `warning`, `info`, `brand`. Não existe **positivo/entrada** como
token. Entrada e saída num extrato precisam de par cromático próprio, e ele não
pode ser só verde/vermelho — 8% dos homens têm alguma deficiência de visão de
cor, e verde/vermelho é justamente o eixo afetado.

**Correção:** tokens `income`/`expense` com sinal explícito (`+`/`−`) e peso
tipográfico, para que a cor seja reforço e não a única portadora do significado.

### D4 — Sem alternância de tema. Severidade C

`main.dart:48`: `themeMode: ThemeMode.system`. Os dois temas existem e são bons,
e o usuário não consegue escolher.

**Correção:** seletor sistema/claro/escuro persistido em `shared_preferences`
(já é dependência).

### D5 — Ícones genéricos do Material. Severidade C

`Icons.space_dashboard_outlined`, `Icons.tune_outlined`, `Icons.category_rounded`.
Corretos, sem personalidade, e `tune` para "Mais" é semanticamente errado —
`tune` significa ajustes, e a aba contém metas, importações e projeção.

---

## Resumo priorizado

| # | Achado | Sev | Esforço |
|---|---|---|---|
| W1 | Sem URL / roteamento | A | M |
| W2 | Navegação de desktop copiada do mobile | A | M |
| W3 | Bottom sheet no desktop | A | M |
| D1 | Sem numeral tabular | A | P |
| M1 | Dashboard sem hierarquia | B | M |
| W5 | Histórico sem tabela no desktop | B | G |
| W6 | Sem teclado | B | M |
| M4 | Breakpoints inconsistentes | B | P |
| D2 | Paleta é o tema padrão do Material, não marca | A | M |
| D2b | Escalas de token ausentes | B | M |
| W4 | Sem largura máxima | B | P |
| M3 | Sem gestos | B | M |
| D3 | Sem token de entrada/saída | B | P |
| M2 | FAB única entrada e cobre conteúdo | B | P |
| M5 | Carregamento e vazio | B | M |
| D4 | Sem seletor de tema | C | P |
| D5 | Ícones genéricos | C | M |

**O que já está certo e não deve ser tocado:** a arquitetura de camadas, o
`FinanceSnapshot` como fonte única, a correção de contraste do texto secundário,
o `RefreshIndicator` único no shell, a barra de período única para o app inteiro
(`app_shell.dart:131-141` — corrigiu a duplicação em quatro páginas), e a dica de
competência de fatura mostrada **antes** de salvar.
