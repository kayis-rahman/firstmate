#!/usr/bin/env bash
# tests/fm-fleet-ui.test.sh - the static fleet dashboard builds and serves read-only data.
#
# The dashboard is a static screen: bin/fm-fleet-ui.sh build writes plain JSON
# files plus a copy of assets/fleet-ui/index.html from the firstmate home, and
# serve hands that directory to python3 -m http.server. This test builds a
# fixture home, asserts the data files, and serves them on an ephemeral port.
set -u

# shellcheck source=tests/lib.sh
# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

command -v python3 >/dev/null 2>&1 || { echo "skip: python3 not found"; exit 0; }
command -v curl >/dev/null 2>&1 || { echo "skip: curl not found"; exit 0; }

unset FM_STATE_OVERRIDE FM_DATA_OVERRIDE FM_CONFIG_OVERRIDE

TMP_ROOT=$(fm_test_tmproot fm-fleet-ui)
HOME_FIXTURE="$TMP_ROOT/home"
OUT_DIR="$TMP_ROOT/out"
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
printf 'id=fixture-task\nkind=ship\nharness=pi\nbranch=fm/fixture\nmodel=free/test:free\neffort=low\n' \
  > "$HOME_FIXTURE/state/fixture-task.meta"
printf 'working [at=1792900000]: started\nneeds-decision [at=1792900100]: Choose A or B. Options: (a) do A (b) do B\n' \
  > "$HOME_FIXTURE/state/fixture-task.status"

FM_HOME="$HOME_FIXTURE" "$ROOT/bin/fm-fleet-ui.sh" build --out "$OUT_DIR" \
  > "$TMP_ROOT/build.out" 2> "$TMP_ROOT/build.err" \
  || { cat "$TMP_ROOT/build.err" >&2; fail "fleet UI build failed"; }

grep -q 'Firstmate Fleet' "$OUT_DIR/index.html" || fail "built page is missing the fleet title"

# The build reads only the fixture home and writes static files: a snapshot from
# the shared script, the captain memories, and one read-only review page per
# open decision.
python3 - "$OUT_DIR" "$HOME_FIXTURE" <<'PY' || fail "the built dashboard data was not valid"
import json
import os
import sys

out, home = sys.argv[1], sys.argv[2]


def load(name):
    with open(os.path.join(out, "data", name), encoding="utf-8") as handle:
        return json.load(handle)


snapshot = load("snapshot.json")
if snapshot.get("schema") != "fm-fleet-snapshot.v1":
    sys.exit("unexpected snapshot schema: %r" % (snapshot.get("schema"),))
if not isinstance(snapshot.get("tasks"), list):
    sys.exit("snapshot tasks is not a list: %r" % (snapshot.get("tasks"),))
if snapshot["tasks"][0].get("model") != "free/test:free":
    sys.exit("worker model was not read from the fixture home metadata")

meta = load("meta.json")
if meta.get("home") != home:
    sys.exit("meta home is %r, expected %r" % (meta.get("home"), home))
if not meta.get("generated"):
    sys.exit("meta generated stamp is missing")
if meta.get("errors"):
    sys.exit("build reported errors: %r" % (meta.get("errors"),))

memories = load("memories.json")
by_key = {row.get("key"): row for row in memories.get("files", [])}
captain = by_key.get("captain")
if captain is None or captain.get("present") is not True:
    sys.exit("captain preferences were not served")
if "Keep it plain." not in (captain.get("content") or ""):
    sys.exit("captain preferences content was not served")
if not isinstance(captain.get("mtime"), (int, float)):
    sys.exit("captain preferences mtime was not served")

decisions = load("decisions.json")
if decisions.get("count") != 1 or decisions.get("review_count") != 1:
    sys.exit("expected one open decision: %r" % (decisions.get("count"),))
row = decisions["decisions"][0]
review = row.get("review")
if not review:
    sys.exit("open decision has no review page")
review_path = os.path.join(out, review)
if not os.path.isfile(review_path):
    sys.exit("review page was not written: %s" % review_path)
page = open(review_path, encoding="utf-8").read()
if "Choose A or B" not in page:
    sys.exit("review page does not carry the decision question")
if "<input" in page or "<textarea" in page:
    sys.exit("review page must stay read-only")
PY

PORT=$(python3 - <<'PY'
import socket

sock = socket.socket()
sock.bind(("127.0.0.1", 0))
print(sock.getsockname()[1])
sock.close()
PY
) || fail "could not reserve an ephemeral port"

FM_HOME="$HOME_FIXTURE" "$ROOT/bin/fm-fleet-ui.sh" serve --no-build --port "$PORT" --out "$OUT_DIR" \
  > "$SERVER_OUT" 2> "$SERVER_ERR" &
SERVER_PID=$!

BASE="http://127.0.0.1:$PORT"
for _ in $(seq 1 100); do
  curl -fsS "$BASE/" >/dev/null 2>&1 && break
  kill -0 "$SERVER_PID" 2>/dev/null || break
  sleep 0.1
done

curl -fsS "$BASE/" | grep -q 'Firstmate Fleet' || fail "GET / did not return the fleet page"

curl -fsS "$BASE/data/snapshot.json" > "$TMP_ROOT/served-snapshot.json" \
  || fail "GET /data/snapshot.json failed"
curl -fsS "$BASE/data/memories.json" > "$TMP_ROOT/served-memories.json" \
  || fail "GET /data/memories.json failed"
curl -fsS "$BASE/data/decisions.json" > "$TMP_ROOT/served-decisions.json" \
  || fail "GET /data/decisions.json failed"
python3 - "$TMP_ROOT/served-snapshot.json" "$TMP_ROOT/served-memories.json" "$TMP_ROOT/served-decisions.json" <<'PY' \
  || fail "the served JSON was not valid"
import json
import sys

snapshot = json.load(open(sys.argv[1], encoding="utf-8"))
if snapshot.get("schema") != "fm-fleet-snapshot.v1":
    sys.exit("served snapshot schema: %r" % (snapshot.get("schema"),))
memories = json.load(open(sys.argv[2], encoding="utf-8"))
if not isinstance(memories.get("files"), list):
    sys.exit("served memories files is not a list")
decisions = json.load(open(sys.argv[3], encoding="utf-8"))
if decisions.get("count") != 1:
    sys.exit("served decisions count: %r" % (decisions.get("count"),))
PY

pass "fleet UI builds static data and serves the page and its JSON read-only"
