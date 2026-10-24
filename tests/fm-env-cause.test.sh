#!/usr/bin/env bash
# Behavior tests for the two named-cause diagnostics (gap: environment failures
# read as ordinary blockers with no named cause):
#   - bin/fm-env-cause.sh classifies the real observed failure - a fresh
#     program's no-route-to-host to a LAN address on macOS - naming Local
#     Network privacy and its setting without claiming certainty, and stays
#     quiet everywhere the rule does not hold;
#   - bin/fm-busy-event.sh records its last error durably despite every harness
#     wrapper discarding its exit status, and bin/fm-bootstrap.sh surfaces that
#     record as a HOOK_LAST_ERROR line.
set -u

# shellcheck source=tests/fixtures.sh
. "$(dirname "${BASH_SOURCE[0]}")/fixtures.sh"

ENV_CAUSE="$ROOT/bin/fm-env-cause.sh"
BUSY_EVENT="$ROOT/bin/fm-busy-event.sh"
TMP_ROOT=$(fm_test_tmproot fm-env-cause)

# The exact Go dial failure observed from a worker (2026-10-17): shell nc
# reached 192.168.0.100:5435, the freshly built program got no route to host.
OBSERVED_ERROR='failed to connect to database: 192.168.0.100:5435 (192.168.0.100): dial error: dial tcp 192.168.0.100:5435: connect: no route to host'

run_classify() { # [--darwin N] <text>  (stdin)
  local darwin=$1 text=$2
  status=0
  out=$(printf '%s\n' "$text" | bash "$ENV_CAUSE" classify --darwin "$darwin" - 2>&1) || status=$?
}

test_observed_error_gets_the_named_cause_with_its_setting() {
  run_classify 1 "$OBSERVED_ERROR"
  expect_code 0 "$status" "classification is a printer and must not fail"
  assert_contains "$out" "192.168.0.100:5435" "the cause must name the observed target"
  assert_contains "$out" "Local Network privacy" "the cause must name the likely cause"
  assert_contains "$out" "System Settings > Privacy & Security > Local Network" "the cause must name the exact setting"
  assert_contains "$out" "(likely, not certain)" "the cause must not claim certainty"
  assert_contains "$out" "does not rule it out" "the cause must address the reachability evidence that made this confusing"
  pass "the observed no-route-to-host failure gets a hedged Local Network privacy cause"
}

test_case_insensitive_and_sibling_markers_classify() {
  run_classify 1 'connect: No Route To Host 192.168.1.10'
  assert_contains "$out" "Local Network privacy" "marker matching must be case-insensitive"
  run_classify 1 'dial tcp 10.0.0.5:5432: connect: host is unreachable'
  assert_contains "$out" "Local Network privacy" "the sibling unreachable marker must classify"
  pass "host-unreachable markers classify case-insensitively"
}

test_non_macos_and_off_target_failures_stay_unclassified() {
  run_classify 0 "$OBSERVED_ERROR"
  [ "$status" -eq 0 ] || fail "classification must not fail on non-macOS"
  [ -z "$out" ] || fail "non-macOS must not name a macOS setting, got: $out"

  run_classify 1 'connect: no route to host'
  [ -z "$out" ] || fail "a no-route error with no LAN address must not be blamed on macOS, got: $out"

  run_classify 1 'dial tcp 8.8.8.8:53: connect: no route to host'
  [ -z "$out" ] || fail "a non-LAN target must not be blamed on macOS Local Network privacy, got: $out"

  run_classify 1 'connection refused 192.168.0.100:5435'
  [ -z "$out" ] || fail "an unrelated failure must stay unclassified, got: $out"
  pass "non-macOS, non-LAN, and unrelated failures stay unclassified"
}

test_auto_platform_follows_uname() {
  if [ "$(uname)" = Darwin ]; then
    run_classify auto "$OBSERVED_ERROR"
    assert_contains "$out" "Local Network privacy" "auto on macOS must classify"
  else
    run_classify auto "$OBSERVED_ERROR"
    [ -z "$out" ] || fail "auto on a non-macOS host must not name a macOS setting, got: $out"
  fi
  pass "auto platform selection follows uname"
}

test_file_input_classifies_like_stdin() {
  local file="$TMP_ROOT/error.txt"
  printf '%s\n' "$OBSERVED_ERROR" > "$file"
  status=0
  out=$(bash "$ENV_CAUSE" classify --darwin 1 "$file" 2>&1) || status=$?
  expect_code 0 "$status" "file input must classify"
  assert_contains "$out" "Local Network privacy" "file input must classify like stdin"
  status=0
  out=$(bash "$ENV_CAUSE" classify --darwin 1 "$TMP_ROOT/does-not-exist.txt" 2>&1) || status=$?
  expect_code 0 "$status" "a missing file must be a quiet no-op"
  [ -z "$out" ] || fail "a missing file must produce nothing, got: $out"
  pass "file input and missing files behave like the contract"
}

# --- the hook's durable last error -------------------------------------------

test_busy_event_records_and_clears_its_last_error() {
  local state="$TMP_ROOT/busy-state" status=0 out record
  mkdir -p "$state"
  record="$state/task-1.busy-event-last-error"

  local gen
  gen=$(bash "$BUSY_EVENT" arm "$state" task-1) || fail "arm must succeed"
  assert_absent "$record" "arm must start a clean incarnation with no last-error record"

  # A hook that outlives its incarnation: retire, then the late event fires
  # and fails - every harness wrapper would discard this exit silently.
  bash "$BUSY_EVENT" retire "$state" task-1 --gen "$gen" >/dev/null 2>&1 \
    || fail "retire must succeed"
  status=0
  out=$(bash "$BUSY_EVENT" apply "$state" task-1 busy --gen "$gen" --source pi-ext --event agent-start 2>&1) || status=$?
  expect_code 1 "$status" "an unarmed apply must fail"
  assert_contains "$out" "error:" "the failure must still print for direct callers"
  assert_present "$record" "the failure must leave a durable last-error record"
  assert_grep "at=" "$record" "the record must carry its timestamp"
  assert_grep "cmd=apply" "$record" "the record must name the command"
  assert_grep "source=pi-ext" "$record" "the record must name the hook's source"
  assert_grep "event=agent-start" "$record" "the record must name the event"
  assert_grep "error=no armed busy-state gen for task-1" "$record" "the record must carry the exact error"
  [ "$(wc -l < "$record" | tr -d ' ')" = 1 ] || fail "the record must stay one line"
  [ "$(stat -f '%Lp' "$record" 2>/dev/null || stat -c '%a' "$record")" = 600 ] \
    || fail "the record must be private (mode $(stat -f '%Lp' "$record" 2>/dev/null || stat -c '%a' "$record"))"

  # A later failure overwrites: this is the LAST error, not a log.
  status=0
  bash "$BUSY_EVENT" apply "$state" task-1 idle --gen "$gen" --source opencode-plugin --event session-idle >/dev/null 2>&1 || status=$?
  expect_code 1 "$status" "the second failure must also fail"
  assert_grep "source=opencode-plugin" "$record" "the record must hold the latest failure"
  assert_no_grep "source=pi-ext" "$record" "the record must not accumulate history"

  # A successful arm clears it: a fresh incarnation starts clean.
  gen=$(bash "$BUSY_EVENT" arm "$state" task-1) || fail "re-arm must succeed"
  assert_absent "$record" "a successful arm must clear the last-error record"
  pass "the hook records its last error durably, newest wins, and arm clears it"
}

test_retire_clears_the_last_error() {
  local state="$TMP_ROOT/busy-state-retire" status=0
  mkdir -p "$state"
  local gen
  gen=$(bash "$BUSY_EVENT" arm "$state" task-2) || fail "arm must succeed"
  bash "$BUSY_EVENT" apply "$state" task-2 busy --gen "$gen" --source pi-ext --event agent-start >/dev/null 2>&1 || true
  status=0
  bash "$BUSY_EVENT" retire "$state" task-2 --gen "$gen" >/dev/null 2>&1 || status=$?
  expect_code 0 "$status" "retire must succeed"
  assert_absent "$state/task-2.busy-event-last-error" "a successful retire must clear the record"
  pass "retirement clears the last-error record"
}

test_session_start_surfaces_the_hook_last_error() {
  local home="$TMP_ROOT/boot-hook"
  mkdir -p "$home/state" "$home/data" "$home/config"
  printf 'at=1792326755 cmd=apply source=pi-ext event=agent-start error=no armed busy-state gen for task-b\n' \
    > "$home/state/task-b.busy-event-last-error"
  status=0
  out=$(FM_BOOTSTRAP_DETECT_ONLY=1 FM_HOME="$home" FM_STATE_OVERRIDE="$home/state" \
    FM_DATA_OVERRIDE="$home/data" FM_CONFIG_OVERRIDE="$home/config" \
    bash "$ROOT/bin/fm-bootstrap.sh" 2>&1) || status=$?
  expect_code 0 "$status" "bootstrap diagnostics must still exit 0"
  assert_contains "$out" "HOOK_LAST_ERROR: task task-b busy-state hook last error: at=1792326755" \
    "session start must surface the hook's last error verbatim"
  assert_contains "$out" "error=no armed busy-state gen for task-b" \
    "the surfaced line must carry the exact cause"
  pass "session start surfaces a silent hook failure with its exact last error"
}

test_session_start_is_silent_without_a_hook_error() {
  local home="$TMP_ROOT/boot-hook-clean"
  mkdir -p "$home/state" "$home/data" "$home/config"
  status=0
  out=$(FM_BOOTSTRAP_DETECT_ONLY=1 FM_HOME="$home" FM_STATE_OVERRIDE="$home/state" \
    FM_DATA_OVERRIDE="$home/data" FM_CONFIG_OVERRIDE="$home/config" \
    bash "$ROOT/bin/fm-bootstrap.sh" 2>&1) || status=$?
  expect_code 0 "$status" "bootstrap diagnostics must still exit 0"
  assert_not_contains "$out" "HOOK_LAST_ERROR:" "a clean home must surface nothing"
  pass "session start stays silent when no hook error is recorded"
}

test_observed_error_gets_the_named_cause_with_its_setting
test_case_insensitive_and_sibling_markers_classify
test_non_macos_and_off_target_failures_stay_unclassified
test_auto_platform_follows_uname
test_file_input_classifies_like_stdin
test_busy_event_records_and_clears_its_last_error
test_retire_clears_the_last_error
test_session_start_surfaces_the_hook_last_error
test_session_start_is_silent_without_a_hook_error