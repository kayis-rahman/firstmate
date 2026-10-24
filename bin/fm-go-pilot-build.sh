#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT_DIR="$SCRIPT_DIR/go-pilot"
mkdir -p "$OUT_DIR"
cd "$CODE_ROOT/go"
for cmd in "$CODE_ROOT"/go/cmd/*/; do
  name="$(basename "$cmd")"
  # strip leading fm- for pilot tool name? keep as-is requested tool names use fm-? Config uses tool short? 
  : 
done
# Build each command under go/cmd, output named without leading fm- to match dispatcher tool names
for cmd in "$CODE_ROOT"/go/cmd/*/; do
  name="$(basename "$cmd")"
  short="${name#fm-}"
  go build -o "$OUT_DIR/$short" "./cmd/$name"
done
echo "built go pilot tools into $OUT_DIR"
