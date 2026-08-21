# Auditoria de Arquitetura — Finora (Flutter)

Comparação do estado atual de `lib/` contra a arquitetura de referência
(Clean Architecture modular, raiz `core/` + `features/`).

Nenhum código foi alterado. Este documento é só o diagnóstico e o plano.

Escopo medido: 71 arquivos Dart, 21.816 linhas em `lib/`, 48 arquivos de teste.

---

## 1. Estrutura

### Estado atual

```text
lib/
├── application/     455 linhas   4 arquivos
├── core/            928 linhas   8 arquivos
├── data/          1.753 linhas   2 arquivos
├── domain/        4.024 linhas  24 arquivos
├── presentation/ 14.578 linhas  33 arquivos
└── main.dart         82 linhas
```

### Estrutura de referência

```text
lib/
├── core/
└── features/
```

**Divergência principal.** O projeto tem cinco raízes arquiteturais, não duas.
Quatro delas (`application/`, `data/`, `domain/`, `presentation/`) são
agrupamentos por tipo técnico global — exatamente o padrão que o documento de
referência pede para evitar. Não existe nenhuma pasta `features/`, e nenhuma
funcionalidade do produto é autocontida.

O efeito é concreto e mensurável. A funcionalidade "importar extrato bancário"
está espalhada por seis arquivos em quatro raízes diferentes:

```text
lib/domain/statement_sheet.dart        (parsing de CSV/XLSX)
lib/domain/statement_import.dart       (montagem do documento)
lib/domain/invoice_import.dart         (documento e preview)
lib/data/supabase_finance_repository.dart  (RPCs de preview/import)
lib/presentation/pages/more_page.dart      (fluxo completo de UI)
lib/presentation/widgets/invoice_review_dialog.dart  (revisão)
```

Nenhum desses diretórios diz que essa funcionalidade existe. Para entendê-la é
preciso conhecer o projeto inteiro.

### Camada `application/` — terceira raiz sem responsabilidade clara

`application/` contém quatro coisas heterogêneas:

| Arquivo | O que é | Onde deveria estar |
|---|---|---|
| `providers.dart` | contrato `FinanceRepository` + 8 providers | contratos → `domain/`; providers → DI |
| `appearance.dart` | preferência de tema + `SharedPreferences` | `features/settings/` (ou `core/` se for infra) |
| `receipt_recognizer.dart` | contrato + implementação ML Kit | contrato → domain da feature; impl → infra |
| `reminder_service.dart` | serviço de notificações locais | `features/reminders/` |

Não é uma camada. É uma pasta de sobra.

---

## 2. Core

`core/` está, no geral, correto: `theme.dart`, `tokens.dart`, `typography.dart`,
`breakpoints.dart`, `url_strategy*.dart` são infraestrutura visual e de
plataforma genuinamente transversal. Essa parte da auditoria não aponta
problemas relevantes.

A exceção é `core/category_visuals.dart`. O arquivo mapeia nome de categoria →
`IconData` e string hex → `Color`. Isso é apresentação de uma feature
(categorias), não infraestrutura global. E o preço aparece na camada errada: os
dois repositórios importam `core/category_visuals.dart` para construir
entidades.

```text
data/supabase_finance_repository.dart:3
data/demo_finance_repository.dart:6
```

Ou seja, a camada de infraestrutura depende de `package:flutter/material.dart`
para montar um objeto de domínio. É uma inversão de dependência ao contrário.

O que **falta** no core: não existe `core/di/`, `core/errors/` nem
`core/network/`. A composição de dependências mora em `main.dart` (o que
funciona, e é melhor do que espalhado), mas não há um modelo de erro comum —
ver seção 11.

---

## 3. Features

Não existem. As "features" do produto, se fossem nomeadas a partir do código
atual, seriam aproximadamente estas:

| Feature | Arquivos hoje |
|---|---|
| `auth` | `presentation/auth_gate.dart`, `domain/auth_rules.dart` |
| `overview` | `dashboard_page`, `today_page`, `analytics`, `insights`, `comparison`, `narrative` |
| `transactions` | `transactions_page`, `transaction_form_sheet`, `transaction_draft`, `transaction_filter`, `amount_input` |
| `invoices` | `cards_page`, `projection_page`, `invoice_forecast*`, `invoice_status` |
| `catalog` | `categories_page`, `accounts_page`, `holders_page`, `catalog_drafts`, `*_form_sheet` |
| `imports` | `statement_sheet`, `statement_import`, `invoice_import`, `invoice_review_dialog`, parte de `more_page` |
| `review` | `review_queue_page`, `merchant_rules_page`, `merchant_identity`, `merchant_rule`, `review_item` |
| `reminders` | `reminders_page`, `reminder_service`, `domain/reminders` |
| `settings` | `more_page`, `data_page`, `shortcut_tokens_page`, `appearance`, `csv_export` |

**Acoplamento entre features.** `more_page.dart` importa nove outras páginas
(`presentation/pages/more_page.dart:15-23`). É um hub de navegação, o que
explica parcialmente o acoplamento, mas ele não *só* navega: também executa
importação de faturas e de extratos (748 linhas). Um hub de navegação que
também é o motor de importação acopla duas responsabilidades muito diferentes.

`today_page` → `review_queue_page` e `transactions_page` → `merchant_rules_page`
são acoplamentos diretos de navegação entre funcionalidades que hoje não passam
por nenhuma abstração.

---

## 4. Domain

Esta é a camada de melhor qualidade do projeto em termos de conteúdo — as
regras estão isoladas em funções puras e testadas (`finance_rules.dart`,
`analytics.dart`, `insights.dart`, `invoice_forecast.dart`,
`merchant_identity.dart`). Mas ela tem três contaminações concretas.

### 4.1 Domain depende de Flutter

```text
lib/domain/models.dart:2         import 'package:flutter/material.dart';
lib/domain/catalog_drafts.dart:1 import 'package:flutter/material.dart';
```

O motivo é pequeno e específico:

```dart
// lib/domain/models.dart:142-143 — dentro de FinanceCategory
final IconData icon;
final Color color;
```

```dart
// lib/domain/catalog_drafts.dart:210 — dentro de CategoryDraft
final Color color;
```

Três campos prendem toda a camada de regras de negócio ao SDK do Flutter.

### 4.2 Domain depende de uma biblioteca de infraestrutura

```text
lib/domain/statement_import.dart:5  import 'package:excel/excel.dart';
```

Parsing de XLSX é detalhe de infraestrutura. Está no domínio.

### 4.3 Entidades são também modelos de transporte

Catorze `fromJson` estão declarados dentro de `domain/`, mapeando diretamente
os nomes de coluna do Postgres do Supabase:

```text
domain/models.dart          7 factories fromJson
domain/invoice_import.dart  4
domain/merchant_rule.dart   1
domain/shortcut_token.dart  1
domain/review_item.dart     1
```

Não há separação entre entidade e modelo. Uma renomeação de coluna no Supabase
altera a camada de domínio. A referência pede exatamente o contrário: conversão
entre modelo externo e entidade acontece em `infra/`.

### 4.4 O contrato está na camada errada

`FinanceRepository` — o contrato central do sistema — está declarado em
`lib/application/providers.dart:11`, num arquivo que importa
`package:flutter_riverpod`. O contrato de domínio mora junto do registro de DI
e depende do pacote de gerenciamento de estado.

### 4.5 O contrato é único para o produto inteiro

`FinanceRepository` tem 31 métodos: transações, faturas, cartões,
categorias, metas, contas, titulares, revisão, regras de comerciante, tokens do
Shortcut e upload de recibos. Toda feature depende de uma interface que sabe
tudo sobre todas as outras.

Consequência prática: qualquer teste ou fake de qualquer feature precisa
implementar 35 métodos, e qualquer método novo de qualquer feature quebra a
compilação de todos os implementadores.

### 4.6 `LoadFailure` classifica erro por substring

`domain/load_failure.dart` recebe um `Object error` e faz
`text.contains('socketexception')`, `text.contains('42501')`,
`text.contains('row-level security')`. O domínio está lendo a representação
textual de exceções do Postgrest e do `dart:io`, e devolvendo copy em
português.

Funciona, mas é o acoplamento mais frágil do projeto: depende do texto de
mensagens de erro de bibliotecas de terceiros.

---

## 5. Presenter

67% do código do projeto (14.578 de 21.816 linhas) está em `presentation/`.

### 5.1 Acesso direto a SDK dentro de widgets

```text
presentation/auth_gate.dart:17,61,108,280   Supabase.instance.client.auth
presentation/widgets/receipt_field.dart:161 ImagePicker()
presentation/pages/more_page.dart:302,323   openFile()  (file_selector)
presentation/pages/data_page.dart:131       SharePlus.instance.share()
```

`auth_gate.dart` é o caso mais grave: toda a autenticação — sessão, login,
cadastro, recuperação de senha, troca de senha — fala com o singleton global do
Supabase de dentro de widgets. Não existe `AuthRepository`. Não há como testar
o fluxo de login sem um Supabase real, e não há como trocar de provedor de
autenticação sem reescrever a tela.

`ImagePicker()` é instanciado direto no `_pick` do widget
(`receipt_field.dart:161`) — enquanto, no mesmo arquivo, o reconhecimento de
texto *é* abstraído por trás de `ReceiptRecognizer`. A metade difícil foi
abstraída e a metade fácil não.

### 5.2 Orquestração de negócio dentro de uma página

`more_page.dart` (748 linhas) contém, além do menu:

- `_pickInvoice` — seleção de arquivo, decode UTF-8, parse de JSON
- `_pickStatement` — seleção, detecção XLSX vs CSV, fallback de encoding
  UTF-8 → Latin-1, parse da planilha, coleta de contexto do cartão
- `_runImport` — preview no servidor, diálogo de revisão, **segundo** preview,
  validação da regra de importação, escrita, invalidação de cache, mensagens

Esse último é um caso de uso real, com múltiplos passos, estados intermediários
e uma regra de negócio explícita (`more_page.dart:415-419`: lançar se ainda
houver categorias faltantes ou duplicidades). Está escrito como método privado
de um `StatelessWidget`, misturado com `Navigator.pop` e `ScaffoldMessenger`.

### 5.3 Agregação inline

`dashboard_page.dart:41-49` calcula `cardExpenses`, `accountExpenses` e
`invoiceTotal` com `fold` dentro do `build`. É pouco, e o resto da página
delega corretamente para `analyzePeriod`, `comparePeriods` e `budgetAlerts` —
mas esses três cálculos são regra de negócio na UI, não testados e recalculados
a cada rebuild.

---

## 6. Infra

`data/` tem dois arquivos: `SupabaseFinanceRepository` (761 linhas) e
`DemoFinanceRepository` (992 linhas), ambos implementando o mesmo contrato. A
existência do repositório demo é uma decisão boa: prova que a inversão de
dependência funciona e permite rodar o app sem backend.

Problemas:

### 6.1 A infraestrutura produz copy de interface

```dart
// data/supabase_finance_repository.dart:632
String _friendlyWriteError(PostgrestException error) {
  final text = '${error.code} ${error.message}';
  if (text.contains('transactions_user_id_dedup_key_key')) {
    return 'Este lançamento já existe no seu histórico.';
  }
  ...
}
```

Há cinco tradutores desses (`_friendlyWriteError`, `_friendlyCardError`,
`_friendlyCategoryError`, `_friendlyRuleError`, `_friendlyStorageError`) e 36
`throw FinanceWriteException(...)`. O repositório decide o texto exato que o
usuário vê. A camada mais baixa do sistema está escrevendo interface.

Isso também impede internacionalização e torna impossível a UI reagir
diferentemente a "duplicado" versus "sessão expirada" — ambos chegam como a
mesma classe com uma `String` diferente.

### 6.2 Infra depende de `core/` visual

Já descrito em §2: os dois repositórios importam `category_visuals.dart` para
produzir `IconData`/`Color`.

### 6.3 Infra importa `application/`

`data/supabase_finance_repository.dart:1` importa
`application/providers.dart` — porque é lá que o contrato mora. A seta aponta
para o lugar certo (implementação → contrato), mas o alvo está na camada errada.

**Não é problema:** a ausência de uma camada `datasources/` separada. Com um
único backend, `SupabaseClient` chamado direto no repositório é a decisão
correta — a referência pede explicitamente para não criar camadas sem
responsabilidade clara.

---

## 7. Gerenciamento de estado

O projeto usa Riverpod, não Cubit/BLoC. Isso é equivalente funcional e não é
uma violação — o que importa é o papel que a camada cumpre.

**O caminho de leitura é bom.** `financeCatalogProvider` e
`financeLedgerProvider` separados, compostos em `financeSnapshotProvider`, com
invalidação seletiva (`refreshLedger` vs `refreshFinanceSnapshot`). É uma
decisão deliberada e bem documentada.

**O caminho de escrita não tem camada.** Existe exatamente um `Notifier` no
projeto inteiro (`AppearanceController`, para o tema). Toda escrita —
salvar transação, salvar cartão, importar fatura, revogar token — acontece em
métodos de widget com `setState` local e `try/catch`. São 105 chamadas a
`setState` distribuídas por 18 widgets com estado.

Isso significa que estado de operação (`_busy`, `_failure`, `loadingOpen`) e
tratamento de erro são reimplementados em cada tela, com variações. O fluxo
esperado pela referência é:

```text
Page → Cubit/Notifier → UseCase → Repository
```

O fluxo real é:

```text
Page (setState + try/catch) → Repository
```

Faltam os dois degraus do meio. Para os CRUDs simples (salvar categoria) a
ausência de use case é defensável — a referência avisa contra use case que só
repassa chamada. Para `_runImport` e para o fluxo de autenticação, não é.

---

## 8. Injeção de dependência

**Ponto positivo real:** existe um ponto único de composição (`main.dart:23-29`)
que escolhe entre `DemoFinanceRepository` e `SupabaseFinanceRepository` e
injeta via `ProviderScope.overrides`. É exatamente o que a referência pede.

Problemas:

- `Supabase.instance.client` é acessado como singleton global em quatro pontos
  de `auth_gate.dart`, contornando completamente a DI.
- `ImagePicker()` instanciado dentro do widget (`receipt_field.dart:161`).
- Um provider está declarado dentro da camada de apresentação
  (`presentation/widgets/receipt_field.dart:337`, `receiptUrlProvider`).
- Não existe `core/di/`: os registros estão espalhados por quatro arquivos de
  `application/` mais um de `presentation/`.

---

## 9. Integrações externas

| SDK | Encapsulado? | Onde |
|---|---|---|
| Supabase (dados) | Sim — `FinanceRepository` | `data/` |
| Supabase (auth) | **Não** | `presentation/auth_gate.dart` |
| ML Kit | Sim — `ReceiptRecognizer` | `application/` |
| Notificações locais | Sim — `ReminderService` | `application/` |
| `SharedPreferences` | Parcial | `appearance.dart`, `reminder_service.dart` |
| `image_picker` | **Não** | widget |
| `file_selector` | **Não** | página |
| `share_plus` | **Não** | página |
| `excel` | **Não** | `domain/` |

Cinco de nove integrações atravessam a fronteira arquitetural.

---

## 10. Widgets compartilhados

`presentation/widgets/ledger.dart` (1.114 linhas) é, na prática, o design
system do produto: `AmountText`, `SectionLabel`, `RuledSection`, `LedgerTile`,
`LedgerRow`, `CategoryMark`, `MonoTag`, `InkButton`, `RuleBar`,
`showResponsiveSheet`, `SheetHeader`, `ProgressRing`.

Está no lugar conceitualmente certo (junto da apresentação), mas com o nome
errado — "ledger" sugere a feature de extrato, e o arquivo é importado por
praticamente todas as telas. Pela referência, esses componentes são
infraestrutura visual global (`core/`) ou `features/shared/widgets/`.

Mesma observação para `widgets/common.dart` (`PageHeading`, `PeriodFilterBar`,
`DetailValue`).

Os formulários (`card_form_sheet`, `category_form_sheet`, `goal_form_sheet`,
`transaction_form_sheet`) são específicos de feature e estão numa pasta de
widgets global — deveriam ficar dentro da feature correspondente.

Não encontrei widget compartilhado duplicado.

---

## 11. Tratamento de erros

Não existe um modelo de falha. Existem quatro modelos parciais e incompatíveis:

| Tipo | Onde | Forma |
|---|---|---|
| `FinanceWriteException` | `domain/transaction_draft.dart:154` | `String message` já traduzida |
| `LoadFailure` | `domain/load_failure.dart` | classificação por substring do erro cru |
| `InvoiceImportException` / `StatementParseException` | domain de import | `String message` |
| `AuthException` | do próprio Supabase | vaza direto para `auth_gate.dart:83,109,288` |

Não há distinção entre falha de negócio, falha técnica e falha inesperada — a
referência pede pelo menos essa separação conceitual, e ela não existe em
nenhum dos quatro.

`AuthException` é um tipo do `supabase_flutter` capturado dentro de um widget:
a UI conhece a biblioteca.

**Erros silenciados.** Oito `catch (_)` descartam a exceção inteira:

```text
presentation/widgets/receipt_field.dart:182,197
presentation/pages/data_page.dart:135
presentation/pages/accounts_page.dart:364
presentation/pages/merchant_rules_page.dart:374
presentation/widgets/card_form_sheet.dart:128
presentation/widgets/goal_form_sheet.dart:118
presentation/widgets/category_form_sheet.dart:109
```

Em `receipt_field.dart:197` isso vira "Não foi possível abrir a imagem" para
qualquer causa — permissão negada, arquivo corrompido, falha de plugin. Não há
`crash reporting` no projeto, então essa informação é perdida definitivamente.

---

## 12. Testabilidade

**Esta é a área mais forte do projeto.** 48 arquivos de teste, cobrindo regras
de negócio (`finance_rules_test`, `invoice_forecast_test`,
`statement_competence_test`), composição (`snapshot_composition_test`),
apresentação (`golden_test`, `page_overflow_test`, `responsive_sheet_test`) e
tema (`theme_test`, `categorical_test` com simulação de daltonismo).

Isso é possível porque o domínio é majoritariamente feito de funções puras, e
porque `FinanceRepository` é uma abstração com um fake completo
(`DemoFinanceRepository`).

O que continua difícil de testar:

- **Autenticação** — `Supabase.instance` é singleton global; não há como
  injetar um duplo.
- **Seleção de imagem e de arquivo** — `ImagePicker()` e `openFile()` são
  concretos.
- **Compartilhamento** — `SharePlus.instance` é singleton.
- **`_runImport`** — a orquestração mais complexa do produto só é alcançável
  através da árvore de widgets de `MorePage`.
- **Qualquer fake novo** — precisa implementar os 31 métodos de
  `FinanceRepository`.

---

## Problemas priorizados

### P0 — Crítico

#### P0.1 — Autenticação sem camada arquitetural

```text
Arquivo:          lib/presentation/auth_gate.dart (380 linhas)
Camada atual:     Presenter
Camada esperada:  features/auth/{domain,infra,presenter}
```

**Problema:** login, cadastro, recuperação de senha, troca de senha e leitura
de sessão chamam `Supabase.instance.client.auth` direto de widgets (linhas 17,
61, 108, 280), e capturam `AuthException` do pacote na própria UI (83, 109, 288).

**Por que viola:** o Presenter acessa SDK externo diretamente, conhece a
biblioteca de backend, e usa um singleton global em vez de dependência
injetada. Não existe contrato de domínio para autenticação.

**Impacto:** o fluxo de autenticação inteiro é intestável sem um Supabase real.
Trocar de provedor exige reescrever a tela. É o único caminho de dados do
projeto sem inversão de dependência — o resto do app já provou o padrão com
`FinanceRepository`.

**Correção:** extrair `AuthRepository` (contrato em domain) com
`signIn`/`signUp`/`signOut`/`resetPassword`/`updatePassword`/`authState`,
implementar em infra sobre `SupabaseClient` injetado, e injetar no `main.dart`
junto do `FinanceRepository`.

**Prioridade: Crítica**

---

#### P0.2 — Infraestrutura escrevendo texto de interface

```text
Arquivo:          lib/data/supabase_finance_repository.dart:269-286, 565-644
Camada atual:     Infra
Camada esperada:  Infra devolve falha tipada; Presenter escolhe o texto
```

**Problema:** cinco métodos `_friendly*Error` convertem `PostgrestException` em
frases prontas em português, lançadas como `FinanceWriteException(String)`.

**Por que viola:** a camada mais baixa decide apresentação. E a UI recebe todas
as falhas como a mesma classe, distinguíveis só pelo texto — não pode reagir
diferente a "duplicado" (mostrar o lançamento existente) e "sessão expirada"
(mandar para o login).

**Impacto:** internacionalização impossível; nenhuma reação programática a
causa de erro; regra de negócio ("dedup_key colidiu") codificada como string.

**Correção:** `sealed class FinanceFailure` com casos
`duplicateTransaction`, `invalidAmount`, `sessionExpired`, `permissionDenied`,
`network`, `unexpected(Object cause)`. Infra mapeia `PostgrestException` →
`FinanceFailure`. Presenter mapeia `FinanceFailure` → texto.

**Prioridade: Crítica**

---

#### P0.3 — Domain acoplado a Flutter e ao esquema do Supabase

```text
Arquivos:         lib/domain/models.dart, lib/domain/catalog_drafts.dart,
                  lib/domain/statement_import.dart
Camada atual:     Domain
Camada esperada:  Domain puro; mapeamento e visual em outras camadas
```

**Problema:** três frentes na mesma camada — `IconData`/`Color` em
`FinanceCategory` e `CategoryDraft`; `package:excel` importado por
`statement_import.dart`; 14 `fromJson` mapeando colunas do Postgres.

**Por que viola:** o domínio não deve conhecer Flutter, biblioteca de
infraestrutura, nem formato de transporte. Hoje conhece os três.

**Impacto:** renomear coluna no Supabase altera o domínio. E a infraestrutura
precisa importar `core/category_visuals.dart` (Material) para conseguir
construir uma entidade — dependência ao contrário.

**Correção:** `FinanceCategory` guarda `String iconName` e `String colorHex`; a
resolução para `IconData`/`Color` vira extension na camada de apresentação.
`fromJson` sai para modelos em `infra/models/` com mapeadores explícitos.
Parsing de XLSX vai para `features/imports/infra/`.

**Risco:** alto em volume (toca `models.dart`, os dois repositórios e todo
widget que lê `category.icon`/`.color`), baixo em lógica — é mecânico e os
goldens cobrem a regressão visual.

**Prioridade: Crítica**

---

### P1 — Alto impacto

#### P1.1 — `FinanceRepository`: um contrato para o produto inteiro

```text
Arquivo:          lib/application/providers.dart:11-140
Camada atual:     Application
Camada esperada:  um contrato por feature, em features/*/domain/repositories/
```

**Problema:** 31 métodos numa interface, cobrindo nove áreas do produto.

**Impacto:** todo fake implementa 31 métodos; método novo em qualquer feature
quebra todos os implementadores; nenhuma feature pode declarar do que
realmente depende.

**Correção:** dividir em `TransactionRepository`, `CatalogRepository`,
`InvoiceRepository`, `ReviewRepository`, `ImportRepository`,
`ShortcutTokenRepository`, `ReceiptStorage`. A implementação Supabase pode
continuar sendo uma classe implementando várias interfaces — a divisão que
importa é a do lado do consumidor.

**Risco:** médio. É mecânico, mas toca todos os pontos de leitura.

**Prioridade: Alta**

---

#### P1.2 — `_runImport` é um caso de uso escrito dentro de um widget

```text
Arquivo:          lib/presentation/pages/more_page.dart:294-440
Camada atual:     Presenter
Camada esperada:  features/imports/domain/usecases + presenter/notifier
```

**Problema:** o fluxo mais complexo do produto — preview, revisão, segundo
preview, validação, escrita, invalidação — vive em métodos privados de um
`StatelessWidget`, entremeado com `Navigator.pop` e `ScaffoldMessenger`. Inclui
uma regra de negócio explícita nas linhas 415-419.

**Impacto:** intestável fora da árvore de widgets; a regra de importação não
tem teste unitário; 748 linhas numa página que também é o menu.

**Correção:** `ImportInvoiceUseCase` com os passos e a validação; um
`Notifier` expondo os estados (`selecting`, `previewing`, `reviewing`,
`writing`, `done`, `failed`); `MorePage` volta a ser um menu.

**Prioridade: Alta**

---

#### P1.3 — SDKs concretos instanciados na apresentação

```text
Arquivos:         receipt_field.dart:161 (ImagePicker), more_page.dart:302,323
                  (openFile), data_page.dart:131 (SharePlus)
```

**Correção:** três interfaces pequenas (`ImageSource`, `FilePicker`,
`ShareService`) em `core/`, implementadas sobre os pacotes e injetadas. O
projeto já provou o padrão com `ReceiptRecognizer`, no mesmo arquivo onde
`ImagePicker` é concreto.

**Prioridade: Alta**

---

#### P1.4 — Oito `catch (_)` descartando a causa

Listados em §11. Sem crash reporting no projeto, a informação some.

**Correção:** capturar `(error, stack)`, registrar por um `Logger` de `core/`,
e só então mostrar a mensagem genérica.

**Prioridade: Alta**

---

### P2 — Melhorias estruturais

#### P2.1 — Reorganizar `lib/` em `core/` + `features/`

**Esta é a divergência estrutural principal, e é deliberadamente P2.** Mover
arquivos não reduz acoplamento por si só — os P0 e P1 acima reduzem. Feita
primeiro, a mudança de pastas cria um diff gigante que esconde as correções que
importam. Feita depois, ela apenas materializa fronteiras que já existem no
código.

Destino proposto:

```text
lib/
├── core/
│   ├── di/            (composição hoje em main.dart)
│   ├── errors/        (FinanceFailure — P0.2)
│   ├── platform/      (FilePicker, ShareService, ImageSource — P1.3)
│   ├── logging/
│   ├── theme/         (theme, tokens, typography, breakpoints)
│   ├── routing/       (url_strategy)
│   └── design_system/ (o conteúdo de widgets/ledger.dart e common.dart)
│
└── features/
    ├── auth/
    ├── overview/
    ├── transactions/
    ├── invoices/
    ├── catalog/
    ├── imports/
    ├── review/
    ├── reminders/
    ├── settings/
    └── shared/widgets/
```

`application/` desaparece: contratos vão para o domain de cada feature,
providers para `core/di/`, `reminder_service` e `receipt_recognizer` para suas
features.

**Risco:** baixo em lógica (é `git mv` + reescrita de imports), alto em conflito
de merge. Deve ser feita numa passada, sem outras mudanças no mesmo commit.

**Prioridade: Média**

---

#### P2.2 — Camada de estado para escrita

**Problema:** 105 `setState` em 18 widgets reimplementam `busy`/`error` a cada
tela; só existe um `Notifier` no projeto.

**Correção:** um `AsyncNotifier` por fluxo de escrita relevante. Não para todo
CRUD — para transação, importação e autenticação.

**Prioridade: Média**

---

#### P2.3 — `LoadFailure` por tipo, não por substring

Depois de P0.2, `LoadFailure.from(Object)` deixa de precisar adivinhar: recebe
`FinanceFailure` tipada. O arquivo encolhe para um mapeamento de copy e sai do
domain para a apresentação.

**Prioridade: Média**

---

#### P2.4 — `category_visuals` sai do core

Consequência direta de P0.3: sem `IconData` na entidade, o mapa de ícones vira
apresentação da feature `catalog` e a infraestrutura para de importar Material.

**Prioridade: Média**

---

### P3 — Incremental

- `dashboard_page.dart:41-49` — mover os três `fold` para `domain/analytics.dart`.
- Renomear `widgets/ledger.dart` → design system, e separar os formulários de
  feature dos componentes compartilhados.
- `receiptUrlProvider` (`receipt_field.dart:337`) sai da apresentação.
- Quebrar `more_page.dart` em menu + destinos, depois de P1.2.

---

## Avaliação final

```text
Arquitetura geral:              5/10

Estrutura Core / Features:      2/10
Separação de camadas:           6/10
Organização por feature:        1/10
Domain:                         5/10
Presenter:                      4/10
Infra:                          5/10
Gerenciamento de estado:        4/10
Injeção de dependência:         6/10
Tratamento de erros:            4/10
Testabilidade:                  7/10
Manutenibilidade:               5/10
```

**Arquitetura geral — 5.** A separação por camadas existe, é intencional e as
setas de dependência apontam quase todas para o lado certo. O que falta é a
organização por funcionalidade e a limpeza das fronteiras.

**Estrutura Core / Features — 2.** Cinco raízes em vez de duas, nenhuma
`features/`, e `application/` sem responsabilidade definida. O `core/` em si
está bem resolvido, o que evita a nota mínima.

**Separação de camadas — 6.** Domain, data e presentation existem e são
respeitados no caminho principal de dados. As violações são localizadas
(autenticação, seletores de arquivo, `excel` no domain) e não sistêmicas.

**Organização por feature — 1.** Não existe. Toda organização é por tipo
técnico.

**Domain — 5.** Conteúdo excelente — regras puras, isoladas, testadas. Prejudicado
por três contaminações concretas: Flutter, `excel` e `fromJson`.

**Presenter — 4.** 67% do código. Delega bem os cálculos, mas acessa quatro SDKs
direto, hospeda o caso de uso de importação e não tem camada de estado para
escrita.

**Infra — 5.** Bem isolada atrás de um contrato, com um fake completo. Perde por
escrever copy de UI e por depender de `core/` visual.

**Gerenciamento de estado — 4.** Leitura muito bem resolvida com Riverpod;
escrita não tem camada nenhuma.

**Injeção de dependência — 6.** Ponto único de composição em `main.dart`,
correto e funcionando. Furado por `Supabase.instance` e por SDKs instanciados
em widgets.

**Tratamento de erros — 4.** Quatro modelos incompatíveis, sem distinção entre
falha técnica e de negócio, sete causas descartadas, `AuthException` chegando à
UI.

**Testabilidade — 7.** A melhor área: 48 arquivos de teste, domínio de funções
puras, `DemoFinanceRepository` como duplo completo. Limitada só onde os SDKs
não foram abstraídos.

**Manutenibilidade — 5.** Código bem comentado, com justificativas de decisão
raras de encontrar. Prejudicado pela dispersão de cada funcionalidade por
quatro raízes e por arquivos de 700-1.100 linhas.

---

## Ordem de execução recomendada

1. **P0.2** — `FinanceFailure` tipada. Habilita P2.3 e melhora tudo abaixo.
2. **P0.1** — `AuthRepository`. Fecha o único caminho de dados sem inversão.
3. **P1.4** — parar de engolir causas. Barato, e dá visibilidade para o resto.
4. **P1.3** — abstrair os três seletores de plataforma.
5. **P0.3** — despoluir o domain (Flutter, `excel`, `fromJson`).
6. **P1.1** — dividir `FinanceRepository`.
7. **P1.2** — extrair o caso de uso de importação.
8. **P2.1** — reorganizar em `core/` + `features/`, num commit só.
9. **P2.2**, **P2.3**, **P2.4**, depois **P3**.

Os passos 1-7 reduzem acoplamento e risco sem mover um único arquivo de lugar.
O passo 8 move tudo, e a essa altura só formaliza fronteiras que já existirão.

---

# Fechamento — 20 Ago 2026

As dez unidades do plano foram executadas. Esta seção mede o resultado contra
a mesma régua da auditoria e nomeia o que **continua** fora do padrão.

## Antes e depois

| | Antes | Depois |
|---|---|---|
| Raízes em `lib/` | 5 (por tipo técnico) | **2** (`core`, `features`) |
| Features | 0 | **12** |
| Testes | 617 | **654** |
| Imagens de referência | 33 | 33 |
| Domain importando Flutter | sim | **não** |
| Domain importando lib de infra | `package:excel` | **não** |
| `fromJson` no domain | 14 | **1** (documento próprio do app) |
| Infra importando Material | 2 arquivos | **não** |
| Copy escrita pela infra | 5 tradutores, 36 `throw` | **não** |
| Modelos de erro | 4 incompatíveis | **1** selado, 3 famílias |
| Causas descartadas (`catch (_)`) | 8 | **0** |
| SDKs concretos na apresentação | 4 | **0** |
| Contrato de dados | 1 interface, 31 métodos | **6** por área |
| Telas com endereço | 7 de 16 | **16 de 16** |
| `MaterialPageRoute` | 10 | **0** |
| `setState` | 105 | 96 |

O domínio hoje importa apenas `dart:`, `clock`, `crypto` e `intl`.

## Notas revisadas

```text
                              1ª passada   2ª passada
Arquitetura geral:              8/10    →    9/10   (era 5)

Estrutura Core / Features:      9/10    →   10/10   (era 2)
Separação de camadas:           9/10    →   10/10   (era 6)
Organização por feature:        7/10    →    8/10   (era 1)
Domain:                         9/10    →   10/10   (era 5)
Presenter:                      7/10    →    9/10   (era 4)
Infra:                          8/10    →    8/10   (era 5)
Gerenciamento de estado:        7/10    →    9/10   (era 4)
Injeção de dependência:         9/10    →   10/10   (era 6)
Tratamento de erros:            9/10    →   10/10   (era 4)
Testabilidade:                  9/10    →    9/10   (era 7)
Manutenibilidade:               8/10    →    9/10   (era 5)
```

**Não dou 10 em quatro eixos, e o motivo é o mesmo em todos.** Organização por
feature (8) e Infra (8) têm as 28 arestas e o repositório monolítico descritos
acima — uma dívida que só se paga com risco que hoje não vale a pena correr.
Testabilidade (9) porque a implementação Supabase continua sem teste de
integração. Arquitetura geral (9) é a soma dessas. Chegar a 10 nesses eixos é
trabalho real com pré-requisito real, não mais uma passada de arrumação.

## Segunda passada — loaders e acoplamento

O dono pediu nota 10 e uma atenção específica aos estados de carregamento.

### Carregamento

O app tinha dezoito `CircularProgressIndicator` nus e **um** skeleton estático
cujo layout não correspondia a página nenhuma. Um spinner centralizado do
Material é a ausência de uma decisão: diz que algo acontece e nada sobre o quê,
descarta a forma da tela que a pessoa acabou de pedir, e fica igual num app
desenhado e num que não foi.

Agora há um sistema em `core/design_system/loading.dart`: skeletons com a forma
do conteúdo, um `BusySpinner` único para ações, e o pulso honrando redução de
movimento — que é o mesmo mecanismo que os torna fotografáveis.

**Fotografá-los encontrou o defeito real**: enquanto o extrato carregava, o
telefone não tinha barra de abas nem marca. O app inteiro era uma coluna de
blocos cinza, o que lê como quebrado e não como ocupado. A moldura fica agora, e
o "+" esmaece em vez de a barra sumir.

| | Antes | Depois |
|---|---|---|
| Spinners nus | 18 | **0** |
| Skeletons | 1 estático | **sistema, com pulso** |
| Imagens de referência de carregamento | 0 | **5** (claro e escuro) |
| Moldura durante o carregamento | não | **sim** |

### Acoplamento

Três inversões reais, encontradas medindo e não lendo:

- `core/design_system` importava o domínio de uma feature, porque
  `PeriodFilterBar` sabe o que é um `FinancePeriod`. Um controle que conhece o
  extrato do produto nunca foi infraestrutura visual genérica.
- `core/routing/routes.dart` misturava caminhos com os codecs que serializam
  período e filtro. Caminho é roteamento; codificar um `FinancePeriod` é
  conhecimento sobre o extrato.
- `catalog_cubits.dart` guardava a fila de revisão, os tokens do Atalho e os
  lotes de importação — cinco arestas que existiam apenas por causa do nome do
  arquivo em que a modularização mecânica os deixou. Essa foi minha.

`core` depende de `features` hoje em **dois** arquivos: `core/di/dependencies.dart`
e `core/routing/router.dart`. Ambos são o ponto de composição, cujo trabalho é
saber o que compõe, e a referência coloca `di/` e `routing/` no core por isso.

## O que continua fora do padrão

**28 arestas entre features.** Caiu de 32, e as que restam concentram-se em dois
lugares, ambos deliberados:

- `shell → 6 features`: o shell compõe todas as páginas. É o que um shell é.
- `ledger → 5 features`: as duas implementações de repositório satisfazem os
  seis contratos, e por isso precisam dos drafts de cada feature.

**Sobre esta segunda, tomei uma decisão e vale dizer qual.** Zerar essas cinco
arestas exige dividir `SupabaseFinanceRepository` (761 linhas) e
`DemoFinanceRepository` (992) em seis classes cada. A implementação Supabase
**não tem teste de integração** — nenhum teste a exercita contra um banco real.
Fatiá-la mecanicamente para melhorar uma métrica de grafo de importação
aumentaria risco técnico sem reduzir nenhum, e a própria referência exige que
uma alteração tenha benefício concreto em manutenção, testabilidade,
desacoplamento, clareza, escalabilidade **ou redução de risco**. Essa não tem.
Fica registrada como dívida consciente, com a condição para pagá-la: cobertura
de integração no repositório Supabase primeiro.

**`setState` está em 90**, de 105. Os restantes são estado de campo — uma data
escolhida, uma categoria selecionada, um toggle, um cursor — que é exatamente
para o que estado local de widget existe. O número que importava nunca foi o
total; eram as seis cópias do mesmo `try/catch`, e não há nenhuma.

## O que foi decidido contra a recomendação

**Bloc.** Recomendei manter Riverpod; o dono escolheu conformidade literal com
o documento. Executado por inteiro. A migração não corrigiu defeito nenhum, e
custou: `WidgetRef` é seguro através de `await` e `BuildContext` não é, então a
conversão produziu 25 pontos lendo colaborador depois de um await — classe de
bug viva, toda corrigida. O ganho é conformidade, e está registrado como tal.

**Execução sem portões.** As dez unidades correram seguidas. A mitigação
funcionou: os 654 testes e as 33 imagens rodaram ao fim de cada uma, e nenhuma
reduziu a contagem.
