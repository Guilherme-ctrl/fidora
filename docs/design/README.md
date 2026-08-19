# Finora — Remake de UI, UX e Design System

Esta pasta documenta o processo completo do remake de interface do produto:
pesquisa de mercado, benchmark, análise de growth, auditoria da interface atual,
o novo design system, a nova arquitetura de informação e as opções de nome.

O código da aplicação continua na raiz do workspace. Aqui só há documentação.

## Ordem de leitura

| # | Documento | O que responde |
|---|---|---|
| 00 | [Mercado e benchmark](00-market-and-bench.md) | Onde o produto joga, contra quem, e o que os melhores fazem |
| 01 | [Growth](01-growth.md) | Onde o funil vaza, quais loops existem, quais métricas seguir |
| 02 | [Auditoria de UX](02-ux-audit.md) | O que está errado hoje, no web e no mobile, com evidência no código |
| 03 | [Design System](03-design-system.md) | Tokens, tipografia, cor, componentes, regras de dinheiro |
| 04 | [Arquitetura de informação e fluxos](04-ia-flows.md) | Nova navegação, web ≠ mobile, telas e estados |
| 05 | [Naming](05-naming.md) | Diagnóstico do nome atual e alternativas |
| 06 | [Roadmap de implementação](06-roadmap.md) | Ordem de execução, esforço e critério de pronto |
| 07 | [Plano de aplicação no código](07-implementation-plan.md) | Os oito PRs, com o tamanho real medido em `lib/` |

## Método

1. **Leitura do sistema existente** — `docs/aidlc/00–04`, `README.md`, `AGENTS.md`
   e o código de `lib/presentation`, `lib/core/theme.dart`, `lib/domain`.
2. **Benchmark** — cinco concorrentes internacionais e quatro brasileiros,
   avaliados por arquitetura de informação, densidade, paridade web/mobile e
   modelo de captura.
3. **Pesquisa de mercado e growth** — benchmarks públicos de retenção e ativação
   de apps de finanças, contexto de Open Finance no Brasil.
4. **Auditoria heurística** da interface atual, com cada achado ancorado em
   arquivo e linha.
5. **Síntese** em design system, IA e protótipo navegável.

## Escopo e limites

- O remake é de **interface e experiência**. O modelo financeiro documentado em
  `docs/aidlc/03-specification.md` é premissa, não está em discussão: competência
  de fatura, dedupe, RLS e linhagem de importação permanecem como estão.
- Os números de mercado citados vêm de fontes públicas secundárias, com
  metodologias diferentes entre si. Estão aqui para calibrar ordem de grandeza e
  decidir prioridade — não como projeção do produto.
- O protótipo é de alta fidelidade visual e **navegável**, mas não conectado ao
  Supabase. Ele existe para aprovar direção antes de escrever Dart.
