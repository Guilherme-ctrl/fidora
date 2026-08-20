# AIDLC — Arquitetura de referência (Flutter)

Padrão arquitetural do projeto, fornecido pelo dono em 20 Ago 2026. É contra
este documento que `docs/arquitetura-auditoria.md` mede o código, e é para este
alvo que a unidade `arch-remake` trabalha.

O projeto deve seguir uma arquitetura modular baseada em Clean Architecture,
priorizando separação de responsabilidades, baixo acoplamento, testabilidade e
facilidade de evolução.

## As duas raízes

```text
lib/
├── core/
└── features/
```

- **Core**: tudo que é global, transversal e compartilhado pela aplicação.
- **Features**: todas as funcionalidades, módulos e componentes do produto.

Não deve existir camada global paralela como `shared/`, `common/`, `services/`,
`repositories/` ou `screens/` na raiz.

## Estrutura geral

```text
lib/
├── core/
│   ├── config/
│   ├── di/
│   ├── errors/
│   ├── network/
│   ├── storage/
│   ├── logging/
│   ├── theme/
│   ├── routing/
│   └── ...
│
└── features/
    ├── authentication/
    │   ├── domain/
    │   │   ├── entities/
    │   │   ├── repositories/
    │   │   ├── services/
    │   │   └── usecases/
    │   ├── infra/
    │   │   ├── datasources/
    │   │   ├── models/
    │   │   ├── repositories/
    │   │   └── services/
    │   └── presenter/
    │       ├── pages/
    │       ├── cubits/
    │       ├── states/
    │       └── widgets/
    ├── home/
    ├── shared/
    │   └── widgets/
    └── ...
```

Organização prioritariamente por funcionalidade, não por tipo técnico. Evitar
`lib/screens/`, `lib/services/`, `lib/repositories/`, `lib/models/`,
`lib/cubits/`, `lib/widgets/` na raiz — esse tipo de organização espalha os
arquivos de uma mesma funcionalidade por toda a aplicação.

## Core

Concentra o que é transversal: configuração, ambiente, injeção de dependência,
cliente HTTP, interceptors, tratamento técnico de erros, armazenamento, secure
storage, logging, analytics, crash reporting, roteamento global, tema,
infraestrutura transversal.

O Core **não** deve possuir regra de negócio específica de uma feature.
`core/network/api_client.dart` é adequado; `core/services/login_service.dart`
provavelmente não é, e deve viver em `features/authentication/`.

O Core não deve virar pasta genérica usada sempre que não estiver claro onde o
código deve ficar.

## Features

Cada feature deve ser autocontida sempre que possível, podendo ter:

```text
feature/
├── domain/
├── infra/
└── presenter/
```

Nem toda feature precisa de todas as pastas. A estrutura reflete a complexidade
real. Não criar camadas vazias ou abstrações sem necessidade só para seguir o
padrão.

### Domain

Núcleo das regras de negócio: entidades, regras, casos de uso, contratos de
repositories e services, validações, decisões de negócio.

Deve ter o mínimo de dependência de tecnologia. Não deve conhecer diretamente
Flutter, Widgets, Dio, HTTP, Firebase, SQLite, SharedPreferences, Secure
Storage, Platform Channels ou SDKs externos.

```dart
abstract interface class UserRepository {
  Future<User> getUser();
}
```

O Domain conhece o contrato, não a implementação.

### Infra

Implementa o que o Domain precisa: repositories, integração com APIs,
datasources, persistência, conversão entre modelos externos e entidades,
services definidos pelo Domain.

```text
Domain                Infra
UserRepository   ←—   UserRepositoryImpl
   (contrato)         (implements)
```

Detalhes técnicos ficam encapsulados nesta camada.

### Presenter

Interface entre usuário e regra de negócio: pages, widgets, cubits, states.

Responsabilidades: renderizar, tratar interação, controlar estado de
apresentação, chamar casos de uso, representar loading/success/error, converter
resultado de domínio em estado de UI.

Não deve acessar API, banco ou Firebase diretamente, conter regra de negócio
relevante, instanciar repositories concretos, nem conhecer detalhes de
persistência.

## Gerenciamento de estado

Cubit/BLoC para estado de comportamento da aplicação.

```text
Page / Widget → Cubit / BLoC → UseCase → Repository → Infra
```

O Cubit coordena o estado da interface; não vira a camada principal de regra de
negócio. Uma decisão como

```dart
if (user.age > 18 && user.subscription == Subscription.premium && payment.isValid)
```

pertence ao Domain. O Cubit trabalha com o resultado.

## Widgets

Widgets de uma feature ficam na feature (`features/x/presenter/widgets/`).
Widgets usados por vários módulos ficam em `features/shared/widgets/` — não em
uma terceira raiz. Um widget vai para o `core` só quando for infraestrutura
visual global (design system, tema) sem relação com feature específica.

## Injeção de dependências

```text
Cubit → UseCase → Repository ←— RepositoryImpl
```

Camadas superiores dependem de abstrações. Evitar instanciação espalhada
(`UserRepositoryImpl(ApiClient())`). A composição acontece em ponto controlado.

## Comunicação externa

Toda integração externa tem fronteira arquitetural clara: `ApiClient`,
`StorageService`, `SecureStorageService`, `AnalyticsService`,
`CrashReportingService`. Integrações globais no `core`; específicas de feature,
na feature.

Evitar `FirebaseCrashlytics.instance`, `FirebaseAnalytics.instance`,
`Dio().get(...)`, `SharedPreferences.getInstance()` dentro de Pages, Widgets,
Cubits ou UseCases.

## Tratamento de erros

Separar, ao menos conceitualmente:

```text
Business Failure
Technical Failure
Unexpected Failure
```

A infra pode conhecer `DioException`, `SocketException`, `FirebaseException`,
`PlatformException`, mas esses detalhes não atravessam livremente as camadas:

```text
DioException → Infra → Failure → Domain / Presenter
```

A UI não deve conhecer qual biblioteca HTTP está em uso.

## Dependência entre camadas

```text
Presenter
    ↓
 Domain
    ↑
  Infra
```

O Domain define contratos; a Infra os implementa; o Presenter consome o Domain.
O Domain permanece independente das implementações externas.

## Comunicação entre features

Evitar dependências diretas excessivas (`feature_a → feature_b → feature_c`).
Quando algo precisa ser compartilhado, avaliar se existe abstração compartilhada
dentro de `features`, se é responsabilidade transversal de `core`, se a
comunicação deveria ser por interface, ou se as features estão representando
responsabilidades separadas corretamente.

Não mover código para o Core só para resolver dependência entre features.

## Princípios esperados

Organização por feature; separação de responsabilidades; baixo acoplamento;
alta coesão; Dependency Inversion; domínio independente de infraestrutura;
abstração de dependências externas; testabilidade; componentes pequenos e
especializados; facilidade de substituição de implementações; mínima dependência
entre features; simplicidade estrutural; ausência de abstrações sem benefício.

**A arquitetura não deve ser seguida de maneira dogmática.** Não criar
repository sem necessidade, use case que apenas repassa uma chamada, interface
com uma única implementação sem benefício arquitetural, nem camada adicional sem
responsabilidade clara. Clean Architecture deve melhorar manutenção e
testabilidade, não aumentar complexidade gratuitamente.

## Fluxo arquitetural esperado

```text
Page → Cubit → UseCase → Repository → RepositoryImpl → Datasource → API/DB/SDK
```

Retorno:

```text
API/DB → Datasource → RepositoryImpl → Entity/Result → UseCase → Cubit → State → UI
```

## Regra para mudanças

Uma alteração só se justifica com benefício concreto em pelo menos um destes
aspectos: manutenção, testabilidade, desacoplamento, clareza de
responsabilidade, escalabilidade do código, redução de risco técnico. Não
apontar problemas por preferência estética. Não sugerir grandes refatorações só
para deixar a estrutura mais "bonita".
