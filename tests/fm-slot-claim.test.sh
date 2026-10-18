#!/usr/bin/env bash
# Behavior tests for bin/fm-slot-claim-lib.sh and its three call sites (gap: two
# task records could claim one shared working copy and only teardown's refusal
# ever noticed):
#   - the lib's scan answers who else claims a live copy and which paths are
#     claimed twice,
#   - bin/fm-spawn.sh reports a launch that would create the second claim as a
#     plain warning and edits no record,
#   - bin/fm-bootstrap.sh reports a pre-existing pair as a COLLISION line at
#     session start, read-only,
#   - bin/fm-teardown.sh keeps its exact refusal on the same pair (the scan
#     moved into the shared lib; the refusal policy did not change).
set -u

# shellcheck source=tests/fixtures.sh
. "$(dirname "${BASH_SOURCE[0]}")/fixtures.sh"

TMP_ROOT=$(fm_test_tmproot fm-slot-claim)

# --- lib-level scan ----------------------------------------------------------

LIB_HOME="$TMP_ROOT/lib-home"
mkdir -p "$LIB_HOME/state" "$LIB_HOME/data" "$LIB_HOME/config"
mkdir -p "$TMP_ROOT/copy-a" "$TMP_ROOT/copy-b"
export FM_HOME="$LIB_HOME"
# shellcheck source=bin/fm-secondmate-registry-lib.sh
. "$ROOT/bin/fm-secondmate-registry-lib.sh"
# shellcheck source=bin/fm-wake-lib.sh
. "$ROOT/bin/fm-wake-lib.sh"
# shellcheck source=bin/fm-backend.sh
. "$ROOT/bin/fm-backend.sh"
# shellcheck source=bin/fm-slot-claim-lib.sh
. "$ROOT/bin/fm-slot-claim-lib.sh"

write_worker_meta() { # <file> <worktree>
  fm_write_meta "$1" "window=firstmate:fm-$(basename "$1" .meta)" \
    "worktree=$2" "project=$TMP_ROOT/proj" "harness=pi" "kind=ship" "backend=tmux"
}

test_rows_report_other_claimants_and_exclude_self() {
  write_worker_meta "$LIB_HOME/state/claim-a.meta" "$TMP_ROOT/copy-a"
  write_worker_meta "$LIB_HOME/state/claim-b.meta" "$TMP_ROOT/copy-a"
  write_worker_meta "$LIB_HOME/state/claim-c.meta" "$TMP_ROOT/copy-b"

  local status=0
  fm_slot_claim_rows "$LIB_HOME/state" "$LIB_HOME/state/claim-a.meta" "$TMP_ROOT/copy-a" || status=$?
  expect_code 0 "$status" "the scan must find the other claimant of copy-a"
  assert_contains "$FM_SLOT_CLAIM_ROWS" "claim-b" "the other claimant must be named"
  assert_contains "$FM_SLOT_CLAIM_ROWS" "worktree" "the claiming field must be named"
  assert_not_contains "$FM_SLOT_CLAIM_ROWS" "claim-a" "the scanning record must exclude itself"

  status=0
  fm_slot_claim_rows "$LIB_HOME/state" "" "$TMP_ROOT/copy-b" || status=$?
  expect_code 0 "$status" "copy-b has one claimant"
  assert_contains "$FM_SLOT_CLAIM_ROWS" "claim-c" "copy-b's claimant must be named"

  status=0
  fm_slot_claim_rows "$LIB_HOME/state" "" "$TMP_ROOT/no-such-copy" || status=$?
  expect_code 1 "$status" "a path that does not exist claims nothing"
  [ -z "$FM_SLOT_CLAIM_ROWS" ] || fail "a dead path must yield no rows: $FM_SLOT_CLAIM_ROWS"
  pass "the scan reports other claimants, excludes self, and ignores dead paths"
}

test_shared_rows_report_only_real_pairs() {
  local status=0
  fm_slot_shared_rows "$LIB_HOME/state" || status=$?
  expect_code 0 "$status" "copy-a is claimed by two records"
  assert_contains "$FM_SLOT_CLAIM_SHARED_ROWS" "$TMP_ROOT/copy-a" "the shared path must be named"
  assert_contains "$FM_SLOT_CLAIM_SHARED_ROWS" "claim-a/worktree" "both claimants must be listed"
  assert_contains "$FM_SLOT_CLAIM_SHARED_ROWS" "claim-b/worktree" "both claimants must be listed"
  assert_not_contains "$FM_SLOT_CLAIM_SHARED_ROWS" "copy-b" "a singly claimed path is not a collision"

  # One record claiming through both worktree= and home= is one claimant, not a pair.
  mkdir -p "$TMP_ROOT/copy-c"
  write_worker_meta "$LIB_HOME/state/claim-d.meta" "$TMP_ROOT/copy-c"
  printf 'home=%s\n' "$TMP_ROOT/copy-c" >> "$LIB_HOME/state/claim-d.meta"
  status=0
  fm_slot_shared_rows "$LIB_HOME/state" || status=$?
  expect_code 0 "$status" "the earlier copy-a pair must still be reported"
  assert_not_contains "$FM_SLOT_CLAIM_SHARED_ROWS" "copy-c" "one record claiming a path through both fields is not a pair"
  pass "shared rows report only paths two distinct records claim"
}

# --- session-start COLLISION line --------------------------------------------

run_bootstrap_detect() { # <home>
  status=0
  out=$(FM_BOOTSTRAP_DETECT_ONLY=1 FM_HOME="$1" FM_STATE_OVERRIDE="$1/state" \
    FM_DATA_OVERRIDE="$1/data" FM_CONFIG_OVERRIDE="$1/config" \
    bash "$ROOT/bin/fm-bootstrap.sh" 2>&1) || status=$?
}

test_session_start_reports_a_shared_copy_pair() {
  local home="$TMP_ROOT/boot-pair"
  mkdir -p "$home/state" "$home/data" "$home/config"
  write_worker_meta "$home/state/task-a.meta" "$TMP_ROOT/copy-a"
  write_worker_meta "$home/state/task-b.meta" "$TMP_ROOT/copy-a"
  run_bootstrap_detect "$home"
  expect_code 0 "$status" "bootstrap diagnostics must still exit 0"$'\n'"$out"
  assert_contains "$out" "COLLISION:" "session start must report the shared copy"
  assert_contains "$out" "task-a/worktree" "the report must name the first claimant"
  assert_contains "$out" "task-b/worktree" "the report must name the second claimant"
  assert_contains "$out" "bin/fm-crew-state.sh" "the report must point at the reconciliation command"
  pass "session start reports two records on one working copy plainly"
}

test_session_start_stays_silent_without_a_pair() {
  local home="$TMP_ROOT/boot-solo"
  mkdir -p "$home/state" "$home/data" "$home/config"
  write_worker_meta "$home/state/task-a.meta" "$TMP_ROOT/copy-a"
  write_worker_meta "$home/state/task-b.meta" "$TMP_ROOT/copy-b"
  run_bootstrap_detect "$home"
  expect_code 0 "$status" "bootstrap diagnostics must still exit 0"
  assert_not_contains "$out" "COLLISION:" "two records on two copies must not be reported"
  pass "session start stays silent when no path is claimed twice"
}

# --- spawn refusal ------------------------------------------------------------

make_spawn_world() { # <name> <task-id> -> home|proj|wt|fakebin|launchlog
  local name=$1 id=$2 home proj wt fakebin launchlog
  home="$TMP_ROOT/spawn-$name/home"
  proj="$TMP_ROOT/spawn-$name/project"
  wt="$TMP_ROOT/spawn-$name/wt"
  launchlog="$TMP_ROOT/spawn-$name/launch.log"
  fakebin=$(fm_fakebin "$TMP_ROOT/spawn-$name")
  fm_test_fake_tmux_spawn "$fakebin"
  fm_fake_exit0 "$fakebin" treehouse free-model-axi
  cat > "$fakebin/timeout" <<'SH'
#!/usr/bin/env bash
if [ "${1:-}" = -k ]; then shift 2; fi
shift
exec "$@"
SH
  chmod +x "$fakebin/timeout"
  cat > "$fakebin/pi" <<'SH'
#!/usr/bin/env bash
if [ "${1:-}" = --help ]; then
  printf '%s\n' 'Pi 0.84.0' 'Options: --help --tui-mode <mode> --approve'
fi
exit 0
SH
  chmod +x "$fakebin/pi"
  fm_test_spawn_home "$home" pi
  fm_git_worktree "$proj" "$wt" "wt-$name"
  fm_test_spawn_brief "$home" "$id"
  printf '%s\n' "$home|$proj|$wt|$fakebin|$launchlog"
}

test_spawn_reports_a_copy_another_record_claims() {
  local rec home proj wt fakebin launchlog id status=0 out
  id=shared-copy-spawn-z1
  rec=$(make_spawn_world shared "$id")
  IFS='|' read -r home proj wt fakebin launchlog <<<"$rec"
  write_worker_meta "$home/state/other-task.meta" "$wt"
  : > "$launchlog"
  out=$(FM_FAKE_LAUNCH_LOG="$launchlog" CLAUDE_CONFIG_DIR='' \
    fm_test_run_spawn "$home" "$wt" "$fakebin" "$id" "$proj" \
    --mode no-mistakes --yolo off --harness pi) || status=$?
  # The check reports plainly and edits nothing: reconciliation is an operator
  # action (bin/fm-crew-state.sh), and slot reuse with a lingering record is a
  # real flow (data/learnings.md 2026-10-07), so dispatch itself proceeds.
  expect_code 0 "$status" "a reported pair must not block the launch"$'\n'"$out"
  assert_contains "$out" "is already claimed by another task record" "the report must say what is wrong"
  assert_contains "$out" "task other-task records it in worktree" "the report must name the other record and field"
  assert_contains "$out" "two task records name one working copy" "the report must name the pair consequence"
  assert_contains "$out" "bin/fm-crew-state.sh" "the report must point at the reconciliation command"
  assert_contains "$out" "edited no record" "the report must state that nothing was edited"
  assert_present "$home/state/$id.meta" "the spawn itself still records its task"
  assert_present "$home/state/other-task.meta" "the other record must be left untouched"
  pass "spawn reports a working copy another record claims, plainly and without editing"
}

# --- teardown keeps its refusal -----------------------------------------------

test_teardown_still_refuses_the_pair() {
  local home="$TMP_ROOT/tear/home" slot="$TMP_ROOT/tear/pool/p1/slot" repo="$TMP_ROOT/tear/repo"
  local fakebin status=0 out
  mkdir -p "$home/state" "$home/data" "$home/config" "$TMP_ROOT/tear/pool"
  fakebin=$(fm_fakebin "$TMP_ROOT/tear")
  cat > "$fakebin/tmux" <<'SH'
#!/usr/bin/env bash
case "${1:-}" in
  has-session | display-message) exit 0 ;;
  list-windows) printf '%s\n' firstmate; exit 0 ;;
esac
exit 0
SH
  chmod +x "$fakebin/tmux"
  fm_git_worktree "$repo" "$slot" "wt-tear"
  printf '{}\n' > "$TMP_ROOT/tear/pool/treehouse-state.json"
  local t
  for t in task-a task-b; do
    fm_write_meta "$home/state/$t.meta" \
      "window=firstmate:fm-$t" "endpoint_task_id=$t" \
      "worktree=$slot" "project=$repo" "harness=pi" "kind=ship" "backend=tmux"
  done
  out=$(PATH="$fakebin:$PATH" FM_GUARD_READ_ONLY=1 FM_HOME="$home" \
    FM_STATE_OVERRIDE="$home/state" FM_DATA_OVERRIDE="$home/data" \
    FM_CONFIG_OVERRIDE="$home/config" \
    bash "$ROOT/bin/fm-teardown.sh" task-a 2>&1) || status=$?
  expect_code 1 "$status" "teardown must still refuse the pair"
  assert_contains "$out" "REFUSED: task task-a's recorded worktree" "teardown must name its refusal"
  assert_contains "$out" "is also task task-b's recorded worktree" "teardown must name the other record"
  assert_present "$home/state/task-a.meta" "a refusal must preserve both records"
  assert_present "$home/state/task-b.meta" "a refusal must preserve both records"
  pass "teardown keeps its exact refusal on a shared working copy"
}

test_rows_report_other_claimants_and_exclude_self
test_shared_rows_report_only_real_pairs
test_session_start_reports_a_shared_copy_pair
test_session_start_stays_silent_without_a_pair
test_spawn_reports_a_copy_another_record_claims
test_teardown_still_refuses_the_pair