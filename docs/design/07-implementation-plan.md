# 07 — Plano de aplicação no código

Como levar o design system [Ledger](03-design-system.md) para dentro de
`lib/`, sem parar o produto e sem um big bang.

## O tamanho real do trabalho

Levantado no código em 19 ago 2026:

| Superfície | Ocorrências | Onde dói |
|---|---|---|
| `context.palette.*` | **270** | toda a camada de apresentação |
| `TextStyle(` literal | **199** | nenhum token tipográfico existe |
| `EdgeInsets` literal | **165** | nenhuma escala de espaço existe |
| `currency.format` | **88** | dinheiro renderizado à mão em 88 lugares |
| `palette.danger` | **74** | boa parte é saída comum, que deixa de ser vermelha |
| `palette.brand` | **71** | precisa ser dividido entre ação (tinta) e acento (azul) |
| `Card(` bruto | **30** | fora dos 21 que já passam por `SectionCard`/`MetricCard` |
| `BorderRadius` literal | **60** | raio 22 espalhado |
| `FilledButton` | **39** | vira `InkButton` |
| `Chip(` | **24** | vira `MonoTag` |
| `showModalBottomSheet` + `showDialog` | **22** | vira `ResponsiveSheet` |
| `ListTile` | **17** | vira `LedgerRow` onde for lançamento |
| `NavigationBar` / `NavigationRail` | 3 + 3 | vira `LedgerTabBar` / `LedgerSidebar` |

### As duas boas notícias

**1. Já existe uma camada de componentes, e ela é o gargalo certo.**
`lib/presentation/widgets/common.dart` concentra cinco classes com 80 pontos de
uso somados:

| Classe | Usos | Vira |
|---|---|---|
| `DetailValue` | **49** | rótulo mono + valor tabular |
| `SectionCard` | 13 | `RuledSection` — pauta, sem card |
| `MetricCard` | 8 | `LedgerTile` — pauta pesada, valor serifado |
| `PageHeading` | 7 | cabeçalho com versalete mono |
| `PeriodFilterBar` | 3 | grupo segmentado com borda única |

Reescrever esses cinco arquivos-classe muda a aparência da maior parte do app
**sem tocar em nenhuma página**. É por aí que o trabalho começa.

**2. Os testes não vão brigar.**
Nenhum teste procura por `Card`, `NavigationBar`, `NavigationRail`, `ListTile`,
`FilledButton` ou `Chip`. Os 47 `testWidgets` existentes buscam por texto,
semântica, `SwitchListTile`, `DropdownButtonFormField` e `ReceiptField` — todos
sobrevivem à troca. As duas únicas exceções são
`find.byIcon(Icons.trending_up_rounded)` e `trending_down_rounded` em
`insights_card_test.dart`, que quebram se os ícones mudarem.

E `test/theme_test.dart` já é um **arnês genérico de contraste**: calcula
luminância WCAG e roda a mesma bateria nos dois temas. Ele não precisa ser
reescrito, precisa ser **estendido** para os tokens novos — e continua sendo a
prova de que a paleta nova não regride o que a auditoria anterior corrigiu.

### A parte que não é mecânica

`palette.brand` (71) e `palette.danger` (74) **não** são renomeação. Cada
chamada precisa de uma decisão:

- `brand` era verde de marca usado tanto para **ação** quanto para **ênfase**.
  Agora ação é `ink` e ênfase é `accent`. São dois destinos diferentes.
- `danger` era vermelho usado tanto para **saída comum** quanto para **problema**.
  Agora saída comum é `ink` e problema é `negative`.

São ~145 decisões semânticas. A tática para não tomar 145 decisões é fazer os
componentes absorverem a maioria: quando `AmountText` for o único caminho para
renderizar dinheiro, dezenas de `palette.danger` desaparecem em vez de migrarem.
**Por isso a camada de componentes vem antes da migração de tokens nas páginas.**

---

## Sequência — 8 entregas

Cada uma compila, passa nos testes e pode ser publicada sozinha.

### PR 0 — Rede de segurança · **entregue** (2026-08-19)

- [x] Costura de relógio (`package:clock`) — sem ela nenhum golden é estável,
      porque a demo e quatro derivações do domínio liam `DateTime.now()`
- [x] 24 goldens: 6 páginas × 3 larguras em claro, 6 em escuro
- [x] `test/support/contrast.dart` — arnês WCAG extraído, pronto para os tokens novos
- [x] `test/page_overflow_test.dart` — 36 casos que **rodam no CI**, porque os
      goldens não podem rodar lá
- [x] `insights_card.dart` com chave por tom: o teste deixa de depender do glifo
- [x] CI passa a excluir a tag `golden`

**Encontrou cinco overflows que já estavam em produção**, todos em telefone,
nenhum com teste — e dois estruturais que os PRs 2 e 3 substituem, marcados como
`skip` com o motivo no nome. Detalhe em
[`docs/aidlc/04-validation.md`](../aidlc/04-validation.md).

Ainda em aberto para o PR 1, porque dependem de tokens que ainda não existem:

- [ ] Estender o arnês para `accent`, `income`, `negative`, `pending`, `ignored`
      e as seis categóricas contra `canvas`, `surface` e `sunken`
- [ ] Teste de distância perceptual entre as seis categóricas
- [ ] `flutter_test_config.dart` carregando as fontes, para os goldens deixarem
      de renderizar texto como retângulo

### PR 1 — Tokens · **entregue** (2026-08-19)

- [x] `lib/core/tokens.dart` — espaço base 4, raio (máximo 10), traço, duração
- [x] `lib/core/breakpoints.dart` — `Breakpoint` e `maxContentWidth`
- [x] `lib/core/typography.dart` — `LedgerText`, três vozes, tabular em todo
      estilo numérico
- [x] `lib/core/theme.dart` — paleta Ledger completa, com pontes `@Deprecated`
- [x] `test/theme_test.dart` reescrito — 75 casos
- [x] `test/support/cvd.dart` + `test/categorical_test.dart` — simulação de
      Viénot–Brettel–Mollon e ΔE CIE76
- [x] CI passa a `flutter analyze --no-fatal-infos`

**Três valores foram escritos, medidos e reprovados antes de entrar no código:**
`inkSubtle` a 4,34:1 contra o fundo zebrado novo; a borda de campo a ~1,5:1
quando a WCAG 1.4.11 pede 3:1; e duas paletas categóricas inteiras, uma a
ΔE 8,4 sob protanopia e outra a ΔE 1,0 sob tritanopia.

**197 avisos de depreciação** — `brand` 69, `danger` 73, `warning` 20,
`onWarning` 12, `brandSoft` 12, `hairline` 7, `onBrandSoft` 3, `info` 1. É a
worklist dos PRs 2 e 5, e bate com as ~145 decisões semânticas previstas.

Ficou de fora, e por quê:

- [ ] **Empacotar Source Serif 4, Inter e JetBrains Mono.** Baixar binário de
      fonte precisa da sua autorização. Até lá `LedgerText` usa
      `fontFamilyFallback` para a serifa do sistema (New York no iOS/macOS,
      Georgia no resto), e `FontFeature.tabularFigures()` já funciona com a
      fonte padrão — o alinhamento de coluna, que era o ganho principal, já
      está valendo.
- [ ] `categoryColors` em `category_visuals.dart` ainda tem o ocre `#8D6414` e
      as 12 cores do seletor não passaram por medição. São **dado gravado** —
      `categories.color` no banco — então mexer nelas é migração, não tema. Fica
      para o PR 5.

### PR 2 — Camada de componentes · **entregue** (2026-08-19)

`lib/presentation/widgets/ledger.dart`, novo:

- [x] `AmountText` — o único caminho para pôr dinheiro na tela. Sinal U+2212
      (largura de dígito, para a coluna não desalinhar), figura tabular, cor
      semântica e rótulo de acessibilidade por extenso
- [x] `RuledSection` · `LedgerTile` · `LedgerTileRow` · `LedgerRow` ·
      `CategoryMark` · `MonoTag` · `InkButton` · `RuleBar` · `SectionLabel`
- [x] `categoryColourFor` — a cor que a categoria mantém em todas as telas

Nos pontos de estrangulamento:

- [x] `SectionCard` e `MetricCard` viraram cascas `@Deprecated` sobre
      `RuledSection` e `LedgerTile` — **21 chamadas mudaram de aparência sem
      que nenhuma página fosse tocada**
- [x] `DetailValue` (49 chamadas) — rótulo em versalete mono, valor tabular
- [x] `PageHeading` e `PeriodFilterBar` refeitos
- [x] `LedgerRow` adotado na lista de lançamentos do painel

**A grade de proporção fixa da projeção virou `LedgerTileRow`**, e com isso
sobrou **um** único caso adiado por Dynamic Type (a grade de categorias, PR 3).

Três defeitos apareceram e foram corrigidos no caminho — dois deles introduzidos
pelos componentes novos, o que é exatamente o que a rede do PR 0 existe para
pegar:

| Onde | Estouro |
|---|---|
| Face do cartão em `cards_page` (pré-existente) | 13px a 1.3x — nome do banco em capitulares espaçadas |
| `MonoTag` (novo) | 21px a 2.0x — a tag não podia quebrar linha |
| `PeriodFilterBar` (novo) | 50px a 375pt — o grupo segmentado não encolhia |

**Correção de registro:** a nota do PR 0 atribuía o estouro de `faturas` ao
`MetricCard`. Estava errada — era a face do cartão. O comentário no teste foi
corrigido.

Depreciações: 197 → **204**, porque `SectionCard` (12) e `MetricCard` (7)
entraram na lista. `brand` caiu de 69 para 66 e `danger` de 73 para 68 — os
componentes começaram a absorver as chamadas, como o plano previa.

### PR 3 — Shell, navegação e IA · **entregue** (2026-08-19)

- [x] `LedgerSidebar` e `LedgerTabBar` no lugar de `NavigationRail` e
      `NavigationBar` — os dois últimos widgets que carregavam a aparência
      Material por inteiro
- [x] Os quatro espaços: **Hoje, Dinheiro, Futuro, Ajustes**. Sete destinos
      nomeados no desktop; "Mais" some acima de 905pt
- [x] `today_page.dart` — a tela que não existia, com a fila de revisão em
      primeiro plano e contador na navegação
- [x] Projeção saiu do porão e virou destino de primeira classe
- [x] `Breakpoint` adotado no shell e nas seis páginas; `maxContentWidth` de
      1440 no contêiner de conteúdo
- [x] Seletor de tema persistido em `shared_preferences`
- [x] **A grade de categorias deixou de fixar proporção** — a lista de adiados
      por Dynamic Type está vazia pela primeira vez
- [x] `navigation_test.dart` — 10 casos
- [x] Três goldens do shell (390, 768, 1440), que as goldens de página não veem

Dois defeitos meus no caminho, ambos pegos pela rede:

| Onde | Sintoma |
|---|---|
| Cabeçalho da sidebar | `_Brand` é a barra do telefone; num trilho de 68pt estourava 200px |
| `navigation_test` | `pumpAndSettle` não retorna enquanto há barra de progresso indeterminada — o teste travava em vez de falhar |

Números mágicos de largura: **23 → 14**. Os que sobraram decidem contagem de
colunas dentro de uma página, não navegação, e migram no PR 4 junto com a tabela.

### PR 4 — Roteamento · **entregue** (2026-08-19)

- [x] `go_router`; `MaterialApp` → `MaterialApp.router`
- [x] Sete endereços, um por destino, na ordem da navegação
- [x] Período na query: `?mes=2026-08` para mês inteiro,
      `?de=…&ate=…` para intervalo — o formato curto é o que se cola numa mensagem
- [x] Filtro do histórico na query: `q`, `categoria`, `cartao`, `estado`,
      `min`, `max`, `parcelado`, `todoPeriodo`
- [x] `/transacoes/:id` abre o lançamento e devolve o endereço ao fechar
- [x] Endereço desconhecido explica o que houve em vez de tela branca
- [x] `routes.dart` separado do `router.dart`, para o codec ser testado sem
      montar widget
- [x] `routing_test.dart` — 16 casos

**O filtro saiu do estado do widget.** `TransactionsPage` guardava
`TransactionFilter` internamente; agora ele vem do endereço, então um recorte do
histórico é um link e F5 o preserva.

**Os sete destinos são rotas irmãs sob a mesma chave de página.** Com uma chave
só o elemento é reaproveitado entre rotas, o `IndexedStack` mantém a posição de
rolagem de cada tela e não há transição entre abas — que é como uma sidebar deve
se comportar. O efeito colateral é que o `Navigator` tem uma página só, então
`popRoute` não tem o que desempilhar: na web o histórico é do navegador, e o
Voltar chega pelo `setNewRoutePath`. O teste exercita esse caminho, e a
verificação no navegador está em `04-validation.md`.

Ficou de fora, com motivo:

- [ ] **A tela de entrada não tem endereço próprio.** O `AuthGate` virou
      envelope da shell roteada em vez de virar `redirect`. Um redirect de
      verdade precisa de um `refreshListenable` sobre o stream de autenticação,
      e o fluxo de recuperação de senha é sutil demais para mexer junto com
      roteamento. Vai com a recuperação de senha, no PR 5.
- [ ] **Deep link para fatura** (`/faturas/:cartao/:competencia`) — não existe
      tela de fatura para abrir; a fatura é renderizada dentro da lista de
      cartões. Vai com o painel lateral, no PR 6.

### PR 5 — Superfícies e limpeza · **entregue** (2026-08-19)

- [x] **As 203 pontes de depreciação foram resolvidas e apagadas**
- [x] `flutter analyze --fatal-infos` restaurado no CI — a porta deste PR
- [x] `showResponsiveSheet` e `showResponsiveSurface`: sheet < 600, dialog
      600–1239, painel lateral direito ≥ 1240
- [x] **Zero `showModalBottomSheet` fora do componente** — os 10 formulários e o
      recategorizar em lote passaram pela superfície responsiva
- [x] `SectionCard` e `MetricCard` deletados; 19 chamadas viraram
      `RuledSection` e `LedgerTile`
- [x] O ocre saiu do seletor de cor de categoria; as 12 vieram da mesma busca
      que produziu a paleta de gráfico
- [x] `responsive_sheet_test.dart` — as três apresentações

**A estimativa do plano estava errada, e para melhor.** Eu previa ~145 decisões
semânticas em `brand` e `danger`. Lendo as 134 ocorrências uma a uma, `danger`
era **erro de verdade em todas**: banner de falha, ação destrutiva, fatura
vencida, saldo negativo, orçamento estourado, variação desfavorável. Virou
renomeação. `brand` se dividiu em três, e só **8** eram sentido de dinheiro —
toast de sucesso, fatura paga, preço que caiu, gasto abaixo da meta, tendência
para baixo. O resto era ênfase.

Um erro meu no caminho: usei uma expressão regular para tirar `icon:` de dentro
do `MetricCard` e ela apagou o ícone do `_OperationTile`, que não tem nada a ver
com métrica. Refeito varrendo o bloco de cada chamada em vez de casar texto
solto.

Fica para o PR 6, com motivo:

- [ ] 28 `Card(`, 22 `Chip(`, 40 `FilledButton`, 7 `LinearProgressIndicator`.
      Os componentes existem (`RuledSection`, `MonoTag`, `InkButton`,
      `RuleBar`); a troca é por chamada e mistura-se com o trabalho de tabela e
      painel do PR 6, então vai junto em vez de duas passagens pelos mesmos
      arquivos.
- [ ] `TextStyle` e `EdgeInsets` literais — mesma razão.
- [ ] Endereço próprio da tela de entrada e recuperação de senha: continua no
      PR 7, onde a recuperação já estava. O que eu disse no PR 4 ("vai no PR 5")
      estava desalinhado com o plano.

### PR 6 — Densidade do desktop · **entregue** (2026-08-19)

- [x] **Histórico em tabela acima de 905pt** — cabeçalho de colunas com pauta
      pesada, zebra, marca de categoria e a coluna de valor atrás de uma pauta
      vertical. Abaixo disso continua a lista empilhada, com os mesmos dados,
      a mesma seleção e as mesmas ações
- [x] **Procedência no painel de detalhe** — origem, arquivo, confiança e chave
      de dedupe
- [x] `CommandPalette` (⌘K) com busca por nome **e por espaço**, navegação por
      seta, `Enter` para executar, `Esc` para sair
- [x] Atalhos globais: `⌘K`, `N` para novo lançamento, `1`–`4` para os espaços
- [x] `keyboard_test.dart` — 7 casos

**Três colunas do banco estavam sendo lidas e jogadas fora.** `source_file`,
`confidence` e `dedup_key` existem desde a primeira migration e o
`select('*')` já as trazia — só não eram mapeadas no modelo. O app segurava a
procedência inteira e não conseguia mostrá-la. São três campos.

**Recategorização em lote já existia.** O `03-specification.md` a listava como
adiada; o código a tem, com seleção múltipla e a oferta de virar regra logo
depois da correção. A especificação foi corrigida, não o código.

Um defeito latente veio à tona: `CategoryMark` desenhava a barra da categoria
como um lado da borda, e `BoxDecoration` dispara assert quando um raio encontra
uma borda de lados diferentes. Nunca tinha aparecido porque nenhuma tela punha a
marca em todas as linhas de uma vez — a tabela pôs. A barra virou filho, não
borda.

Fica para o PR 7, com motivo:

- [ ] 28 `Card(`, 22 `Chip(`, 40 `FilledButton`, 7 `LinearProgressIndicator`.
      Adiei de novo, e desta vez a razão é honesta: são trocas por chamada em
      muitos arquivos, e eu preferi não fazê-las às pressas no fim de um PR
      grande. Os componentes existem e o trabalho é mecânico.
- [ ] `TextStyle` e `EdgeInsets` literais.

### PR 7 — Ritual e primeira sessão · ~2 dias

- [ ] `ReviewCard` com aprovar / corrigir / sempre assim; gesto no celular,
      teclado no desktop
- [ ] Onboarding "dados antes de configuração", quatro passos
- [ ] Fluxo do Atalho dentro do app, com verificação real da primeira captura
- [ ] Estados vazios desenhados nas seis listas
- [ ] Skeleton por card no lugar do spinner de tela cheia

**Total: ~12 dias de trabalho focado.** PRs 0–2 (~3,5 dias) já entregam a maior
parte da mudança visual.

---

## Riscos

**A migração de `brand` e `danger` é onde bugs entram.** São decisões caso a
caso, e um erro não quebra teste — só fica feio ou, pior, comunica errado (uma
saída comum pintada de vermelho de problema). Mitigação: PR 2 antes de PR 5, para
os componentes absorverem a maioria; e revisão por golden, não por leitura de
diff.

**Fontes empacotadas aumentam o bundle web.** Três famílias em subconjunto latino
≈ 250–350 KB. Aceitável, mas medir; se pesar, usar `font-display` e subsetting.

**`insights_card_test.dart` quebra se os ícones mudarem** — dois
`find.byIcon`. Trocar por `find.bySemanticsLabel` no PR 0.

**Escopo que não pode vazar para dentro deste trabalho:** competência de fatura,
dedupe, RLS e linhagem de importação são premissa. Nenhum PR aqui toca
`lib/domain`, `lib/data` ou `supabase/`.

## Critério de aceite do conjunto

1. Nenhum `Card`, `NavigationBar` ou `NavigationRail` em `lib/presentation`.
2. Todo valor financeiro passa por `AmountText`; nenhum `currency.format` solto
   dentro de um `Text`.
3. Nenhum literal de cor, espaço, raio ou tipografia fora de `lib/core`.
4. `dart analyze` limpo, sem depreciações pendentes.
5. Contraste AA verificado nos dois temas pelo arnês de `theme_test.dart`.
6. O web tem URL, teclado e tabela; nenhum bottom sheet acima de 1240px.
7. `flutter test` verde — os 378 testes existentes mais os novos.
