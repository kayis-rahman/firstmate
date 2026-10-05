#!/usr/bin/env bash
# Real Herdr regression for preparing, provisioning, and tearing down a named lab.
# Every Herdr command uses the helper, and the live default session must remain unchanged.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAB_HELPER=${HERDR_LAB_HELPER:-$ROOT/bin/fm-herdr-lab.sh}

fail() { printf 'not ok - %s\n' "$1" >&2; exit 1; }
pass() { printf 'ok - %s\n' "$1"; }

fm_live_gate default-on FM_HERDR_LAB_PROVISION_LIVE_E2E herdr jq
[ -x "$LAB_HELPER" ] || { echo "skip: Herdr lab helper not executable at $LAB_HELPER"; exit 0; }

LAB_SESSION=$("$LAB_HELPER" name firstmate-herdr-lab-tripwire-fix-v1) \
  || fail 'could not generate an isolated lab session name'
DEFAULT_BEFORE=
LAB_TORN_DOWN=0

capture_default() {
  local sessions
  sessions=$("$LAB_HELPER" run "$LAB_SESSION" session list --json) || return 1
  printf '%s' "$sessions" | jq -ce '
    [.sessions[]? | select(.default == true)]
    | if length == 1 and .[0].name == "default" and .[0].running == true
      then .[0] | {name, default, running, socket_path}
      else error("expected exactly one running default session")
      end
  '
}

cleanup() {
  local status=$? after
  if [ "$LAB_TORN_DOWN" != 1 ]; then
    "$LAB_HELPER" teardown "$LAB_SESSION" || status=1
    LAB_TORN_DOWN=1
  fi
  if [ -n "$DEFAULT_BEFORE" ]; then
    after=$(capture_default) || status=1
    [ "$after" = "$DEFAULT_BEFORE" ] || {
      printf 'not ok - default session changed across lab lifecycle\nbefore: %s\nafter:  %s\n' \
        "$DEFAULT_BEFORE" "${after:-<unreadable>}" >&2
      status=1
    }
  fi
  exit "$status"
}
trap cleanup EXIT

DEFAULT_BEFORE=$(capture_default) || fail 'could not snapshot the live default session'
"$LAB_HELPER" prepare "$LAB_SESSION" || fail 'could not prepare named lab session'
"$LAB_HELPER" provision "$LAB_SESSION" || fail 'provision rejected the tripwire written by prepare'
SESSIONS=$("$LAB_HELPER" run "$LAB_SESSION" session list --json) \
  || fail 'could not inspect the provisioned lab session'
printf '%s' "$SESSIONS" | jq -e --arg name "$LAB_SESSION" '
  [.sessions[]? | select(.name == $name and .default == false and .running == true)] | length == 1
' >/dev/null || fail 'named lab session was not running as a non-default session'
"$LAB_HELPER" teardown "$LAB_SESSION" || fail 'could not tear down named lab session'
LAB_TORN_DOWN=1
DEFAULT_AFTER=$(capture_default) || fail 'could not verify the live default session after teardown'
[ "$DEFAULT_AFTER" = "$DEFAULT_BEFORE" ] || fail 'live default session changed during lab lifecycle'
pass 'fm-herdr-lab: real prepare/provision/teardown preserves the live default session'
