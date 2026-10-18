#!/usr/bin/env bash
# Behavior tests for bin/fm-model-preflight.sh - the free-model-axi launch gate -
# and its bin/fm-spawn.sh wiring (gap: the model chosen for a worker was not
# health-checked before dispatch).
#
# The advisor is driven through its public CLI contract (a fake
# `free-model-axi` on PATH or via FM_FREE_MODEL_AXI emitting canned
# `models --json`), so these tests pin the behavior a real advisor exposes:
# an unhealthy recorded probe refuses with the exact evidence and the healthiest
# alternative, a stale snapshot warns with its exact age but proceeds, an absent
# advisor or unknown model tolerates, a spawn stops before any record or launch
# when the gate refuses, and nothing ever switches the model.
set -u

# shellcheck source=tests/fixtures.sh
. "$(dirname "${BASH_SOURCE[0]}")/fixtures.sh"

PREFLIGHT="$ROOT/bin/fm-model-preflight.sh"
TMP_ROOT=$(fm_test_tmproot fm-model-preflight)

# write_snapshot <json-file> <synced-at-epoch> <stale-true|false> <model-json-rows>
write_snapshot() {
  local file=$1 synced=$2 stale=$3 rows=$4 tmp
  tmp="$file.tmp"
  cat > "$tmp" <<EOF
{
  "as_of": {"age": "1h ago", "local_time": "now", "stale": $stale},
  "models": [
$rows
  ]
}
EOF
  sed "s/NOWVAL/$synced/g" "$tmp" > "$file" && rm -f "$tmp"
}

# write_advisor <path-to-executable> <snapshot-json-file-or-GARBAGE>
# A fake free-model-axi honoring the real CLI shape: `models --json` prints the
# snapshot; anything else exits 0.
write_advisor() {
  local tool=$1 payload=$2
  cat > "$tool" <<SH
#!/usr/bin/env bash
case "\${1:-}" in
  models) cat "$payload" ;;
  *) exit 0 ;;
esac
SH
  chmod +x "$tool"
}

run_preflight() { # <tool-or-empty> <model> -> stdout+stderr captured in $out, rc in $status
  local tool=$1 model=$2
  status=0
  out=$(FM_FREE_MODEL_AXI="$tool" bash "$PREFLIGHT" "$model" 2>&1) || status=$?
}

test_absent_advisor_proceeds_silently() {
  run_preflight "" "vendor/some-model"
  expect_code 0 "$status" "an explicitly absent advisor must not block dispatch"
  [ -z "$out" ] || fail "an absent advisor must be silent, got: $out"
  pass "an absent free-model-axi tolerates every model"
}

test_unknown_model_proceeds_silently() {
  local tool="$TMP_ROOT/tool-unknown"
  write_snapshot "$TMP_ROOT/snap-unknown.json" "$(date +%s)" false \
    '{"model":"vendor/listed-model","provider":"vendor","health_status":"unchecked","healthy":null,"checked_age":"never","evidence":"none","rate_limit_event":null,"auth_error":null,"ready":true,"latency_ms":null,"latency_display":"not probed","synced_at":NOWVAL}'
  write_advisor "$tool" "$TMP_ROOT/snap-unknown.json"
  run_preflight "$tool" "vendor/not-in-the-snapshot"
  expect_code 0 "$status" "a model the advisor does not know must not block dispatch"
  [ -z "$out" ] || fail "an unknown model must be silent, got: $out"
  pass "a model the snapshot does not know is tolerated"
}

test_fresh_healthy_probe_proceeds_silently() {
  local tool="$TMP_ROOT/tool-healthy"
  write_snapshot "$TMP_ROOT/snap-healthy.json" "$(date +%s)" false \
    '{"model":"vendor/good-model","provider":"vendor","health_status":"healthy","healthy":true,"checked_age":"1h ago","evidence":"probe","rate_limit_event":null,"auth_error":null,"ready":true,"latency_ms":950,"latency_display":"950ms","synced_at":NOWVAL}'
  write_advisor "$tool" "$TMP_ROOT/snap-healthy.json"
  run_preflight "$tool" "vendor/good-model"
  expect_code 0 "$status" "a fresh healthy probe must dispatch"
  [ -z "$out" ] || fail "a fresh healthy probe must be silent, got: $out"
  pass "a fresh healthy probe launches without noise"
}

test_stale_snapshot_warns_with_exact_age_and_proceeds() {
  local tool="$TMP_ROOT/tool-stale" synced
  synced=$(( $(date +%s) - 90000 ))
  write_snapshot "$TMP_ROOT/snap-stale.json" "$synced" true \
    '{"model":"vendor/good-model","provider":"vendor","health_status":"unchecked","healthy":null,"checked_age":"never","evidence":"none","rate_limit_event":null,"auth_error":null,"ready":true,"latency_ms":null,"latency_display":"not probed","synced_at":'"$synced"'}'
  write_advisor "$tool" "$TMP_ROOT/snap-stale.json"
  run_preflight "$tool" "vendor/good-model"
  expect_code 0 "$status" "a stale snapshot must warn, not refuse"
  assert_contains "$out" "warning:" "the stale warning must say what it is"
  printf '%s' "$out" | grep -Eq 'snapshot is 900(0[0-9]|1[0-5])s old' \
    || fail "the stale warning must carry the exact snapshot age, got: $out"
  assert_contains "$out" "bound 86400s" "the stale warning must name the bound it measured against"
  assert_contains "$out" "as_of.stale=true" "the stale warning must carry the advisor's own freshness flag"
  assert_contains "$out" "free-model-axi sync" "the stale warning must name the refresh command"
  pass "a stale snapshot warns with the exact age and still dispatches"
}

test_unhealthy_probe_refuses_with_exact_reason_and_alternative() {
  local tool="$TMP_ROOT/tool-unhealthy"
  write_snapshot "$TMP_ROOT/snap-unhealthy.json" "$(date +%s)" false \
    '{"model":"vendor/bad-model","provider":"vendor","health_status":"unhealthy","healthy":false,"checked_age":"15h ago","evidence":"model-id-free-marker","rate_limit_event":"unavailable","auth_error":null,"ready":true,"latency_ms":2880,"latency_display":"2880ms","synced_at":NOWVAL}
, {"model":"vendor/good-model","provider":"vendor","health_status":"healthy","healthy":true,"checked_age":"30m ago","evidence":"probe","rate_limit_event":null,"auth_error":null,"ready":true,"latency_ms":950,"latency_display":"950ms","synced_at":NOWVAL}'
  write_advisor "$tool" "$TMP_ROOT/snap-unhealthy.json"
  run_preflight "$tool" "vendor/bad-model"
  expect_code 1 "$status" "an unhealthy recorded probe must refuse the launch"
  assert_contains "$out" "REFUSED for vendor/bad-model" "the refusal must name the model"
  assert_contains "$out" "health_status=unhealthy" "the refusal must carry health_status verbatim"
  assert_contains "$out" "checked_age=15h ago" "the refusal must carry checked_age verbatim"
  assert_contains "$out" "evidence=model-id-free-marker" "the refusal must carry the probe evidence verbatim"
  assert_contains "$out" "rate_limit_event=unavailable" "the refusal must carry the rate-limit event verbatim"
  assert_contains "$out" "healthiest alternative: vendor/good-model" "the refusal must name the healthiest alternative"
  assert_contains "$out" "950ms" "the alternative must carry its own latency evidence"
  assert_contains "$out" "only the captain chooses models" "the refusal must leave the model choice to the captain"
  pass "an unhealthy probe refuses with exact evidence, the alternative, and the captain's authority"
}

test_unreadable_snapshot_is_tolerated_with_a_notice() {
  local tool="$TMP_ROOT/tool-broken"
  printf 'not json at all\n' > "$TMP_ROOT/snap-broken.json"
  write_advisor "$tool" "$TMP_ROOT/snap-broken.json"
  run_preflight "$tool" "vendor/good-model"
  expect_code 0 "$status" "an unreadable snapshot must not block dispatch"
  assert_contains "$out" "no readable model snapshot" "an unreadable snapshot must say so"
  pass "an unreadable snapshot tolerates with a named notice"
}

# --- spawn wiring ------------------------------------------------------------

make_spawn_world() { # <name> <task-id> -> case|home|proj|wt|fakebin|launchlog
  local name=$1 id=$2 case_dir home proj wt fakebin launchlog
  case_dir="$TMP_ROOT/spawn-$name"
  home="$case_dir/home"
  proj="$case_dir/project"
  wt="$case_dir/wt"
  launchlog="$case_dir/launch.log"
  fakebin=$(fm_fakebin "$case_dir")
  fm_test_fake_tmux_spawn "$fakebin"
  fm_fake_exit0 "$fakebin" treehouse
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
  printf '%s\n' "$case_dir|$home|$proj|$wt|$fakebin|$launchlog"
}

run_world_spawn() { # <home> <wt> <fakebin> <launchlog> [args...]
  local home=$1 wt=$2 fakebin=$3 launchlog=$4
  shift 4
  : > "$launchlog"
  status=0
  out=$(FM_FAKE_LAUNCH_LOG="$launchlog" CLAUDE_CONFIG_DIR='' \
    fm_test_run_spawn "$home" "$wt" "$fakebin" "$@") || status=$?
}

test_spawn_launches_on_a_healthy_probe() {
  local rec home proj wt fakebin launchlog id
  id=healthy-spawn-z1
  rec=$(make_spawn_world healthy "$id")
  IFS='|' read -r _ home proj wt fakebin launchlog <<<"$rec"
  write_snapshot "$TMP_ROOT/snap-spawn-healthy.json" "$(date +%s)" false \
    '{"model":"vendor/good-model","provider":"vendor","health_status":"healthy","healthy":true,"checked_age":"1h ago","evidence":"probe","rate_limit_event":null,"auth_error":null,"ready":true,"latency_ms":950,"latency_display":"950ms","synced_at":NOWVAL}'
  write_advisor "$fakebin/free-model-axi" "$TMP_ROOT/snap-spawn-healthy.json"
  run_world_spawn "$home" "$wt" "$fakebin" "$launchlog" "$id" "$proj" \
    --mode no-mistakes --yolo off --harness pi --model vendor/good-model
  expect_code 0 "$status" "a healthy probe must let spawn launch"$'\n'"$out"
  assert_contains "$out" "spawned $id harness=pi" "spawn must report success"
  assert_grep "model=vendor/good-model" "$home/state/$id.meta" "spawn must record the chosen model unchanged"
  [ -s "$launchlog" ] || fail "the healthy case must actually launch (launch log empty)"
  pass "spawn launches when the recorded probe is healthy"
}

test_spawn_refuses_an_unhealthy_probe_before_launch() {
  local rec home proj wt fakebin launchlog id
  id=unhealthy-spawn-z1
  rec=$(make_spawn_world unhealthy "$id")
  IFS='|' read -r _ home proj wt fakebin launchlog <<<"$rec"
  write_snapshot "$TMP_ROOT/snap-spawn-unhealthy.json" "$(date +%s)" false \
    '{"model":"vendor/bad-model","provider":"vendor","health_status":"unhealthy","healthy":false,"checked_age":"15h ago","evidence":"model-id-free-marker","rate_limit_event":"unavailable","auth_error":null,"ready":true,"latency_ms":2880,"latency_display":"2880ms","synced_at":NOWVAL}
, {"model":"vendor/good-model","provider":"vendor","health_status":"healthy","healthy":true,"checked_age":"30m ago","evidence":"probe","rate_limit_event":null,"auth_error":null,"ready":true,"latency_ms":950,"latency_display":"950ms","synced_at":NOWVAL}'
  write_advisor "$fakebin/free-model-axi" "$TMP_ROOT/snap-spawn-unhealthy.json"
  run_world_spawn "$home" "$wt" "$fakebin" "$launchlog" "$id" "$proj" \
    --mode no-mistakes --yolo off --harness pi --model vendor/bad-model
  [ "$status" -ne 0 ] || fail "spawn must refuse an unhealthy recorded probe"$'\n'"$out"
  assert_contains "$out" "REFUSED for vendor/bad-model" "spawn must surface the gate's exact reason"
  assert_contains "$out" "healthiest alternative: vendor/good-model" "spawn must surface the named alternative"
  assert_absent "$home/state/$id.meta" "a refused launch must publish no task record"
  [ -s "$launchlog" ] && fail "a refused launch must send nothing to the pane: $(cat "$launchlog")"
  pass "spawn refuses an unhealthy probe before any record or launch"
}

test_absent_advisor_at_spawn_still_launches() {
  local rec home proj wt fakebin launchlog id
  id=absent-advisor-z1
  rec=$(make_spawn_world absent "$id")
  IFS='|' read -r _ home proj wt fakebin launchlog <<<"$rec"
  # FM_FREE_MODEL_AXI='' is the visible pin for "no advisor" - on a host that
  # really has free-model-axi installed, PATH alone cannot prove absence from a
  # fixture, and the unit cases above already cover a genuinely absent binary.
  status=0
  out=$(FM_FREE_MODEL_AXI='' FM_FAKE_LAUNCH_LOG="$launchlog" CLAUDE_CONFIG_DIR='' \
    fm_test_run_spawn "$home" "$wt" "$fakebin" "$id" "$proj" \
    --mode no-mistakes --yolo off --harness pi --model vendor/anything 2>&1) || status=$?
  expect_code 0 "$status" "an explicitly absent advisor must not block spawn"$'\n'"$out"
  assert_contains "$out" "spawned $id harness=pi" "spawn must report success with the advisor off"
  pass "spawn tolerates the advisor being absent"
}

test_absent_advisor_proceeds_silently
test_unknown_model_proceeds_silently
test_fresh_healthy_probe_proceeds_silently
test_stale_snapshot_warns_with_exact_age_and_proceeds
test_unhealthy_probe_refuses_with_exact_reason_and_alternative
test_unreadable_snapshot_is_tolerated_with_a_notice
test_spawn_launches_on_a_healthy_probe
test_spawn_refuses_an_unhealthy_probe_before_launch
test_absent_advisor_at_spawn_still_launches