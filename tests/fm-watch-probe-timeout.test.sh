#!/usr/bin/env bash
# tests/fm-watch-probe-timeout.test.sh - a hung remote or process-event probe
# must not stop the watcher's liveness beacon (bin/fm-watch.sh).
#
# The beacon is touched at the top of every poll, so any foreground probe that
# never returns freezes it and the supervision cycle looks dead. Two probes ran
# unbounded in the cycle: the remote secondmate endpoint probe (SSH through
# bin/fm-on.sh) and the per-cycle process-event reconcile. Both now carry a hard
# wall-clock bound, and fm-on.sh arms an SSH connect timeout.
set -u

# shellcheck source=tests/watch-triage-helpers.sh
. "$(dirname "${BASH_SOURCE[0]}")/watch-triage-helpers.sh"

TMP_ROOT=$(fm_test_tmproot fm-watch-probe-timeout)

test_hung_remote_secondmate_probe_keeps_the_beacon_beating() {
  local dir state fakebin out pid wake
  dir=$(make_case hung-remote-probe)
  state="$dir/state"; fakebin="$dir/fakebin"; out="$dir/watch.out"
  mkdir -p "$dir/data" "$dir/config"
  cat > "$state/rsm1.meta" <<EOF
window=remote:rsm1
kind=secondmate
harness=claude
remote_host=lab-host
remote_backend=herdr
remote_herdr_session=fm-remote
remote_target=fm-remote:w1:p1
home=/remote/rsm1-home
EOF
  cat > "$dir/data/secondmates.md" <<EOF
- rsm1 - Remote mate (host: lab-host; root: /remote/root; home: /remote/rsm1-home; scope: remote work; projects: alpha; added 2026-01-01)
EOF
  # An SSH peer that accepts the connection and never answers.
  cat > "$fakebin/ssh" <<'SH'
#!/usr/bin/env bash
printf 'called\n' >> "${FM_FAKE_SSH_LOG:?}"
exec sleep 120
SH
  chmod +x "$fakebin/ssh"
  watch_bg "$state" "$fakebin" "$out" env FM_HOME="$dir" FM_ROOT_OVERRIDE="$ROOT" FM_DATA_OVERRIDE="$dir/data" \
    FM_SSH_BIN="$fakebin/ssh" FM_FAKE_SSH_LOG="$dir/ssh.log" \
    FM_SECONDMATE_LIVENESS_SECS=1 FM_SECONDMATE_LIVENESS_PROBE_SECS=1
  pid=$!
  wait_poll_cycle "$state" "$pid" 200 \
    || { reap "$pid"; fail "a hung remote secondmate probe froze the watcher beacon: $(cat "$out")"; }
  [ -s "$dir/ssh.log" ] || { reap "$pid"; fail "the remote probe never ran, so the case proves nothing: $(tail -3 "$state/.watch-triage.log")"; }
  wake=$(cat "$state/.wake-queue" 2>/dev/null || true)
  reap "$pid"
  case "$wake" in *relaunch*) fail "a timed-out probe was read as a dead endpoint: $wake" ;; esac
  pass "a remote secondmate probe that hangs is bounded and the beacon keeps beating"
}

test_hung_procevent_reconcile_keeps_the_beacon_beating() {
  local dir state fakebin out root pid
  dir=$(make_case hung-procevent)
  state="$dir/state"; fakebin="$dir/fakebin"; out="$dir/watch.out"
  root="$dir/root"
  mkdir -p "$root" "$state/procevent"
  cp -R "$ROOT/bin" "$root/bin"
  printf '#!/usr/bin/env bash\n: >> "%s/reconcile.log"\nexec sleep 120\n' "$dir" > "$root/bin/fm-procevent.sh"
  chmod +x "$root/bin/fm-procevent.sh"
  PATH="$fakebin:$PATH" FM_STATE_OVERRIDE="$state" FM_CREW_STATE_BIN="$fakebin/fm-crew-state.sh" \
    FM_POLL=1 FM_SIGNAL_GRACE=1 FM_CHECK_INTERVAL=999999 FM_HEARTBEAT=999999 \
    FM_SECONDMATE_LIVENESS_SECS=99999999 FM_PROCEVENT_RECONCILE_SECS=1 \
    "$root/bin/fm-watch.sh" > "$out" 2>&1 &
  pid=$!
  wait_poll_cycle "$state" "$pid" 200 \
    || { reap "$pid"; fail "a hung process-event reconcile froze the watcher beacon: $(cat "$out")"; }
  [ -e "$dir/reconcile.log" ] || { reap "$pid"; fail "the reconcile never ran, so the case proves nothing"; }
  reap "$pid"
  pass "a process-event reconcile that hangs is bounded and the beacon keeps beating"
}

if [ -n "${FM_TEST_ONLY:-}" ]; then
  "$FM_TEST_ONLY"
  exit 0
fi

fm_test_run \
  test_hung_remote_secondmate_probe_keeps_the_beacon_beating \
  test_hung_procevent_reconcile_keeps_the_beacon_beating
