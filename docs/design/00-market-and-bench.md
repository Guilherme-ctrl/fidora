# 00 — Mercado e benchmark

## Onde o Finora joga

O Finora não é um app de orçamento genérico. Ele nasceu de uma planilha própria
(`Financeiro AI — Controle Mestre`) e carrega três coisas que a maioria dos
concorrentes não tem:

1. **Captura no momento da compra** via automação de Transação do iOS + Apple Pay,
   com token revogável e Edge Function (`AD-001`).
2. **Competência de fatura como conceito de primeira classe** — o gasto do cartão
   pertence ao mês de fechamento, não ao dia da compra. Quase nenhum app popular
   modela isso corretamente; eles tratam cartão como conta.
3. **Linhagem de importação e fila de revisão** — cada lançamento sabe de onde
   veio, e conciliação com captura do Atalho é idempotente.

Isso posiciona o produto num nicho específico: **quem já controla finanças com
rigor de planilha e não aceita a imprecisão dos apps de massa**. Não é o público
de "quero começar a me organizar". É o público que hoje mantém uma planilha
porque nenhum app respeita o modelo dele.

Essa escolha tem consequência direta de design: densidade é uma virtude, não um
problema. O erro seria copiar a interface de um app de massa.

## Benchmark — internacional

| Produto | Força de design | Fraqueza | O que roubar |
|---|---|---|---|
| **Copilot Money** | Considerado o app de finanças mais bem desenhado do mercado; categorização automática forte; aba **Review** com interação de swipe para confirmar/recategorizar | Só iOS/macOS, sem web, sem Android | **A fila de revisão como ritual diário.** O Finora já tem `review_queue_page` — mas ela está escondida em "Mais", tratada como tarefa administrativa em vez de o momento central do produto |
| **Monarch Money** | Design limpo e consistente entre web e mobile; forte em household/compartilhado; net worth e metas no mesmo painel | Preço alto; menos opinativo | **Paridade real web/mobile.** O web deles é um web app, não um app espremido |
| **YNAB** | Método forte, mudança de comportamento, comunidade | Interface difícil, curva de aprendizado longa | **A ideia de que o app tem uma opinião.** O Finora tem uma regra própria (competência) e deveria ensiná-la, não escondê-la |
| **Stripe Dashboard** (fora de categoria, referência de ofício) | Numerais tabulares alinhados à direita, sparklines inline, drill-down que preserva o lugar do usuário | — | **Disciplina numérica.** É o que separa interface "financial-grade" de interface genérica |
| **Era** | Camada de assistente/AI sobre os dados | Jovem, dados dependentes de agregador | O Finora já tem `domain/narrative.dart` e `insights.dart` — a matéria-prima de uma camada de linguagem natural existe e está subutilizada |

## Benchmark — Brasil

| Produto | Posição | Observação para o Finora |
|---|---|---|
| **Organizze** | O mais conhecido do país; web + iOS + Android; Open Finance; controle compartilhado para casais; reputação forte de atendimento | É o padrão de expectativa do usuário brasileiro. Se o Finora tiver web pior que o do Organizze, perde por comparação direta |
| **Mobills** | Muito popular; Android/iOS/web; integra gastos com investimentos | Densidade alta e visual carregado — território a **não** ocupar |
| **Minhas Economias / FinVibe** | Nicho, mais leves | — |
| **Apps de banco (Nubank, Itaú)** | Onde a maioria já vê o extrato | O Finora nunca vence em captura bruta; vence em **consolidar múltiplos cartões e portadores num modelo único** |

O contexto de Open Finance no Brasil (mais de 100 milhões de contas conectadas e
mais de 154 milhões de consentimentos ativos reportados em 2026) explica por que
o usuário brasileiro hoje **espera** que dados apareçam sozinhos. O Finora
resolve isso por outro caminho — Atalho + importação de extrato — e precisa
comunicar essa escolha explicitamente, senão parece uma limitação em vez de uma
decisão de privacidade.

## Conclusões do benchmark

1. **A concorrência ganha no visual, não no modelo.** O modelo financeiro do
   Finora é mais correto que o da maioria. O gap é de apresentação.
2. **Ninguém do mercado brasileiro tem um web app de verdade bem resolvido.**
   Existe espaço para o Finora ser o melhor web da categoria, e hoje ele é
   literalmente o app mobile esticado (ver `02-ux-audit.md`).
3. **A revisão de lançamentos é o ritual que fideliza.** Copilot provou isso.
   O Finora tem a estrutura de dados e escondeu a experiência.
4. **Densidade calma vence densidade nervosa.** A referência de tipografia e
   espaçamento deve ser Stripe/Copilot, não Mobills.

## Fontes

- [Monarch Money vs YNAB vs Copilot Money (2026)](https://top-apps-list.com/articles/monarch-money-vs-ynab-vs-copilot-money/)
- [Era vs. Monarch vs. Copilot vs. YNAB: 2026 comparison](https://era.app/articles/era-vs-monarch-vs-copilot-vs-ynab/)
- [Best Budgeting Apps in 2026: YNAB vs Copilot vs Monarch](https://www.openbudget.sh/blog/best-budgeting-apps-in-2026-ynab-vs-copilot-vs-monarch-vs-openbudget)
- [Melhores Apps Controle Financeiro 2026: Mobills vs Organizze](https://gazetabrasilia.com.br/melhores-aplicativos-de-controle-financeiro-2026/)
- [10 apps de controle financeiro para 2026 — TechTudo](https://www.techtudo.com.br/listas/2026/01/10-apps-de-controle-financeiro-para-cuidar-melhor-do-dinheiro-em-2026-edapps.ghtml)
- [Fintech UI/UX Design: Best Practices for Financial Apps in 2026](https://www.theskinsfactory.com/uiux-design-blog/fintech-ui-ux-design)
- [Fintech Dashboard Design: 9 Real Products, Analyzed (2026)](https://adminlte.io/blog/fintech-dashboard-design-examples/)
