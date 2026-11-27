#!/usr/bin/env bash
# tests/fm-supervision-events.test.sh - unit tests for the watcher's native
# event-wait splice (event_wait_or_sleep in bin/fm-watch.sh and
# handle_push_transition in bin/fm-push-transition-lib.sh). The watcher's source
# guard lets this file source it to load
# the functions WITHOUT acquiring the singleton lock or entering the blocking
# loop; wake/sleep and the backend dispatchers are overridden so the exemptions,
# capability memo, and fail-closed disable are asserted deterministically with no
# real herdr, watcher process, or blocking sleeps.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

TMP=$(fm_test_tmproot fm-supervision-events)
STATE_DIR="$TMP/state"
mkdir -p "$STATE_DIR"

# Source the watcher with an isolated state/home. The guard returns before the
# lock/loop, so only the functions load.
export FM_STATE_OVERRIDE="$STATE_DIR"
export FM_ROOT_OVERRIDE="$ROOT"
# Production modules are independently linted canonical roots. Keep this test's
# ShellCheck context local while preserving its unchanged runtime source path.
# shellcheck source=/dev/null
. "$ROOT/bin/fm-watch.sh"

# Overrides: capture wake reasons and neutralize real sleeps (POLL is 15s).
WAKE_LOG="$TMP/wakes"
SLEEP_LOG="$TMP/sleeps"
wake() { printf '%s\n' "$1" >> "$WAKE_LOG"; return 0; }
sleep() { printf 'SLEEP %s\n' "${1:-}" >> "$SLEEP_LOG"; }

reset_state() {
  rm -f "$STATE_DIR"/*.meta "$STATE_DIR"/*.status "$STATE_DIR"/.wake-queue \
    "$STATE_DIR"/.wake-queue.seq "$STATE_DIR"/.watch-triage.log \
    "$STATE_DIR"/.herdr-escalated-* "$TMP"/panes "$TMP"/wtcalls "$TMP"/wtcalled 2>/dev/null || true
  : > "$WAKE_LOG"
  : > "$SLEEP_LOG"
  _event_cap_key=""
  _event_cap_ok=0
  _event_cap_fails=0
}

mkrec() {  # <pane_id> <status>
  fm_transition_record "$1" "wG" "" "$2" claude
}

# --- handle_push_transition: enqueue + wake for a non-paused blocked crew -----

reset_state
fm_write_meta "$STATE_DIR/tk1.meta" "window=default:wG:pQ" "backend=herdr" "kind=ship"
handle_push_transition herdr default "$(mkrec wG:pQ blocked)"
[ -e "$STATE_DIR/.wake-queue" ] || fail "handle_push_transition should enqueue a wake for a blocked crew"
grep -q 'stale' "$STATE_DIR/.wake-queue" || fail "the enqueued wake must be a stale record: $(cat "$STATE_DIR/.wake-queue")"
grep -q 'default:wG:pQ' "$STATE_DIR/.wake-queue" || fail "the stale record must name the crew's window"
grep -q 'herdr: agent blocked' "$STATE_DIR/.wake-queue" || fail "the stale payload must name the herdr-blocked cause"
[ -s "$WAKE_LOG" ] || fail "handle_push_transition must wake the supervisor for a blocked crew"
[ -e "$STATE_DIR/.herdr-escalated-default_wG_pQ" ] || fail "handle_push_transition must commit dedupe only after enqueue"
pass "handle_push_transition: a blocked crew enqueues a stale wake naming its window and wakes the supervisor"

reset_state
rm -f "$STATE_DIR"/.rex-escalated-* 2>/dev/null || true
fm_write_meta "$STATE_DIR/tk1.meta" "window=0a1b-c2:3d4e-f5" "backend=rex" "kind=ship"
handle_push_transition rex 0a1b-c2 "$(fm_transition_record 3d4e-f5 "" "" blocked claude-code "permission: Allow Bash: rm -rf build")"
grep -q 'stale	0a1b-c2:3d4e-f5' "$STATE_DIR/.wake-queue" || fail "a rex push must name the task's recorded window: $(cat "$STATE_DIR/.wake-queue")"
grep -q 'rex: agent blocked (permission: Allow Bash: rm -rf build) - waiting on human' "$STATE_DIR/.wake-queue" \
  || fail "the stale payload must name rex and carry the blocked kind and message: $(cat "$STATE_DIR/.wake-queue")"
[ -e "$STATE_DIR/.rex-escalated-0a1b-c2_3d4e-f5" ] || fail "the rex dedupe marker must be committed after enqueue"
pass "handle_push_transition: a rex blocked edge's wake names the backend and carries Rex's blocked kind and message"

reset_state
fm_write_meta "$STATE_DIR/tk1.meta" "window=default:wG:pQ" "backend=herdr" "kind=ship"
(
  # shellcheck disable=SC2329 # Runtime override called by the isolated production owner.
  fm_wake_append() { return 1; }
  handle_push_transition herdr default "$(mkrec wG:pQ blocked)"
) >/dev/null 2>&1 || true
[ ! -e "$STATE_DIR/.herdr-escalated-default_wG_pQ" ] || fail "a failed durable enqueue must leave the blocked edge eligible for reconnect reconciliation"
pass "handle_push_transition: enqueue failure cannot commit the Herdr dedupe marker"

# --- handle_push_transition: absorb (no wake, no enqueue) for a declared pause -

reset_state
fm_write_meta "$STATE_DIR/tk2.meta" "window=default:wG:pQ" "backend=herdr" "kind=ship"
printf 'paused: waiting on the upstream release\n' > "$STATE_DIR/tk2.status"
handle_push_transition herdr default "$(mkrec wG:pQ blocked)"
if [ -e "$STATE_DIR/.wake-queue" ] && grep -q 'stale' "$STATE_DIR/.wake-queue"; then
  fail "a declared-pause crew must NOT be fast-escalated: $(cat "$STATE_DIR/.wake-queue")"
fi
[ ! -s "$WAKE_LOG" ] || fail "a declared-pause crew must not wake the supervisor from the event fast-path"
grep -q 'absorbed push' "$STATE_DIR/.watch-triage.log" 2>/dev/null || fail "the paused absorb should be logged to the triage log"
pass "handle_push_transition: a declared-pause crew is absorbed (no fast wake), left to the poll loop's long cadence"

# --- handle_push_transition: absorb for a verified captain-held transfer -------

reset_state
fm_write_meta "$STATE_DIR/tk2h.meta" "window=default:wG:pQ" "backend=herdr" "kind=ship"
printf 'captain-held [key=route]: tracked by task-decision-route\n' > "$STATE_DIR/tk2h.status"
handle_push_transition herdr default "$(mkrec wG:pQ blocked)"
if [ -e "$STATE_DIR/.wake-queue" ] && grep -q 'stale' "$STATE_DIR/.wake-queue"; then
  fail "a captain-held crew must NOT be fast-escalated: $(cat "$STATE_DIR/.wake-queue")"
fi
[ ! -s "$WAKE_LOG" ] || fail "a captain-held crew must not wake the supervisor from the event fast-path"
grep -q 'absorbed push' "$STATE_DIR/.watch-triage.log" 2>/dev/null || fail "the captain-held absorb should be logged to the triage log"
pass "handle_push_transition: a captain-held crew is absorbed (no fast wake), left to the poll loop's long cadence"

# --- event_wait_or_sleep: secondmate windows are excluded from the pane list --

reset_state
fm_write_meta "$STATE_DIR/tk3.meta" "window=default:wG:pQ" "backend=herdr" "kind=ship"
fm_write_meta "$STATE_DIR/sm1.meta" "window=default:wA:pS" "backend=herdr" "kind=secondmate"
# shellcheck disable=SC2329 # Runtime overrides called by the isolated watcher.
fm_backend_events_capable() { return 0; }
# shellcheck disable=SC2329 # Runtime overrides called by the isolated watcher.
fm_backend_wait_transition() { shift 4; printf '%s\n' "$*" > "$TMP/panes"; return 1; }
event_wait_or_sleep
PANES=$(cat "$TMP/panes" 2>/dev/null || true)
case "$PANES" in *"default:wG:pQ"*) : ;; *) fail "the ship window must be in the event pane list, got '$PANES'" ;; esac
case "$PANES" in *"default:wA:pS"*) fail "a kind=secondmate window must be EXCLUDED from the event pane list, got '$PANES'" ;; *) : ;; esac
pass "event_wait_or_sleep: herdr windows go on the event pane list, but kind=secondmate endpoints are excluded"

# --- event_wait_or_sleep: a T3 task never takes herdr's fast path away -------

reset_state
fm_write_meta "$STATE_DIR/api-fix.meta" "window=fm-api-fix" "backend=t3code" "t3_thread_id=mcp:thread-api" "kind=ship"
fm_write_meta "$STATE_DIR/web-ui.meta" "window=default:wG:pQ" "backend=herdr" "kind=ship"
# shellcheck disable=SC2329 # Runtime overrides called by the isolated watcher.
fm_backend_events_capable() { return 0; }
# shellcheck disable=SC2329 # Runtime overrides called by the isolated watcher.
fm_backend_wait_transition() { printf '%s %s\n' "$1" "$*" > "$TMP/panes"; return 1; }
event_wait_or_sleep
PANES=$(cat "$TMP/panes" 2>/dev/null || true)
case "$PANES" in "herdr "*"default:wG:pQ"*) : ;; *) fail "a mixed home must keep herdr's push wait even when a T3 task sorts first, got '$PANES'" ;; esac
rm -f "$STATE_DIR/web-ui.meta" "$TMP/panes"
_event_cap_key=""
event_wait_or_sleep
PANES=$(cat "$TMP/panes" 2>/dev/null || true)
case "$PANES" in "t3code "*) : ;; *) fail "a T3-only home must use T3's bounded wait, got '$PANES'" ;; esac
pass "event_wait_or_sleep: herdr keeps the push wait in a mixed home; T3's wait runs only without another push backend"

reset_state
fm_write_meta "$STATE_DIR/tk3.meta" "window=default:wG:pQ" "backend=herdr" "kind=ship"
CAP_CALLS=0
# shellcheck disable=SC2329 # Runtime overrides called by the isolated watcher.
fm_backend_events_capable() { CAP_CALLS=$((CAP_CALLS + 1)); return 0; }
# shellcheck disable=SC2329 # Runtime overrides called by the isolated watcher.
fm_backend_wait_transition() {
  # The wait runs in its own process, so record what it saw for the assertion.
  printf '%s\n' "${FM_BACKEND_EVENTS_CAPABILITY_CONFIRMED:-0}" >> "$TMP/wtcalls"
  return 1
}
: > "$TMP/wtcalls"
event_wait_or_sleep
event_wait_or_sleep
[ "$CAP_CALLS" = 1 ] || fail "capability probe must be memoized across waits, got $CAP_CALLS calls"
[ "$(cat "$TMP/wtcalls")" = $'1\n1' ] || fail "cached capability verdict was not passed to each wait, got: $(cat "$TMP/wtcalls")"
pass "event_wait_or_sleep: one cached capability probe owns validation across bounded waits"

# --- event_wait_or_sleep: a tmux-only home never runs the event path ----------

reset_state
fm_write_meta "$STATE_DIR/tk4.meta" "window=fmses:fm-tk4" "kind=ship"   # no backend= -> tmux
# shellcheck disable=SC2329 # Runtime override called by the isolated watcher.
fm_backend_wait_transition() { printf 'CALLED\n' > "$TMP/wtcalled"; return 1; }
event_wait_or_sleep
[ ! -e "$TMP/wtcalled" ] || fail "a tmux-only home must never invoke the event wait path"
grep -q 'SLEEP' "$SLEEP_LOG" || fail "a tmux-only home must sleep POLL exactly as before"
pass "event_wait_or_sleep: a home with no push-capable window is inert (sleeps POLL, never touches the event path)"

# --- event_wait_or_sleep: runtime failures disable the event path (fail-closed)

reset_state
fm_write_meta "$STATE_DIR/tk5.meta" "window=default:wG:pQ" "backend=herdr" "kind=ship"
export EVENT_CAP_FAIL_MAX=2
# shellcheck disable=SC2329 # Runtime overrides called by the isolated watcher.
fm_backend_events_capable() { return 0; }
# shellcheck disable=SC2329 # Runtime overrides called by the isolated watcher.
fm_backend_wait_transition() { printf 'WT\n' >> "$TMP/wtcalls"; return 2; }
: > "$TMP/wtcalls"
event_wait_or_sleep   # fails=1
event_wait_or_sleep   # fails=2 -> disable
event_wait_or_sleep   # disabled: sleeps without calling wait_transition
WTN=$(wc -l < "$TMP/wtcalls" | tr -d '[:space:]')
[ "$WTN" = 2 ] || fail "after EVENT_CAP_FAIL_MAX connect failures the event path must be disabled for the process (expected 2 wait_transition calls, got $WTN)"
pass "event_wait_or_sleep: consecutive event-path failures disable the fast-path and revert to pure polling (fail-closed)"

# --- event_wait_or_sleep: mixed herdr+rex home waits on both; rex edge wakes ---

reset_state
fm_write_meta "$STATE_DIR/aa-herdr.meta" "window=default:wHV:p24" "backend=herdr" "kind=ship"
fm_write_meta "$STATE_DIR/bb-rex-s1.meta" "window=01a21afd-0001:blk-1111" "backend=rex" "kind=ship"
fm_write_meta "$STATE_DIR/cc-rex-s2.meta" "window=01a21ae4-0002:blk-2222" "backend=rex" "kind=ship"
fm_write_meta "$STATE_DIR/dd-sm.meta" "window=01a21afa-0003:blk-3333" "backend=rex" "kind=secondmate"
: > "$TMP/wtcalls"
# shellcheck disable=SC2329 # Runtime overrides called by the isolated watcher.
fm_backend_events_capable() { return 0; }
# shellcheck disable=SC2329 # Runtime overrides called by the isolated watcher.
fm_backend_wait_transition() {
  local b=$1 s=$2
  printf '%s:%s\n' "$b" "$s" >> "$TMP/wtcalls"
  if [ "$b" = rex ] && [ "$s" = "01a21ae4-0002" ]; then
    command sleep 0.2
    fm_transition_record "blk-2222" "" "" blocked claude-code "permission: Allow Bash: echo hi"
    return 0
  fi
  command sleep 2
  return 1
}
event_wait_or_sleep
grep -q '^herdr:default$' "$TMP/wtcalls" || fail "mixed home must wait on herdr:default: $(cat "$TMP/wtcalls")"
grep -q '^rex:01a21afd-0001$' "$TMP/wtcalls" || fail "mixed home must wait on rex session 1: $(cat "$TMP/wtcalls")"
grep -q '^rex:01a21ae4-0002$' "$TMP/wtcalls" || fail "mixed home must wait on rex session 2: $(cat "$TMP/wtcalls")"
if grep -q '01a21afa-0003' "$TMP/wtcalls"; then
  fail "secondmate rex endpoint must be excluded from event wait: $(cat "$TMP/wtcalls")"
fi
grep -q 'stale	01a21ae4-0002:blk-2222' "$STATE_DIR/.wake-queue" \
  || fail "rex blocked edge in mixed home must enqueue a stale wake: $(cat "$STATE_DIR/.wake-queue")"
[ -s "$WAKE_LOG" ] || fail "rex blocked edge in mixed home must wake the supervisor"
pass "event_wait_or_sleep: mixed herdr+rex home waits on herdr and multiple rex sessions, excluding secondmate, and wakes on rex edge"

# --- event_wait_or_sleep: failing herdr cannot disable push for rex -----------

reset_state
fm_write_meta "$STATE_DIR/aa-herdr.meta" "window=default:wHV:p24" "backend=herdr" "kind=ship"
fm_write_meta "$STATE_DIR/zz-rex.meta" "window=01a21afd-0001:blk-1111" "backend=rex" "kind=ship"
export EVENT_CAP_FAIL_MAX=2
: > "$TMP/wtcalls"
# shellcheck disable=SC2329 # Runtime overrides called by the isolated watcher.
fm_backend_events_capable() { return 0; }
# shellcheck disable=SC2329 # Runtime overrides called by the isolated watcher.
fm_backend_wait_transition() {
  local b=$1 s=$2
  printf '%s:%s\n' "$b" "$s" >> "$TMP/wtcalls"
  if [ "$b" = herdr ]; then
    return 2
  fi
  command sleep 0.1
  return 1
}
event_wait_or_sleep   # herdr fails=1, rex clean
event_wait_or_sleep   # herdr fails=2 -> herdr disabled, rex clean
event_wait_or_sleep   # herdr skipped, rex still active
HERDR_CALLS=$(grep -c '^herdr:default$' "$TMP/wtcalls" || true)
REX_CALLS=$(grep -c '^rex:01a21afd-0001$' "$TMP/wtcalls" || true)
[ "$HERDR_CALLS" = 2 ] || fail "herdr should be disabled after EVENT_CAP_FAIL_MAX=2 failures, got $HERDR_CALLS calls"
[ "$REX_CALLS" = 3 ] || fail "rex must remain active across all 3 cycles even after herdr fails, got $REX_CALLS calls"
if grep -q "^SLEEP ${POLL:-15}\$" "$SLEEP_LOG" 2>/dev/null; then
  fail "must not fall back to blind sleep while rex event wait is still running: $(cat "$SLEEP_LOG")"
fi
pass "event_wait_or_sleep: dead/failing herdr disables only herdr and keeps rex push active"

echo "# fm-supervision-events.test.sh: all assertions passed"
