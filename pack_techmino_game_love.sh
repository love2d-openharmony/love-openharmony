#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TECHMINO_DIR="${1:-"$ROOT/Techmino"}"
OUT="${2:-"$ROOT/ohos-love2d/entry/src/main/resources/resfile/game.love"}"
TMP="${OUT}.tmp"

if [[ ! -d "$TECHMINO_DIR" ]]; then
  echo "Techmino dir not found: $TECHMINO_DIR" >&2
  exit 2
fi

mkdir -p "$(dirname "$OUT")"
rm -f "$TMP"

( cd "$TECHMINO_DIR" && /usr/bin/zip -q -r -9 -X "$TMP" . \
  -x "*.DS_Store" "*/.DS_Store" ".git/*" ".git/**" ".github/*" ".github/**" )

/usr/bin/zip -T "$TMP" >/dev/null
mv -f "$TMP" "$OUT"

size=""
if stat -f%z "$OUT" >/dev/null 2>&1; then
  size="$(stat -f%z "$OUT")"
elif stat -c%s "$OUT" >/dev/null 2>&1; then
  size="$(stat -c%s "$OUT")"
fi

echo "Wrote: $OUT"
if [[ -n "$size" ]]; then
  echo "Bytes: $size"
fi
