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

### PR 3 — Shell, navegação e IA · ~1,5 dia

- [ ] `LedgerSidebar` e `LedgerTabBar` no lugar de `NavigationRail`/`NavigationBar`
- [ ] Adotar `breakpoints.dart`; remover os onze valores mágicos
      (470, 600, 650, 680, 700, 850, 900, 1100, 1180, 1200, 1250)
- [ ] Quatro espaços — Hoje, Dinheiro, Futuro, Ajustes — conforme [04](04-ia-flows.md)
- [ ] `hoje_page.dart` nova, com a fila de revisão em primeiro plano
- [ ] `maxWidth: 1440` no contêiner de conteúdo
- [ ] Seletor de tema persistido em `shared_preferences` (já é dependência)

**Pronto quando:** "Mais" não existe acima de 1024px e nenhuma página lê largura
direto de `MediaQuery`.

### PR 4 — Roteamento · ~1,5 dia

Independente do visual — **pode correr em paralelo com o PR 2**.

- [ ] `go_router`; `MaterialApp` → `MaterialApp.router`
- [ ] Rotas nomeadas para os quatro espaços e as telas
- [ ] Período e filtros como query params
      (`/transacoes?de=2026-08-01&ate=2026-08-31&cat=mercado`)
- [ ] Deep link para entidade (`/faturas/nubank-1847/2026-09`, `/transacoes/:id`)
- [ ] `AuthGate` como redirect do router, não como `home`

**Pronto quando:** F5 em `/faturas/2026-08` devolve a mesma tela e o Voltar do
navegador funciona.

### PR 5 — Superfícies e limpeza · ~1,5 dia

- [ ] Substituir os 30 `Card(` brutos
- [ ] `ResponsiveSheet` no lugar dos 22 `showModalBottomSheet`/`showDialog`
      — sheet < 600, dialog 600–1239, painel lateral ≥ 1240
- [ ] 24 `Chip(` → `MonoTag`; 39 `FilledButton` → `InkButton`;
      7 `LinearProgressIndicator` → `RuleBar`
- [ ] **Remover os getters depreciados do PR 1** e resolver as ~145 decisões
      semânticas restantes de `brand`/`danger`
- [ ] Zerar `TextStyle(` e `EdgeInsets` literais na apresentação

**Pronto quando:** `dart analyze` limpo e
`grep -rn "BorderRadius.circular(22)" lib` vazio.

### PR 6 — Densidade do desktop · ~2 dias

- [ ] Histórico como tabela acima de 1024px (`TwoDimensionalScrollView`)
- [ ] Seleção múltipla e barra de ação em lote
- [ ] **Recategorização em lote** — destrava o item diferido em
      `docs/aidlc/03-specification.md`
- [ ] `Shortcuts`/`Actions`/`Intent` e `CommandPalette` (⌘K)
- [ ] Painel lateral de detalhe com linhagem: origem, arquivo, confiança,
      chave de dedupe — dados que o modelo guarda e a interface nunca mostrou

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
