#!/usr/bin/env bash
set -u
. /Users/kayisrahman/.no-mistakes/worktrees/e322667d68a7/01M6XWX1FZFZXEVWF80BN131D9/tests/lib.sh
ROOT=/Users/kayisrahman/.no-mistakes/worktrees/e322667d68a7/01M6XWX1FZFZXEVWF80BN131D9
HERDR_LAB_HELPER=$ROOT/bin/fm-herdr-lab.sh
LAB_HOME_HELPER=$ROOT/bin/fm-lab-home.sh
TASK_TMP=$(mktemp -d "${TMPDIR:-/tmp}/fm-pig-debug.XXXXXX")
export FM_HERDR_LAB_STATE_DIR="$TASK_TMP/herdr-state"
HERDR_LAB_SESSION=$("$HERDR_LAB_HELPER" name firstmate-pig-primary-live-verify-v1)
FM_HOME=$("$LAB_HOME_HELPER" create "$TASK_TMP/fmhome")
LAB_TMUX_DIR=$("$LAB_HOME_HELPER" tmux-dir "$FM_HOME")
PANE=; WORKSPACE=; TAB=
"$HERDR_LAB_HELPER" provision "$HERDR_LAB_SESSION"
lab() { "$HERDR_LAB_HELPER" run "$HERDR_LAB_SESSION" "$@"; }
created=$(lab workspace create --cwd "$ROOT" --label pig-debug --no-focus)
PANE=$(printf '%s' "$created" | jq -er '.result.root_pane.pane_id')
WORKSPACE=$(printf '%s' "$created" | jq -er '.result.workspace.workspace_id')
TAB=$(printf '%s' "$created" | jq -er '.result.root_pane.tab_id')
echo "PANE=$PANE WORKSPACE=$WORKSPACE TAB=$TAB FM_HOME=$FM_HOME"
PIG_CMD=$(printf 'env FM_HOME=%q FM_ROOT_OVERRIDE=%q FM_GATE_REFUSE_BYPASS=1 FM_PIG_HARNESS=pig FM_POLL=1 FM_SIGNAL_GRACE=0 FM_HEARTBEAT=600 FM_WATCH_REARM_RETRY_BASE_MS=60000 FM_WATCH_REARM_RETRY_MAX_MS=60000 pig --approve --no-context-files --model %s --thinking medium -e .pi/extensions/fm-branch-supervision.ts' "$FM_HOME" "$ROOT" openai-codex/gpt-6-luna)
lab pane run "$PANE" "$PIG_CMD" >/dev/null
"$HERDR_LAB_HELPER" viewer start "$HERDR_LAB_SESSION" >/dev/null
echo "$PANE" > "$TASK_TMP/pane"
echo "$FM_HOME" > "$TASK_TMP/home"
echo "$HERDR_LAB_SESSION" > "$TASK_TMP/session"
echo "$WORKSPACE" > "$TASK_TMP/ws"
echo "$TAB" > "$TASK_TMP/tab"
echo "$LAB_TMUX_DIR" > "$TASK_TMP/tmux"
echo "$TASK_TMP" > "$TASK_TMP/path"
