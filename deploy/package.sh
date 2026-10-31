#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: bash deploy/package.sh /path/to/bulletin-board.tar.gz"
  exit 1
fi

OUTPUT="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
cd "$(dirname "$0")/.."

# Server databases and uploaded images live in storage/ and must never be
# replaced by data from a developer's computer.
tar -czf "$OUTPUT" \
  --exclude="$OUTPUT" \
  --exclude='./.git' \
  --exclude='./.env*' \
  --exclude='*.pem' \
  --exclude='*.sqlite3*' \
  --exclude='./config/master.key' \
  --exclude='./config/credentials/*.key' \
  --exclude='./.aws' \
  --exclude='./.codex' \
  --exclude='./.agents' \
  --exclude='./.kamal' \
  --exclude='./.bundle' \
  --exclude='./vendor/bundle' \
  --exclude='./log' \
  --exclude='./tmp' \
  --exclude='./storage' \
  --exclude='./public/assets' \
  .
