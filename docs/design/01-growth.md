# 01 — Análise de growth

## Premissa honesta

O Finora é hoje um produto de **um dono**, com dados de produção de uma pessoa e
distribuição por TestFlight (`00-foundation.md`). Análise de growth aqui não é
sobre aquisição paga — é sobre responder duas perguntas:

1. **O produto sobrevive ao próprio dono?** Se ele parar de usar por uma semana,
   volta? Hoje não há nada no produto que puxe de volta além da fatura vencendo.
2. **Se um segundo usuário entrar, ele chega ao valor?** Hoje o caminho até o
   primeiro insight passa por criar conta, gerar token, instalar Atalho e
   importar histórico. Isso é uma parede.

O design precisa resolver as duas. Os benchmarks abaixo servem para calibrar
quanto de atrito o mercado tolera.

## Benchmarks públicos de referência

Metodologias divergem entre fontes; use como ordem de grandeza, não como meta.

| Métrica | Faixa reportada | Implicação para o Finora |
|---|---|---|
| Retenção D30, apps de finanças | ~4% (média ampla da categoria) a 10–15% (bancos/fintech) | A categoria inteira perde quase todo mundo em 30 dias. Sobreviver ao mês 1 **é** a estratégia |
| Retenção D1, iOS | ~25% | O primeiro dia decide |
| Retenção D1, LATAM | ~13% | Mercado brasileiro é mais difícil que Europa/MENA |
| Usuários que completam a ativação até D30 | ~14% | Onboarding longo mata o produto |
| Ganho de retenção D30 com onboarding otimizado | até +40% | É a alavanca de maior retorno disponível |

Leitura: **o gargalo não é aquisição, é ativação e ritual.** Todo o esforço de
design deve ir para (a) encurtar o tempo até o primeiro valor e (b) criar um
motivo recorrente de abrir o app.

## Funil atual do Finora, com o vazamento em cada etapa

```text
[1] Instalar / abrir
     ↓  vaza: web não tem URL própria; nada é compartilhável ou linkável
[2] Criar conta
     ↓  vaza: sem recuperação de senha (gate aberto em 03-specification.md)
[3] Ver dados
     ↓  vaza GRAVE: tela vazia. Sem dados importados, o dashboard não diz nada
[4] Gerar token + instalar Atalho
     ↓  vaza GRAVE: passo fora do app, em docs/SHORTCUT.md, manual
[5] Primeira captura Apple Pay
     ↓  vaza: sem confirmação visível no app de que a automação funcionou
[6] Primeira revisão / regra de estabelecimento
     ↓  vaza: review_queue está enterrada dentro de "Mais"
[7] Hábito mensal (fatura fecha → confere → paga)
        único loop que já funciona hoje: lembretes de vencimento
```

### Os três vazamentos que o remake precisa fechar

**V1 — O primeiro minuto não tem valor.**
Hoje o usuário novo vê um dashboard vazio. A correção de design é **inverter a
ordem**: importar antes de configurar. A primeira tela depois do cadastro deve
ser "traga seus dados" com três caminhos (JSON, extrato CSV/XLSX, começar do
zero com lançamento manual), e o dashboard só aparece com algo dentro.

**V2 — A configuração do Atalho é um documento, não um fluxo.**
`docs/SHORTCUT.md` é um manual fora do produto. Precisa virar um passo a passo
dentro do app, com estado verificável: *token gerado → Atalho instalado →
primeira captura recebida*. O card "Automação Apple Pay" em `more_page.dart` já
tem os três passos desenhados; falta ele saber em qual passo o usuário está.

**V3 — Não existe ritual diário.**
O único gancho recorrente é o lembrete de fatura, mensal. Copilot resolve isso
com a fila de revisão diária. O Finora tem `pendingReviews` no snapshot e
esconde. A correção é promover a revisão a destino de primeira classe com
contador visível na navegação.

## Loops de crescimento disponíveis

| Loop | Como funciona | Estado | Custo de implementar |
|---|---|---|---|
| **Ritual de revisão** | Captura gera item de baixa confiança → usuário revisa → vira regra de estabelecimento → menos revisão futura | Dados prontos, UX enterrada | Baixo — é redesenho |
| **Lembrete de fatura** | Fatura fecha → notificação → usuário abre → confere → paga | Funciona | Já feito |
| **Narrativa mensal** | Fim do mês → resumo em linguagem natural do que mudou | `domain/narrative.dart` existe, aparece como card no dashboard | Médio — virar tela/notificação |
| **Compartilhamento entre portadores** | O modelo já tem `holders`; um segundo portador vira usuário | Só modelo de dados | Alto |
| **Exportação como prova social** | CSV/print do mês | `csv_export.dart` existe | Baixo |

O loop com melhor razão impacto/esforço é claramente o **ritual de revisão**.

## Métricas para instrumentar

Nenhuma existe hoje. Ordem de prioridade:

**Ativação**
- `time_to_first_transaction` — do cadastro ao primeiro lançamento visível
- `import_completed` — importou histórico (JSON ou extrato) na primeira sessão
- `shortcut_verified` — primeira captura recebida pela Edge Function

**Ritual**
- `review_queue_cleared` — dias em que a fila chegou a zero
- `rule_created_from_review` — o loop fechou
- `sessions_per_week`

**Saúde do modelo**
- `dedupe_hit_rate` — quantas conciliações a importação evitou duplicar
- `manual_recategorization_rate` — se subir, a categorização automática piorou

**Regra de privacidade:** telemetria de produto num app financeiro pessoal só
com evento e contagem. Nunca valor, comerciante ou categoria. Registrar isso em
`AGENTS.md` quando for implementado.

## Prioridade de growth para o remake

1. Onboarding com dados primeiro (V1) — maior impacto em D1/D7
2. Revisão como destino de primeira classe (V3) — maior impacto em D30
3. Fluxo guiado do Atalho dentro do app (V2) — desbloqueia o diferencial
4. Recuperação de senha — hoje é um beco sem saída literal
5. URLs reais no web — pré-requisito de qualquer compartilhamento

## Fontes

- [Finance App Benchmarks (2026) — Business of Apps](https://www.businessofapps.com/data/finance-app-benchmarks/)
- [App Retention Benchmarks 2026: D1/D7/D30 by Industry](https://vmobify.com/blog/app-retention-benchmarks)
- [Mobile App Retention Statistics 2026](https://www.getpanto.ai/blog/mobile-app-retention-statistics)
- [Growth and Retention Levers for Fintech](https://mobupps.com/blog/growth-retention-levers-for-fintech)
- [App retention rate: 2026 benchmarks by industry — Appcues](https://www.appcues.com/blog/app-retention-is-hard-heres-how-to-improve-it)
