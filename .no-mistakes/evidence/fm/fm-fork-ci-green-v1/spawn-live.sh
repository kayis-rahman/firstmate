#!/usr/bin/env bash
set -eu
ROOT=$PWD
LAB=$(mktemp -d .live-test/fm-lab.XXXXXX)
LOG=/Users/kayisrahman/.no-mistakes/evidence/01M7KH6C5G1XVHFRXS8H8NQ0BQ/live-spawn.txt
exec >"$LOG" 2>&1
bin/fm-lab-home.sh create "$LAB"
mkdir -p "$LAB/tmux" "$LAB/user" "$LAB/pool" "$LAB/project"
cleanup() { TMUX_TMPDIR="$LAB/tmux" tmux -L fm-lab kill-server 2>/dev/null || true; rm -rf "$LAB"; }
trap cleanup EXIT
export FM_HOME="$ROOT/$LAB" HOME="$ROOT/$LAB/user" XDG_CONFIG_HOME="$ROOT/$LAB/user/.config" XDG_DATA_HOME="$ROOT/$LAB/user/.local/share" TREEHOUSE_ROOT="$ROOT/$LAB/pool" CLAUDE_CONFIG_DIR="" FM_FREE_MODEL_AXI="" FM_SPAWN_NO_GUARD=1
unset FM_ROOT_OVERRIDE FM_STATE_OVERRIDE FM_DATA_OVERRIDE FM_CONFIG_OVERRIDE FM_PROJECTS_OVERRIDE
export TMUX_TMPDIR="$LAB/tmux"
env -u NO_MISTAKES_GATE -u FM_GATE_REFUSE_BYPASS -u FM_ROOT_OVERRIDE -u FM_STATE_OVERRIDE -u FM_DATA_OVERRIDE -u FM_CONFIG_OVERRIDE -u FM_PROJECTS_OVERRIDE tmux -L fm-lab new-session -d -x 120 -y 40 -s firstmate -c "$PWD" -e FM_HOME="$FM_HOME" claude
export TMUX=$(tmux -L fm-lab display-message -p -t firstmate '#{socket_path},#{pid},0')
git -C "$LAB/project" init -b main
git -C "$LAB/project" -c user.name=Test -c user.email=test@example.invalid commit --allow-empty -m fixture
mkdir -p "$LAB/data/browser-probe"
printf '# Task\n## Captain intent\nDo nothing, this is a disposable launch verification.\n## Firstmate spec\nDo not use tools.\n' >"$LAB/data/browser-probe/brief.md"
printf 'claude\n' >"$LAB/config/crew-harness"
touch "$LAB/state/.last-watcher-beat"
echo '$ bin/fm-spawn.sh browser-probe <disposable-project> --mode local-only --yolo off --harness claude --backend tmux'
bin/fm-spawn.sh browser-probe "$ROOT/$LAB/project" --mode local-only --yolo off --harness claude --backend tmux
sleep 3
tmux -L fm-lab list-windows -t firstmate
WINDOW=$(awk -F= '$1=="window" {print $2}' "$LAB/state/browser-probe.meta")
tmux -L fm-lab capture-pane -p -t "$WINDOW"
tmux -L fm-lab send-keys -t "$WINDOW" C-c
sleep 1
tmux -L fm-lab send-keys -t "$WINDOW" C-c
sleep 1
tmux -L fm-lab send-keys -t "$WINDOW" C-d
sleep 1
tmux -L fm-lab send-keys -t "$WINDOW" -l 'printf "LIVE_BROWSER_BOUND=%s CWD=%s\n" "$CHROME_DEVTOOLS_AXI_IDLE_TIMEOUT_MS" "$PWD"'
tmux -L fm-lab send-keys -t "$WINDOW" Enter
sleep 2
tmux -L fm-lab capture-pane -p -S -100 -t "$WINDOW"
