#!/usr/bin/env bash
# Capture Lavish poll responses durably before presenting any summary.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd -P)
FM_HOME=${FM_HOME:-$(cd "$ROOT" && pwd -P)}
usage() { echo 'usage: fm-lavish-capture.sh [--loop] <board.html>'; }
loop=0
if [ "${1:-}" = --loop ]; then loop=1; shift; fi
[ "$#" -eq 1 ] || { usage >&2; exit 2; }
board=$(cd "$(dirname "$1")" && pwd -P)/$(basename "$1")
dir="$FM_HOME/data/lavish-feedback"
mkdir -p "$dir"
while :; do
  tmp=$(mktemp "$dir/.capture.XXXXXX")
  if ! lavish-axi poll "$board" >"$tmp"; then rm -f "$tmp"; exit 1; fi
  dest="$dir/$(date +%Y%m%dT%H%M%S)-$$-$RANDOM.txt"
  chmod 600 "$tmp"
  mv "$tmp" "$dest"
  printf 'Captured full Lavish response: %s\n' "$dest"
  if [ "$loop" -ne 1 ] || grep -qE 'status: (ended|session_ended)' "$dest"; then exit 0; fi
done
