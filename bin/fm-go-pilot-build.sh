#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODE_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
OUT_DIR="$CODE_ROOT/bin/go-pilot"
mkdir -p "$OUT_DIR"
cd "$CODE_ROOT/go"
# Build each command under go/cmd, output named without leading fm- to match dispatcher tool names
for cmd in "$CODE_ROOT"/go/cmd/*/; do
  name="$(basename "$cmd")"
  short="${name#fm-}"
  go build -o "$OUT_DIR/$short" "./cmd/$name"
done
echo "built go pilot tools into $OUT_DIR"
