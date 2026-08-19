# 03 — Design System "Fólio"

> **Correção de rota (19 ago 2026).** A primeira versão deste documento mandava
> preservar a paleta de `lib/core/theme.dart`. Estava errado, e travava o remake
> dentro do problema. O bege `#F5F3EC` não é uma cor de marca — é o *surface
> tint* do Material 3 vestido de bege, e é ele que obriga todo conteúdo a virar
> card branco flutuando. O que se preserva é o **método** (contraste medido,
> tokens semânticos, `ThemeExtension`), não os valores.

Nome do sistema: **Fólio** — a folha numerada do livro contábil.

## O diagnóstico do "cara de Flutter"

Cinco coisas produzem a aparência genérica, e nenhuma delas é limitação do
framework:

| Sintoma | Causa no código | O que o Fólio faz |
|---|---|---|
| Fundo bege com cards brancos boiando | `scaffoldBackgroundColor: canvas` + `cardTheme` | O fundo **é** a superfície. O que separa é pauta, não card |
| Botão primário tonal na cor da marca | `ColorScheme.fromSeed` | **A ação primária é tinta**, não cor de marca |
| Cantos de 22px em tudo | `cardTheme` radius 22 | Raio máximo do sistema: 10, e só em objeto de verdade |
| Números iguais a texto | nenhuma fonte declarada no `pubspec.yaml` | Serifa no valor dominante, tabular na coluna, mono no metadado |
| Barra e rail do Material | `NavigationBar` / `NavigationRail` | Componentes próprios |

Os três widgets que sozinhos carregam a aparência Material são `Card`,
`NavigationBar` e `NavigationRail`. Substituí-los é a maior parte do trabalho
visual.

## Princípios

1. **O que separa é a pauta.** Seção não é objeto. Superfície e raio existem
   apenas para o que é objeto de fato: o cartão, o item de revisão, uma opção
   escolhível.
2. **A ação primária é tinta.** Preto sobre papel, branco sobre grafite. Cor de
   marca em botão é a assinatura do tema gerado.
3. **O número tem duas vozes.** O valor de manchete é impresso — serifa, corpo
   grande. A coluna é máquina — tabular, alinhada à direita, atrás de uma pauta
   vertical. Metadado é mono, versalete, espaçado.
4. **Latão é pauta e foco, não preenchimento.**
5. **A cor categórica trabalha.** Ela identifica a categoria numa barra de 3px na
   marca do lançamento — em vez de ícone genérico ou emoji.
6. **Acessível por padrão.** AA (4.5:1) em texto normal, 3:1 em componente, alvo
   ≥ 44×44, foco visível, cor nunca sozinha.

## Cor

### Papel e tinta

| Token | Claro | Escuro | Uso |
|---|---|---|---|
| `canvas` | `#FBFBF9` | `#0E1112` | o chão — papel neutro / grafite |
| `surface` | `#FFFFFF` | `#161A1B` | **só** objeto discreto |
| `sunken` | `#F3F4F1` | `#0A0D0D` | zebra de linha e tabela |
| `ink/strong` | `#0E1112` | `#EDEFEC` | texto e ação primária |
| `ink/muted` | `#525A5B` | `#9AA3A2` | secundário, ≥ 4.5:1 |
| `ink/subtle` | `#6B7476` | `#7F8988` | metadado, ≥ 4.5:1 |
| `rule` | `#E3E5E1` | `#232827` | a pauta comum |
| `rule/2` | `#C7CBC6` | `#343A39` | borda de campo e de objeto |
| `rule/heavy` | `#0E1112` | `#EDEFEC` | pauta de cabeçalho, 2px |

O bege sai. O papel novo é neutro (croma ≈ 0) e o grafite tem viés levemente
frio — nenhum dos dois puxa para o creme.

### Latão

| Token | Claro | Escuro | Uso |
|---|---|---|---|
| `accent` | `#8A6A18` | `#D9B860` | pauta ativa, foco, atalho, item selecionado |
| `accent/soft` | `#F4EDD9` | `#241E10` | linha sob o cursor, estado pendente |
| `brand` (ação) | `#0E1112` | `#EDEFEC` | **botão primário = tinta** |

Latão sobre grafite tem o peso de uma placa gravada e não é o verde
institucional de banco nem o verde ácido que todo dashboard escuro usa.

### Semântica de dinheiro

| Token | Claro | Escuro | Regra |
|---|---|---|---|
| `income` | `#0B6B4F` | `#5CC79B` | **sempre** com prefixo `+` |
| `expense` | `#0E1112` | `#EDEFEC` | saída normal é tinta, **não** vermelho |
| `negative` | `#A33A1F` | `#E5836A` | só saldo negativo, meta estourada, falha |
| `pending` | `#8A6A18` | `#D9B860` | não confirmado, em revisão |
| `ignored` | `#8B9394` | `#6E7877` | fora dos totais pessoais |

### Categórica — segura em deuteranopia e protanopia

`#2F6F5B` · `#3B5C8A` · `#B8892E` · `#A8452F` · `#5A7D8C` · `#7A5A8C`
(no tema escuro, as versões claras equivalentes)

Aparece como barra de 3px na marca do lançamento. Ordem fixa por categoria: o
verde de Mercado é o mesmo no painel, na projeção e na fatura. Nunca gerar cor
por hash. Acima de seis, agrupar em "Outros".

## Tipografia — três vozes

| Papel | Família | Onde |
|---|---|---|
| **Display** | New York / Charter / Georgia (serifa de texto) | valor dominante: saldo, total de fatura, valor em revisão |
| **Interface** | Inter com `fontFeatures: [FontFeature.tabularFigures()]` | corpo, títulos e **toda coluna numérica** |
| **Metadado** | JetBrains Mono / SF Mono | rótulo em versalete, cartão, parcela, data, tag, atalho |

| Token | Tamanho / linha | Peso | Família |
|---|---|---|---|
| `display/hero` | 56 / 54 | 500 | serifa |
| `display/metric` | 27 / 32 | 500 | serifa |
| `title/lg` | 19 / 26 | 600 | interface |
| `title/md` | 13 / 18 | 600 | interface |
| `body/md` | 14 / 21 | 400 | interface |
| `amount/column` | 14 / 20 | 500 tabular | interface |
| `meta/mono` | 10.5 / 15, +0.02em | 500 | mono |
| `label/caps` | 9.5 / 14, +0.16em, caixa alta | 600 | mono |

Regras:
- Serifa **nunca** em coluna — ela existe para o número único e grande.
- Nenhum texto financeiro abaixo de 13px; metadado mono pode ir a 10.5px porque
  é caixa alta e espaçado.
- Centavos a ~42% do corpo e em `ink/subtle` **apenas** em `display/hero`.

## Espaço, raio, elevação

**Base 4.** Escala `4 8 12 16 20 24 32 40 48 64`.

| Raio | Valor | Uso |
|---|---|---|
| `radius/xs` | 2–3 | marca de lançamento, tag |
| `radius/sm` | 5 | botão, campo, chip |
| `radius/md` | 10 | objeto: cartão, item de revisão, opção |

Não existe raio acima de 10. **Elevação zero em todo o produto** — sombra só em
menu suspenso e modal. O que dá profundidade é pauta e zebra.

## Componentes que substituem os do Material

| Sai | Entra | Nota |
|---|---|---|
| `Card` | `RuledSection` | borda superior de 1px, sem fundo, sem raio |
| `Card` (métrica) | `LedgerTile` | pauta de 2px no topo, valor serifado, rule vertical entre colunas |
| `ListTile` | `LedgerRow` | marca tipográfica com barra de categoria, zebra, **coluna de valor atrás de pauta vertical** |
| `NavigationRail` | `FolioSidebar` | seções separadas por pauta, item ativo com barra de latão à esquerda |
| `NavigationBar` | `FolioTabBar` | indicador é pauta de latão no topo, não pílula |
| `Chip` | `MonoTag` | mono, caixa alta, borda de 1px, raio 2 |
| `FilledButton` | `InkButton` | fundo `ink/strong`, raio 5 |
| `showModalBottomSheet` | `ResponsiveSheet` | sheet < 600 · dialog 600–1239 · painel lateral ≥ 1240 |
| `LinearProgressIndicator` | `RuleBar` | 4px, sem raio |

Financeiros específicos: `AmountText` (sinal, tabular, cor semântica, largura de
coluna fixa) · `CycleTimeline` (a competência da fatura desenhada em
`CustomPaint`) · `CompetenceHint` · `BudgetBar` · `ReviewCard` · `CommandPalette`.

## Isto não exige sair do Flutter

Tudo acima é framework padrão, sem dependência nova:

- `TextStyle(fontFeatures: [FontFeature.tabularFigures()])` — o app não usa em
  lugar nenhum hoje
- `CustomPaint` para a linha do ciclo, as pautas e o sparkline
- `Shortcuts` / `Actions` / `Intent` — já existem no framework, zero uso no código
- `TwoDimensionalScrollView` para a tabela do desktop
- `ThemeExtension` — o padrão que `FinoraPalette` já adota corretamente

O que muda não é a tecnologia; é parar de aceitar o `ThemeData` pronto.

## Breakpoints

| Nome | Faixa | Navegação | Formulário | Histórico |
|---|---|---|---|---|
| `compact` | < 600 | tab bar | bottom sheet | lista com gesto |
| `medium` | 600–904 | rail de ícones | dialog | lista, 2 colunas |
| `expanded` | 905–1239 | rail de ícones | dialog | tabela simples |
| `large` | ≥ 1240 | sidebar completa | painel lateral | tabela + seleção múltipla |

Conteúdo com `maxWidth 1440`, grid de 12 colunas, gutter 24.

## Movimento

120ms micro · 200ms painel · 320ms sheet. `easeOutCubic` entrando,
`easeInCubic` saindo. Contagem crescente de 400ms **apenas** no valor de
manchete. `MediaQuery.disableAnimations` respeitado.

## Acessibilidade — checklist de aceite

- [ ] Contraste AA verificado nos dois temas, com o mesmo rigor da auditoria que
      produziu `inkMuted`/`inkSubtle` no tema atual
- [ ] Latão sobre papel: `#8A6A18` em `#FBFBF9` mede 5.3:1 — válido para texto
- [ ] Todo alvo de toque ≥ 44×44
- [ ] Estado nunca só por cor: sinal, borda ou texto junto
- [ ] Ordem de foco lógica, anel visível no web
- [ ] `Semantics` com valor por extenso
- [ ] 200% de fonte sem overflow — `test/dashboard_layout_test.dart` já cobre a grade
- [ ] Navegação completa por teclado no web
