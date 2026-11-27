#!/usr/bin/env bash
# tests/fm-jev-monitoring.test.sh - portable tests for Jev monitoring (off/watch/act).
set -u
# shellcheck source=tests/lib.sh disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

TMP_ROOT=$(fm_test_tmproot fm-jev-monitoring-tests)
FAKEBIN="$TMP_ROOT/fakebin"
mkdir -p "$FAKEBIN"
export PATH="$FAKEBIN:$PATH"

# Unset any ambient TypeSafe vars so tests only ever use local stubs.
unset TYPESAFE_API_KEY TYPESAFE_BASE TYPESAFE_PATH TYPESAFE_MODEL

make_home() {
  local h
  h=$(mktemp -d "$TMP_ROOT/home.XXXXXX")
  mkdir -p "$h/config" "$h/state"
  printf '%s' "$h"
}

write_stub_curl() {
  local mode=${1:-ok_routine}
  local log_dir=${2:-$TMP_ROOT}
  cat > "$FAKEBIN/curl" <<CURL
#!/usr/bin/env bash
out=''
body=\$(cat)
printf '%s\n' "\$*" > "$log_dir/curl.argv"
printf '%s\n' "\$body" > "$log_dir/curl.body"
env > "$log_dir/curl.env"
if [ -r /dev/fd/3 ]; then
  cat <&3 > "$log_dir/curl.fd3" 2>/dev/null || true
fi
while [ \$# -gt 0 ]; do
  case "\$1" in
    -o) out="\$2"; shift 2 ;;
    *) shift ;;
  esac
done
case "$mode" in
  ok_routine)
    printf '{"answers":{"classification":{"type":"choice","choice":"routine","confidence":0.97,"probabilities":{"routine":0.97,"needs-firstmate":0.03}}}}' > "\$out"
    printf '200'
    ;;
  ok_routine_95)
    printf '{"answers":{"classification":{"type":"choice","choice":"routine","confidence":0.95,"probabilities":{"routine":0.95,"needs-firstmate":0.05}}}}' > "\$out"
    printf '200'
    ;;
  ok_routine_94)
    printf '{"answers":{"classification":{"type":"choice","choice":"routine","confidence":0.94,"probabilities":{"routine":0.94,"needs-firstmate":0.06}}}}' > "\$out"
    printf '200'
    ;;
  ok_needs)
    printf '{"answers":{"classification":{"type":"choice","choice":"needs-firstmate","confidence":0.98,"probabilities":{"routine":0.02,"needs-firstmate":0.98}}}}' > "\$out"
    printf '200'
    ;;
  ok_mlx)
    printf '{"answers":{"classification":{"type":"choice","choice":"captain-relevant","confidence":0.9,"probabilities":{"captain-relevant":0.9,"not-captain-relevant":0.1}}}}' > "\$out"
    printf '200'
    ;;
  slow)
    exit 28
    ;;
  down)
    exit 7
    ;;
  http_500)
    printf '{"error":"internal"}' > "\$out"
    printf '500'
    ;;
  bad_key_401)
    printf '{"error":"unauthorized"}' > "\$out"
    printf '401'
    ;;
  bad_key_403)
    printf '{"error":"forbidden"}' > "\$out"
    printf '403'
    ;;
  no_credit_402)
    printf '{"error":"payment_required"}' > "\$out"
    printf '402'
    ;;
  no_credit_429)
    printf '{"error":"rate_limit"}' > "\$out"
    printf '429'
    ;;
  odd_json)
    printf 'not-json' > "\$out"
    printf '200'
    ;;
  odd_choice)
    printf '{"answers":{"classification":{"type":"choice","choice":"banana","confidence":0.99}}}' > "\$out"
    printf '200'
    ;;
  odd_conf)
    printf '{"answers":{"classification":{"type":"choice","choice":"routine","confidence":1.5}}}' > "\$out"
    printf '200'
    ;;
esac
CURL
  chmod +x "$FAKEBIN/curl"
}

# ---- 1. Absent setting: byte-identical behavior & no Jev calls ---------------
H1=$(make_home)
export FM_HOME="$H1"
export FM_CONFIG_OVERRIDE="$H1/config"
export FM_STATE_OVERRIDE="$H1/state"
rm -f "$TMP_ROOT/curl.argv"
write_stub_curl ok_routine "$TMP_ROOT"

. "$ROOT/bin/fm-classify-lib.sh"
[ "$(fm_jev_mode)" = "off" ] || fail "absent jev-monitoring did not return off"
status_is_captain_relevant "working: compiling modules" && fail "absent: working should not be captain-relevant"
status_is_captain_relevant "done: shipped" || fail "absent: done should be captain-relevant"
[ ! -e "$TMP_ROOT/curl.argv" ] || fail "absent setting called curl"
[ ! -e "$H1/state/jev-watch.jsonl" ] || fail "absent setting created jev-watch.jsonl"

# mlx mode must ignore TYPESAFE_PATH and always use /v1/systemone
write_stub_curl ok_mlx "$TMP_ROOT"
cat > "$H1/.env" <<'ENV'
TYPESAFE_BASE=http://127.0.0.1:11234
TYPESAFE_PATH=/v1/hosted-custom
TYPESAFE_API_KEY=local-mlx-serve
ENV
"$ROOT/bin/fm-decision-api.sh" --context "done: shipped" >/dev/null || fail "mlx mode failed"
grep -q 'http://127.0.0.1:11234/v1/systemone' "$TMP_ROOT/curl.argv" || fail "mlx mode did not use /v1/systemone: $(cat "$TMP_ROOT/curl.argv")"
! grep -q '/v1/hosted-custom' "$TMP_ROOT/curl.argv" || fail "mlx mode wrongly honored TYPESAFE_PATH"
rm -f "$H1/.env" "$TMP_ROOT/curl.argv"
pass "absent setting keeps existing behavior and makes no Jev calls"

# ---- 2. Setting values and invalid notice once -------------------------------
printf 'watch\n' > "$H1/config/jev-monitoring"
[ "$(fm_jev_mode)" = "watch" ] || fail "watch setting not read"
printf 'act\n' > "$H1/config/jev-monitoring"
[ "$(fm_jev_mode)" = "act" ] || fail "act setting not read"
printf 'off\n' > "$H1/config/jev-monitoring"
[ "$(fm_jev_mode)" = "off" ] || fail "off setting not read"

printf 'bogus-mode\n' > "$H1/config/jev-monitoring"
err1=$(fm_jev_mode 2>&1 >/dev/null)
[ -n "$err1" ] || fail "invalid setting did not emit first notice"
[ "$(fm_jev_mode 2>/dev/null)" = "off" ] || fail "invalid setting did not behave as off"
err2=$(fm_jev_mode 2>&1 >/dev/null)
[ -z "$err2" ] || fail "invalid setting repeated notice: $err2"
pass "setting values off/watch/act and invalid value behaves as off with one notice"

# ---- 3. Key containment, TYPESAFE_BASE/PATH, minimal payload -----------------
H2=$(make_home)
export FM_HOME="$H2"
export FM_CONFIG_OVERRIDE="$H2/config"
export FM_STATE_OVERRIDE="$H2/state"
cat > "$H2/.env" <<'ENV'
TYPESAFE_BASE=http://127.0.0.1:19999
TYPESAFE_PATH=/v1/custom-jev
TYPESAFE_API_KEY=stub-secret-key-do-not-leak
ENV
rm -f "$TMP_ROOT/curl.argv" "$TMP_ROOT/curl.body" "$TMP_ROOT/curl.env" "$TMP_ROOT/curl.fd3"
write_stub_curl ok_routine "$TMP_ROOT"

out=$("$ROOT/bin/fm-decision-api.sh" --mode jev --job "task-123" --status-line "working: running tests") || fail "fm-decision-api --mode jev failed"
echo "$out" | jq -e '.choice == "routine" and .confidence == 0.97 and (.latency_ms | type) == "number"' >/dev/null || fail "unexpected output: $out"
! grep -q 'stub-secret-key-do-not-leak' "$TMP_ROOT/curl.argv" || fail "key leaked into curl argv"
! grep -q 'stub-secret-key-do-not-leak' "$TMP_ROOT/curl.env" || fail "key leaked into curl child env"
grep -q 'Authorization: Bearer stub-secret-key-do-not-leak' "$TMP_ROOT/curl.fd3" || fail "key not passed on fd 3"
grep -q 'http://127.0.0.1:19999/v1/custom-jev' "$TMP_ROOT/curl.argv" || fail "TYPESAFE_BASE/PATH not used"
jq -e '.state.job == "task-123" and .state.status_line == "working: running tests" and ((.state | keys | sort) == ["job", "status_line"])' "$TMP_ROOT/curl.body" >/dev/null || fail "payload leaked extra fields: $(cat "$TMP_ROOT/curl.body")"
pass "key stays off argv/env/logs, TYPESAFE_BASE/PATH honored, only job and status_line sent"

# ---- 4. Protected kinds never sent -------------------------------------------
printf 'watch\n' > "$H2/config/jev-monitoring"
export FM_JEV_WATCH_SYNC=1
for protected in \
  "blocked: waiting on credentials" \
  "needs-decision [key=q1]: pick A or B" \
  "failed: build broke" \
  "done: shipped" \
  "PR ready https://example.invalid/pull/1" \
  "checks green" \
  "ready in branch fm/test" \
  "merged" \
  "captain-held: waiting"; do
  rm -f "$TMP_ROOT/curl.argv"
  fm_jev_watch_evaluate "task-p" "needs-firstmate" "$protected"
  [ ! -e "$TMP_ROOT/curl.argv" ] || fail "protected line was sent to Jev: $protected"
done
fm_jev_is_protected_wake check "check: pr-register" "" || fail "check wake not protected"
fm_jev_is_protected_wake signal "needs-decision: f" "working: x" || fail "needs-decision wake not protected"
pass "protected kinds (blockers, decisions, failures, done, PR/merge, check) are never sent"

# ---- 5. Redaction & dispatch-never-send --------------------------------------
printf 'secret-project-codename\n' > "$H2/config/dispatch-never-send"
for sensitive in \
  "working: check https://internal.example.com/path" \
  "working: token sk-abc1234567890xyz" \
  "working: ghp_1234567890abcdef" \
  "working: api_key=mysecretvalue" \
  "working: please login to dashboard" \
  "working: user alice@example.com signed in" \
  "working: building secret-project-codename"; do
  rm -f "$TMP_ROOT/curl.argv"
  fm_jev_watch_evaluate "task-r" "routine" "$sensitive"
  [ ! -e "$TMP_ROOT/curl.argv" ] || fail "sensitive line was sent to Jev: $sensitive"
done
! grep -q 'sk-abc1234567890xyz' "$H2/state/jev-watch.jsonl" || fail "sensitive token leaked into watch log"
! grep -q 'secret-project-codename' "$H2/state/jev-watch.jsonl" || fail "never-send phrase leaked into watch log"
pass "redaction and dispatch-never-send keep links, keys, logins, and blocked terms local"

# ---- 6. Every fallback row ---------------------------------------------------
rm -f "$H2/config/dispatch-never-send"
for stub_mode in slow down http_500 bad_key_401 bad_key_403 no_credit_402 no_credit_429 odd_json odd_choice odd_conf; do
  rm -f "$H2/state/jev-circuit.json"
  write_stub_curl "$stub_mode" "$TMP_ROOT"
  if "$ROOT/bin/fm-decision-api.sh" --mode jev --job "t" --status-line "working: step 1" >/dev/null 2>&1; then
    fail "fallback mode $stub_mode unexpectedly succeeded"
  fi
done
pass "every fallback row (slow, down, 500, 401, 403, 402, 429, odd JSON/choice/conf) fails open"

# ---- 7. 3-failure circuit breaker pause (30 min) and resume ------------------
H3=$(make_home)
export FM_HOME="$H3"
export FM_CONFIG_OVERRIDE="$H3/config"
export FM_STATE_OVERRIDE="$H3/state"
cat > "$H3/.env" <<'ENV'
TYPESAFE_BASE=http://127.0.0.1:19999
TYPESAFE_API_KEY=stub-key
ENV
printf 'watch\n' > "$H3/config/jev-monitoring"
write_stub_curl slow "$TMP_ROOT"

export FM_JEV_NOW_OVERRIDE=1000000
fm_jev_watch_evaluate "t1" "routine" "working: 1"
fm_jev_watch_evaluate "t1" "routine" "working: 2"
fm_jev_watch_evaluate "t1" "routine" "working: 3"
[ "$(jq -r '.failures' "$H3/state/jev-circuit.json")" = "3" ] || fail "circuit failures did not reach 3"
[ "$(jq -r '.paused_until' "$H3/state/jev-circuit.json")" = "1001800" ] || fail "circuit paused_until not +1800s"

# Within 30 minutes: skipped without calling curl
rm -f "$TMP_ROOT/curl.argv"
export FM_JEV_NOW_OVERRIDE=1001799
fm_jev_watch_evaluate "t1" "routine" "working: 4"
[ ! -e "$TMP_ROOT/curl.argv" ] || fail "circuit open still called curl"
tail -n 1 "$H3/state/jev-watch.jsonl" | jq -e '.jev_label == "skipped_circuit"' >/dev/null || fail "watch log did not record skipped_circuit"

# After 30 minutes: retried and reset on success
write_stub_curl ok_routine "$TMP_ROOT"
export FM_JEV_NOW_OVERRIDE=1001800
fm_jev_watch_evaluate "t1" "routine" "working: 5"
[ -e "$TMP_ROOT/curl.argv" ] || fail "circuit did not retry after 30 minutes"
[ "$(jq -r '.failures' "$H3/state/jev-circuit.json")" = "0" ] || fail "circuit failures did not reset on recovery"
unset FM_JEV_NOW_OVERRIDE
pass "3-failure circuit breaker pauses 30 minutes then retries and resets"

# ---- 8. Watch log bounded size & fm-jev-report.sh ----------------------------
H4=$(make_home)
export FM_HOME="$H4"
export FM_CONFIG_OVERRIDE="$H4/config"
export FM_STATE_OVERRIDE="$H4/state"
cat > "$H4/.env" <<'ENV'
TYPESAFE_BASE=http://127.0.0.1:19999
TYPESAFE_API_KEY=stub-key
ENV
printf 'watch\n' > "$H4/config/jev-monitoring"
write_stub_curl ok_routine "$TMP_ROOT"
fm_jev_watch_evaluate "job-a" "routine" "working: running lint"
fm_jev_watch_evaluate "job-b" "needs-firstmate" "working: waiting on peer"
write_stub_curl ok_needs "$TMP_ROOT"
fm_jev_watch_evaluate "job-c" "needs-firstmate" "working: unclear spec"

report=$("$ROOT/bin/fm-jev-report.sh")
echo "$report" | grep -q 'total entries: 3' || fail "report missing total entries: $report"
echo "$report" | grep -q 'jev routine: 2, needs-firstmate: 1' || fail "report missing jev counts: $report"
echo "$report" | grep -q 'potential savings.*: 1' || fail "report missing potential savings: $report"
echo "$report" | grep -q '\[job-b\].*waiting on peer' || fail "report missing missed candidate job-b: $report"

# Bounded size trim
FM_JEV_WATCH_MAX_BYTES=300 FM_JEV_WATCH_KEEP_LINES=2 fm_jev_watch_evaluate "job-d" "routine" "working: trim test"
lines=$(wc -l < "$H4/state/jev-watch.jsonl" | tr -d ' ')
[ "$lines" -le 2 ] || fail "watch log did not trim to bounded size (lines=$lines)"

# status_is_captain_relevant must NOT dispatch Jev in watch mode
rm -f "$TMP_ROOT/curl.argv"
status_is_captain_relevant "working: classifier must not call jev" && fail "working should not be captain-relevant"
[ ! -e "$TMP_ROOT/curl.argv" ] || fail "status_is_captain_relevant wrongly dispatched Jev in watch mode"

# Deduplicate per task and exact status line
rm -f "$TMP_ROOT/curl.argv"
fm_jev_watch_evaluate "job-dedup" "routine" "working: exact same line"
[ -e "$TMP_ROOT/curl.argv" ] || fail "first watch evaluation did not call curl"
rm -f "$TMP_ROOT/curl.argv"
fm_jev_watch_evaluate "job-dedup" "routine" "working: exact same line"
[ ! -e "$TMP_ROOT/curl.argv" ] || fail "duplicate (task, status_line) was evaluated twice"

# Bound concurrent background watch evaluations
mkdir -p "$H4/state/.jev-watch-pids"
sleep 2 &
bg_pid=$!
printf '%s\n' "$bg_pid" > "$H4/state/.jev-watch-pids/$bg_pid"
rm -f "$TMP_ROOT/curl.argv"
FM_JEV_WATCH_MAX_CONCURRENT=1 FM_JEV_WATCH_SYNC=0 fm_jev_watch_dispatch "job-cap" "routine" "working: concurrency capped"
wait 2>/dev/null || true
[ ! -e "$TMP_ROOT/curl.argv" ] || fail "watch dispatch exceeded concurrency bound"
pass "watch mode logs bounded JSONL and fm-jev-report.sh summarizes counts and disagreements"

# ---- 9. Act mode: 95% confidence boundary ------------------------------------
H5=$(make_home)
export FM_HOME="$H5"
export FM_CONFIG_OVERRIDE="$H5/config"
export FM_STATE_OVERRIDE="$H5/state"
cat > "$H5/.env" <<'ENV'
TYPESAFE_BASE=http://127.0.0.1:19999
TYPESAFE_API_KEY=stub-key
ENV
printf 'act\n' > "$H5/config/jev-monitoring"

write_stub_curl ok_routine_94 "$TMP_ROOT"
if fm_jev_act_evaluate "task-94" "signal" "signal: task-94.status" "working: step 1" 0; then
  fail "routine at 0.94 was wrongly suppressed"
fi
[ ! -s "$H5/state/jev-suppressed.jsonl" ] || fail "0.94 wrote a suppressed record"

write_stub_curl ok_needs "$TMP_ROOT"
if fm_jev_act_evaluate "task-nf" "signal" "signal: task-nf.status" "working: step 2" 0; then
  fail "needs-firstmate was wrongly suppressed"
fi

write_stub_curl ok_routine_95 "$TMP_ROOT"
fm_jev_act_evaluate "task-95" "signal" "signal: task-95.status" "working: step 3" 42 \
  || fail "routine at 0.95 was not suppressed"
[ -s "$H5/state/jev-suppressed.jsonl" ] || fail "0.95 did not record before suppressing"
jq -e '.task == "task-95" and .confidence == 0.95 and .drained == false' "$H5/state/jev-suppressed.jsonl" >/dev/null \
  || fail "suppressed record missing expected fields"
pass "95% confidence boundary: >=0.95 routine suppresses, <0.95 and needs-firstmate wake"

# ---- 10. Crash after record -> next drain; fail-open if record fails ---------
# Simulate crash after fm_jev_act_evaluate recorded (no wake-queue row written).
# Create a dummy fm-guard.sh / fm-wake-drain dependencies? Use fm-wake-drain.sh directly!
drain_out=$(FM_HOME="$H5" FM_CONFIG_OVERRIDE="$H5/config" FM_STATE_OVERRIDE="$H5/state" \
  FM_NO_MISTAKES_OFF=1 "$ROOT/bin/fm-wake-drain.sh" 2>/dev/null || true)
echo "$drain_out" | grep -q 'JEV MONITORING, SUPPRESSED ROUTINE' || fail "next drain did not show suppressed row: $drain_out"
echo "$drain_out" | grep -q 'task-95: working: step 3' || fail "next drain missing task-95 detail: $drain_out"
drain_out2=$(FM_HOME="$H5" FM_CONFIG_OVERRIDE="$H5/config" FM_STATE_OVERRIDE="$H5/state" \
  FM_NO_MISTAKES_OFF=1 "$ROOT/bin/fm-wake-drain.sh" 2>/dev/null || true)
if echo "$drain_out2" | grep -q 'JEV MONITORING, SUPPRESSED ROUTINE'; then
  fail "second drain repeated already-shown suppressed row"
fi

# Unwritable store -> must NOT suppress
H5B=$(make_home)
export FM_HOME="$H5B"
export FM_CONFIG_OVERRIDE="$H5B/config"
export FM_STATE_OVERRIDE="$H5B/state"
cat > "$H5B/.env" <<'ENV'
TYPESAFE_BASE=http://127.0.0.1:19999
TYPESAFE_API_KEY=stub-key
ENV
printf 'act\n' > "$H5B/config/jev-monitoring"
mkdir -p "$H5B/state/jev-suppressed.jsonl"
write_stub_curl ok_routine "$TMP_ROOT"
if fm_jev_act_evaluate "task-unwritable" "signal" "signal: task-unwritable.status" "working: step" 0; then
  fail "suppressed even though record-before-suppress failed"
fi
pass "record-before-suppress surfaces in next drain after crash and never suppresses on write failure"

# ---- 11. Protected kinds never suppressed in act mode ------------------------
export FM_HOME="$H5"
export FM_CONFIG_OVERRIDE="$H5/config"
export FM_STATE_OVERRIDE="$H5/state"
rm -f "$TMP_ROOT/curl.argv"
for prot_line in "blocked: stuck" "needs-decision [key=x]: choose" "failed: err" "done: ok" "PR ready"; do
  if fm_jev_act_evaluate "task-prot" "signal" "signal: task-prot.status" "$prot_line" 0; then
    fail "protected line suppressed in act mode: $prot_line"
  fi
done
if fm_jev_act_evaluate "task-prot" "check" "check: pr-register" "working: ok" 0; then
  fail "check wake suppressed in act mode"
fi
if fm_jev_act_evaluate "task-prot" "stale" "stale: s:0 (idle 240s, possible wedge, escalation 1)" "working: ok" 0; then
  fail "stuck-worker wedge alarm suppressed in act mode"
fi
[ ! -e "$TMP_ROOT/curl.argv" ] || fail "act mode called curl for a protected kind"
pass "act mode never sends or suppresses protected kinds or stuck-worker alarms"

# ---- 12. Missed-blocker auto-off (span-covered vs later genuine blocker) ----
H6=$(make_home)
export FM_HOME="$H6"
export FM_CONFIG_OVERRIDE="$H6/config"
export FM_STATE_OVERRIDE="$H6/state"
cat > "$H6/.env" <<'ENV'
TYPESAFE_BASE=http://127.0.0.1:19999
TYPESAFE_API_KEY=stub-key
ENV
printf 'act\n' > "$H6/config/jev-monitoring"
write_stub_curl ok_routine "$TMP_ROOT"

printf 'working: doing fine\n' > "$H6/state/task-auto.status"
offset_before=$(wc -c < "$H6/state/task-auto.status" | tr -d ' ')
fm_jev_act_evaluate "task-auto" "signal" "signal: task-auto.status" "working: doing fine" 0 \
  || fail "setup suppression for task-auto failed"
recorded_offset=$(jq -r '.status_offset' "$H6/state/jev-suppressed.jsonl")
[ "$recorded_offset" = "$offset_before" ] || fail "expected real status_offset=$offset_before, got $recorded_offset"

# A later genuine blocker appended AFTER the suppressed row (offset > recorded_offset) must NOT turn auto-off on
printf 'blocked: genuine new blocker\n' >> "$H6/state/task-auto.status"
offset_after=$(wc -c < "$H6/state/task-auto.status" | tr -d ' ')
if fm_jev_check_missed_blocker "task-auto" "full-check" "$offset_after"; then
  fail "auto-off wrongly triggered on a newer event beyond suppressed row's offset"
fi
[ "$(cat "$H6/config/jev-monitoring")" = "act" ] || fail "config/jev-monitoring turned off for uncovered newer event"

# An event covered by the suppressed row's span (event_offset <= recorded_offset) MUST trigger auto-off
fm_jev_check_missed_blocker "task-auto" "full-check" "$offset_before" || fail "auto-off did not trigger on covered missed blocker"
[ "$(cat "$H6/config/jev-monitoring")" = "off" ] || fail "config/jev-monitoring not durably switched to off"
[ "$(fm_jev_mode)" = "off" ] || fail "fm_jev_mode did not report off after auto-off"
if fm_jev_check_missed_blocker "task-auto" "full-check" "$offset_before"; then
  fail "auto-off re-triggered when already off"
fi
rm -f "$TMP_ROOT/curl.argv"
if fm_jev_act_evaluate "task-other" "signal" "signal: task-other.status" "working: step" 0; then
  fail "act mode still suppressed after auto-off"
fi
[ ! -e "$TMP_ROOT/curl.argv" ] || fail "curl called after auto-off"
pass "missed-blocker auto-off checks span offset and durably switches jev-monitoring to off"

# ---- 13. Multi-file signal: evaluate all before recording --------------------
H7=$(make_home)
export FM_HOME="$H7"
export FM_CONFIG_OVERRIDE="$H7/config"
export FM_STATE_OVERRIDE="$H7/state"
cat > "$H7/.env" <<'ENV'
TYPESAFE_BASE=http://127.0.0.1:19999
TYPESAFE_API_KEY=stub-key
ENV
printf 'act\n' > "$H7/config/jev-monitoring"
printf 'working: step 1\n' > "$H7/state/task-m1.status"
printf 'working: step 2\n' > "$H7/state/task-m2.status"

# Stub curl: first call returns routine 0.97, second call returns needs-firstmate
rm -f "$TMP_ROOT/seq_count"
cat > "$FAKEBIN/curl" <<CURL
#!/usr/bin/env bash
out=''
while [ \$# -gt 0 ]; do
  case "\$1" in
    -o) out="\$2"; shift 2 ;;
    *) shift ;;
  esac
done
n=\$(cat "$TMP_ROOT/seq_count" 2>/dev/null || echo 0)
n=\$((n + 1))
printf '%s' "\$n" > "$TMP_ROOT/seq_count"
if [ "\$n" -eq 1 ]; then
  printf '{"answers":{"classification":{"type":"choice","choice":"routine","confidence":0.97,"probabilities":{"routine":0.97,"needs-firstmate":0.03}}}}' > "\$out"
else
  printf '{"answers":{"classification":{"type":"choice","choice":"needs-firstmate","confidence":0.98,"probabilities":{"routine":0.02,"needs-firstmate":0.98}}}}' > "\$out"
fi
printf '200'
CURL
chmod +x "$FAKEBIN/curl"

pending_batch=$(printf 'sf1\tsig1\t%s/state/task-m1.status\nsf2\tsig2\t%s/state/task-m2.status\n' "$H7" "$H7")
if fm_jev_act_signal_batch "$pending_batch" "signal: task-m1.status task-m2.status"; then
  fail "multi-file batch suppressed when second file needed firstmate"
fi
[ ! -s "$H7/state/jev-suppressed.jsonl" ] || fail "first task was recorded as suppressed even though batch woke firstmate"

# Both routine >= 0.95 -> both recorded and batch suppressed
write_stub_curl ok_routine "$TMP_ROOT"
fm_jev_act_signal_batch "$pending_batch" "signal: task-m1.status task-m2.status" \
  || fail "multi-file batch did not suppress when all files were routine >= 0.95"
[ "$(wc -l < "$H7/state/jev-suppressed.jsonl" | tr -d ' ')" = "2" ] || fail "both tasks should be recorded when batch suppresses"
pass "multi-file signal evaluates all before recording and records nothing on wake"
