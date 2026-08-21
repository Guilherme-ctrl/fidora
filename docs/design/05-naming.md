# 05 — Naming

> **Decidido (20 ago 2026): o nome é Compasso.** O dono trouxe um board de marca
> fechado — nome, símbolo, cores, tipografia e assinatura — e o produto foi
> renomeado inteiro no mesmo dia. O documento abaixo fica como está: é o
> raciocínio que existia *antes* da decisão, e a lista de alternativas que ele
> gerou não incluía Compasso.
>
> Vale registrar que a recomendação que este documento fazia — *"não trocar
> antes de aprovar a direção de design; nome é a última peça, ele deve caber no
> visual"* — foi seguida na prática: o nome só mudou depois de o fúcsia sobre
> escuro estar aprovado, e o símbolo do board é fúcsia sobre escuro.
>
> **O aviso do fim continua valendo, e agora vale mais**: nenhuma verificação de
> INPI, domínio ou handle foi feita para "Compasso" — e é um substantivo comum,
> o que costuma ser pior nesse quesito, não melhor.
>
> Pendências mecânicas que a troca deixou: `pubspec.yaml` ainda é
> `financeiro_ai`, o repositório ainda é `fidora`, e o arquivo de configuração
> de produção ainda é `finora.production.json`. Nenhuma delas é visível ao
> usuário; todas são renomeações que quebram caminho e merecem passo próprio.

## Primeiro: existe uma inconsistência a resolver

O produto tem três nomes vivos ao mesmo tempo:

| Onde | Nome |
|---|---|
| `pubspec.yaml` → `name:` | `financeiro_ai` |
| Repositório / `.idea/fidora.iml` | **fidora** |
| `README.md`, `main.dart:42`, `config/finora.production.json`, contrato de importação | **Finora** |

Todos os imports do código são `package:financeiro_ai/...`. Independentemente do
nome escolhido, isso precisa convergir — o contrato de importação JSON usa
"Finora 1.0" e é a string que aparece em dado de produção.

## Diagnóstico de "Finora"

**A favor**

- Duas sílabas fortes, fácil de falar em português, sem ambiguidade de leitura.
- Termina em vogal aberta — soa bem no imperativo ("abre o Finora").
- Já está em produção: contrato JSON, nome do projeto Supabase, README.
- Não tem conotação negativa.

**Contra**

- **`Fin-` é o prefixo mais saturado da categoria.** Finora, Fintual, Finbits,
  FinVibe, Finanzero, Finpass. O nome anuncia o setor e não diz nada sobre o
  produto — é a estratégia de nome mais genérica que existe em fintech.
- **Diz "finanças", quando o produto é sobre entender.** O diferencial do Finora
  não é ser um app de finanças; é ser o único que respeita competência de fatura,
  guarda a linhagem de cada lançamento e captura no momento da compra.
- **Colide foneticamente com "fidora"**, o próprio nome do repositório — se dois
  nomes tão próximos já se confundem internamente, se confundem fora.
- Sonoridade próxima de nomes de instituição financeira tradicional.

**Veredito:** Finora é um nome **seguro e adequado**, não um nome forte. Trocar é
opcional; a decisão depende de quanto o produto pretende sair de uso pessoal. Se
ficar pessoal, o custo da troca não se paga. Se houver intenção de distribuir,
vale trocar agora, enquanto o custo é um `sed` e não uma base de usuários.

## Critérios usados

1. Pronunciável em português sem hesitação e sem soletrar.
2. Duas ou três sílabas.
3. Não começa com `fin`, `pay`, `mo` ou `conta`.
4. Diz algo sobre **clareza, registro ou ritmo** — não sobre dinheiro.
5. `.com.br` plausível e handle curto.
6. Funciona como verbo ou substantivo em frase ("lancei no ___", "o ___ avisou").

## Alternativas

### A. Registro e livro-razão — a linha mais alinhada ao produto

| Nome | Origem | Por quê | Risco |
|---|---|---|---|
| **Razão** | "livro-razão", o registro contábil definitivo | Palavra portuguesa, dupla leitura perfeita: o registro *e* o bom senso. "Ver a Razão do mês" funciona nos dois sentidos. É o nome mais inteligente da lista | Palavra comum → SEO e domínio difíceis |
| **Lastro** | garantia que dá respaldo a um valor | Sonoridade forte, conceito financeiro real, pouco usado em consumo. Combina com "cada número tem lastro na transação que o gerou" — que é literalmente o princípio de qualidade do produto | Termo técnico, pode soar sério demais |
| **Folio** | fólio, a folha numerada do livro contábil | Curto, internacional, elegante. Já é vocabulário de design (portfólio, in-folio) | Genérico em software |
| **Verso** | o lado de trás da folha lançada | Bonito, curto, inesperado | Ambíguo demais sozinho |

### B. Clareza e leitura

| Nome | Origem | Por quê | Risco |
|---|---|---|---|
| **Nítido** | adjetivo | Diz exatamente o que o remake quer entregar. "Está nítido" é uma frase que o produto pode reivindicar | Adjetivo puro, difícil de registrar |
| **Claro** | — | Perfeito conceitualmente | **Descartado**: operadora de telecom no Brasil |
| **Aurora** | a luz que precede o dia | Bonito, e mantém o `-ora` final de Finora — troca com custo baixo de reconhecimento | Muito usado em produtos de dados |

### C. Ritmo e periodicidade — o conceito central do produto

O Finora é organizado por **competência**: ciclos, fechamentos, meses. Essa é a
veia de nome mais própria e menos explorada.

| Nome | Origem | Por quê | Risco |
|---|---|---|---|
| **Ciclo** | o ciclo da fatura | Descreve o modelo mental exato do produto. Curto, português, pronunciável | Comum |
| **Fecha** / **Fechô** | "a fatura fecha dia 28" | Vocabulário nativo do domínio, e "fechô" tem a informalidade brasileira certa | Informal demais para um produto sério |
| **Marco** | marco temporal, ponto de referência | Sólido, curto, também é nome próprio → soa humano | Nome de pessoa |
| **Compasso** | a métrica que organiza o tempo | Metáfora musical elegante para ritmo de gastos — e o produto já tem uma tela chamada "Ritmo de gastos" | Três sílabas, mais longo |

### D. Evolução mínima de Finora

Se o objetivo for manter reconhecimento e só reduzir a genericidade:

| Nome | Ganho | Perda |
|---|---|---|
| **Finora** (manter) | Custo zero, já em produção | Continua genérico |
| **Nora** | Tira o `fin-`, mantém a sonoridade, vira quase um nome de assistente — combina com a camada de linguagem natural que `domain/narrative.dart` já produz | Nome próprio comum |
| **Ora** | Radical puro, "ora" = agora em português | Curto demais, indexação impossível |

## Recomendação

**Ranking:**

1. **Razão** — o único nome da lista que carrega o produto inteiro numa palavra:
   é o livro-razão *e* é o bom senso. Aceita o slogan óbvio: *"Suas contas, com
   razão."* Aceita a marca visual (o "ã" é um símbolo gráfico pronto).
2. **Lastro** — se "Razão" for julgado abstrato demais. Mais concreto, mais raro,
   e ancora o princípio de qualidade do produto.
3. **Ciclo** — a escolha segura e descritiva.
4. **Manter Finora** — escolha legítima se o produto continuar pessoal. Nesse
   caso, resolver a inconsistência: renomear o repositório e o `pubspec.yaml`
   para `finora`.

**Não** recomendo trocar antes de aprovar a direção de design. Nome é a última
peça: ele deve caber no visual, e não o contrário.

## Aviso

Nenhuma verificação de marca registrada (INPI), domínio ou handle foi feita —
não tenho como confirmar disponibilidade. Antes de qualquer decisão, checar INPI
classe 09/36/42, `registro.br` e as lojas de aplicativo.
