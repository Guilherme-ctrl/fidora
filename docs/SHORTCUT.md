# Configurar a captura do Apple Pay

## 1. Gere um token

No app: **Mais → Automação Apple Pay → Gerenciar tokens → Gerar**. Ele aparece
uma única vez e já vai para a área de transferência; o banco guarda apenas o
SHA-256, então não há como recuperá-lo depois — se perder, revogue e gere outro.

> A versão anterior desta página mandava inserir a linha à mão no SQL. Isso
> deixou de ser necessário quando a tela de tokens foi entregue, e a instrução
> ficou para trás.

## 2. Implante a função

```bash
supabase functions deploy capture-transaction
```

Ela já está publicada no projeto `ddmilzlinvpxfvzyigok`. Republique sempre que
`index.ts` ou `rules.ts` mudarem — o que está no ar é o código do último deploy,
não o do repositório.

O projeto já declara `verify_jwt = false` especificamente para essa função em `supabase/config.toml`, porque o Atalho não possui uma sessão Supabase. A função aplica sua própria autenticação por token revogável e usa a chave secreta somente no servidor.

## 3. Monte o Atalho

Crie uma automação pessoal a partir de **Wallet** na lista de gatilhos — a Apple
documenta como *Transaction trigger*, mas ele aparece agrupado sob Wallet.
Selecione o cartão e marque **Executar imediatamente**. Para cartões com nomes
iguais, crie uma automação por cartão e fixe os quatro últimos dígitos.

> **O gatilho só dispara em pagamento por aproximação.** Compra online ou dentro
> de app com Apple Pay não aciona a automação — essas continuam entrando pela
> importação da fatura. Não é defeito da configuração.

Adicione uma lista com as categorias e a ação `Escolher da Lista`. Em seguida use `Obter Conteúdo do URL`:

- URL: `https://ddmilzlinvpxfvzyigok.supabase.co/functions/v1/capture-transaction`
- Método: `POST`
- Cabeçalho `x-shortcut-token`: o token original
- Corpo: JSON

```json
{
  "merchant": "Entrada do Atalho → Estabelecimento",
  "amount": "Entrada do Atalho → Valor",
  "category": "Item escolhido",
  "card_last_four": "6902",
  "purchased_at": "Data atual em ISO 8601"
}
```

## 4. Confirme que chegou

Pague qualquer coisa com Apple Pay no cartão que você escolheu na automação,
escolha a categoria quando o Atalho perguntar, e abra **Hoje**. A compra tem de
estar lá em segundos. Se não estiver, o Atalho mostra o erro da requisição na
própria execução — `401` é token errado ou revogado, `404` é `card_last_four`
que não bate com nenhum cartão cadastrado.

O Atalho é o único componente autorizado a enxergar o token original. Para
revogar, use a mesma tela que o gerou.
