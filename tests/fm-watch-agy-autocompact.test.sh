#!/usr/bin/env bash
# Behavior tests for opt-in Antigravity (agy) autocompact in fm-spawn.sh and fm-watch.sh.
# Exercises spawn env wiring, event mapping with cwd cross-check, idle/composer
# gating, deferral/retry, secondmate/primary exclusion, and 10-minute rate limiting
# using fake backends (no live agy or terminal daemon).
set -eu

# shellcheck source=tests/fixtures.sh
. "$(dirname "${BASH_SOURCE[0]}")/fixtures.sh"

TMP_ROOT=$(fm_test_tmproot fm-watch-agy-autocompact)
export FM_HOME="$TMP_ROOT/home"
export FM_STATE_OVERRIDE="$TMP_ROOT/home/state"
export FM_CONFIG_OVERRIDE="$TMP_ROOT/home/config"
mkdir -p "$FM_STATE_OVERRIDE" "$FM_CONFIG_OVERRIDE"

# --- Part 1: fm-spawn.sh agy path sets COMPACT_ADVISER_EVENT_FILE when opted in ---
test_spawn_agy_event_file_opt_in() {
  local case_dir="$TMP_ROOT/spawn-case"
  local home="$case_dir/home" proj="$case_dir/proj" wt="$case_dir/wt"
  local fakebin launch_off launch_on
  fakebin=$(fm_test_make_spawn_fakebin "$case_dir/fake")
  mv "$fakebin/tmux" "$fakebin/tmux.orig"
  cat > "$fakebin/tmux" <<'SH'
#!/usr/bin/env bash
if [ "${1:-}" = "capture-pane" ]; then
  printf 'Generating...\nesc to cancel                                Gemini 3.8 Flash · low\n'
  exit 0
fi
exec "$(dirname "$0")/tmux.orig" "$@"
SH
  chmod +x "$fakebin/tmux"
  cat > "$fakebin/agy" <<'SH'
#!/bin/sh
if [ "${1:-}" = "models" ]; then
  printf 'gemini-3.8-flash-high\n'
  exit 0
fi
printf 'EVENT_FILE=%s|DISABLE=%s\n' "${COMPACT_ADVISER_EVENT_FILE-unset}" "${COMPACT_ADVISER_DISABLE-unset}"
SH
  chmod +x "$fakebin/agy"

  fm_test_spawn_home "$home" agy
  fm_git_worktree "$proj" "$wt" "wt-agy-ac"

  # Off by default with ambient COMPACT_ADVISER_EVENT_FILE: must not leak into worker
  fm_test_spawn_brief "$home" agy-off
  launch_off="$case_dir/launch-off.log"
  : > "$launch_off"
  FM_FAKE_LAUNCH_LOG="$launch_off" FM_FAKE_PANE_LOG="$case_dir/pane-off.log" \
    fm_test_run_spawn "$home" "$wt" "$fakebin" agy-off "$proj" --mode direct-PR --yolo off --harness agy --model gemini-3.8-flash-high
  local out_off
  out_off=$(env -i HOME="$case_dir/pane-home" PATH="$fakebin:$PATH" TERM=xterm TMUX=synthetic-pane \
    COMPACT_ADVISER_EVENT_FILE=/tmp/leaked.jsonl \
    /bin/sh -c "$(cat "$launch_off")")
  [ "$out_off" = "EVENT_FILE=/tmp/leaked.jsonl|DISABLE=1" ] || [ "$out_off" = "EVENT_FILE=unset|DISABLE=1" ] \
    || fail "default agy spawn must keep COMPACT_ADVISER_DISABLE=1, got: $out_off"

  # Under launch-env-allowlist, ambient COMPACT_ADVISER_EVENT_FILE must not be forwarded when opted out
  : > "$home/config/launch-env-allowlist"
  fm_test_spawn_brief "$home" agy-off-allow
  local launch_off_allow="$case_dir/launch-off-allow.log"
  : > "$launch_off_allow"
  FM_FAKE_LAUNCH_LOG="$launch_off_allow" FM_FAKE_PANE_LOG="$case_dir/pane-off-allow.log" \
    fm_test_run_spawn "$home" "$wt" "$fakebin" agy-off-allow "$proj" --mode direct-PR --yolo off --harness agy --model gemini-3.8-flash-high
  local out_off_allow
  out_off_allow=$(env -i HOME="$case_dir/pane-home" PATH="$fakebin:$PATH" TERM=xterm TMUX=synthetic-pane \
    COMPACT_ADVISER_EVENT_FILE=/tmp/leaked.jsonl \
    /bin/sh -c "$(cat "$launch_off_allow")")
  [ "$out_off_allow" = "EVENT_FILE=unset|DISABLE=1" ] \
    || fail "allowlist must not forward ambient COMPACT_ADVISER_EVENT_FILE when opted out, got: $out_off_allow"

  # Opted in with allowlist + inherited COMPACT_ADVISER_DISABLE=1:
  # COMPACT_ADVISER_EVENT_FILE is set and COMPACT_ADVISER_DISABLE is unset
  touch "$home/config/agy-autocompact"
  fm_test_spawn_brief "$home" agy-on
  launch_on="$case_dir/launch-on.log"
  : > "$launch_on"
  FM_FAKE_LAUNCH_LOG="$launch_on" FM_FAKE_PANE_LOG="$case_dir/pane-on.log" \
    fm_test_run_spawn "$home" "$wt" "$fakebin" agy-on "$proj" --mode direct-PR --yolo off --harness agy --model gemini-3.8-flash-high
  local state_real expected_file out_on
  state_real=$(cd "$home/state" && pwd -P)
  expected_file="$state_real/agy-on.compact-adviser.jsonl"
  out_on=$(env -i HOME="$case_dir/pane-home" PATH="$fakebin:$PATH" TERM=xterm TMUX=synthetic-pane \
    COMPACT_ADVISER_DISABLE=1 \
    /bin/sh -c "$(cat "$launch_on")")
  [ "$out_on" = "EVENT_FILE=$expected_file|DISABLE=unset" ] \
    || fail "opted-in agy spawn under allowlist must export COMPACT_ADVISER_EVENT_FILE=$expected_file and clear inherited COMPACT_ADVISER_DISABLE, got: $out_on"
  pass "fm-spawn agy sets COMPACT_ADVISER_EVENT_FILE and clears inherited COMPACT_ADVISER_DISABLE only when opted in"
}

test_spawn_agy_event_file_opt_in

# --- Part 2: Watcher handling with fake backends ---
# Source fm-watch.sh and stub backend functions for deterministic unit testing.
# shellcheck source=bin/fm-watch.sh
. "$ROOT/bin/fm-watch.sh"

FAKE_AGENT_STATE=alive
FAKE_CAPTURE="? for shortcuts"
FAKE_COMPOSER_STATE=empty
FAKE_SUBMIT_VERDICT=empty
SUBMIT_LOG="$TMP_ROOT/submit.log"

fm_backend_agent_state() { printf '%s' "$FAKE_AGENT_STATE"; }
watcher_capture() {
  WATCHER_CAPTURE=$FAKE_CAPTURE
  return 0
}
fm_backend_composer_state() { printf '%s' "$FAKE_COMPOSER_STATE"; }
fm_backend_send_text_submit() {
  printf '%s|%s|%s\n' "$1" "$2" "$3" >> "$SUBMIT_LOG"
  printf '%s' "$FAKE_SUBMIT_VERDICT"
}

WT_A="$TMP_ROOT/wt-a"
WT_B="$TMP_ROOT/wt-b"
mkdir -p "$WT_A" "$WT_B"

reset_watcher_case() {
  rm -rf -- "${STATE:?}"/* "${STATE:?}"/.[!.]* "${CONFIG:?}"/*
  : > "$SUBMIT_LOG"
  FAKE_AGENT_STATE=alive
  FAKE_CAPTURE="? for shortcuts"
  FAKE_COMPOSER_STATE=empty
  FAKE_SUBMIT_VERDICT=empty
}

write_agy_meta() {  # <id> <kind> <worktree> [harness]
  local id=$1 kind=$2 wt=$3 harness=${4:-agy}
  cat > "$STATE/$id.meta" <<EOF
backend=tmux
window=lab:fm-$id
harness=$harness
kind=$kind
worktree=$wt
EOF
}

append_event() {  # <id> <harness> <cwd> [verdict]
  printf '{"ts":1000,"harness":"%s","cwd":"%s","verdict":"%s","reason":"safe boundary"}\n' \
    "$2" "$3" "${4:-compact}" >> "$STATE/$1.compact-adviser.jsonl"
}

submit_count() {
  wc -l < "$SUBMIT_LOG" | tr -d ' '
}

test_watcher_opt_in_default_off() {
  reset_watcher_case
  write_agy_meta task1 ship "$WT_A"
  append_event task1 agy "$WT_A"
  agy_autocompact_tick 1000
  [ "$(submit_count)" = 0 ] || fail "default off should not deliver /compact"
  pass "watcher ignores agy autocompact events when config/agy-autocompact is absent"
}

test_watcher_mapping_and_exclusions() {
  reset_watcher_case
  touch "$CONFIG/agy-autocompact"

  # Mismatched cwd must not compact
  write_agy_meta task-cwd ship "$WT_A"
  append_event task-cwd agy "$WT_B"
  agy_autocompact_tick 1000
  [ "$(submit_count)" = 0 ] || fail "mismatched cwd must not trigger /compact"

  # Secondmate and primary must never compact
  write_agy_meta sm1 secondmate "$WT_A"
  append_event sm1 agy "$WT_A"
  write_agy_meta prim1 primary "$WT_A"
  append_event prim1 agy "$WT_A"
  agy_autocompact_tick 1000
  [ "$(submit_count)" = 0 ] || fail "secondmate and primary must never be compacted"

  # Non-agy harness must never compact
  write_agy_meta cl1 ship "$WT_A" claude
  append_event cl1 agy "$WT_A"
  agy_autocompact_tick 1000
  [ "$(submit_count)" = 0 ] || fail "non-agy task must never be compacted"

  # Non-compact verdict must be ignored
  write_agy_meta task-verdict ship "$WT_A"
  append_event task-verdict agy "$WT_A" skip
  agy_autocompact_tick 1000
  [ "$(submit_count)" = 0 ] || fail "non-compact verdict must not trigger /compact"

  # Matching agy ship task delivers /compact
  write_agy_meta task-ok ship "$WT_A"
  append_event task-ok agy "$WT_A"
  agy_autocompact_tick 1000
  [ "$(submit_count)" = 1 ] || fail "matching agy ship task should deliver /compact"
  [ "$(cat "$SUBMIT_LOG")" = "tmux|lab:fm-task-ok|/compact" ] \
    || fail "unexpected submit payload: $(cat "$SUBMIT_LOG")"
  pass "watcher maps per-task event with cwd cross-check and excludes secondmate, primary, and non-agy"
}

test_watcher_gating_and_deferral() {
  reset_watcher_case
  touch "$CONFIG/agy-autocompact"
  write_agy_meta task-gate ship "$WT_A"
  append_event task-gate agy "$WT_A"

  # 1. Busy worker defers
  FAKE_CAPTURE="esc to cancel"
  agy_autocompact_tick 1000
  [ "$(submit_count)" = 0 ] || fail "busy worker must defer /compact"

  # 2. Non-empty composer defers
  FAKE_CAPTURE="? for shortcuts"
  FAKE_COMPOSER_STATE=pending
  agy_autocompact_tick 1005
  [ "$(submit_count)" = 0 ] || fail "non-empty composer must defer /compact"

  # 3. Unknown composer defers
  FAKE_COMPOSER_STATE=unknown
  agy_autocompact_tick 1010
  [ "$(submit_count)" = 0 ] || fail "unknown composer state must defer /compact"

  # 4. Dead or unknown agent defers
  FAKE_COMPOSER_STATE=empty
  FAKE_AGENT_STATE=dead
  agy_autocompact_tick 1015
  [ "$(submit_count)" = 0 ] || fail "dead agent must not receive /compact"

  FAKE_AGENT_STATE=unknown
  agy_autocompact_tick 1017
  [ "$(submit_count)" = 0 ] || fail "unknown agent_state must defer /compact"

  # 5. Idle + alive + empty composer retries and succeeds on next tick
  FAKE_AGENT_STATE=alive
  agy_autocompact_tick 1020
  [ "$(submit_count)" = 1 ] || fail "deferred event did not retry and succeed once idle and empty"
  pass "watcher gates on idle, alive, and exact empty composer, deferring and retrying on next tick"
}

test_watcher_rate_limiting() {
  reset_watcher_case
  touch "$CONFIG/agy-autocompact"
  write_agy_meta task-rate ship "$WT_A"

  append_event task-rate agy "$WT_A"
  agy_autocompact_tick 1000
  [ "$(submit_count)" = 1 ] || fail "initial compaction failed"

  # Within 10 minutes (599s later): rate-limited
  append_event task-rate agy "$WT_A"
  agy_autocompact_tick 1599
  [ "$(submit_count)" = 1 ] || fail "compaction within 10-minute cooldown must be rate-limited"

  # At 10 minutes (600s later): allowed again
  append_event task-rate agy "$WT_A"
  agy_autocompact_tick 1600
  [ "$(submit_count)" = 2 ] || fail "compaction after 10-minute cooldown should succeed"
  pass "watcher rate-limits compaction to at most once per task per 10 minutes"
}

test_teardown_cleans_agy_autocompact_artifacts() {
  local td_root="$TMP_ROOT/teardown-case"
  local home="$td_root/home" proj="$td_root/home/projects/proj" wt="$td_root/wt"
  local fakebin
  fakebin=$(fm_test_make_spawn_fakebin "$td_root/fake")
  fm_test_spawn_home "$home" agy
  fm_git_worktree "$proj" "$wt" "wt-td"
  printf 'backend=tmux\nwindow=firstmate:fm-td1\nharness=agy\nkind=ship\nmode=local-only\nyolo=off\nproject=proj\nworktree=%s\n' "$wt" > "$home/state/td1.meta"
  touch "$home/state/td1.compact-adviser.jsonl" \
    "$home/state/.agy-autocompact-offset-td1" \
    "$home/state/.agy-autocompact-last-td1"
  local td_out
  td_out=$( ( cd "$home/projects" && PATH="$fakebin:$PATH" FM_ROOT_OVERRIDE='' FM_HOME="$home" \
    FM_STATE_OVERRIDE="$home/state" FM_CONFIG_OVERRIDE="$home/config" \
    FM_DATA_OVERRIDE="$home/data" FM_PROJECTS_OVERRIDE="$home/projects" \
    HOME="$td_root/user-home" \
    bash "$ROOT/bin/fm-teardown.sh" td1 ) 2>&1) || fail "fm-teardown.sh failed: $td_out"
  [ ! -e "$home/state/td1.compact-adviser.jsonl" ] \
    || fail "teardown did not remove compact-adviser.jsonl"
  [ ! -e "$home/state/.agy-autocompact-offset-td1" ] \
    || fail "teardown did not remove .agy-autocompact-offset"
  [ ! -e "$home/state/.agy-autocompact-last-td1" ] \
    || fail "teardown did not remove .agy-autocompact-last"
  pass "fm-teardown cleans up compact-adviser event file and watcher markers"
}

test_watcher_opt_in_default_off
test_watcher_mapping_and_exclusions
test_watcher_gating_and_deferral
test_watcher_rate_limiting
test_teardown_cleans_agy_autocompact_artifacts
