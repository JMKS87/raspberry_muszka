#!/usr/bin/env bash
# Szybki test serwera: /health, /v1/models i krótki czat po polsku.
# Użycie:  bash scripts/test-api.sh [http://adres:port]
# Klucz API brany jest z .env (API_KEY) albo ze zmiennej środowiskowej API_KEY.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -z "${API_KEY:-}" ] && [ -f "$ROOT/.env" ]; then
  API_KEY="$(grep -E '^API_KEY=' "$ROOT/.env" | cut -d= -f2- || true)"
fi
if [ -z "${1:-}" ] && [ -f "$ROOT/.env" ]; then
  MUSZKA_PORT="$(grep -E '^MUSZKA_PORT=' "$ROOT/.env" | cut -d= -f2- || true)"
fi
BASE_URL="${1:-http://localhost:${MUSZKA_PORT:-8080}}"

AUTH=()
if [ -n "${API_KEY:-}" ]; then
  AUTH=(-H "Authorization: Bearer $API_KEY")
fi

echo "== $BASE_URL/health"
curl -fsS "$BASE_URL/health"; echo

echo "== $BASE_URL/v1/models"
curl -fsS "${AUTH[@]}" "$BASE_URL/v1/models"; echo

echo "== $BASE_URL/v1/chat/completions"
curl -fsS "${AUTH[@]}" "$BASE_URL/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "muszka-instruct",
    "messages": [
      {"role": "system", "content": "Jesteś pomocnym asystentem. Odpowiadaj po polsku."},
      {"role": "user", "content": "Wyjaśnij w trzech zdaniach, czym jest fotosynteza."}
    ],
    "max_tokens": 200
  }'
echo
