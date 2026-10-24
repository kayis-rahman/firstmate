#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FM_HOME="${FM_HOME:-${FM_ROOT_OVERRIDE:-$CODE_ROOT}}"
CONFIG_DIR="${FM_CONFIG_OVERRIDE:-$FM_HOME/config}"
PILOT_CONFIG="$CONFIG_DIR/go-pilot"

TOOL="${1:-}"
if [[ -z "$TOOL" ]]; then
  echo "Usage: $0 <tool> [args...]" >&2
  exit 2
fi
shift

GO_BIN="$SCRIPT_DIR/go-pilot/$TOOL"

SH_BIN=""
for cand in "$CODE_ROOT/bin/fm-$TOOL.sh" "$CODE_ROOT/bin/fm-$TOOL-lib.sh"; do
  if [[ -x "$cand" ]]; then SH_BIN="$cand"; break; fi
done

enabled=0
if [[ -f "$PILOT_CONFIG" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    [[ "$line" == \#* ]] && continue
    if [[ "$line" == "$TOOL" ]]; then enabled=1; break; fi
  done < "$PILOT_CONFIG"
fi

if [[ "$enabled" -eq 1 && -x "$GO_BIN" ]]; then
  "$GO_BIN" "$@"
  go_rc=$?
  echo "[pilot] $TOOL -> go (exit=$go_rc)" >&2
  exit "$go_rc"
fi

if [[ "$enabled" -eq 1 && ! -x "$GO_BIN" ]]; then
  echo "[pilot] $TOOL -> go missing, falling back to shell" >&2
fi

if [[ -n "$SH_BIN" ]]; then
  "$SH_BIN" "$@"
  sh_rc=$?
  echo "[pilot] $TOOL -> shell ($SH_BIN, exit=$sh_rc)" >&2
  exit "$sh_rc"
fi
echo "[pilot] $TOOL: no executable found" >&2
exit 127
