#!/usr/bin/env bash
# fm-update-go-check.sh - inspect pulled shell changes against docs/go-port.md.
#
# Usage:
#   fm-update-go-check.sh <old-commit> <new-commit>
#   fm-update-go-check.sh --help
#
# Lists shell scripts under bin/ added or changed between <old-commit> and
# <new-commit>. Any changed script that has a Go port in docs/go-port.md is
# flagged as out of date and removed from $FM_HOME/config/go-pilot so it falls
# back to shell until re-ported and re-verified. Newly added standalone helper
# scripts are reported as port candidates. Best-effort rebuilds Go pilot tools
# via bin/fm-go-pilot-build.sh. Never blocks the update (exits 0).
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
FM_HOME="${FM_HOME:-${FM_ROOT_OVERRIDE:-$FM_ROOT}}"
CONFIG="${FM_CONFIG_OVERRIDE:-$FM_HOME/config}"
PILOT_CONFIG="$CONFIG/go-pilot"
GO_PORT_DOC="$FM_ROOT/docs/go-port.md"

usage() {
  sed -n '2,12{s/^# \{0,1\}//;p;}' "$0"
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

if [ "$#" -ne 2 ]; then
  usage >&2
  exit 2
fi

OLD_COMMIT=$1
NEW_COMMIT=$2

if ! git -C "$FM_ROOT" rev-parse --verify "${OLD_COMMIT}^{commit}" >/dev/null 2>&1 \
  || ! git -C "$FM_ROOT" rev-parse --verify "${NEW_COMMIT}^{commit}" >/dev/null 2>&1; then
  echo "go-port-check: skipped (invalid commit range $OLD_COMMIT..$NEW_COMMIT)"
  exit 0
fi

go_port_tool_for_script() {  # <bin/fm-foo.sh>
  local script_path=$1 base tool status
  [ -f "$GO_PORT_DOC" ] || return 1
  status=$(awk -F'|' -v target=" $script_path " '
    $0 ~ /^\|/ {
      col2=$2
      if (col2 == target) {
        col6=$6
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", col6)
        print col6
        exit
      }
    }
  ' "$GO_PORT_DOC" 2>/dev/null || true)
  case "$status" in
    ported*|direct-go*)
      base=${script_path##*/}
      tool=${base#fm-}
      tool=${tool%.sh}
      printf '%s\n' "$tool"
      return 0
      ;;
  esac
  return 1
}

disable_go_pilot_tool() {  # <tool>
  local tool=$1 tmp
  [ -f "$PILOT_CONFIG" ] || return 1
  grep -qx "$tool" "$PILOT_CONFIG" 2>/dev/null || return 1
  tmp=$(mktemp "${PILOT_CONFIG}.XXXXXX") || return 1
  awk -v t="$tool" '$0 != t' "$PILOT_CONFIG" > "$tmp" && mv "$tmp" "$PILOT_CONFIG"
}

diff_lines=$(git -C "$FM_ROOT" diff --name-status "$OLD_COMMIT" "$NEW_COMMIT" -- 'bin/*.sh' 2>/dev/null || true)

while IFS=$'\t' read -r st path extra; do
  [ -n "${st:-}" ] || continue
  # For renames (R100\told\tnew), inspect the destination path.
  if [ -n "${extra:-}" ]; then
    path=$extra
  fi
  printf 'changed-shell: %s %s\n' "$st" "$path"
  if tool=$(go_port_tool_for_script "$path"); then
    printf 'out-of-date-go-port: %s (%s)\n' "$tool" "$path"
    if disable_go_pilot_tool "$tool"; then
      printf 'switched-to-shell: %s\n' "$tool"
    fi
  elif [ "$st" = "A" ]; then
    case "$path" in
      *-lib.sh) ;;
      *) printf 'new-helper-candidate: %s\n' "$path" ;;
    esac
  fi
done <<EOF
$diff_lines
EOF

if command -v go >/dev/null 2>&1 && [ -x "$SCRIPT_DIR/fm-go-pilot-build.sh" ]; then
  if FM_ROOT_OVERRIDE="$FM_ROOT" "$SCRIPT_DIR/fm-go-pilot-build.sh" >/dev/null 2>&1; then
    echo "go-pilot-build: ok"
  else
    echo "go-pilot-build: failed (non-blocking)"
  fi
else
  echo "go-pilot-build: skipped (go toolchain unavailable)"
fi

exit 0
