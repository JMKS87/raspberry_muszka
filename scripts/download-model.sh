#!/usr/bin/env bash
# Pobiera Muszka Instruct 1.5B v1.0 (Q6_K, GGUF) do ./models i weryfikuje SHA-256.
# Użycie:  bash scripts/download-model.sh
set -euo pipefail

REPO="Fibogacci/muszka-instruct-1.5b-v1.0-GGUF"
# Przypięty commit repozytorium HF — gwarantuje ten sam plik przy każdym pobraniu.
REVISION="599f80a0ab87b5611deec43bb1652a9ddb2e0c18"
FILE="muszka-instruct-1.5b-v1.0-Q6_K.gguf"
SHA256="525dfd71cfa9eadb77d91f5ea2e4313bd81e36225e41a4277e3ac235cc856d17"
SIZE=1313116256

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST_DIR="$ROOT/models"
DEST="$DEST_DIR/$FILE"
URL="https://huggingface.co/$REPO/resolve/$REVISION/$FILE"

mkdir -p "$DEST_DIR"

verify() {
  echo "Weryfikuję SHA-256..."
  echo "$SHA256  $DEST" | sha256sum -c -
}

if [ -f "$DEST" ] && [ "$(stat -c %s "$DEST")" -eq "$SIZE" ]; then
  echo "Plik już istnieje: $DEST"
  verify
  exit 0
fi

echo "Pobieram $FILE (~1,3 GB)..."
# -C - wznawia przerwane pobieranie
curl -fL --retry 5 --retry-delay 5 -C - -o "$DEST.part" "$URL"
mv "$DEST.part" "$DEST"

if ! verify; then
  echo "Błędna suma kontrolna — usuwam plik. Uruchom skrypt ponownie." >&2
  rm -f "$DEST"
  exit 1
fi

echo "Gotowe: $DEST"
