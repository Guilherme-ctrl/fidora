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

### PR 1 — Tokens · ~1 dia

Arquivos novos em `lib/core/`:

```text
lib/core/tokens.dart       espaço, raio, duração, elevação — const, não variam por tema
lib/core/breakpoints.dart  a escala única
lib/core/typography.dart   LedgerText como ThemeExtension
lib/core/theme.dart        FinoraPalette com o conjunto novo de campos
```

**Mantém `FinoraPalette` como nome de classe e `context.palette` como acesso.**
São 270 chamadas; renomear a classe seria churn puro. O que muda é o conjunto de
campos:

| Campo atual | Vira | Observação |
|---|---|---|
| `ink` | `ink` | valor muda: `#17211B` → `#0E1112` |
| `inkMuted` / `inkSubtle` | iguais | valores novos, mesmo rigor de contraste |
| `canvas` | `canvas` | **`#F5F3EC` → `#FBFBF9`** — o bege sai |
| `surface` | `surface` | passa a ser **só objeto discreto** |
| — | `sunken` **(novo)** | zebra de linha e tabela |
| `hairline` | `rule` | + `rule2` (borda) e `rule3` (pauta pesada) |
| `brand` | `brand` | **muda de significado**: passa a ser tinta, não verde |
| `brandSoft` / `onBrandSoft` | `accent` / `accentSoft` | azul-caneta `#1D4E89` |
| `danger` | `negative` | só problema |
| `warning` / `onWarning` | `pending` | azul, não âmbar — revisão é ação |
| — | `income` / `expense` / `ignored` **(novos)** | semântica de dinheiro |
| `info` | removido | 1 uso |
| `cardGradient` / `onCard` | mantidos | 0 usos hoje; a face do cartão passa a usar |
| — | `categorical` **(novo)** | `List<Color>` de 6, ordem fixa |

**Ponte de migração:** manter `danger`, `warning`, `onWarning`, `brandSoft` e
`onBrandSoft` como getters `@Deprecated` apontando para o destino mais próximo.
Isso é o que permite o PR 1 entrar sem quebrar as 270 chamadas — o app compila
com avisos, e os avisos viram a lista de tarefas dos PRs seguintes. Eles são
removidos no PR 5, e aí `dart analyze` limpo é o critério de pronto.

**Fontes** — adicionar ao `pubspec.yaml` (hoje não há nenhuma declarada):

| Papel | Família | Licença |
|---|---|---|
| Display | **Source Serif 4** | OFL |
| Interface | **Inter** | OFL |
| Metadado | **JetBrains Mono** | OFL |

New York é bonita e é só da Apple; empacotar Source Serif 4 mantém iOS e web
idênticos. Cada estilo numérico leva
`fontFeatures: [FontFeature.tabularFigures()]` — recurso que o app não usa em
lugar nenhum hoje.

**Pronto quando:** `buildAppTheme()` devolve os dois temas novos, `theme_test`
passa, e o app compila (com os avisos de depreciação).

### PR 2 — Camada de componentes · ~2 dias

O PR de maior alavancagem. Reescreve `common.dart` e cria os componentes que
substituem os widgets Material.

- [ ] `AmountText` — sinal, tabular, cor semântica, largura de coluna fixa,
      centavos reduzidos só no display. **Único caminho para renderizar dinheiro.**
- [ ] `RuledSection`, `LedgerTile`, `LedgerRow`, `MonoTag`, `InkButton`, `RuleBar`
- [ ] `PageHeading`, `DetailValue`, `PeriodFilterBar` reestilizados
- [ ] `CycleTimeline` em `CustomPaint` — a competência da fatura desenhada
- [ ] `CompetenceHint` extraído de `transaction_form_sheet.dart` para virar
      reutilizável (hoje a regra do produto só existe dentro do formulário)

Ao final, trocar `SectionCard`/`MetricCard` pelos novos nomes com um
`@Deprecated typedef`, para as 21 chamadas migrarem sem PR travado.

**Pronto quando:** os goldens do PR 0 mudaram — e a mudança é a esperada.

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
