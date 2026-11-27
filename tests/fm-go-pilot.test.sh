#!/usr/bin/env bash
# Behavior tests for bin/fm-go-pilot.sh, the per-tool Go/shell dispatcher.
# The dispatcher runs from a private code-root copy so the test never mutates
# this checkout's gitignored bin/go-pilot/ build output. The Go tool is built
# from go/cmd when a Go toolchain is installed; without one, a stub binary
# stands in for it, because the dispatcher contract under test (selection,
# exit-status reporting, and fallback) does not depend on the Go program.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() { printf 'not ok - %s\n' "$1" >&2; exit 1; }
pass() { printf 'ok - %s\n' "$1"; }

TMP_HOME="$(mktemp -d)"
trap 'rm -rf "$TMP_HOME"' EXIT
CODE="$TMP_HOME/code"
mkdir -p "$TMP_HOME/config" "$CODE/bin/go-pilot"
cp "$ROOT/bin/fm-go-pilot.sh" "$ROOT/bin/fm-env-cause.sh" "$CODE/bin/"
PILOT="$CODE/bin/fm-go-pilot.sh"
GO_TOOL="$CODE/bin/go-pilot/env-cause"
export FM_HOME="$TMP_HOME"

if command -v go >/dev/null 2>&1; then
  ( cd "$ROOT/go" && go build -o "$GO_TOOL" ./cmd/fm-env-cause ) \
    || fail "go build of go/cmd/fm-env-cause failed"
else
  # shellcheck disable=SC2016 # The stub script text is written literally.
  printf '#!/bin/sh\n[ "${1:-}" = --help ] && exit 0\nexit 2\n' > "$GO_TOOL"
  chmod +x "$GO_TOOL"
  printf '# go toolchain not installed; dispatcher checked against a stub Go tool\n'
fi

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
  *'-> go (exit='*) pass "enabled uses go" ;;
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
rm -f "$GO_TOOL"
out=$("$PILOT" env-cause --help 2>&1) || true
case "$out" in
  *'falling back to shell'*'-> shell'*) pass "missing binary falls back to shell" ;;
  *) fail "missing binary did not fall back: $out" ;;
esac

# direct shell entry point handoff via config/go-pilot
for tool in forge-detect env-cause storage-policy test-tap-verify lint-workflows; do
  cp "$ROOT/bin/fm-$tool.sh" "$CODE/bin/fm-$tool.sh"
  cat > "$CODE/bin/go-pilot/$tool" <<SH
#!/bin/sh
printf 'go-handoff:%s\n' "$tool"
exit 0
SH
  chmod +x "$CODE/bin/go-pilot/$tool"
  printf '%s\n' "$tool" > "$TMP_HOME/config/go-pilot"
  out=$(FM_ROOT_OVERRIDE="$CODE" FM_CONFIG_OVERRIDE="$TMP_HOME/config" bash "$CODE/bin/fm-$tool.sh" --help 2>&1) || fail "$tool handoff failed: $out"
  case "$out" in
    "go-handoff:$tool") ;;
    *) fail "direct entry point fm-$tool.sh did not hand off to Go: $out" ;;
  esac
done
pass "direct shell entry points hand off to go-pilot when enabled"

pass "all checks"
