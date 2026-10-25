#!/usr/bin/env bash
# tests/fm-spawn-chrome-idle-timeout.test.sh - every agent this fleet launches
# must start with a bounded chrome-devtools-axi bridge lifetime in its
# environment, so a browser chain a worker abandons cannot outlive its session.
#
# The assertions never read bin/fm-spawn.sh's source. They drive the real spawn
# against a fake pane and a real isolated git worktree, then EXECUTE the launch
# command the pane actually received, under a synthetic pane environment, with
# the harness binary replaced by a probe that prints the environment it was
# started with. What the probe prints is what a real agent would have received.
set -u

# shellcheck source=tests/fixtures.sh
. "$(dirname "${BASH_SOURCE[0]}")/fixtures.sh"

TMP_ROOT=$(fm_test_tmproot fm-spawn-chrome-idle-timeout)

BOUND=1800000
# A synthetic pane value the launch must override rather than inherit: the bound
# is a floor, so a pane that already carries a different value still has to
# start its agent on this one.
CONTRARY=1

# make_case <name> <harness> <id>...
# Echoes "<case-dir>|<home>|<project>|<worktree>|<fakebin>|<launch-log>|<pane-log>".
make_case() {
  local name=$1 harness=$2 case_dir home proj wt fakebin launchlog panelog id
  shift 2
  case_dir="$TMP_ROOT/$name"
  home="$case_dir/home"
  proj="$case_dir/project"
  wt="$case_dir/wt"
  launchlog="$case_dir/launch.log"
  panelog="$case_dir/pane.log"
  fakebin=$(fm_test_make_spawn_fakebin "$case_dir/fake")
  fm_test_spawn_home "$home" "$harness"
  fm_git_worktree "$proj" "$wt" "wt-$name"
  for id in "$@"; do
    fm_test_spawn_brief "$home" "$id"
  done
  printf '%s\n' "$case_dir|$home|$proj|$wt|$fakebin|$launchlog|$panelog"
}

read_case() {
  IFS='|' read -r CASE_DIR HOME_DIR PROJ_DIR WT_DIR FAKEBIN_DIR LAUNCH_LOG PANE_LOG <<EOF
$1
EOF
}

run_case_spawn() {
  : > "$LAUNCH_LOG"
  : > "$PANE_LOG"
  FM_FAKE_LAUNCH_LOG="$LAUNCH_LOG" FM_FAKE_PANE_LOG="$PANE_LOG" \
    fm_test_run_spawn "$HOME_DIR" "$WT_DIR" "$FAKEBIN_DIR" "$@"
}

# Replace the harness binary with a probe that reports the single environment
# fact under test.
install_env_probe() {  # <fakebin> <harness> [variable]
  cat > "$1/$2" <<SH
#!/bin/sh
printf '%s\n' "\${${3:-CHROME_DEVTOOLS_AXI_IDLE_TIMEOUT_MS}-unset}"
SH
  chmod +x "$1/$2"
}

# Run the emitted launch command in a synthetic pane shell that carries a
# contrary value, so a launch that merely forwarded the ambient environment
# would be caught here rather than reported as a pass.
#   emitted_launch_env <fakebin> <launch-log> <pane-log>
emitted_launch_env() {
  local fakebin=$1 launchlog=$2 panelog=$3 launch preamble
  launch=$(cat "$launchlog")
  preamble=$(grep '^export ' "$panelog")
  env -i HOME="$TMP_ROOT/pane-home" PATH="$fakebin:$PATH" TERM=xterm \
    TMUX=synthetic-pane CHROME_DEVTOOLS_AXI_IDLE_TIMEOUT_MS="$CONTRARY" \
    /bin/sh -c "$preamble
$launch"
}

pane_export_lines() { grep -c "^export CHROME_DEVTOOLS_AXI_IDLE_TIMEOUT_MS=$BOUND\$" "$1" || true; }

assert_pane_export_rides_prelaunch_site() {  # <pane-log> <label>
  local panelog=$1 label=$2 gotmp bound
  [ "$(pane_export_lines "$panelog")" = 1 ] \
    || fail "$label: the pane shell should receive exactly one browser-lifetime export, got $(pane_export_lines "$panelog")"
  gotmp=$(grep -n '^export GOTMPDIR=' "$panelog" | tail -1 | cut -d: -f1)
  bound=$(grep -n "^export CHROME_DEVTOOLS_AXI_IDLE_TIMEOUT_MS=$BOUND\$" "$panelog" | tail -1 | cut -d: -f1)
  [ -n "$gotmp" ] && [ -n "$bound" ] \
    || fail "$label: the pane log is missing the pre-launch exports"
  [ "$bound" -gt "$gotmp" ] \
    || fail "$label: the browser-lifetime export must ride the GOTMPDIR pre-launch site (gotmp=$gotmp bound=$bound)"
}

test_launch_bounds_the_lifetime() {
  local setting rec out status seen launch
  for setting in absent enabled; do
    rec=$(make_case "ship-$setting" codex "ship-$setting-a1")
    read_case "$rec"
    [ "$setting" = absent ] || : > "$HOME_DIR/config/launch-env-allowlist"
    out=$(run_case_spawn "ship-$setting-a1" "$PROJ_DIR" --mode no-mistakes --yolo off)
    status=$?
    expect_code 0 "$status" "allowlist=$setting spawn should succeed: $out"
    assert_pane_export_rides_prelaunch_site "$PANE_LOG" "allowlist=$setting"
    install_env_probe "$FAKEBIN_DIR" codex
    seen=$(emitted_launch_env "$FAKEBIN_DIR" "$LAUNCH_LOG" "$PANE_LOG") \
      || fail "allowlist=$setting: the emitted launch failed to run"
    assert_equals "$BOUND" "$seen" \
      "allowlist=$setting: a launched worker must start with a bounded browser-automation lifetime"
    launch=$(cat "$LAUNCH_LOG")
    if [ "$setting" = enabled ]; then
      assert_contains "$launch" '/usr/bin/env -i' \
        "an enabled allowlist should launch under a cleared environment"
    fi
  done
  pass "a launch bounds the browser-automation lifetime, with and without the cleared-environment allowlist"
}

# The floor must not depend on the pane export having landed: a pane whose
# export was lost still has to launch its agent on the bound.
test_launch_command_carries_the_bound_alone() {
  local harness rec out status seen launch
  for harness in codex claude; do
    rec=$(make_case "ship-nopane-$harness" "$harness" "ship-nopane-$harness-a1")
    read_case "$rec"
    out=$(run_case_spawn "ship-nopane-$harness-a1" "$PROJ_DIR" --mode no-mistakes --yolo off)
    status=$?
    expect_code 0 "$status" "$harness spawn should succeed: $out"
    install_env_probe "$FAKEBIN_DIR" "$harness"
    launch=$(cat "$LAUNCH_LOG")
    seen=$(env -i HOME="$TMP_ROOT/pane-home" PATH="$FAKEBIN_DIR:$PATH" TERM=xterm \
      TMUX=synthetic-pane CHROME_DEVTOOLS_AXI_IDLE_TIMEOUT_MS="$CONTRARY" \
      /bin/sh -c "$launch") \
      || fail "$harness: the emitted launch failed to run without the pane exports"
    assert_equals "$BOUND" "$seen" \
      "$harness: the launch command alone must set a bounded browser-automation lifetime, overriding a contrary pane value"
  done
  pass "the launch command carries the browser-automation bound on its own, across harness prefix shapes"
}

test_launch_bounds_the_lifetime
test_launch_command_carries_the_bound_alone
echo 'fm-spawn-chrome-idle-timeout: PASS'
