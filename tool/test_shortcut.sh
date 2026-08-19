#!/usr/bin/env bash
# Testa o token do Atalho sem criar lançamento nenhum.
#
# A função checa o token antes de procurar o cartão, e devolve 404 se o cartão
# não existir — antes de escrever. Então mandar um cartão impossível separa as
# duas perguntas que se confundem quando o Atalho não funciona:
#
#   "meu token está certo?"   e   "meu Atalho está certo?"
#
# O token é lido da entrada, não de argumento: argumento fica no histórico do
# shell.
#
#   ./tool/test_shortcut.sh
#   ./tool/test_shortcut.sh 6902     # com um cartão seu, aí SIM cria lançamento

set -euo pipefail

URL="https://ddmilzlinvpxfvzyigok.supabase.co/functions/v1/capture-transaction"
CARTAO="${1:-0000}"

if [ "$CARTAO" = "0000" ]; then
  echo "Testando só o token (cartão 0000 não existe, nada será gravado)."
else
  echo "ATENÇÃO: cartão $CARTAO — se ele existir, isto CRIA um lançamento de R\$ 0,01."
  printf "Continuar? [s/N] "
  read -r resposta
  [ "$resposta" = "s" ] || { echo "cancelado"; exit 0; }
fi

printf "Cole o token (não aparece na tela): "
read -rs TOKEN
echo

RESPOSTA=$(curl -sS -w '\n%{http_code}' -X POST "$URL" \
  -H "x-shortcut-token: $TOKEN" \
  -H "content-type: application/json" \
  -d "{
    \"merchant\": \"TESTE DO ATALHO\",
    \"amount\": 0.01,
    \"category\": \"Outros\",
    \"card_last_four\": \"$CARTAO\",
    \"purchased_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
  }")

CORPO=$(printf '%s' "$RESPOSTA" | sed '$d')
CODIGO=$(printf '%s' "$RESPOSTA" | tail -n1)

echo
echo "HTTP $CODIGO"
echo "$CORPO"
echo

case "$CODIGO" in
  404) echo "✓ Token VÁLIDO. A função rejeitou o cartão, que é o esperado — nada foi gravado."
       echo "  Agora rode de novo com um cartão seu de verdade para testar ponta a ponta." ;;
  200|201) echo "✓ Funcionou ponta a ponta. Um lançamento de R\$ 0,01 foi criado; apague pelo app." ;;
  401) echo "✗ Token inválido ou revogado. Gere outro em Mais → Automação Apple Pay." ;;
  422) echo "✗ A função recebeu o corpo mas achou algum campo inválido — veja a mensagem acima." ;;
  405) echo "✗ Método errado. Isto não deveria acontecer com este script." ;;
  *)   echo "✗ Resposta inesperada. Se for 5xx, o problema está na função, não no token." ;;
esac
