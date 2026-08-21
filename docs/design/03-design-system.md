# 03 — Design System "Compasso"

> **Correção de rota (19 ago 2026).** A primeira versão deste documento mandava
> preservar a paleta de `lib/core/theme.dart`. Estava errado, e travava o remake
> dentro do problema. O bege `#F5F3EC` não é uma cor de marca — é o *surface
> tint* do Material 3 vestido de bege, e é ele que obriga todo conteúdo a virar
> card branco flutuando. O que se preserva é o **método** (contraste medido,
> tokens semânticos, `ThemeExtension`), não os valores.

> **Quarta correção (20 ago 2026) — a virada fúcsia.** Avaliação do dono:
> *"está parecendo um artigo científico no modo branco"*. Estava certo. As três
> primeiras correções tiraram coisas — o bege, o latão, o amarelo — e o que
> sobrou foi um sistema tecnicamente correto e sem temperatura nenhuma. Um app
> que se abre todo dia precisa de uma cor que seja dele. As mudanças estruturais
> desta virada estão marcadas ao longo do documento; o método não mudou, e é por
> isso que cada valor novo aqui foi medido antes de ser publicado.

> **Quinta correção (20 ago 2026) — a marca chegou.** O dono trouxe um board de
> marca fechado: nome **Compasso**, símbolo (um C aberto com agulha de bússola),
> quatro cores (`#FF3D8A`, `#111317`, `#6B6F76`, `#F2F3F5`), tipografia **Sora**
> e a linha *"Seu dinheiro no ritmo certo."*. Junto veio a avaliação de que a
> home continuava sem personalidade. As quatro correções anteriores foram o
> sistema procurando identidade por medição; esta é a identidade chegando
> pronta, e o trabalho virou **encaixar o sistema nela sem afrouxar o rigor** —
> os quatro valores entram literais, o resto é derivado e medido.

Nome do sistema: **Compasso**, o mesmo do produto. Era "Ledger" — o livro-razão:
denso, alinhado e legível por definição. Aquele nome descrevia bem o que o
sistema fazia e mal o que o produto é; com marca de verdade, ter dois nomes é só
mais uma coisa para explicar.

## O diagnóstico do "cara de Flutter"

Cinco coisas produzem a aparência genérica, e nenhuma delas é limitação do
framework:

| Sintoma | Causa no código | O que o Ledger faz |
|---|---|---|
| Fundo bege com cards brancos boiando | `scaffoldBackgroundColor: canvas` + `cardTheme` | O fundo **é** a superfície. O que separa é pauta, não card |
| Botão primário tonal na cor da marca | `ColorScheme.fromSeed` | A ação preenche com **a** cor da marca — `#FF3D8A`, vinda do board, não gerada por semente |
| Cantos de 22px em tudo | `cardTheme` radius 22 | Escala de raio própria (6 / 11 / 18 / 24), e superfície só em objeto de verdade |
| Números iguais a texto | nenhuma fonte declarada no `pubspec.yaml` | Uma família variável no display e na interface, mono no metadado, tabular em toda coluna |
| Barra e rail do Material | `NavigationBar` / `NavigationRail` | Componentes próprios |

Os três widgets que sozinhos carregam a aparência Material são `Card`,
`NavigationBar` e `NavigationRail`. Substituí-los é a maior parte do trabalho
visual.

## Princípios

1. **O que separa é a pauta.** Seção não é objeto. Superfície e raio existem
   apenas para o que é objeto de fato: o cartão, o item de revisão, uma opção
   escolhível.
2. **A ação primária é a marca.** Fúcsia `#FF3D8A`, cheia, com texto quase
   preto por cima. Foi o inverso disto até a quarta correção — e o inverso
   estava certo enquanto o sistema não tinha marca nenhuma para gastar. O que
   continua valendo é a escassez: **uma** cor de ação, em **um** botão por tela.
3. **O número tem duas vozes.** O valor de manchete é largo e pesado — a mesma
   família, puxada nos eixos `wght` e `wdth`. A coluna é máquina — tabular,
   alinhada à direita, atrás de uma pauta vertical. Metadado é mono, versalete,
   espaçado.
4. **O escuro é o padrão.** É onde o fúcsia tem o contraste que a marca precisa;
   o claro existe porque o dono pediu e é mantido no mesmo rigor, não é um
   descarte. Nenhum amarelo, ocre ou âmbar no sistema.
7. **O número vem antes da frase.** Quem abre um app de finanças duas vezes por
   dia não está lendo, está conferindo. A home abre em três valores e uma linha;
   o texto — que continua correto e continua útil — vem depois deles.
5. **A cor categórica trabalha.** Ela identifica a categoria numa barra de 3px na
   marca do lançamento — em vez de ícone genérico ou emoji.
6. **Acessível por padrão.** AA (4.5:1) em texto normal, 3:1 em componente, alvo
   ≥ 44×44, foco visível, cor nunca sozinha.

## Cor

### Papel e tinta

**Em negrito, os quatro valores que vieram do board.** O resto é derivado deles.

| Token | Claro | Escuro | Uso |
|---|---|---|---|
| `canvas` | **`#F2F3F5`** | **`#111317`** | o chão |
| `surface` | `#FFFFFF` | `#191D23` | **só** objeto discreto |
| `sunken` | `#E7E9EC` | `#0B0D10` | zebra de linha e tabela |
| `ink/strong` | **`#111317`** | **`#F2F3F5`** | texto |
| `ink/muted` | `#55595F` | `#9AA1AA` | secundário, ≥ 4.5:1 |
| `ink/subtle` | `#5F636A` | `#8B929B` | metadado, ≥ 4.5:1 nos **três** chãos |
| `rule` | `#DFE2E6` | `#262A31` | a pauta comum |
| `rule/2` | **`#6B6F76`** | **`#6B6F76`** | borda de componente — WCAG 1.4.11 pede 3:1 |
| `rule/heavy` | `#111317` | `#F2F3F5` | pauta de cabeçalho, 2px |

O viés de magenta dos neutros saiu: o board pede cinza-azulado neutro, e um chão
neutro é o que deixa o fúcsia ser a única coisa colorida da tela.

> **O cinza `#6B6F76` quase virou o metadado, e a medição não deixou.** Ele dá
> 4,55:1 sobre o fundo claro — passa — mas 4,15:1 sobre a zebra, e metadado é
> justamente o que aparece em linha zebrada. Então ele foi para onde de fato
> serve, a borda de componente, onde 3:1 é a régua e ele sobra. O metadado
> escureceu o mínimo necessário para passar nos três chãos.

> **O chão claro deixou de ser branco, e uma invariante caiu junto.** O sistema
> tinha uma regra dizendo que o chão não podia estar mais de 5 pontos de
> luminância abaixo da superfície — ela existia para impedir o bege, que
> obrigava todo conteúdo a virar card. `#F2F3F5` está 10 pontos abaixo do
> branco, de propósito: cinza com card branco é a linguagem do board. A regra
> foi **reescrita para o que sempre importou** — o chão tem de ser *neutro*
> (saturação < 0,16) e estar a **um** passo da superfície, não a três.

### Tinta de caneta

| Token | Claro | Escuro | Uso |
|---|---|---|---|
| `action` | `#FF3D8A` | `#FF3D8A` | **o preenchimento do botão primário — igual nos dois temas** |
| `on/action` | `#14090E` | `#14090E` | o que vai escrito em cima dele |
| `accent` | `#C2185B` | `#FF3D8A` | pauta ativa, foco, item em revisão, linha do gráfico |
| `accent/soft` | `#FDE7F0` | `#2A0F1D` | linha sob o cursor, pílula de sugestão |

O `action` é o único token que **não** troca entre os temas: a marca é a mesma
cor nos dois, e o que muda é o que está por baixo dela.

> **O texto do botão é escuro, e isso é medida, não gosto.** `#FF3D8A` com
> branco por cima dá **3,34:1** — reprova em AA. Com `#14090E` dá **5,85:1**.
> O fúcsia é claro demais para carregar branco; quem publica botão rosa com
> letra branca está publicando um contraste que não passa. Medido em
> `test/theme_test.dart`, que falha se alguém inverter.

> **Segunda correção (19 ago 2026).** A versão anterior usava latão
> (`#8A6A18` / `#D9B860`). Avaliação do dono: *"esse bege/amarelo precisa
> sair"* — e ele estava certo duas vezes, porque o ocre reintroduzia por trás
> exatamente a temperatura quente que o bege do fundo tinha acabado de perder.
> **Amarelo, ocre e âmbar saíram do sistema inteiro**, inclusive da paleta
> categórica.

> **Quarta correção (20 ago 2026).** O azul-caneta saiu junto. Ele resolvia o
> problema de temperatura sem resolver o de identidade — era correto e anônimo.
> A referência de mercado é explícita: Organizze e S1NC vendem confiança em azul
> e verde e por isso se parecem entre si; a Brim ocupa o extremo oposto com
> magenta sobre preto e é reconhecível numa miniatura. Este app tem um usuário
> só, então não precisa parecer um banco — precisa parecer o dele.

O fúcsia aparece onde há **ação**: o botão, a pauta ativa, o anel de foco, o
item aguardando revisão, a linha do gráfico. Por isso `pending` é a mesma cor:
um lançamento em revisão não é um problema, é uma tarefa. Vermelho fica
reservado a problema de verdade.

### Semântica de dinheiro

| Token | Claro | Escuro | Regra |
|---|---|---|---|
| `income` | `#0B6B4F` | `#3FD98A` | **sempre** com prefixo `+` |
| `expense` | `#140F14` | `#F3EFF4` | saída normal é tinta, **não** vermelho |
| `negative` | `#B03A18` | `#FF7A4D` | só saldo negativo, meta estourada, falha |
| `pending` | `#C2185B` | `#FF3D8A` | não confirmado, em revisão — é ação, não alarme |
| `ignored` | `#6B6270` | `#918A9B` | igual a `ink/subtle` — ver nota |

`negative` foi para o laranja-queimado: com um fúcsia no sistema, um vermelho
puro ao lado dele vira briga de matiz vizinha e o alarme deixa de ler como
alarme.

### Categórica — segura em deuteranopia e protanopia

| # | Claro | Escuro |
|---|---|---|
| 1 | `#553858` | `#A280A4` |
| 2 | `#7F3B3D` | `#D38785` |
| 3 | `#3D5AA9` | `#93A6FE` |
| 4 | `#5B7625` | `#AAC570` |
| 5 | `#3082A2` | `#8CD6F9` |
| 6 | `#5B9086` | `#B0E8DC` |

> **Quarta correção (20 ago 2026).** A paleta foi buscada de novo, agora com a
> faixa do fúcsia (matiz 330–352°) banida junto com a amarela: uma categoria na
> cor da ação faria o gráfico prometer um clique que não existe. E a paleta
> escrita de intuição para acompanhar o fúcsia **falhou medida pela terceira
> vez** — daí a busca com as duas faixas vetadas e separação mínima de 28°.

> **Terceira correção (19 ago 2026).** As duas paletas categóricas anteriores
> deste documento foram escritas de intuição e **falharam quando medidas**:
> a primeira caiu a ΔE 8,4 sob protanopia; a segunda, otimizada só para
> deuteranopia, caiu a ΔE 1,0 sob tritanopia. Esta foi buscada com simulação de
> Viénot–Brettel–Mollon e ΔE CIE76, com a faixa amarela (matiz 30–120°) banida
> e separação mínima de 34° entre matizes.

Cada categoria tem **uma matiz**, renderizada numa claridade para o tema claro e
outra para o escuro — a categoria não troca de identidade ao trocar de tema. As
seis se separam por claridade além da matiz, que é o que sobrevive a qualquer
deficiência de visão de cor.

Medido em `test/categorical_test.dart`, que roda a simulação a cada build:

| | claro | escuro |
|---|---|---|
| ΔE mínimo sob visão normal, deuteranopia e protanopia | **24,5** | **24,7** |
| ΔE mínimo sob tritanopia | 15,0 | 15,3 |
| contraste mínimo com o fundo | 3,53:1 | 5,78:1 |

Uma das seis escureceu na virada Compasso (`#5B9086` → `#4F7F76`): sobre a zebra
do fundo cinza ela media 2,99:1, três centésimos abaixo dos 3:1 — e três
centésimos abaixo é abaixo.

Deuteranopia e protanopia somam ~8% dos homens; tritanopia, ~0,01%. Por isso o
par comum carrega a barra mais alta e a tritanopia um piso — otimizar as três
igualmente gasta todo o orçamento na mais rara.

Aparece como barra de 3px na marca do lançamento. Ordem fixa por categoria: o
verde de Mercado é o mesmo no painel, na projeção e na fatura. Nunca gerar cor
por hash. Acima de seis, agrupar em "Outros".

## Tipografia — três vozes

| Papel | Família | Onde |
|---|---|---|
| **Display** | Sora variável, `wght` 700 | valor dominante: saldo, total de fatura, valor em revisão |
| **Interface** | Sora com `fontFeatures: [FontFeature.tabularFigures()]` | corpo, títulos e **toda coluna numérica** |
| **Metadado** | Sora, `wght` 500 e 600 | rótulo em versalete, cartão, parcela, data, tag, atalho |

> **Quinta correção (20 ago 2026).** Sora, do board, no lugar da Archivo — e
> **o mono saiu**. A JetBrains Mono segurava o metadado desde que o sistema se
> chamava Ledger e nunca esteve errada nos próprios termos, mas versalete mono
> pequeno é exatamente a textura de leitura de instrumento que estava por trás
> do *"parece um artigo científico"*. O que o mono comprava de verdade era
> alinhamento de coluna, e a Sora traz `tnum` — o alinhamento sobrevive à troca,
> o ar de terminal não. Sora tem um eixo só (`wght` 100–800): perdi o eixo de
> largura da Archivo, e a compensação é que a Sora já é larga de desenho. Uma
> família, **80 KB** em subset, contra 392 KB de duas.

> **Quarta correção (20 ago 2026).** A serifa saiu e a Inter saiu junto. A
> serifa no valor dominante é exatamente o que faz a tela parecer publicação, e
> a Inter é o default de todo produto do setor. Ficou **uma** família variável
> nos dois papéis: o display não muda de família, muda de **eixo** — mais peso e
> mais largura na mesma letra. É um recurso que a fonte variável dá de graça e
> que duas famílias estáticas não conseguem imitar.

| Token | Tamanho / linha | Eixos | Família |
|---|---|---|---|
| `display/hero` | 42 / 44 | `wght` 700 | Sora |
| `display/metric` | 26 / 30 | `wght` 700 | Sora |
| `title/lg` | 19 / 26 | `wght` 620 | Sora |
| `title/md` | 13.5 / 18 | `wght` 620 | Sora |
| `body/md` | 14 / 21 | `wght` 400 | Sora |
| `amount/column` | 14 / 20 | `wght` 560, tabular | Sora |
| `meta` | 11.5 / 16 | `wght` 400, tabular | Sora |
| `label/caps` | 10.5 / 14, +0.9 | `wght` 600 | Sora |

A família vai no bundle com subset (latino + pontuação + símbolo de moeda):
**80 KB**, contra 392 KB das duas anteriores e 2,2 MB dos arquivos originais.
| `label/caps` | 9.5 / 14, +0.16em, caixa alta | 600 | mono |

Regras:
- Os eixos do display **nunca** em coluna — eles existem para o número único e
  grande.
- Nenhum texto financeiro abaixo de 13px; metadado mono pode ir a 10.5px porque
  é caixa alta e espaçado.
- Centavos a ~42% do corpo e em `ink/subtle` **apenas** em `display/hero`.

## Espaço, raio, elevação

**Base 4.** Escala `4 8 12 16 20 24 32 40 48 64`.

| Raio | Valor | Uso |
|---|---|---|
| `radius/xs` | 6 | marca de lançamento, tag |
| `radius/sm` | 11 | botão, campo, chip |
| `radius/md` | 18 | objeto: item de lista, opção, modal |
| `radius/lg` | 24 | o que se empilha: a face do cartão, a carta da fila |
| `radius/full` | 999 | pílula — a única forma redonda de propósito |

> **Quarta correção (20 ago 2026).** Os raios dobraram. O teto de 10 foi
> escrito para impedir o `rounded-lg` em tudo, e impediu — mas junto impediu que
> qualquer coisa parecesse um objeto que se pega. Não é o raio que faz o app
> parecer genérico, é aplicá-lo sem escala. A escala continua sendo o contrato:
> `test/theme_test.dart` falha se alguém escolher um canto fora dela.

**Profundidade em três degraus**, no token `Depth`, e só onde há motivo:

| Degrau | Onde |
|---|---|
| `resting` | as cartas de trás do baralho da fila |
| `raised` | a carta da frente — a única coisa do app que se empilha de verdade |
| `glow` | o botão primário, com a sombra na cor da própria ação |

O resto do produto continua em elevação zero: o que separa uma seção da outra é
pauta e zebra, não sombra.

## A marca

O símbolo é **código**, não asset: um `CustomPainter` em
`lib/core/design_system/brand.dart`. Três coisas dependem disso e as três
importam — ele pega a cor da paleta (fúcsia nos dois temas, sem segundo
arquivo); fica nítido dos 20pt de uma barra de abas aos 1024px do ícone da App
Store; e a abertura do C é o mesmo arco que o anel de progresso desenha, que é o
que faz a marca e o instrumento principal do produto parecerem parentes em vez
de vizinhos.

Os ícones de iOS e do PWA saem do mesmo pincel, por
`flutter test tool/generate_icons.dart` — quinze tamanhos para iOS, quatro para
web, um favicon. Marca e ícone não têm como divergir porque são o mesmo desenho.

| Peça | Onde |
|---|---|
| `CompassoMark` | símbolo sozinho — trilho recolhido, ícone, splash |
| `CompassoWordmark` | símbolo + `compasso` em caixa baixa, com a linha opcional |
| `goldens/marca-claro.png` · `marca-escuro.png` | as duas imagens que impedem o desenho de mudar sem ninguém ver |

## Componentes que substituem os do Material

| Sai | Entra | Nota |
|---|---|---|
| `Card` | `RuledSection` | borda superior de 1px, sem fundo, sem raio |
| `Card` (métrica) | `LedgerTile` | pauta de 2px no topo, valor no display, rule vertical entre colunas |
| `ListTile` | `LedgerRow` | marca tipográfica com barra de categoria, zebra, **coluna de valor atrás de pauta vertical** |
| `NavigationRail` | `LedgerSidebar` | seções separadas por pauta, item ativo com barra de tinta à esquerda |
| `NavigationBar` | `LedgerTabBar` | indicador é pauta de tinta no topo, não pílula |
| `Chip` | `MonoTag` | mono, caixa alta, borda de 1px, `radius/xs` |
| `FilledButton` | `InkButton` | fundo `action`, texto `on/action`, brilho na cor da ação |
| — | `ProgressRing` | anel aberto: 26pt ao lado de um título, 38–44pt onde o progresso é o assunto |
| — | `Sparkline` | a linha sem eixo nem grade: gasto **acumulado**, com a cabeça acesa em "hoje" |
| — | `CompassoMark` / `CompassoWordmark` | a marca, desenhada em código |
| `showModalBottomSheet` | `ResponsiveSheet` | sheet < 600 · dialog 600–1239 · painel lateral ≥ 1240 |
| `LinearProgressIndicator` | `RuleBar` / `ProgressRing` | barra de 4px onde é medida; anel onde é conquista |

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
- [x] O fúcsia mede: `#C2185B` em `#FDFBFC` dá 5,70:1; `#FF3D8A` em `#0C0A0D` dá
      5,90:1; e o botão só passa com texto escuro — 5,85:1 contra 3,34:1 com
      branco
- [ ] Todo alvo de toque ≥ 44×44
- [ ] Estado nunca só por cor: sinal, borda ou texto junto
- [ ] Ordem de foco lógica, anel visível no web
- [ ] `Semantics` com valor por extenso
- [ ] 200% de fonte sem overflow — `test/dashboard_layout_test.dart` já cobre a grade
- [ ] Navegação completa por teclado no web
