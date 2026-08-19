# 06 — Roadmap de implementação

Cinco ondas. Cada uma entrega valor sozinha e nenhuma exige a seguinte para ser
útil. Esforço em dias de trabalho focado, não em semanas de calendário.

## Onda 1 — Fundação do sistema (≈3 dias)

Muda a sensação do produto sem mexer em nenhuma tela.

- [ ] `core/tokens.dart` — cor, espaço, raio, tipografia como escalas
- [ ] `core/breakpoints.dart` — a escala única; remover os 11 valores mágicos
- [ ] Fonte Inter com `tnum`; `AmountText` e `Money` como único caminho para
      renderizar valor
- [ ] `money/income` e `money/expense`; **saída deixa de ser vermelha**
- [ ] Raio de card 22 → 16
- [ ] Seletor de tema com persistência em `shared_preferences`

**Pronto quando:** nenhum widget constrói `TextStyle` de valor por conta própria,
e `grep` por literais de padding fora da escala volta vazio.

## Onda 2 — O web deixa de ser um app portado (≈5 dias)

- [ ] `go_router`: rotas nomeadas, período e filtros em query params, deep link
      para transação e fatura
- [ ] `AppSidebar` com os quatro espaços; "Mais" desaparece acima de 1024px
- [ ] `ResponsiveSheet` — um componente, três apresentações
- [ ] `maxWidth: 1440` no container de conteúdo
- [ ] `CommandPalette` (`⌘K`) e o conjunto mínimo de atalhos

**Pronto quando:** F5 em `/faturas/2026-08` devolve a mesma tela, o botão Voltar
do navegador funciona, e é possível operar o app inteiro sem mouse.

## Onda 3 — Hoje e a fila de revisão (≈4 dias)

O trabalho de maior impacto em retenção (`01-growth.md`, V3).

- [ ] Tela **Hoje** com revisões, faturas fechando e alertas de orçamento
- [ ] `ReviewCard` — aprovar / corrigir / sempre assim
- [ ] Swipe no mobile; `J/K/Enter/R` no desktop
- [ ] Badge de contador na navegação
- [ ] Criação de regra de estabelecimento a partir da revisão, em um toque

**Pronto quando:** zerar a fila leva menos de 30 segundos para 10 itens.

## Onda 4 — Densidade e hierarquia (≈5 dias)

- [ ] Dashboard reordenado: hero metric + 3 `MetricTile` + o resto
- [ ] Histórico como tabela acima de 1024px, com seleção múltipla
- [ ] Recategorização em lote — destrava o item diferido de `03-specification.md`
- [ ] Painel de detalhe com linhagem (origem, arquivo, confiança, dedupe)
- [ ] `InvoiceCard` com a linha do tempo do ciclo e a competência explicada
- [ ] Skeleton por card no lugar do spinner de tela cheia

## Onda 5 — Primeira sessão (≈4 dias)

- [ ] Onboarding "dados antes de configuração", 4 passos
- [ ] Fluxo do Atalho dentro do app, com verificação real da primeira captura
- [ ] Recuperação de senha (gate aberto em `03-specification.md`)
- [ ] Estados vazios desenhados nas seis listas
- [ ] Telemetria de ativação — só evento e contagem, nunca valor ou comerciante

## Fora do escopo deste remake

- Open Finance / agregador bancário — decisão de produto, não de design
- Multiusuário real por portador
- Migração do modelo financeiro: competência, dedupe e RLS são premissa

## Critério de aceite do remake inteiro

1. O web tem URL, teclado e tabela; nenhum bottom sheet acima de 1240px.
2. Todo valor financeiro em numeral tabular alinhado à direita.
3. Contraste AA verificado nos dois temas.
4. Nenhum número mágico de layout fora de `tokens.dart` e `breakpoints.dart`.
5. Um usuário novo chega ao primeiro insight sem sair do aplicativo.
6. A fila de revisão é alcançável em um toque a partir de qualquer tela.
