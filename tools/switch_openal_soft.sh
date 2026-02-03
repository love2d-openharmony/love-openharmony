#!/bin/sh
set -eu

ROOT="${ROOT:-/Users/artin/0Workspace/github.com/bytemain/love-android}"
SRC="${1:-/Users/artin/Downloads/openal-soft-1.24.3}"
DST="${2:-$ROOT/app/src/main/cpp/megasource/libs/openal-soft}"
STAMP="$(date +%Y%m%d_%H%M%S)"
BAK="${DST}.bak_${STAMP}"
STATE_FILE="${ROOT}/.openal-soft-last-backup.txt"

if [ ! -d "$SRC" ]; then
  echo "missing SRC: $SRC" >&2
  exit 2
fi
if [ ! -d "$DST" ]; then
  echo "missing DST: $DST" >&2
  exit 2
fi

echo "Backup:"
echo "  $DST"
echo "  -> $BAK"
mv "$DST" "$BAK"

echo "Copy:"
echo "  $SRC"
echo "  -> $DST"
cp -R "$SRC" "$DST"

if [ ! -f "$DST/CMakeLists.txt" ]; then
  echo "switch failed: missing $DST/CMakeLists.txt" >&2
  exit 3
fi

echo "$BAK" > "$STATE_FILE"
echo "Wrote state: $STATE_FILE"
echo "Done."
