# Live evidence (real bin scripts, isolated mktemp homes, fake terminal backend)
1. Usage limit: tests/fm-watch-triage-pause.test.sh -> ok "a worker stopped at a usage limit wakes once with its reset time and the same-account relaunch; quoted text does not"; ok phrasing recognizer.
2. Superseded wait: ok "declared waits surface unreported gates and terminal runs once..."; ok "cached supersession verdict is invalidated when the status signature changes"; throttle ok.
3. Coalescing: tests/fm-branch-supervision.test.sh (exit 0) -> ok "unchanged routine repeats are stored silent with a repeat count; changes and captain rows stay visible"; ok "report command does not relay a coalesced repeat".
Logs: watch-pause.log, watch-pause-rerun.log, branch-supervision.log in this directory.
Note: requested path under ~/Documents/workspace/firstmate is outside the worktree boundary, so evidence is written here.
