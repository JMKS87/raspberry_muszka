#!/usr/bin/env bash
# Benchmark llama-bench dla różnych liczb wątków — pomaga dobrać THREADS w .env.
# Uruchamiaj na Pi, najlepiej przy zatrzymanym serwerze (docker compose stop),
# żeby wyniki nie były zaniżone.
# Użycie:  bash scripts/bench.sh [lista_wątków]     np.  bash scripts/bench.sh 1,2,3,4
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THREADS_LIST="${1:-2,3,4}"
MODEL_FILE="muszka-instruct-1.5b-v1.0-Q6_K.gguf"
# Obraz "full" zawiera wszystkie narzędzia llama.cpp, w tym llama-bench.
BENCH_IMAGE="${BENCH_IMAGE:-ghcr.io/ggml-org/llama.cpp:full}"

if [ -f "$ROOT/.env" ]; then
  f="$(grep -E '^MODEL_FILE=' "$ROOT/.env" | cut -d= -f2- || true)"
  MODEL_FILE="${f:-$MODEL_FILE}"
fi

if [ ! -f "$ROOT/models/$MODEL_FILE" ]; then
  echo "Brak modelu: models/$MODEL_FILE — uruchom najpierw scripts/download-model.sh" >&2
  exit 1
fi

# pp = przetwarzanie promptu, tg = generowanie (to drugie liczy się dla czatu)
docker run --rm \
  -v "$ROOT/models:/models:ro" \
  --entrypoint /app/llama-bench \
  "$BENCH_IMAGE" \
  -m "/models/$MODEL_FILE" \
  -t "$THREADS_LIST" \
  -p 256 -n 128 -r 3
