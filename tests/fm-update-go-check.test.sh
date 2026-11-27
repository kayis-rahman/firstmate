#!/usr/bin/env bash
# Behavior tests for bin/fm-update-go-check.sh.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

CHECK="$ROOT/bin/fm-update-go-check.sh"
TMP_ROOT=$(fm_test_tmproot fm-update-go-check)
fm_git_identity fmtest fmtest@example.invalid

setup_repo() {
  local repo="$TMP_ROOT/repo"
  mkdir -p "$repo/bin" "$repo/docs" "$repo/config"
  cp "$ROOT/docs/go-port.md" "$repo/docs/go-port.md"
  cp "$ROOT/bin/fm-forge-detect.sh" "$repo/bin/fm-forge-detect.sh"
  git -C "$repo" init -q
  git -C "$repo" add .
  git -C "$repo" commit -q -m "initial"
  printf '%s\n' "$repo"
}

test_flags_changed_ported_helper_and_switches_to_shell() {
  local repo old new out
  repo=$(setup_repo)
  old=$(git -C "$repo" rev-parse HEAD)
  printf '# updated\n' >> "$repo/bin/fm-forge-detect.sh"
  printf '#!/usr/bin/env bash\necho new\n' > "$repo/bin/fm-new-helper.sh"
  printf '#!/usr/bin/env bash\n# lib\n' > "$repo/bin/fm-new-lib.sh"
  git -C "$repo" add .
  git -C "$repo" commit -q -m "upstream update"
  new=$(git -C "$repo" rev-parse HEAD)

  printf 'forge-detect\nstorage-policy\n' > "$repo/config/go-pilot"

  out=$(FM_ROOT_OVERRIDE="$repo" FM_HOME="$repo" FM_CONFIG_OVERRIDE="$repo/config" \
    PATH="/usr/bin:/bin" bash "$CHECK" "$old" "$new" 2>&1) || fail "check failed: $out"

  assert_contains "$out" "changed-shell: M bin/fm-forge-detect.sh" "did not list changed ported script"
  assert_contains "$out" "out-of-date-go-port: forge-detect (bin/fm-forge-detect.sh)" "did not flag out-of-date Go port"
  assert_contains "$out" "switched-to-shell: forge-detect" "did not switch forge-detect back to shell"
  assert_contains "$out" "new-helper-candidate: bin/fm-new-helper.sh" "did not report new helper candidate"
  assert_not_contains "$out" "new-helper-candidate: bin/fm-new-lib.sh" "library should not be reported as helper candidate"

  if grep -qx 'forge-detect' "$repo/config/go-pilot"; then
    fail "forge-detect remained enabled in config/go-pilot"
  fi
  if ! grep -qx 'storage-policy' "$repo/config/go-pilot"; then
    fail "unrelated storage-policy was removed from config/go-pilot"
  fi
  pass "flags changed Go port, switches it to shell, and reports new helper candidates"
}

test_runs_go_pilot_build_when_go_available() {
  local repo old new fakebin out
  repo=$(setup_repo)
  mkdir -p "$repo/go/cmd/fm-forge-detect"
  cp "$ROOT/bin/fm-go-pilot-build.sh" "$repo/bin/fm-go-pilot-build.sh"
  cp "$ROOT/bin/fm-update-go-check.sh" "$repo/bin/fm-update-go-check.sh"
  git -C "$repo" add .
  git -C "$repo" commit -q -m "add go-pilot-build"
  old=$(git -C "$repo" rev-parse HEAD)
  printf '# updated\n' >> "$repo/bin/fm-forge-detect.sh"
  git -C "$repo" add .
  git -C "$repo" commit -q -m "update"
  new=$(git -C "$repo" rev-parse HEAD)

  fakebin=$(fm_fakebin "$TMP_ROOT/build-bin")
  cat > "$fakebin/go" <<'SH'
#!/usr/bin/env bash
out=
while [ "$#" -gt 0 ]; do
  if [ "$1" = "-o" ]; then out=$2; shift 2; continue; fi
  shift
done
[ -n "$out" ] && printf '#!/bin/sh\nexit 0\n' > "$out" && chmod +x "$out"
exit 0
SH
  chmod +x "$fakebin/go"

  out=$(FM_ROOT_OVERRIDE="$repo" FM_HOME="$repo" FM_CONFIG_OVERRIDE="$repo/config" \
    PATH="$fakebin:/usr/bin:/bin" bash "$repo/bin/fm-update-go-check.sh" "$old" "$new" 2>&1) || fail "build check failed: $out"
  assert_contains "$out" "go-pilot-build: ok" "expected go-pilot-build: ok, got: $out"
  [ -x "$repo/bin/go-pilot/forge-detect" ] || fail "go-pilot-build did not write into FM_ROOT_OVERRIDE/bin/go-pilot"
  pass "runs go-pilot-build into FM_ROOT_OVERRIDE when go is available"
}

fm_test_run test_flags_changed_ported_helper_and_switches_to_shell test_runs_go_pilot_build_when_go_available
