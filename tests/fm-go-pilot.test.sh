#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PILOT="$ROOT/bin/fm-go-pilot.sh"

fail() { printf 'not ok - %s\n' "$1" >&2; exit 1; }
pass() { printf 'ok - %s\n' "$1"; }

TMP_HOME="$(mktemp -d)"
trap 'rm -rf "$TMP_HOME"' EXIT
export FM_HOME="$TMP_HOME"
mkdir -p "$TMP_HOME/config"

# default off runs shell
out=$("$PILOT" env-cause --help 2>&1) || true
case "$out" in
  *'-> shell'*) pass "default off uses shell" ;;
  *) fail "default off did not use shell: $out" ;;
esac

# enabled runs go
printf 'env-cause\n' > "$TMP_HOME/config/go-pilot"
out=$("$PILOT" env-cause --help 2>&1) || true
case "$out" in
  *'-> go'*) pass "enabled uses go" ;;
  *) fail "enabled did not use go: $out" ;;
esac

# The dispatcher must report the Go command's actual exit code.
out=$("$PILOT" env-cause definitely-not-a-valid-env-name-causing-failure 2>&1)
rc=$?
case "$out" in
  *"-> go (exit=$rc)"*) pass "Go command exit status is preserved (rc=$rc)" ;;
  *) fail "Go command exit status was not reported accurately (rc=$rc): $out" ;;
esac

# missing binary falls back to shell
mv "$ROOT/bin/go-pilot/env-cause" "$ROOT/bin/go-pilot/env-cause.bak"
out=$("$PILOT" env-cause --help 2>&1) || true
mv "$ROOT/bin/go-pilot/env-cause.bak" "$ROOT/bin/go-pilot/env-cause"
case "$out" in
  *'falling back to shell'* | *'-> shell'*) pass "missing binary falls back to shell" ;;
  *) fail "missing binary did not fall back: $out" ;;
esac

pass "all checks"
