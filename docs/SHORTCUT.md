# Configurar a captura do Apple Pay

## 1. Gere um token

Gere pelo menos 32 bytes aleatórios. Guarde o valor original no Atalho e grave somente seu SHA-256 no banco:

```sql
insert into public.shortcut_tokens (user_id, name, token_hash)
values ('SEU-USER-ID', 'iPhone principal', encode(digest('SEU-TOKEN-SECRETO', 'sha256'), 'hex'));
```

## 2. Implante a função

```bash
supabase functions deploy capture-transaction
```

O projeto já declara `verify_jwt = false` especificamente para essa função em `supabase/config.toml`, porque o Atalho não possui uma sessão Supabase. A função aplica sua própria autenticação por token revogável e usa a chave secreta somente no servidor.

## 3. Monte o Atalho

Crie uma automação pessoal `Transação`, selecione um cartão e escolha `Executar imediatamente`. Para cartões com nomes iguais, crie uma automação por cartão e fixe os quatro últimos dígitos.

Adicione uma lista com as categorias e a ação `Escolher da Lista`. Em seguida use `Obter Conteúdo do URL`:

- URL: `https://SEU-PROJETO.supabase.co/functions/v1/capture-transaction`
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

O Atalho é o único componente autorizado a enxergar o token original. Revogue-o preenchendo `revoked_at` se o aparelho for perdido.
