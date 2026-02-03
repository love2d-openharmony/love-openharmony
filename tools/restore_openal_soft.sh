#!/bin/sh
set -eu

ROOT="${ROOT:-/Users/artin/0Workspace/github.com/bytemain/love-android}"
DST="${1:-$ROOT/app/src/main/cpp/megasource/libs/openal-soft}"
STATE_FILE="${2:-$ROOT/.openal-soft-last-backup.txt}"

if [ ! -f "$STATE_FILE" ]; then
  echo "missing state file: $STATE_FILE" >&2
  exit 2
fi

BAK="$(cat "$STATE_FILE" | tr -d '\n')"
if [ -z "$BAK" ] || [ ! -d "$BAK" ]; then
  echo "invalid backup path in state file: $BAK" >&2
  exit 3
fi

if [ ! -d "$DST" ]; then
  echo "missing dst: $DST" >&2
  exit 4
fi

echo "Restore:"
echo "  $BAK"
echo "  -> $DST"
rm -rf "$DST"
mv "$BAK" "$DST"
echo "Done."
