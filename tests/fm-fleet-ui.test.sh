#!/usr/bin/env bash
# tests/fm-fleet-ui.test.sh - the read-only fleet UI serves its page and live JSON.
set -u

# shellcheck source=tests/lib.sh
# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

command -v python3 >/dev/null 2>&1 || { echo "skip: python3 not found"; exit 0; }
command -v curl >/dev/null 2>&1 || { echo "skip: curl not found"; exit 0; }

TMP_ROOT=$(fm_test_tmproot fm-fleet-ui)
HOME_FIXTURE="$TMP_ROOT/home"
SERVER_PID=
SERVER_OUT="$TMP_ROOT/server.out"
SERVER_ERR="$TMP_ROOT/server.err"

cleanup() {
  if [ -n "$SERVER_PID" ]; then
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT
trap 'cleanup; exit 130' INT TERM

mkdir -p "$HOME_FIXTURE/state" "$HOME_FIXTURE/data" "$HOME_FIXTURE/config" "$HOME_FIXTURE/projects"
printf '# Backlog\n\n## In flight\n\n## Queued\n' > "$HOME_FIXTURE/data/backlog.md"
printf '# Captain preferences\n\n## Tone\n\nKeep it plain.\n' > "$HOME_FIXTURE/data/captain.md"
printf '# Learnings\n\n## Rail\n\nRead-only wins.\n' > "$HOME_FIXTURE/data/learnings.md"

FM_HOME="$HOME_FIXTURE" FM_ROOT="$ROOT" "$ROOT/bin/fm-fleet-ui.sh" --port 0 \
  > "$SERVER_OUT" 2> "$SERVER_ERR" &
SERVER_PID=$!

PORT=
for _ in $(seq 1 100); do
  if [ -s "$SERVER_OUT" ]; then
    PORT=$(sed -n 's|.*http://[^:]*:\([0-9][0-9]*\)/.*|\1|p' "$SERVER_OUT" | head -1)
    [ -n "$PORT" ] && break
  fi
  kill -0 "$SERVER_PID" 2>/dev/null || break
  sleep 0.1
done
if [ -z "$PORT" ]; then
  cat "$SERVER_ERR" >&2
  fail "fleet UI server did not report a listening port"
fi

BASE="http://127.0.0.1:$PORT"

INDEX_BODY=$(curl -fsS "$BASE/") || fail "GET / failed"
printf '%s' "$INDEX_BODY" | grep -q 'Firstmate Fleet' \
  || fail "GET / did not return the fleet page"

SNAPSHOT_FILE="$TMP_ROOT/snapshot.json"
curl -fsS "$BASE/api/snapshot" > "$SNAPSHOT_FILE" || fail "GET /api/snapshot failed"
python3 - "$SNAPSHOT_FILE" <<'PY' || fail "GET /api/snapshot was not valid fleet snapshot JSON"
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)
if payload.get("schema") != "fm-fleet-snapshot.v1":
    sys.exit("unexpected snapshot schema: %r" % (payload.get("schema"),))
if not isinstance(payload.get("tasks"), list):
    sys.exit("snapshot tasks is not a list")
PY

MEMORIES_FILE="$TMP_ROOT/memories.json"
curl -fsS "$BASE/api/memories" > "$MEMORIES_FILE" || fail "GET /api/memories failed"
python3 - "$MEMORIES_FILE" <<'PY' || fail "GET /api/memories was not valid captain-memory JSON"
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)
files = payload.get("files")
if not isinstance(files, list):
    sys.exit("memories files is not a list")
by_key = {row.get("key"): row for row in files}
captain = by_key.get("captain")
if captain is None or captain.get("present") is not True:
    sys.exit("captain preferences were not served")
if "Keep it plain." not in (captain.get("content") or ""):
    sys.exit("captain preferences content was not served")
if not isinstance(captain.get("mtime"), (int, float)):
    sys.exit("captain preferences mtime was not served")
PY

pass "fleet UI serves its page and live snapshot and memory JSON"
