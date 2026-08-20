# Plano — remake arquitetural (`arch-remake`)

Origem: `docs/arquitetura-auditoria.md` (auditoria de 20 Ago 2026, nota 5/10).
Alvo: `docs/aidlc/reference-architecture.md`.
Branch base: `arch-audit`.

## Linha de base medida antes de começar

```text
Testes (sem golden):  617 passam
Arquivos Dart:         71
Linhas em lib/:    21.816
Raízes atuais:          5  (application, core, data, domain, presentation)
Features:               0
```

Toda unidade abaixo termina com esses 617 testes passando. Nenhuma unidade tem
permissão de reduzir a contagem.

## Princípio de ordenação

Sete das nove unidades reduzem acoplamento **sem mover um arquivo de lugar**. A
mudança de pastas é a unidade 7, não a 1. O motivo está no relatório: mover 71
arquivos não desacopla nada por si só, e feita primeiro ela produz um diff que
esconde as correções que importam. Feita depois, apenas materializa fronteiras
que já existirão no código.

## Unidades

### Unidade 1 — `failures` (P0.2, P1.4, P2.3)

**Problema:** quatro modelos de erro incompatíveis; infra escrevendo copy em
português; oito `catch (_)` descartando a causa; `LoadFailure` classificando por
substring.

**Entrega:**
- `core/errors/failure.dart` — `sealed class Failure` com as três famílias que a
  referência pede: `BusinessFailure`, `TechnicalFailure`, `UnexpectedFailure`.
  Casos concretos: `DuplicateTransaction`, `InvalidAmount`, `SessionExpired`,
  `PermissionDenied`, `NetworkUnavailable`, `Timeout`, `Unexpected(cause, stack)`.
- Infra mapeia `PostgrestException`/`StorageException`/`SocketException` → `Failure`.
  Os cinco `_friendly*Error` deixam de existir; os 36 `throw FinanceWriteException`
  viram `throw` de falha tipada.
- Presenter ganha um único `failureCopy(Failure)` — o lugar onde o português mora.
- `core/logging/logger.dart`; os oito `catch (_)` viram `catch (e, s)` com registro.
- `LoadFailure` sai do domain e vira mapeamento de copy.

**Benefício:** a UI passa a poder reagir à causa (duplicado → mostrar o
lançamento existente; sessão expirada → mandar ao login). Internacionalização
deixa de ser impossível. Causas param de sumir.

**Risco:** médio. Toca os dois repositórios e todas as telas de escrita. Mitigado
pelos testes de escrita já existentes.

---

### Unidade 2 — `auth-boundary` (P0.1)

**Problema:** `Supabase.instance.client.auth` chamado de dentro de widgets em
quatro pontos; `AuthException` capturada na UI; sem contrato; intestável.

**Entrega:**
- `AuthRepository` (contrato): `authState`, `currentSession`, `signIn`, `signUp`,
  `signOut`, `resetPassword`, `updatePassword`.
- `SupabaseAuthRepository` sobre um `SupabaseClient` **injetado**, não o singleton.
- `FakeAuthRepository` para teste, no mesmo espírito do `DemoFinanceRepository`.
- `auth_gate.dart` deixa de importar `supabase_flutter`.
- Erros de auth passam a ser `Failure` da unidade 1.

**Benefício:** fecha o único caminho de dados do projeto sem inversão de
dependência. O fluxo de login passa a ser testável.

**Risco:** médio-alto — é o caminho de entrada do app. Mitigado por testes novos
do gate, que hoje não existem.

---

### Unidade 3 — `platform-boundaries` (P1.3)

**Entrega:** três contratos pequenos em `core/platform/`, implementados sobre os
pacotes e injetados: `FilePicker` (`file_selector`), `ShareService`
(`share_plus`), `ImageSource` (`image_picker`). O projeto já provou o padrão com
`ReceiptRecognizer` — no mesmo arquivo onde `ImagePicker()` é concreto.

**Risco:** baixo. Mecânico, três pontos de uso.

---

### Unidade 4 — `domain-purity` (P0.3, P2.4)

**Entrega:**
- `FinanceCategory` e `CategoryDraft` guardam `String iconName` / `String colorHex`.
  A resolução para `IconData`/`Color` vira extension de apresentação.
- `category_visuals.dart` sai do `core` e vira apresentação da feature `catalog`.
  Os dois repositórios param de importar Material.
- Os 14 `fromJson` saem do domain para `infra/models/` com mapeadores explícitos.
- Parsing de XLSX sai do domain; `package:excel` passa a ser dependência de infra.

**Benefício:** renomear coluna no Supabase deixa de alterar a camada de regras.
O domain para de depender do Flutter.

**Risco:** alto em volume, baixo em lógica. É a maior unidade mecânica. As 33
imagens de referência são a rede de segurança contra regressão visual.

---

### Unidade 5 — `repository-split` (P1.1)

**Entrega:** `FinanceRepository` (31 métodos, nove áreas) dividido em
`TransactionRepository`, `CatalogRepository`, `InvoiceRepository`,
`ReviewRepository`, `ImportRepository`, `ShortcutTokenRepository`,
`ReceiptStorage`. As implementações Supabase e Demo podem continuar sendo uma
classe cada, implementando várias interfaces — a divisão que importa é a do lado
do consumidor.

**Benefício:** cada feature declara do que realmente depende. Um método novo
deixa de quebrar todos os implementadores.

**Risco:** médio, mecânico.

---

### Unidade 6 — `state-migration` (decisão do dono)

**Entrega:** `flutter_bloc` como dependência; os 12 providers do caminho de
leitura viram Cubits com States explícitos; `ProviderScope` dá lugar a
`RepositoryProvider` + `BlocProvider` como ponto único de composição; os 19
arquivos de apresentação que importam `flutter_riverpod` deixam de importá-lo.

**Risco:** alto. É a unidade de maior superfície na apresentação e a única sem
ganho arquitetural sobre o estado atual — está no plano por decisão do dono,
registrada acima.

---

### Unidade 7 — `import-usecase` (P1.2)

**Entrega:** `ImportInvoiceUseCase` com os passos hoje em `more_page.dart:294-440`
(preview, revisão, segundo preview, validação da regra das linhas 415-419,
escrita) e a regra ganhando teste unitário pela primeira vez. Um estado de
apresentação para o fluxo. `MorePage` volta a ser um menu.

**Risco:** médio. É o fluxo mais complexo do produto e hoje não tem teste
unitário — o que é exatamente o argumento para extraí-lo.

---

### Unidade 8 — `modularization` (P2.1)

**A mudança estrutural principal.** Um commit, sem nenhuma alteração de lógica.

```text
lib/
├── core/
│   ├── di/            (composição hoje em main.dart)
│   ├── errors/        (unidade 1)
│   ├── logging/       (unidade 1)
│   ├── platform/      (unidade 3)
│   ├── theme/         (theme, tokens, typography, breakpoints)
│   ├── routing/       (router, routes, url_strategy)
│   └── design_system/ (o conteúdo de widgets/ledger.dart e common.dart)
│
└── features/
    ├── auth/          domain · infra · presenter
    ├── overview/      (hoje, visão geral, analytics, insights, comparison, narrative)
    ├── transactions/  (histórico, formulário, draft, filtro, amount_input)
    ├── invoices/      (faturas, projeção, forecast, status)
    ├── catalog/       (categorias, cartões, contas, titulares, metas)
    ├── imports/       (statement, invoice, planilha, revisão, exportação)
    ├── review/        (fila, regras de comerciante, identidade)
    ├── reminders/
    ├── settings/      (mais, dados, tokens do Atalho, aparência)
    └── shared/widgets/
```

`application/` desaparece: contratos vão para o domain de cada feature, providers
para `core/di/`, `reminder_service` e `receipt_recognizer` para suas features.

**Risco:** baixo em lógica (`git mv` + reescrita de imports), alto em conflito de
merge. Deve ir sozinha num commit, sem outra mudança junto.

---

### Unidade 9 — `write-state` (P2.2)

**Problema:** 105 `setState` em 18 widgets reimplementam `busy`/`error` a cada
tela; existe um único controlador de estado no projeto.

**Entrega:** uma camada de estado para os fluxos de escrita que a merecem —
transação, importação e autenticação. **Não** para todo CRUD: a referência avisa
contra use case que só repassa chamada, e o mesmo vale para controlador que só
embrulha um `save`.

---

### Unidade 10 — `routing-completion`

**Problema:** 7 das 16 páginas têm endereço. `context.go` aparece 2 vezes no
projeto; `MaterialPageRoute`, 10.

**Entrega:** endereço para Contas, Titulares, Regras de comerciante, Lembretes,
Tokens do Atalho, Assinaturas, Dados, Fila de revisão e Nova senha. O roteador
passa a viver em `core/routing/`.

**Nota:** é dívida de produto, não violação arquitetural — está no plano porque a
unidade 7 mexe no roteamento de qualquer jeito, e porque a fila de revisão é um
ritual diário sem URL.

## Sequência e portões

| # | Unidade | Move arquivos? | Risco |
|---|---|---|---|
| 1 | `failures` | não | médio |
| 2 | `auth-boundary` | não | médio-alto |
| 3 | `platform-boundaries` | não | baixo |
| 4 | `domain-purity` | não | alto (volume) |
| 5 | `repository-split` | não | médio |
| 6 | `state-migration` | não | alto |
| 7 | `import-usecase` | não | médio |
| 8 | `modularization` | **sim, tudo** | baixo (lógica) |
| 9 | `write-state` | não | médio |
| 10 | `routing-completion` | não | baixo |

Cada unidade é uma branch, no encadeamento que o projeto já usa
(`feat/arch-remake-1` … `-9`), com portão de aprovação do dono ao fim, evidência
em `04-validation.md` e registro em `audit.md`.

## Decisões do dono (20 Ago 2026)

**Migrar para `flutter_bloc`.** Recomendei manter Riverpod; o dono escolheu
conformidade literal com o documento de referência. Consequências registradas:
entra a unidade 6 `state-migration`, o plano vai a dez unidades, e as unidades de
caso de uso e estado de escrita passam a ser escritas em Bloc desde o início.

**Sem portões intermediários.** As dez unidades correm seguidas. Mitigação: 617
testes e 33 imagens de referência ao fim de cada unidade, e nenhuma unidade pode
reduzir a contagem.

## O que este plano não faz
- **Não cria use case que só repassa chamada.** Salvar categoria continua indo
  direto ao repositório.
- **Não introduz camada `datasources/`.** Com um único backend, `SupabaseClient`
  chamado direto no repositório é a decisão correta, e a referência pede
  explicitamente para não criar camada sem responsabilidade clara.
- **Não altera regra financeira, política de RLS nem linhagem de importação.**
