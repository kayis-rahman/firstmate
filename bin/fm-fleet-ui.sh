#!/usr/bin/env bash
# fm-fleet-ui.sh - build and serve a static, read-only firstmate fleet dashboard.
#
# `build` runs the read-only fleet sources once and writes plain JSON data files
# plus a copy of assets/fleet-ui/index.html under the output directory.
# `serve` builds, then hands that directory to the Shipcat project's Rust fleet
# host (`fm-fleet-ui`, built from the Shipcat project's `fleet-host/` crate),
# which is the only HTTP server for this dashboard. firstmate never vendors,
# copies, installs, or builds that binary: `serve` uses FM_FLEET_UI_HOST_BIN
# when it is set and otherwise resolves `fm-fleet-ui` from PATH.
# The page never calls a live API and never drains, acknowledges, or mutates
# fleet state.
#
# Usage:
#   fm-fleet-ui.sh build  [--out <dir>]
#   fm-fleet-ui.sh refresh [--out <dir>]
#   fm-fleet-ui.sh serve  [--port <n>] [--host <addr>] [--open] [--out <dir>] [--no-build]
#   fm-fleet-ui.sh path   [--out <dir>]
#
# Default output directory: $FM_HOME/state/fleet-ui
# Default serve address: 127.0.0.1:8765
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"

# The dashboard is a read-only screen over a firstmate home. The home is
# FM_HOME when set and otherwise the primary firstmate home directory below -
# never this worktree, a treehouse copy, or a test directory.
FM_DEFAULT_HOME=/Users/kayisrahman/Documents/workspace/firstmate
FM_HOME="${FM_HOME:-$FM_DEFAULT_HOME}"
STATE="${FM_STATE_OVERRIDE:-$FM_HOME/state}"
DATA="${FM_DATA_OVERRIDE:-$FM_HOME/data}"
CONFIG="${FM_CONFIG_OVERRIDE:-$FM_HOME/config}"

# The page and the read-only helper scripts come from the home once it has
# them, so a copy run from a worktree still reads the home's fleet. Before the
# home is updated they fall back to the files beside this script.
ASSETS_DIR="$FM_HOME/assets/fleet-ui"
[ -f "$ASSETS_DIR/index.html" ] || ASSETS_DIR="$FM_ROOT/assets/fleet-ui"
INDEX_FILE="$ASSETS_DIR/index.html"
SNAPSHOT_SCRIPT="$FM_HOME/bin/fm-fleet-snapshot.sh"
[ -f "$SNAPSHOT_SCRIPT" ] || SNAPSHOT_SCRIPT="$SCRIPT_DIR/fm-fleet-snapshot.sh"
CAPACITY_SCRIPT="$FM_HOME/bin/fm-capacity.sh"
[ -f "$CAPACITY_SCRIPT" ] || CAPACITY_SCRIPT="$SCRIPT_DIR/fm-capacity.sh"

usage() {
  cat <<'USAGE'
usage: fm-fleet-ui.sh <build|refresh|serve|path> [options]

  build    run the read-only sources once and write static dashboard files
  refresh  alias for build
  serve    build, then serve the output directory with the Shipcat Rust fleet host
  path     print the output directory
  install-refresh   write (but do not load) a LaunchAgent that rebuilds every 60s
  uninstall-refresh remove that LaunchAgent file

options:
  --out <dir>   output directory (default: $FM_HOME/state/fleet-ui)
  --port <n>    serve port (default: 8765)
  --host <addr> serve bind address (default: 127.0.0.1)
  --open        open the dashboard in a browser after serve starts
  --no-build    serve existing files without rebuilding
  --lavish      also open a Lavish review session for each open decision

environment:
  FM_FLEET_UI_HOST_BIN  path to the Shipcat fleet host binary `fm-fleet-ui`
                        (default: resolve `fm-fleet-ui` from PATH)
USAGE
}

MODE="serve"
OUT=""
NO_BUILD=0
HOST=""
HOST_EXPLICIT=0
PORT=8765
OPEN=0
LAVISH=0

if [ "$#" -gt 0 ]; then
  case "$1" in
    build|refresh|serve|path|install-refresh|uninstall-refresh)
      MODE=$1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --*)
      ;;
    *)
      echo "fm-fleet-ui: unknown command: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
fi

while [ "$#" -gt 0 ]; do
  case "$1" in
    --out)
      [ "$#" -ge 2 ] || { echo "fm-fleet-ui: --out requires a value" >&2; exit 2; }
      OUT=$2; shift 2 ;;
    --port)
      [ "$#" -ge 2 ] || { echo "fm-fleet-ui: --port requires a value" >&2; exit 2; }
      PORT=$2; shift 2 ;;
    --host)
      [ "$#" -ge 2 ] || { echo "fm-fleet-ui: --host requires a value" >&2; exit 2; }
      HOST=$2; HOST_EXPLICIT=1; shift 2 ;;
    --open)
      OPEN=1; shift ;;
    --lavish)
      LAVISH=1; shift ;;
    --no-build)
      NO_BUILD=1; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "fm-fleet-ui: unknown argument: $1" >&2
      usage >&2
      exit 2 ;;
  esac
done

if [ -z "$OUT" ]; then
  OUT="$FM_HOME/state/fleet-ui"
fi
if [ "$MODE" = "path" ]; then
  printf '%s\n' "$OUT"
  exit 0
fi
if [ "$MODE" = "refresh" ]; then
  MODE="build"
fi
if [ "$MODE" = "serve" ] && [ "$NO_BUILD" -eq 0 ]; then
  MODE="serve"
fi

# Loopback only by default. A non-loopback address is used only when the
# caller passed --host explicitly.
if [ "$HOST_EXPLICIT" -eq 0 ]; then
  HOST="127.0.0.1"
fi

# `serve` delegates the HTTP server to the Shipcat project's Rust fleet host.
# firstmate never vendors, copies, installs, or builds that binary, so name the
# exact thing to build when it is not where we look.
FLEET_HOST_BIN=""
if [ "$MODE" = "serve" ]; then
  if [ -n "${FM_FLEET_UI_HOST_BIN:-}" ]; then
    FLEET_HOST_BIN=$FM_FLEET_UI_HOST_BIN
  else
    FLEET_HOST_BIN=$(command -v fm-fleet-ui 2>/dev/null || true)
  fi
  if [ -z "$FLEET_HOST_BIN" ] || [ ! -x "$FLEET_HOST_BIN" ]; then
    echo "fm-fleet-ui: serve needs the Shipcat fleet host binary 'fm-fleet-ui'." >&2
    echo "fm-fleet-ui: build it from the Shipcat project's fleet-host/ crate (cargo build --release in fleet-host/) and put the binary on PATH, or set FM_FLEET_UI_HOST_BIN to its path." >&2
    exit 1
  fi
fi

if [ ! -f "$INDEX_FILE" ]; then
  echo "fm-fleet-ui: missing page: $INDEX_FILE" >&2
  exit 1
fi

export FM_ROOT FM_HOME STATE DATA CONFIG
export FM_FLEET_UI_MODE="$MODE"
export FM_FLEET_UI_OUT="$OUT"
export FM_FLEET_UI_NO_BUILD="$NO_BUILD"
export FM_FLEET_UI_ASSETS="$ASSETS_DIR"
export FM_FLEET_UI_INDEX="$INDEX_FILE"
export FM_FLEET_UI_SNAPSHOT="$SNAPSHOT_SCRIPT"
export FM_FLEET_UI_CAPACITY="$CAPACITY_SCRIPT"
export FM_FLEET_UI_HOST="$HOST"
export FM_FLEET_UI_PORT="$PORT"
export FM_FLEET_UI_OPEN="$OPEN"
export FM_FLEET_UI_LAVISH="$LAVISH"
export FM_FLEET_UI_HOST_EXPLICIT="$HOST_EXPLICIT"
export FM_FLEET_UI_HOST_BIN="$FLEET_HOST_BIN"

exec python3 - <<'PY'
import collections
import concurrent.futures
import datetime
import glob
import json
import os
import re
import shutil
import signal
import socket
import subprocess
import fcntl
import threading
import time
import urllib.parse
import webbrowser

FM_ROOT = os.environ["FM_ROOT"]
FM_HOME = os.environ["FM_HOME"]
STATE = os.environ["STATE"]
DATA = os.environ["DATA"]
CONFIG = os.environ["CONFIG"]
ASSETS = os.environ["FM_FLEET_UI_ASSETS"]
INDEX = os.environ["FM_FLEET_UI_INDEX"]
SNAPSHOT = os.environ["FM_FLEET_UI_SNAPSHOT"]
CAPACITY = os.environ["FM_FLEET_UI_CAPACITY"]
HOST = os.environ["FM_FLEET_UI_HOST"]
PORT = int(os.environ["FM_FLEET_UI_PORT"])
OPEN = os.environ["FM_FLEET_UI_OPEN"] == "1"
LAVISH = os.environ["FM_FLEET_UI_LAVISH"] == "1"
HOST_EXPLICIT = os.environ["FM_FLEET_UI_HOST_EXPLICIT"] == "1"
FLEET_HOST_BIN = os.environ["FM_FLEET_UI_HOST_BIN"]

VERSION = "fm-fleet-ui.v3"
LOOPBACK = {"127.0.0.1", "localhost", "::1", "0:0:0:0:0:0:0:1"}
ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")
URL_RE = re.compile(r"https?://[^\s<>\"')]+")

SNAPSHOT_TTL = 45
PR_CACHE_TTL = 30
QUOTA_CACHE_TTL = 60
MODELS_CACHE_TTL = 120
CAPACITY_CACHE_TTL = 15
REVIEWS_CACHE_TTL = 10
ACTIVITY_CACHE_TTL = 10

MEMORY_FILES = [
    ("captain", "Captain preferences", "captain.md", False),
    ("captain_shared", "Shared captain preferences", "captain-shared.md", True),
    ("learnings", "Learnings", "learnings.md", False),
]

SNAPSHOT_LOCK = threading.Lock()
SNAPSHOT_CACHE = {"at": 0.0, "payload": None}
CACHE_LOCK = threading.Lock()
CACHES = {}


class SnapshotError(Exception):
    pass


def loopback(host):
    if host in LOOPBACK:
        return True
    try:
        return socket.gethostbyname(host).startswith("127.")
    except OSError:
        return False


def iso_now():
    return datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def parse_iso(value):
    if not value:
        return None
    try:
        return datetime.datetime.fromisoformat(str(value).replace("Z", "+00:00")).timestamp()
    except ValueError:
        return None


def read_text(path):
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as handle:
            return handle.read()
    except OSError:
        return None


def read_tail(path, max_bytes=240000):
    if not path:
        return None
    try:
        with open(path, "rb") as handle:
            handle.seek(0, os.SEEK_END)
            size = handle.tell()
            start = max(0, size - max_bytes)
            handle.seek(start)
            data = handle.read()
    except OSError:
        return None
    text = data.decode("utf-8", errors="replace")
    if start > 0 and "\n" in text:
        text = text.split("\n", 1)[1]
    return text


def mtime(path):
    try:
        return os.path.getmtime(path)
    except OSError:
        return None


def human_age(seconds):
    if seconds is None:
        return "unknown"
    try:
        seconds = int(seconds)
    except (TypeError, ValueError):
        return "unknown"
    if seconds < 0:
        seconds = 0
    if seconds < 60:
        return "%ds" % seconds
    if seconds < 3600:
        return "%dm" % (seconds // 60)
    if seconds < 86400:
        return "%dh" % (seconds // 3600)
    return "%dd" % (seconds // 86400)


def clean_url(value):
    if not value:
        return None
    match = URL_RE.search(str(value))
    if not match:
        return None
    url = match.group(0).rstrip(".,;:)]}")
    if not url.startswith(("http://", "https://")):
        return None
    return url


def all_urls(text):
    urls = []
    for raw in URL_RE.findall(text or ""):
        url = clean_url(raw)
        if url and url not in urls:
            urls.append(url)
    return urls


def first_board_url(text):
    urls = all_urls(text)
    for url in urls:
        if "/session/" in url:
            return url
    return urls[0] if urls else None


def first_session_url(text):
    for url in all_urls(text):
        if "/session/" in url:
            return url
    return None


def snapshot_env():
    env = os.environ.copy()
    env["FM_HOME"] = FM_HOME
    env["FM_STATE_OVERRIDE"] = STATE
    env["FM_DATA_OVERRIDE"] = DATA
    env["FM_CONFIG_OVERRIDE"] = CONFIG
    return env


def snapshot_payload(force=False):
    with SNAPSHOT_LOCK:
        now = time.time()
        cached = SNAPSHOT_CACHE["payload"]
        if not force and cached is not None and now - SNAPSHOT_CACHE["at"] < SNAPSHOT_TTL:
            return cached
        try:
            proc = subprocess.run(
                [SNAPSHOT, "--json"],
                capture_output=True,
                env=snapshot_env(),
                timeout=300,
            )
        except Exception as exc:  # noqa: BLE001 - surface the failure as JSON
            raise SnapshotError(str(exc)) from exc
        if proc.returncode != 0:
            detail = proc.stderr.decode("utf-8", errors="replace").strip()
            raise SnapshotError(detail or ("snapshot exited %d" % proc.returncode))
        try:
            payload = json.loads(proc.stdout.decode("utf-8", errors="replace"))
        except json.JSONDecodeError as exc:
            raise SnapshotError("snapshot returned invalid JSON: %s" % exc) from exc
        payload = augment_snapshot(payload)
        SNAPSHOT_CACHE["at"] = time.time()
        SNAPSHOT_CACHE["payload"] = payload
        return payload


def cache_get(key, ttl):
    with CACHE_LOCK:
        entry = CACHES.get(key)
        if entry is not None and time.time() - entry["at"] < ttl:
            return entry["payload"]
    return None


def cache_set(key, payload):
    with CACHE_LOCK:
        CACHES[key] = {"at": time.time(), "payload": payload}


def cached_read(key, ttl, loader, force=False):
    if not force:
        hit = cache_get(key, ttl)
        if hit is not None:
            return hit
    payload = loader()
    cache_set(key, payload)
    return payload


def meta_values(task_id):
    values = {}
    text = read_text(os.path.join(STATE, task_id + ".meta"))
    if not text:
        return values
    for line in text.splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip()
    return values


def augment_snapshot(payload):
    """Add home-local worker fields to a snapshot payload in the server.

    The snapshot contract stays untouched; the per-worker model and effort are
    read from the home metadata here so the page has them without changing
    bin/fm-fleet-snapshot.sh.
    """
    tasks = payload.get("tasks") if isinstance(payload, dict) else None
    if not isinstance(tasks, list):
        return payload
    for task in tasks:
        if not isinstance(task, dict):
            continue
        task_id = task.get("id")
        if not task_id or not ID_RE.match(str(task_id)):
            continue
        meta = meta_values(str(task_id))
        if not task.get("model"):
            task["model"] = meta.get("model") or None
        if not task.get("effort"):
            task["effort"] = meta.get("effort") or None
    return payload


def meta_kinds():
    result = {"workers": 0, "secondmates": 0, "total": 0}
    try:
        names = os.listdir(STATE)
    except OSError:
        return result
    for name in names:
        if not name.endswith(".meta"):
            continue
        result["total"] += 1
        kind = meta_values(name[:-5]).get("kind") or "ship"
        if kind == "secondmate":
            result["secondmates"] += 1
        else:
            result["workers"] += 1
    return result


def project_name(path):
    if not path:
        return None
    return os.path.basename(str(path).rstrip("/")) or None


def task_last_age(task):
    last = ((task.get("paths") or {}).get("status_log") or {}).get("last_event") or {}
    age = last.get("age_seconds")
    return age if isinstance(age, int) else None


def task_summary(task):
    current = task.get("current_state") or {}
    endpoint = task.get("endpoint") or {}
    backlog = task.get("backlog") or {}
    project = task.get("project") or ""
    return {
        "id": task.get("id"),
        "kind": task.get("kind"),
        "title": backlog.get("title") or task.get("id"),
        "project": project,
        "project_name": project_name(project),
        "state": current.get("state") or "unknown",
        "state_detail": current.get("detail") or "",
        "source": current.get("source") or None,
        "mode": task.get("mode") or None,
        "yolo": task.get("yolo") or None,
        "branch": task.get("branch"),
        "model": task.get("model"),
        "effort": task.get("effort"),
        "harness": task.get("harness"),
        "endpoint_status": endpoint.get("status") or "unknown",
        "age_seconds": task_last_age(task),
        "pr_url": clean_url((task.get("pr") or {}).get("url")),
        "report_present": bool(((task.get("paths") or {}).get("report") or {}).get("present")),
        "report_path": ((task.get("paths") or {}).get("report") or {}).get("path"),
        "captain_actionable": bool(backlog.get("captain_actionable")),
        "hold_reason": backlog.get("hold_reason"),
        "hold_until": backlog.get("hold_until"),
        "hold_kind": backlog.get("hold_kind"),
    }


def status_verb(line):
    left = line.split(":", 1)[0].strip()
    return left.split(" ", 1)[0] if left else ""


def parse_status(text):
    rows = []
    for raw in (text or "").splitlines():
        line = raw.strip()
        if not line:
            continue
        state = ""
        at = None
        note = line
        left, sep, right = line.partition(":")
        if sep:
            note = right.strip()
            parts = left.strip().split()
            if parts:
                state = parts[0]
            for part in parts[1:]:
                if part.startswith("[at=") and part.endswith("]"):
                    try:
                        at = int(part[4:-1])
                    except ValueError:
                        at = None
        key = None
        key_match = re.search(r"\[key=([^\]]+)\]", left)
        if key_match:
            key = key_match.group(1).strip()
        rows.append({"raw": raw, "state": state, "at": at, "note": note, "key": key})
    return rows


def first_event_for(rows, verbs):
    for row in reversed(rows):
        if row["state"] in verbs:
            return row
    return None


def event_with_age(row, now):
    if row is None:
        return None
    at = row.get("at")
    age = int(now - at) if isinstance(at, int) and at <= now else None
    return {
        "raw": row.get("raw"),
        "state": row.get("state"),
        "note": row.get("note"),
        "key": row.get("key"),
        "at": at,
        "opened_at": datetime.datetime.fromtimestamp(at, datetime.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z") if isinstance(at, int) else None,
        "age_seconds": age,
    }


PAUSED_UNTIL_RE = re.compile(
    r"\b(?:until|resetsAt|reset at)\s+([0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9]{2}:[0-9]{2}(?::[0-9]{2})?Z?)",
    re.I,
)
WAITING_RE = re.compile(
    r"\b(?:waiting (?:on|for)|awaiting|blocked on|blocked by|needs|depends on)\s+([^.;\n]+)",
    re.I,
)


def paused_until(text):
    match = PAUSED_UNTIL_RE.search(text or "")
    return match.group(1) if match else None


def waiting_on(text):
    match = WAITING_RE.search(text or "")
    if not match:
        return None
    value = re.sub(r"\s+", " ", match.group(1)).strip()
    return value[:240] if value else None


def task_session_url(task):
    for decision in ((task.get("hints") or {}).get("open_decisions") or []):
        url = first_session_url(decision.get("summary"))
        if url:
            return url
    url = first_session_url((task.get("hints") or {}).get("last_event_text") or "")
    if url:
        return url
    path = ((task.get("paths") or {}).get("status_log") or {}).get("path")
    tail = read_tail(path, 40000)
    if tail:
        for candidate in reversed(all_urls(tail)):
            if "/session/" in candidate:
                return candidate
    return None


def task_any_url(task):
    for decision in ((task.get("hints") or {}).get("open_decisions") or []):
        url = first_board_url(decision.get("summary"))
        if url:
            return url
    url = first_board_url((task.get("hints") or {}).get("last_event_text") or "")
    if url:
        return url
    path = ((task.get("paths") or {}).get("status_log") or {}).get("path")
    tail = read_tail(path, 40000)
    if tail:
        urls = all_urls(tail)
        if urls:
            return urls[-1]
    return None


def split_options(summary):
    text = summary or ""
    match = re.search(r"\bOptions?\s*:\s*", text, re.I)
    target = text[match.end():] if match else ""
    if not target:
        labels = re.findall(r"\(([a-zA-Z])\)", text)
        if len(labels) >= 2:
            target = text[text.find("(" + labels[0] + ")"):]
    options = []
    for option in re.finditer(r"\(([a-zA-Z])\)\s*(.*?)(?=\s*\([a-zA-Z]\)|\Z)", target, re.S):
        body = re.sub(r"\s+", " ", option.group(2)).strip()
        body = re.sub(r"\s+Evidence in .*$", "", body, flags=re.I).strip()
        if body:
            options.append({"label": option.group(1).lower(), "text": body})
        if len(options) >= 6:
            break
    return options


def decision_question(summary):
    text = summary or ""
    head = re.split(r"\bOptions?\s*:", text, maxsplit=1, flags=re.I)[0].strip()
    head = re.sub(r"^(?:(?:corr|pending-reply)=?[0-9A-Za-z_-]+\s+)+", "", head, flags=re.I).strip()
    return (head or text).strip()[:1400]


def decision_epoch(task_id, key):
    text = read_text(os.path.join(STATE, task_id + ".status"))
    if not text:
        return None
    latest = None
    for line in text.splitlines():
        verb = status_verb(line)
        if verb not in ("needs-decision", "blocked"):
            continue
        key_match = re.search(r"\[key=([^\]]+)\]", line)
        line_key = key_match.group(1).strip() if key_match else "default"
        if line_key != key:
            continue
        at_match = re.search(r"\[at=(\d+)\]", line)
        if not at_match:
            continue
        try:
            epoch = int(at_match.group(1))
        except ValueError:
            continue
        if latest is None or epoch > latest:
            latest = epoch
    return latest


def decision_impact(task, verb, count, board_url, age):
    score = 0
    reasons = []
    if verb == "blocked":
        score += 50
        reasons.append("blocker")
    elif verb == "needs-decision":
        score += 40
        reasons.append("decision waiting")
    state = ((task.get("current_state") or {}).get("state") or "")
    if state == "working":
        score += 20
        reasons.append("worker active")
    elif state in ("paused", "parked"):
        score += 5
        reasons.append("worker parked")
    backlog = task.get("backlog") or {}
    if backlog.get("captain_actionable"):
        score += 30
        reasons.append("captain action")
    if (task.get("pr") or {}).get("url"):
        score += 15
        reasons.append("PR waiting")
    if board_url:
        score += 10
        reasons.append("board link")
    if count > 1:
        score += min(15, (count - 1) * 5)
        reasons.append("multiple decisions")
    if age and age > 3600:
        score += min(20, age // 3600)
        reasons.append("open for %s" % human_age(age))
    label = "high" if score >= 80 else "medium" if score >= 45 else "low"
    return score, label, reasons


def decisions_payload(force=False):
    snapshot = snapshot_payload(force)
    now = time.time()
    decisions = []
    for task in snapshot.get("tasks") or []:
        open_decisions = ((task.get("hints") or {}).get("open_decisions") or [])
        if not open_decisions:
            continue
        count = len(open_decisions)
        for decision in open_decisions:
            key = decision.get("key") or "default"
            verb = decision.get("verb") or "needs-decision"
            summary = decision.get("summary") or ""
            board_url = first_session_url(summary) or task_session_url(task)
            link_url = first_board_url(summary) or task_any_url(task)
            epoch = decision_epoch(task.get("id", ""), key)
            age = int(now - epoch) if epoch and epoch <= now else task_last_age(task)
            score, label, reasons = decision_impact(task, verb, count, board_url, age)
            decisions.append({
                "task": task_summary(task),
                "key": key,
                "verb": verb,
                "summary": summary,
                "question": decision_question(summary),
                "options": split_options(summary),
                "board_url": board_url,
                "link_url": link_url,
                "impact": label,
                "impact_score": score,
                "impact_reason": "; ".join(reasons),
                "age_seconds": age,
                "opened_at": datetime.datetime.fromtimestamp(epoch, datetime.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z") if epoch else None,
                "source": "status_open_decisions",
            })
    decisions.sort(key=lambda item: (-item["impact_score"], -(item.get("age_seconds") or 0), item["task"]["id"] or ""))
    return {
        "schema": "fm-fleet-ui.decisions.v1",
        "generated": iso_now(),
        "count": len(decisions),
        "decisions": decisions,
    }


UNREAD_RE = re.compile(r"unread[^0-9]{0,40}age=(\d+)\s*s", re.I)
UNREAD_ALT_RE = re.compile(r"steer:[^·]{0,90}?age=(\d+)\s*s", re.I)


def parse_unread(detail):
    for pattern in (UNREAD_RE, UNREAD_ALT_RE):
        match = pattern.search(detail or "")
        if match:
            try:
                return int(match.group(1))
            except ValueError:
                pass
    return None


def route_info(task):
    endpoint = task.get("endpoint") or {}
    detail = ((task.get("current_state") or {}).get("detail") or "").lower()
    model = task.get("model") or ""
    provider = model.split("/", 1)[0] if "/" in model else (model or None)
    status = endpoint.get("status") or "unknown"
    dead = False
    reason = None
    if status == "absent":
        dead = True
        reason = "no live worker endpoint"
    elif endpoint.get("agent_alive") == "dead":
        dead = True
        reason = "worker process is dead"
    elif "no backend target recorded" in detail:
        dead = True
        reason = "no backend target recorded"
    elif "endpoint gone" in detail:
        dead = True
        reason = "worker endpoint is gone"
    elif not model:
        reason = "model not recorded"
    return {
        "model": model or None,
        "provider": provider,
        "status": status,
        "dead": dead,
        "reason": reason,
    }


def stuck_payload(force=False):
    snapshot = snapshot_payload(force)
    now = time.time()
    alerts = []
    for task in snapshot.get("tasks") or []:
        state = ((task.get("current_state") or {}).get("state") or "unknown")
        if state == "done":
            continue
        kind = task.get("kind")
        idle = task_last_age(task)
        detail = ((task.get("current_state") or {}).get("detail") or "")
        unread = parse_unread(detail)
        route = route_info(task)
        reasons = []
        severity = 0
        if route["dead"]:
            reasons.append("model route dead: %s" % (route["reason"] or "endpoint missing"))
            severity = max(severity, 3)
        unread_threshold = 1800 if kind == "secondmate" else 600
        if unread is not None and unread >= unread_threshold:
            reasons.append("unread steer for %s" % human_age(unread))
            severity = max(severity, 3 if unread >= 3600 else 2)
        if kind != "secondmate" and idle is not None and idle >= 1800:
            reasons.append("idle for %s" % human_age(idle))
            severity = max(severity, 3 if idle >= 21600 else 2)
        if not reasons:
            continue
        alerts.append({
            "task": task_summary(task),
            "id": task.get("id"),
            "kind": kind,
            "state": state,
            "idle_seconds": idle,
            "unread_steer_seconds": unread,
            "route": route,
            "severity": severity,
            "severity_label": "high" if severity >= 3 else "medium",
            "reasons": reasons,
        })
    alerts.sort(key=lambda item: (-item["severity"], -(item.get("unread_steer_seconds") or 0), -(item.get("idle_seconds") or 0)))
    return {
        "schema": "fm-fleet-ui.stuck.v1",
        "generated": iso_now(),
        "thresholds": {"idle_seconds": 1800, "unread_seconds": 600, "secondmate_unread_seconds": 1800},
        "count": len(alerts),
        "alerts": alerts,
    }


def backlog_bucket(record):
    if record.get("state") == "done":
        return "done"
    if record.get("state") == "in_flight":
        return "in_flight"
    if record.get("unresolved_blocker_ids") or record.get("blocked_by_ids") or record.get("blocked_reason"):
        return "blocked"
    if record.get("hold_kind") or record.get("hold_bucket"):
        return "held"
    return "queued"


def backlog_payload(force=False):
    snapshot = snapshot_payload(force)
    backlog = snapshot.get("backlog") or {}
    records = backlog.get("records") or []
    counts = {"queued": 0, "held": 0, "blocked": 0, "in_flight": 0, "done": 0, "total": len(records)}
    rows = []
    for record in records:
        bucket = backlog_bucket(record)
        counts[bucket] = counts.get(bucket, 0) + 1
        if bucket == "done":
            continue
        rows.append({
            "id": record.get("id"),
            "title": record.get("title"),
            "repo": record.get("repo"),
            "kind": record.get("kind"),
            "state": record.get("state"),
            "bucket": bucket,
            "held": bool(record.get("hold_kind") or record.get("hold_bucket")),
            "blocked": bool(record.get("unresolved_blocker_ids") or record.get("blocked_by_ids") or record.get("blocked_reason")),
            "captain_actionable": bool(record.get("captain_actionable")),
            "hold_reason": record.get("hold_reason"),
            "hold_until": record.get("hold_until"),
            "hold_kind": record.get("hold_kind"),
            "hold_bucket": record.get("hold_bucket"),
            "hold_age_days": record.get("hold_age_days"),
            "blocked_reason": record.get("blocked_reason"),
            "blocked_by_ids": record.get("blocked_by_ids") or [],
            "unresolved_blocker_ids": record.get("unresolved_blocker_ids") or [],
            "since": record.get("since"),
            "body_excerpt": record.get("body_excerpt"),
            "pr_url": clean_url(record.get("pr_url")),
            "report_path": record.get("report_path"),
            "completion": record.get("completion"),
        })
    order = {"blocked": 0, "held": 1, "queued": 2, "in_flight": 3}
    rows.sort(key=lambda item: (order.get(item["bucket"], 9), item.get("id") or ""))
    return {
        "schema": "fm-fleet-ui.backlog.v1",
        "generated": iso_now(),
        "path": backlog.get("path"),
        "present": bool(backlog.get("present")),
        "counts": counts,
        "records": rows,
    }


def secondmate_registry_details():
    text = read_text(os.path.join(DATA, "secondmates.md")) or ""
    details = {}
    for line in text.splitlines():
        if not line.startswith("- "):
            continue
        match = re.match(r"^- ([A-Za-z0-9][A-Za-z0-9._-]*) - (.*)$", line)
        if not match:
            continue
        mate_id = match.group(1)
        rest = match.group(2)
        description = rest.split(" (home:", 1)[0].strip()
        scope_match = re.search(r"scope:\s*(.*?)(?:;\s*projects:|\)\s*$)", rest)
        projects_match = re.search(r"projects:\s*([^;)]+)", rest)
        projects = []
        if projects_match:
            projects = [item.strip() for item in projects_match.group(1).split(",") if item.strip()]
        details[mate_id] = {
            "description": description,
            "scope": scope_match.group(1).strip() if scope_match else None,
            "projects": projects,
        }
    return details


def secondmates_payload(force=False):
    snapshot = snapshot_payload(force)
    current = snapshot.get("secondmate_current") or {}
    registry = current.get("registry") or {}
    tasks = {task.get("id"): task for task in (snapshot.get("tasks") or [])}
    details = secondmate_registry_details()
    records = []
    for record in current.get("records") or []:
        mate_id = record.get("id")
        task = tasks.get(mate_id) or {}
        info = details.get(mate_id) or {}
        projects = task.get("secondmate_projects") or info.get("projects") or []
        scope = info.get("scope") or (", ".join(projects) if projects else "Not recorded")
        counts = record.get("counts") or {}
        records.append({
            "id": mate_id,
            "home": record.get("home"),
            "host": record.get("host"),
            "remote": bool(record.get("remote")),
            "registered": bool(record.get("registered")),
            "description": info.get("description"),
            "scope": scope,
            "projects": projects,
            "state": (record.get("current") or {}).get("state") or "unknown",
            "reason": (record.get("current") or {}).get("reason"),
            "invalidity": record.get("invalidity"),
            "freshness": record.get("freshness"),
            "counts": counts,
            "queued": (record.get("queued") or [])[:8],
            "holds": (record.get("holds") or [])[:8],
            "decisions_open": (record.get("decisions_open") or [])[:8],
            "landed_count": len(record.get("landed") or []),
            "active_children": record.get("active_children") or [],
            "task_state": (task.get("current_state") or {}).get("state") if task else None,
            "endpoint": task.get("endpoint") if task else None,
        })
    records.sort(key=lambda item: item["id"] or "")
    return {
        "schema": "fm-fleet-ui.secondmates.v1",
        "generated": iso_now(),
        "registry": {
            "present": bool(registry.get("present")),
            "path": registry.get("path"),
            "total": len(registry.get("records") or []),
        },
        "count": len(records),
        "secondmates": records,
    }


def activity_kind(verb, note):
    low = (note or "").lower()
    if "merged" in low and ("pull/" in low or " pr" in low or "pr #" in low or "merge" in low):
        return "merge"
    if verb == "failed":
        return "failure"
    if "pipeline failed" in low or low.startswith("failed"):
        return "failure"
    for token in ("pr ready", "pull request ready", "reported", "handoff", "handed off", "routed", "child outcome", "report ready"):
        if token in low:
            return "handoff"
    return None


def activity_payload(force=False):
    def load():
        now = time.time()
        cutoff = now - 86400
        projects = {}
        events = []
        seen = set()
        for path in glob.glob(os.path.join(STATE, "*.status")):
            task_id = os.path.basename(path)[:-7]
            text = read_tail(path, 300000)
            if not text:
                continue
            meta = meta_values(task_id)
            project = project_name(meta.get("project"))
            for raw in reversed(text.splitlines()):
                row = parse_status(raw)
                if not row:
                    continue
                event = row[0]
                at = event.get("at")
                if not isinstance(at, int):
                    continue
                if at < cutoff:
                    break
                kind = activity_kind(event.get("state"), event.get("note"))
                if not kind:
                    continue
                note = event.get("note") or ""
                dedupe = (task_id, kind, note[:220])
                if dedupe in seen:
                    continue
                seen.add(dedupe)
                events.append({
                    "kind": kind,
                    "task_id": task_id,
                    "project": project,
                    "state": event.get("state"),
                    "at": at,
                    "age_seconds": int(now - at) if at <= now else None,
                    "note": note,
                    "url": first_board_url(note) if "/session/" in note else clean_url(note),
                    "key": event.get("key"),
                })
        events.sort(key=lambda item: item.get("at") or 0, reverse=True)
        counts = collections.Counter(item["kind"] for item in events)
        return {
            "schema": "fm-fleet-ui.activity.v1",
            "generated": iso_now(),
            "window_seconds": 86400,
            "counts": {kind: counts.get(kind, 0) for kind in ("merge", "handoff", "failure")},
            "events": events[:120],
        }
    return cached_read("activity", ACTIVITY_CACHE_TTL, load, force)


def html_title(path):
    try:
        with open(path, "rb") as handle:
            head = handle.read(8192)
    except OSError:
        return None
    text = head.decode("utf-8", errors="replace")
    match = re.search(r"<title[^>]*>(.*?)</title>", text, re.I | re.S)
    if not match:
        return None
    return re.sub(r"\s+", " ", match.group(1)).strip()[:140] or None


def review_paths(path):
    parts = str(path or "").split(os.sep)
    task_id = None
    project = None
    if "data" in parts:
        index = parts.index("data")
        if index + 1 < len(parts):
            task_id = parts[index + 1]
    if "projects" in parts:
        index = parts.index("projects")
        if index + 1 < len(parts):
            project = parts[index + 1]
    if not task_id and ".lavish" in parts:
        index = parts.index(".lavish")
        if index + 1 < len(parts):
            task_id = os.path.splitext(parts[index + 1])[0]
    if not task_id:
        task_id = os.path.splitext(os.path.basename(str(path or "")))[0]
    return task_id or None, project or task_id


def reviews_payload(force=False):
    def load():
        state_path = os.environ.get("LAVISH_AXI_STATE") or os.path.expanduser("~/.lavish-axi/state.json")
        text = read_text(state_path)
        if text is None:
            return {
                "schema": "fm-fleet-ui.reviews.v1",
                "generated": iso_now(),
                "available": False,
                "state_path": state_path,
                "active_count": 0,
                "ended_count": 0,
                "pending_prompts": 0,
                "sessions": [],
            }
        try:
            state = json.loads(text)
        except json.JSONDecodeError:
            state = {}
        sessions = []
        ended = 0
        now = time.time()
        for key, session in (state.get("sessions") or {}).items():
            status = session.get("status") or "unknown"
            if status == "ended":
                ended += 1
                continue
            file_path = session.get("file") or ""
            task_id, project = review_paths(file_path)
            updated_epoch = parse_iso(session.get("updated_at"))
            warnings = session.get("layout_warnings") or []
            open_warnings = sum(1 for warning in warnings if (warning.get("status") or "").lower() not in ("resolved", "dismissed"))
            sessions.append({
                "key": key,
                "file": file_path,
                "url": clean_url(session.get("url")),
                "status": status,
                "pending_prompts": int(session.get("pending_prompts") or 0),
                "updated_at": session.get("updated_at"),
                "updated_age_seconds": int(now - updated_epoch) if updated_epoch and updated_epoch <= now else None,
                "title": html_title(file_path) or os.path.splitext(os.path.basename(file_path))[0],
                "task_id": task_id,
                "project": project,
                "layout_warnings": open_warnings,
                "artifact_exists": bool(file_path and os.path.isfile(file_path)),
            })
        sessions.sort(key=lambda item: (item["pending_prompts"], -(item.get("updated_age_seconds") or 0)), reverse=True)
        return {
            "schema": "fm-fleet-ui.reviews.v1",
            "generated": iso_now(),
            "available": True,
            "state_path": state_path,
            "active_count": len(sessions),
            "ended_count": ended,
            "pending_prompts": sum(item["pending_prompts"] for item in sessions),
            "sessions": sessions[:60],
        }
    return cached_read("reviews", REVIEWS_CACHE_TTL, load, force)


def parse_contract(path):
    text = read_text(path)
    if text is None:
        return None
    values = {}
    for line in text.splitlines():
        if ":" in line:
            key, value = line.split(":", 1)
            values[key.strip()] = value.strip()
    return values


def away_payload():
    now = time.time()
    afk_path = os.path.join(STATE, ".afk")
    present = os.path.isfile(afk_path)
    raw = None
    mode = None
    entered_epoch = None
    if present:
        text = read_text(afk_path) or ""
        raw = text.splitlines()[0].strip() if text.splitlines() else ""
        mode = "quiet" if raw == "quiet" else "away"
        entered_epoch = mtime(afk_path)
    contract_path = os.path.join(STATE, ".afk-contract")
    if not os.path.exists(contract_path):
        candidates = glob.glob(os.path.join(STATE, "afk-contracts", "*.afk-contract"))
        if candidates:
            contract_path = max(candidates, key=lambda item: mtime(item) or 0)
    contract = parse_contract(contract_path) if present else None
    queue_path = os.path.join(STATE, ".wake-queue")
    queue_text = read_text(queue_path) or ""
    rows = [line for line in queue_text.splitlines() if line.strip()]
    kinds = collections.Counter()
    epochs = []
    for line in rows:
        parts = line.split("\t")
        if len(parts) >= 3:
            kinds[parts[2]] += 1
        if parts:
            try:
                epochs.append(int(parts[0]))
            except ValueError:
                pass
    seq = (read_text(os.path.join(STATE, ".wake-queue.seq")) or "").strip() or None
    return {
        "schema": "fm-fleet-ui.away.v1",
        "generated": iso_now(),
        "read_only": True,
        "away": {
            "present": present,
            "mode": mode,
            "raw": raw,
            "path": afk_path,
            "entered_epoch": entered_epoch,
            "age_seconds": int(now - entered_epoch) if entered_epoch and entered_epoch <= now else None,
        },
        "contract": contract,
        "contract_path": contract_path if contract else None,
        "wake_queue": {
            "path": queue_path,
            "count": len(rows),
            "seq": seq,
            "kinds": dict(kinds),
            "oldest_age_seconds": int(now - min(epochs)) if epochs and min(epochs) <= now else None,
        },
    }


QUOTA_HEALTH_RANK = {"unavailable": 0, "critical": 1, "tight": 2, "stale": 3, "unknown": 4, "ok": 5}


def quota_health(provider):
    state = provider.get("state") or {}
    status = (state.get("status") or "").lower()
    if provider.get("notSetUp") or status in ("auth_required", "not_set_up", "error"):
        return "unavailable"
    windows = provider.get("windows") or []
    values = [window.get("percentRemaining") for window in windows if isinstance(window.get("percentRemaining"), (int, float))]
    effective = ((provider.get("quotaSemantics") or {}).get("effectiveAvailability") or [])
    values += [item.get("effectivePercentRemaining") for item in effective if isinstance(item.get("effectivePercentRemaining"), (int, float))]
    if not values:
        return "unknown"
    low = min(values)
    if state.get("stale"):
        return "stale"
    if low <= 10:
        return "critical"
    if low <= 25:
        return "tight"
    return "ok"


def quota_payload(force=False):
    def load():
        binary = shutil.which("quota-axi")
        if not binary:
            return {"schema": "fm-fleet-ui.quota.v1", "generated": iso_now(), "available": False, "error": "quota-axi not found", "providers": [], "counts": {}}
        try:
            proc = subprocess.run(
                [binary, "--json", "--no-credential-refresh", "--max-age", "5m"],
                capture_output=True,
                env=os.environ.copy(),
                timeout=30,
            )
        except Exception as exc:  # noqa: BLE001 - surface the failure as JSON
            return {"schema": "fm-fleet-ui.quota.v1", "generated": iso_now(), "available": False, "error": str(exc), "providers": [], "counts": {}}
        if proc.returncode != 0:
            return {"schema": "fm-fleet-ui.quota.v1", "generated": iso_now(), "available": False, "error": proc.stderr.decode("utf-8", errors="replace").strip() or "quota-axi failed", "providers": [], "counts": {}}
        try:
            data = json.loads(proc.stdout.decode("utf-8", errors="replace"))
        except json.JSONDecodeError as exc:
            return {"schema": "fm-fleet-ui.quota.v1", "generated": iso_now(), "available": False, "error": str(exc), "providers": [], "counts": {}}
        providers = []
        counts = collections.Counter()
        for provider in data.get("providers") or []:
            health = quota_health(provider)
            counts[health] += 1
            effective = []
            for item in ((provider.get("quotaSemantics") or {}).get("effectiveAvailability") or []):
                runway = item.get("runway") or {}
                effective.append({
                    "scope": item.get("scope"),
                    "status": item.get("status"),
                    "percent_remaining": item.get("effectivePercentRemaining"),
                    "bounded_by": item.get("boundedBy") or [],
                    "limiting_window_ids": item.get("limitingWindowIds") or [],
                    "pace": item.get("pace"),
                    "runway": {
                        "status": runway.get("status"),
                        "usable_seconds": runway.get("usableRunwaySeconds"),
                        "projected_exhausted_at": runway.get("projectedExhaustedAt"),
                        "limiting_window_id": runway.get("limitingWindowId"),
                        "confidence": runway.get("projectionConfidence"),
                    },
                    "spend_priority": (item.get("selection") or {}).get("spendPriority"),
                })
            windows = []
            for window in provider.get("windows") or []:
                windows.append({
                    "id": window.get("id"),
                    "label": window.get("label"),
                    "kind": window.get("kind"),
                    "percent_remaining": window.get("percentRemaining"),
                    "resets_at": window.get("resetsAt"),
                    "pace": window.get("pace"),
                })
            providers.append({
                "provider": provider.get("provider"),
                "plan": provider.get("plan"),
                "state": provider.get("state") or {},
                "not_set_up": bool(provider.get("notSetUp")),
                "health": health,
                "windows": windows,
                "effective": effective,
                "account_keys": provider.get("accountKeys") or [],
            })
        providers.sort(key=lambda item: (QUOTA_HEALTH_RANK.get(item["health"], 9), item.get("provider") or ""))
        return {
            "schema": "fm-fleet-ui.quota.v1",
            "generated": iso_now(),
            "generated_at": data.get("generatedAt"),
            "available": True,
            "providers": providers,
            "counts": {key: counts.get(key, 0) for key in QUOTA_HEALTH_RANK},
        }
    return cached_read("quota", QUOTA_CACHE_TTL, load, force)


def model_health(row):
    if row.get("healthy") is True:
        return "healthy"
    if row.get("healthy") is False:
        return "unhealthy"
    return "unchecked"


def models_payload(force=False):
    def load():
        binary = shutil.which("free-model-axi")
        if not binary:
            return {"schema": "fm-fleet-ui.models.v1", "generated": iso_now(), "available": False, "error": "free-model-axi not found", "providers": [], "counts": {}}

        def run(args):
            try:
                return subprocess.run([binary] + args, capture_output=True, env=os.environ.copy(), timeout=30)
            except Exception as exc:  # noqa: BLE001 - surface the failure as JSON
                return exc

        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            futures = [pool.submit(run, ["--json", "limits"]), pool.submit(run, ["--json", "models"])]
            results = [future.result() for future in futures]
        parsed = []
        as_of = None
        for result in results:
            if isinstance(result, Exception) or result.returncode != 0:
                continue
            try:
                data = json.loads(result.stdout.decode("utf-8", errors="replace"))
            except json.JSONDecodeError:
                continue
            as_of = as_of or data.get("as_of")
            for row in data.get("limits") or data.get("models") or []:
                parsed.append(row)
        if not parsed:
            error = "free-model-axi returned no model data"
            for result in results:
                if not isinstance(result, Exception) and result.returncode != 0:
                    error = result.stderr.decode("utf-8", errors="replace").strip() or error
            return {"schema": "fm-fleet-ui.models.v1", "generated": iso_now(), "available": False, "error": error, "providers": [], "counts": {}}
        merged = {}
        for row in parsed:
            key = (row.get("provider") or "", row.get("model") or "")
            merged.setdefault(key, {}).update(row)
        providers = {}
        for row in merged.values():
            provider = row.get("provider") or "unknown"
            group = providers.setdefault(provider, {
                "provider": provider,
                "local": False,
                "models": [],
                "healthy": 0,
                "unhealthy": 0,
                "unchecked": 0,
                "ready": 0,
            })
            health = model_health(row)
            group[health] = group.get(health, 0) + 1
            group["local"] = group["local"] or bool(row.get("local"))
            group["ready"] = group["ready"] + (1 if row.get("ready") else 0)
            group["models"].append({
                "model": row.get("model"),
                "health": health,
                "health_status": row.get("health_status"),
                "health_stale": bool(row.get("health_stale")),
                "latency_ms": row.get("latency_ms"),
                "price": row.get("price"),
                "context": row.get("context"),
                "thinking": bool(row.get("thinking")),
                "images": bool(row.get("images")),
                "local": bool(row.get("local")),
                "ready": bool(row.get("ready")),
                "remaining": row.get("remaining"),
                "reset": row.get("reset"),
                "reset_display": row.get("reset_display"),
                "runway": row.get("runway"),
                "quota_status": row.get("quota_status"),
                "quota_reason": row.get("quota_reason"),
            })
        rows = []
        for group in providers.values():
            group["model_count"] = len(group["models"])
            if group["healthy"] and group["unhealthy"]:
                group["health"] = "mixed"
            elif group["healthy"]:
                group["health"] = "healthy"
            elif group["unhealthy"]:
                group["health"] = "unhealthy"
            else:
                group["health"] = "unchecked"
            group["models"].sort(key=lambda item: ({"healthy": 0, "unchecked": 1, "unhealthy": 2}.get(item["health"], 3), item["latency_ms"] if isinstance(item["latency_ms"], (int, float)) else 10**9, item["model"] or ""))
            group["models"] = group["models"][:8]
            rows.append(group)
        rank = {"healthy": 0, "mixed": 1, "unchecked": 2, "unhealthy": 3}
        rows.sort(key=lambda item: (rank.get(item["health"], 9), item["provider"]))
        counts = {
            "providers": len(rows),
            "models": len(merged),
            "healthy": sum(item["healthy"] for item in rows),
            "unhealthy": sum(item["unhealthy"] for item in rows),
            "unchecked": sum(item["unchecked"] for item in rows),
        }
        return {
            "schema": "fm-fleet-ui.models.v1",
            "generated": iso_now(),
            "available": True,
            "as_of": as_of,
            "providers": rows,
            "counts": counts,
        }
    return cached_read("models", MODELS_CACHE_TTL, load, force)


def capacity_payload(force=False):
    def load():
        try:
            proc = subprocess.run(
                [CAPACITY, "--json"],
                capture_output=True,
                env=snapshot_env(),
                timeout=30,
            )
        except Exception as exc:  # noqa: BLE001 - surface the failure as JSON
            return {"schema": "fm-fleet-ui.capacity.v1", "generated": iso_now(), "available": False, "error": str(exc), "capacity": None, "summary": {}}
        if proc.returncode != 0:
            return {"schema": "fm-fleet-ui.capacity.v1", "generated": iso_now(), "available": False, "error": proc.stderr.decode("utf-8", errors="replace").strip() or "fm-capacity.sh failed", "capacity": None, "summary": {}}
        try:
            data = json.loads(proc.stdout.decode("utf-8", errors="replace"))
        except json.JSONDecodeError as exc:
            return {"schema": "fm-fleet-ui.capacity.v1", "generated": iso_now(), "available": False, "error": str(exc), "capacity": None, "summary": {}}
        pressure = data.get("pressure") or {}
        avail = pressure.get("avail_gb")
        total = pressure.get("total_gb")
        free_pct = round((avail / total) * 100, 1) if isinstance(avail, (int, float)) and isinstance(total, (int, float)) and total else None
        kinds = meta_kinds()
        snapshot = SNAPSHOT_CACHE.get("payload")
        active_workers = None
        if snapshot:
            active_workers = sum(
                1 for task in snapshot.get("tasks") or []
                if task.get("kind") != "secondmate"
                and ((task.get("current_state") or {}).get("state") == "working")
            )
        return {
            "schema": "fm-fleet-ui.capacity.v1",
            "generated": iso_now(),
            "available": True,
            "capacity": data,
            "summary": {
                "running_workers": ((data.get("lanes") or {}).get("count")),
                "task_records": kinds.get("total"),
                "secondmates": kinds.get("secondmates"),
                "active_workers": active_workers,
                "ram_available_gb": avail,
                "ram_total_gb": total,
                "ram_free_pct": free_pct,
                "load1": pressure.get("load1"),
                "cores": os.cpu_count(),
                "verdict": data.get("verdict"),
                "cap": data.get("cap"),
                "machine": data.get("machine"),
                "uptime_s": data.get("uptime_s"),
            },
        }
    return cached_read("capacity", CAPACITY_CACHE_TTL, load, force)


PR_JSON_FIELDS = "number,title,url,state,isDraft,mergeable,mergeStateStatus,reviewDecision,createdAt,updatedAt,headRefName,baseRefName,statusCheckRollup"
PR_URL_RE = re.compile(r"^https?://[^/]+/([^/]+)/([^/]+)/pull/(\d+)")


def pr_status_rank(status):
    return {
        "conflict": 0,
        "failing": 1,
        "pending": 2,
        "ready": 3,
        "draft": 4,
        "merged": 5,
        "closed": 6,
        "error": 7,
        "unknown": 8,
    }.get(status, 9)


def pr_check_rollup(rollup):
    passed = failed = pending = 0
    failed_names = []
    for item in rollup or []:
        if "conclusion" in item or item.get("__typename") == "CheckRun":
            status = item.get("status")
            conclusion = item.get("conclusion")
            name = item.get("name") or "check"
            if status and status != "COMPLETED":
                pending += 1
            elif conclusion in ("SUCCESS", "NEUTRAL", "SKIPPED"):
                passed += 1
            elif conclusion in ("FAILURE", "CANCELLED", "TIMED_OUT", "ACTION_REQUIRED", "STALE"):
                failed += 1
                failed_names.append(name)
            else:
                pending += 1
        else:
            state = item.get("state")
            name = item.get("context") or item.get("name") or "status"
            if state == "SUCCESS":
                passed += 1
            elif state in ("FAILURE", "ERROR"):
                failed += 1
                failed_names.append(name)
            elif state == "PENDING":
                pending += 1
            else:
                pending += 1
    total = passed + failed + pending
    if total:
        label = "%d passed, %d failed, %d pending" % (passed, failed, pending)
    else:
        label = "No checks configured"
    return {
        "passed": passed,
        "failed": failed,
        "pending": pending,
        "total": total,
        "label": label,
        "failed_names": failed_names[:10],
    }


def pr_entry_base(url, task_ids, projects):
    match = PR_URL_RE.match(url or "")
    number = None
    owner = None
    repo = None
    if match:
        owner, repo, number = match.group(1), match.group(2), int(match.group(3))
    project = projects.get(next(iter(task_ids), "")) if task_ids else None
    if not project or project == "firstmate":
        project = repo
    return {
        "url": url,
        "number": number,
        "owner": owner,
        "repo": repo,
        "repo_name": "%s/%s" % (owner, repo) if owner and repo else None,
        "task_ids": sorted(task_ids),
        "project": project,
        "title": None,
        "state": "unknown",
        "draft": False,
        "checks": {"passed": 0, "failed": 0, "pending": 0, "total": 0, "label": "Not checked", "failed_names": []},
        "mergeable": None,
        "merge_state": None,
        "conflict": False,
        "review_decision": None,
        "head_ref": None,
        "base_ref": None,
        "age_seconds": None,
        "updated_age_seconds": None,
        "created_at": None,
        "updated_at": None,
        "status": "error",
        "error": None,
    }


def fetch_pr(gh_binary, url, task_ids, projects):
    base = pr_entry_base(url, task_ids, projects)
    if not gh_binary:
        base["error"] = "GitHub CLI (gh) not found"
        return base
    if not base["owner"] or not base["repo"] or base["number"] is None:
        base["error"] = "could not parse pull request URL"
        return base
    try:
        proc = subprocess.run(
            [gh_binary, "pr", "view", str(base["number"]), "-R", "%s/%s" % (base["owner"], base["repo"]), "--json", PR_JSON_FIELDS],
            capture_output=True,
            env=os.environ.copy(),
            timeout=30,
        )
    except Exception as exc:  # noqa: BLE001 - surface the failure as JSON
        base["error"] = str(exc)
        return base
    if proc.returncode != 0:
        base["error"] = proc.stderr.decode("utf-8", errors="replace").strip() or "gh pr view failed"
        return base
    try:
        data = json.loads(proc.stdout.decode("utf-8", errors="replace"))
    except json.JSONDecodeError as exc:
        base["error"] = "gh returned invalid JSON: %s" % exc
        return base
    now = time.time()
    created = parse_iso(data.get("createdAt"))
    updated = parse_iso(data.get("updatedAt"))
    state = (data.get("state") or "").upper()
    mergeable = (data.get("mergeable") or "").upper()
    merge_state = (data.get("mergeStateStatus") or "").upper()
    checks = pr_check_rollup(data.get("statusCheckRollup"))
    conflict = mergeable == "CONFLICTING" or merge_state == "DIRTY"
    if state == "MERGED":
        status = "merged"
    elif state == "CLOSED":
        status = "closed"
    elif data.get("isDraft"):
        status = "draft"
    elif conflict:
        status = "conflict"
    elif checks["failed"]:
        status = "failing"
    elif checks["pending"]:
        status = "pending"
    elif mergeable == "MERGEABLE" and merge_state == "CLEAN":
        status = "ready"
    else:
        status = (merge_state.lower() or "unknown")
    base.update({
        "title": data.get("title"),
        "state": state.lower(),
        "draft": bool(data.get("isDraft")),
        "checks": checks,
        "mergeable": mergeable or None,
        "merge_state": merge_state or None,
        "conflict": conflict,
        "review_decision": data.get("reviewDecision") or None,
        "head_ref": data.get("headRefName"),
        "base_ref": data.get("baseRefName"),
        "age_seconds": int(now - created) if created and created <= now else None,
        "updated_age_seconds": int(now - updated) if updated and updated <= now else None,
        "created_at": data.get("createdAt"),
        "updated_at": data.get("updatedAt"),
        "status": status,
        "error": None,
    })
    return base


def prs_payload(force=False):
    snapshot = snapshot_payload(force)
    task_urls = collections.defaultdict(set)
    projects = {}
    for task in snapshot.get("tasks") or []:
        url = clean_url((task.get("pr") or {}).get("url"))
        if url:
            task_urls[url].add(task.get("id"))
            projects.setdefault(task.get("id"), task_summary(task)["project_name"])
    for record in ((snapshot.get("backlog") or {}).get("records") or []):
        url = clean_url(record.get("pr_url"))
        if url:
            task_urls[url].add(record.get("id"))
            projects.setdefault(record.get("id"), record.get("repo"))
    urls = sorted(task_urls)
    if not urls:
        return {
            "schema": "fm-fleet-ui.prs.v1",
            "generated": iso_now(),
            "available": bool(shutil.which("gh")),
            "error": None if shutil.which("gh") else "GitHub CLI (gh) not found",
            "counts": {"total": 0, "open": 0, "ready": 0, "failing": 0, "pending": 0, "conflict": 0, "merged": 0, "closed": 0, "draft": 0, "error": 0},
            "prs": [],
        }
    cache_key = "prs:" + "|".join(urls)
    if not force:
        hit = cache_get(cache_key, PR_CACHE_TTL)
        if hit is not None:
            return hit
    gh_binary = shutil.which("gh")
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        futures = [pool.submit(fetch_pr, gh_binary, url, task_urls[url], projects) for url in urls]
        rows = [future.result() for future in futures]
    rows.sort(key=lambda item: (pr_status_rank(item["status"]), -(item.get("age_seconds") or 0), item.get("url") or ""))
    counts = collections.Counter(item["status"] for item in rows)
    payload = {
        "schema": "fm-fleet-ui.prs.v1",
        "generated": iso_now(),
        "available": bool(gh_binary),
        "error": None if gh_binary else "GitHub CLI (gh) not found",
        "counts": {
            "total": len(rows),
            "open": sum(1 for item in rows if item["state"] == "open"),
            "ready": counts.get("ready", 0),
            "failing": counts.get("failing", 0),
            "pending": counts.get("pending", 0),
            "conflict": counts.get("conflict", 0),
            "merged": counts.get("merged", 0),
            "closed": counts.get("closed", 0),
            "draft": counts.get("draft", 0),
            "error": counts.get("error", 0),
        },
        "prs": rows,
    }
    cache_set(cache_key, payload)
    return payload


def task_detail_payload(task_id):
    if not ID_RE.match(task_id):
        return None
    meta = meta_values(task_id)
    status_path = os.path.join(STATE, task_id + ".status")
    rows = parse_status(read_text(status_path))
    now = time.time()
    latest_blocked = event_with_age(first_event_for(rows, {"blocked"}), now)
    latest_decision = event_with_age(first_event_for(rows, {"needs-decision"}), now)
    latest_paused = event_with_age(first_event_for(rows, {"paused", "parked"}), now)
    latest_event = event_with_age(rows[-1] if rows else None, now)
    relevant = [event for event in (latest_blocked, latest_decision, latest_paused) if event]
    relevant.sort(key=lambda event: event.get("at") or 0, reverse=True)
    headline = relevant[0] if relevant else latest_event
    latest_text = (headline or {}).get("note") or ""
    snapshot = None
    if SNAPSHOT_CACHE["payload"] is not None:
        snapshot = SNAPSHOT_CACHE["payload"]
    task = None
    backlog_record = None
    if snapshot:
        for candidate in snapshot.get("tasks") or []:
            if candidate.get("id") == task_id:
                task = candidate
                break
        for record in ((snapshot.get("backlog") or {}).get("records") or []):
            if record.get("id") == task_id:
                backlog_record = record
                break
    if task is None:
        task = {
            "id": task_id,
            "kind": meta.get("kind") or "ship",
            "harness": meta.get("harness"),
            "mode": meta.get("mode"),
            "yolo": meta.get("yolo"),
            "branch": meta.get("branch"),
            "model": meta.get("model"),
            "effort": meta.get("effort"),
            "project": meta.get("project"),
            "pr": {"url": meta.get("pr")},
            "current_state": {"state": (latest_event or {}).get("state") or "unknown"},
            "endpoint": {"status": "unknown"},
            "paths": {"report": {"present": os.path.isfile(os.path.join(DATA, task_id, "report.md")), "path": os.path.join(DATA, task_id, "report.md")}},
            "backlog": {},
        }
    decision_key = None
    for event in (latest_decision, latest_blocked):
        if event and event.get("key"):
            decision_key = event["key"]
            break
    if not decision_key:
        for decision in ((task.get("hints") or {}).get("open_decisions") or []):
            if decision.get("key"):
                decision_key = decision.get("key")
                break
    decision_age = None
    for event in (latest_decision, latest_blocked):
        if event and event.get("age_seconds") is not None:
            decision_age = event["age_seconds"]
            break
    backlog_payload_row = None
    if backlog_record:
        backlog_payload_row = {
            "id": backlog_record.get("id"),
            "title": backlog_record.get("title"),
            "state": backlog_record.get("state"),
            "bucket": backlog_bucket(backlog_record),
            "hold_reason": backlog_record.get("hold_reason"),
            "hold_until": backlog_record.get("hold_until"),
            "hold_kind": backlog_record.get("hold_kind"),
            "hold_bucket": backlog_record.get("hold_bucket"),
            "hold_age_days": backlog_record.get("hold_age_days"),
            "captain_actionable": bool(backlog_record.get("captain_actionable")),
            "blocked_reason": backlog_record.get("blocked_reason"),
            "blocked_by_ids": backlog_record.get("blocked_by_ids") or [],
            "unresolved_blocker_ids": backlog_record.get("unresolved_blocker_ids") or [],
            "body_excerpt": backlog_record.get("body_excerpt"),
        }
    pr_url = clean_url((task.get("pr") or {}).get("url")) or clean_url(meta.get("pr"))
    if not pr_url:
        for event in reversed(rows):
            note = event.get("note") or ""
            if "/pull/" not in note:
                continue
            match = re.search(r"https?://[^\s<>\"')]+/pull/\d+", note)
            if match:
                pr_url = clean_url(match.group(0))
                if pr_url:
                    break
    board_url = first_session_url(latest_text)
    if not board_url:
        board_url = task_session_url(task)
    link_url = first_board_url(latest_text)
    if not link_url:
        link_url = task_any_url(task)
    report_path = os.path.join(DATA, task_id, "report.md")
    report_present = os.path.isfile(report_path)
    recent = []
    for row in reversed(rows[-12:]):
        event = event_with_age(row, now)
        if event:
            recent.append(event)
    return {
        "schema": "fm-fleet-ui.task-detail.v1",
        "generated": iso_now(),
        "id": task_id,
        "task": task_summary(task),
        "meta": {
            "window": meta.get("window"),
            "project": meta.get("project"),
            "worktree": meta.get("worktree"),
            "harness": meta.get("harness"),
            "kind": meta.get("kind"),
            "mode": meta.get("mode"),
            "yolo": meta.get("yolo"),
            "branch": meta.get("branch"),
            "model": meta.get("model"),
            "effort": meta.get("effort"),
            "backend": meta.get("backend"),
            "spawn_gen": meta.get("spawn_gen"),
            "pr": meta.get("pr"),
            "pr_head": meta.get("pr_head"),
        },
        "latest": {
            "event": latest_event,
            "blocked": latest_blocked,
            "needs_decision": latest_decision,
            "paused": latest_paused,
            "headline": headline,
            "headline_text": latest_text,
        },
        "decision": {
            "key": decision_key,
            "age_seconds": decision_age,
        },
        "waiting_on": waiting_on(latest_text),
        "paused_until": paused_until((latest_paused or {}).get("note") or latest_text),
        "recent_events": recent,
        "backlog": backlog_payload_row,
        "links": {
            "pr": pr_url,
            "report": "/api/report?id=" + urllib.parse.quote(task_id) if report_present else None,
            "board": board_url,
            "link": link_url,
        },
        "report_present": report_present,
        "report_path": report_path if report_present else None,
        "status_path": status_path,
    }


def report_payload(task_id):
    if not ID_RE.match(task_id):
        return None
    path = os.path.join(DATA, task_id, "report.md")
    text = read_text(path)
    if text is None:
        return None
    truncated = len(text) > 200000
    return {
        "id": task_id,
        "present": True,
        "path": path,
        "mtime": mtime(path),
        "truncated": truncated,
        "content": text[:200000],
    }


def memories_payload():
    files = []
    for key, label, name, optional in MEMORY_FILES:
        path = os.path.join(DATA, name)
        present = os.path.isfile(path)
        files.append({
            "key": key,
            "label": label,
            "name": name,
            "optional": optional,
            "present": present,
            "content": read_text(path) if present else None,
            "mtime": mtime(path) if present else None,
        })
    return {"files": files}


def task_status_payload(task_id):
    if not ID_RE.match(task_id):
        return None
    path = os.path.join(STATE, task_id + ".status")
    text = read_text(path)
    if text is None:
        return {"id": task_id, "present": False, "lines": []}
    rows = parse_status(text)
    rows.reverse()
    return {"id": task_id, "present": True, "path": path, "lines": rows}



DECISION_PAGE_CSS = """
  :root { color-scheme: light; }
  * { box-sizing: border-box; }
  html, body { margin: 0; background: #f4f6f8; color: #18212b; }
  body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; font-size: 15px; line-height: 1.55; }
  .wrap { max-width: 860px; margin: 0 auto; padding: 28px 20px 48px; }
  .kicker { text-transform: uppercase; letter-spacing: .08em; font-size: 11px; font-weight: 700; color: #5f6b7a; }
  h1 { font-size: 22px; margin: 6px 0 4px; overflow-wrap: anywhere; }
  .sub { color: #3f4b5a; margin: 0 0 18px; overflow-wrap: anywhere; }
  .card { background: #fff; border: 1px solid #dbe1e8; border-radius: 14px; padding: 16px 20px; box-shadow: 0 1px 2px rgba(16,24,40,.05), 0 10px 28px rgba(16,24,40,.07); }
  .row { display: grid; grid-template-columns: minmax(0, 140px) minmax(0, 1fr); gap: 6px 14px; padding: 5px 0; border-bottom: 1px solid #eef1f4; }
  .row:last-child { border-bottom: 0; }
  .label { color: #5f6b7a; font-size: 12.5px; }
  .row > span { min-width: 0; overflow-wrap: anywhere; }
  h2 { font-size: 13px; text-transform: uppercase; letter-spacing: .05em; color: #5f6b7a; margin: 22px 0 8px; }
  .question { font-size: 17px; margin: 0; white-space: pre-wrap; overflow-wrap: anywhere; }
  ul { list-style: none; padding: 0; margin: 0; display: grid; gap: 8px; }
  li { display: grid; grid-template-columns: 26px minmax(0, 1fr); gap: 8px; background: #f8fafc; border: 1px solid #eef1f4; border-radius: 10px; padding: 10px 12px; }
  li > span { min-width: 0; overflow-wrap: anywhere; }
  .opt-label { font-weight: 700; color: #1d4ed8; }
  .links { display: flex; flex-wrap: wrap; gap: 10px; margin-top: 10px; }
  .links a { color: #1d4ed8; }
  .muted { color: #5f6b7a; }
  .note { margin-top: 18px; background: #fffbeb; border: 1px solid #fde68a; color: #92400e; border-radius: 10px; padding: 10px 12px; }
  footer { margin-top: 22px; color: #6b7789; font-size: 12.5px; display: flex; flex-wrap: wrap; gap: 6px 16px; }
  code { font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; overflow-wrap: anywhere; }
"""


def escape_html(value):
    return (
        str(value if value is not None else "")
        .replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
    )


def decision_slug(index, task_id, key):
    base = "%02d-%s-%s" % (index + 1, task_id or "task", key or "default")
    slug = re.sub(r"[^A-Za-z0-9._-]+", "-", base).strip("-")
    return (slug or "decision")[:120]


def decision_review_page(decision, generated):
    task = decision.get("task") or {}
    question = decision.get("question") or decision.get("summary") or ""
    options = decision.get("options") or []
    links = []
    for label, url in (("Review board", decision.get("board_url")), ("Related link", decision.get("link_url"))):
        if url and url not in [existing for _, existing in links]:
            links.append((label, url))
    if options:
        option_html = "".join(
            '<li><span class="opt-label">(%s)</span><span>%s</span></li>'
            % (escape_html(option.get("label")), escape_html(option.get("text")))
            for option in options
        )
    else:
        option_html = (
            '<li><span class="opt-label">-</span><span class="muted">No explicit options were '
            "recorded. Answer this call through the task or its review board.</span></li>"
        )
    rows = (
        ("Task", task.get("id") or "unknown"),
        ("Project", task.get("project_name") or task.get("project") or "unknown"),
        ("State", task.get("state") or "unknown"),
        ("Kind", "Blocker" if decision.get("verb") == "blocked" else "Needs decision"),
        ("Key", decision.get("key") or "default"),
        ("Impact", "%s - %s" % (decision.get("impact") or "unranked", decision.get("impact_reason") or "no reason recorded")),
        ("Open for", human_age(decision.get("age_seconds"))),
        ("Opened at", decision.get("opened_at") or "unknown"),
    )
    row_html = "".join(
        '<div class="row"><span class="label">%s</span><span>%s</span></div>' % (label, escape_html(value))
        for label, value in rows
    )
    if links:
        link_html = '<div class="links">%s</div>' % "".join(
            '<a href="%s" target="_blank" rel="noopener noreferrer">%s</a>' % (escape_html(url), escape_html(label))
            for label, url in links
        )
    else:
        link_html = ""
    subtitle = " - ".join(part for part in (task.get("project_name"), decision.get("key") or "") if part)
    return """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Open call - %(title)s</title>
<style>%(css)s</style>
</head>
<body>
<div class="wrap">
  <div class="kicker">Firstmate fleet - open captain call</div>
  <h1>%(heading)s</h1>
  <p class="sub">%(sub)s</p>
  <div class="card">%(rows)s</div>
  <h2>Question</h2>
  <div class="card"><p class="question">%(question)s</p></div>
  <h2>Recorded options</h2>
  <ul>%(options)s</ul>
  %(links)s
  <div class="note">Read-only page: it never answers, resolves, or acknowledges this call. Answer it in the fleet chat or the task's own review board.</div>
  <footer>
    <span>Home: <code>%(home)s</code></span>
    <span>Built %(generated)s</span>
    <span>Editor: <code>lavish-axi &lt;this file&gt;</code></span>
  </footer>
</div>
</body>
</html>
""" % {
        "title": escape_html(task.get("id") or "decision"),
        "heading": escape_html(task.get("title") or task.get("id") or "Open captain call"),
        "sub": escape_html(subtitle or "Fleet decision"),
        "css": DECISION_PAGE_CSS,
        "rows": row_html,
        "question": escape_html(question),
        "options": option_html,
        "links": link_html,
        "home": escape_html(FM_HOME),
        "generated": escape_html(generated or iso_now()),
    }


def run_lavish_axi(path):
    try:
        proc = subprocess.run(["lavish-axi", path], capture_output=True, timeout=120)
    except (OSError, subprocess.SubprocessError):
        return None
    if proc.returncode != 0:
        return None
    match = re.search(r'url:\s*"?(https?://[^\s"]+)', proc.stdout.decode("utf-8", errors="replace"))
    return match.group(1).rstrip('"') if match else None


def attach_decision_reviews(errors):
    text = read_text(os.path.join(OUT, "data", "decisions.json"))
    if text is None:
        return
    try:
        payload = json.loads(text)
    except json.JSONDecodeError:
        return
    decisions = payload.get("decisions") if isinstance(payload, dict) else None
    if not isinstance(decisions, list):
        return
    directory = os.path.join(OUT, "decisions")
    os.makedirs(directory, exist_ok=True)
    generated = payload.get("generated")
    changed = False
    for index, decision in enumerate(decisions):
        if not isinstance(decision, dict):
            continue
        task = decision.get("task") or {}
        name = decision_slug(index, task.get("id"), decision.get("key")) + ".html"
        page = os.path.join(directory, name)
        try:
            with open(page, "w", encoding="utf-8") as handle:
                handle.write(decision_review_page(decision, generated))
        except OSError as exc:
            errors.append({"panel": "decision-review:" + name, "detail": str(exc)})
            continue
        decision["review"] = "decisions/" + name
        changed = True
        if LAVISH:
            decision["lavish_url"] = run_lavish_axi(page)
    if changed:
        payload["review_count"] = len(decisions)
        write_json("decisions", payload)

import sys


MODE = os.environ["FM_FLEET_UI_MODE"]
OUT = os.path.abspath(os.environ["FM_FLEET_UI_OUT"])
NO_BUILD = os.environ["FM_FLEET_UI_NO_BUILD"] == "1"


def write_json(name, payload):
    path = os.path.join(OUT, "data", name + ".json")
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2, sort_keys=False)
        handle.write("\n")
    return path


def write_panel(name, builder, generated, errors):
    try:
        payload = builder()
    except Exception as exc:  # noqa: BLE001 - a failed panel must stay viewable
        payload = {
            "available": False,
            "error": "This panel could not be built from the last sources.",
            "detail": str(exc),
        }
        errors.append({"panel": name, "detail": str(exc)})
    if not isinstance(payload, dict):
        payload = {"available": True, "data": payload}
    payload.setdefault("available", True)
    payload.setdefault("generated", generated)
    write_json(name, payload)
    return payload


def prepare_output():
    os.makedirs(OUT, exist_ok=True)
    marker = os.path.join(OUT, ".fm-fleet-ui")
    if not os.path.exists(marker):
        existing = [name for name in os.listdir(OUT) if not name.startswith(".")]
        if existing:
            raise SystemExit(
                "fm-fleet-ui: refusing to write into a non-empty directory without "
                ".fm-fleet-ui marker: %s" % OUT
            )
        with open(marker, "w", encoding="utf-8") as handle:
            handle.write("generated by bin/fm-fleet-ui.sh; safe to delete\n")
    data_dir = os.path.join(OUT, "data")
    reports_dir = os.path.join(OUT, "reports")
    decisions_dir = os.path.join(OUT, "decisions")
    for directory in (data_dir, reports_dir, decisions_dir):
        if os.path.isdir(directory):
            shutil.rmtree(directory)
        os.makedirs(directory)
    shutil.copyfile(INDEX, os.path.join(OUT, "index.html"))


def build_lock_path():
    return os.path.join(STATE, ".fm-fleet-ui-build.lock")


def release_build_lock(handle):
    if handle is None:
        return
    try:
        fcntl.flock(handle.fileno(), fcntl.LOCK_UN)
    except OSError:
        pass
    try:
        handle.close()
    except OSError:
        pass


def acquire_build_lock():
    try:
        os.makedirs(STATE, exist_ok=True)
        handle = open(build_lock_path(), "w", encoding="utf-8")
    except OSError as exc:  # noqa: BLE001 - surface as a skip
        raise SystemExit("fm-fleet-ui: cannot create build lock: %s" % exc)
    try:
        fcntl.flock(handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        handle.close()
        return None
    handle.write(str(os.getpid()) + "\n")
    handle.flush()
    return handle


def build_dashboard():
    lock = acquire_build_lock()
    if lock is None:
        print("fm-fleet-ui: build skipped, another build is running", flush=True)
        return 0
    prepare_output()
    generated = iso_now()
    errors = []

    try:
        snapshot = snapshot_payload(True)
    except Exception as exc:  # noqa: BLE001 - the snapshot panel stays viewable
        snapshot = {
            "available": False,
            "error": "The fleet snapshot could not be built.",
            "detail": str(exc),
        }
        errors.append({"panel": "snapshot", "detail": str(exc)})
    if not isinstance(snapshot, dict):
        snapshot = {"available": True, "data": snapshot}
    snapshot.setdefault("available", True)
    snapshot.setdefault("generated", generated)
    write_json("snapshot", snapshot)

    snapshot_panels = (
        ("decisions", lambda: decisions_payload(True)),
        ("stuck", lambda: stuck_payload(True)),
        ("backlog", lambda: backlog_payload(True)),
        ("secondmates", lambda: secondmates_payload(True)),
        ("activity", lambda: activity_payload(True)),
    )
    for name, builder in snapshot_panels:
        write_panel(name, builder, generated, errors)

    attach_decision_reviews(errors)

    independent_panels = (
        ("prs", lambda: prs_payload(True)),
        ("capacity", lambda: capacity_payload(True)),
        ("away", lambda: away_payload()),
        ("reviews", lambda: reviews_payload(True)),
        ("quota", lambda: quota_payload(True)),
        ("models", lambda: models_payload(True)),
        ("memories", lambda: memories_payload()),
    )
    for name, builder in independent_panels:
        write_panel(name, builder, generated, errors)

    details = {}
    tasks = snapshot.get("tasks") if isinstance(snapshot, dict) else []
    if isinstance(tasks, list):
        for task in tasks:
            task_id = task.get("id") if isinstance(task, dict) else None
            if not task_id:
                continue
            try:
                detail = task_detail_payload(task_id)
            except Exception as exc:  # noqa: BLE001 - one task must not break the build
                detail = {
                    "id": task_id,
                    "available": False,
                    "error": "Task detail could not be built.",
                    "detail": str(exc),
                }
                errors.append({"panel": "task-detail:" + task_id, "detail": str(exc)})
            if detail is None:
                detail = {
                    "id": task_id,
                    "available": False,
                    "error": "Task detail was not available.",
                }
            links = detail.get("links")
            if isinstance(links, dict) and links.get("report"):
                links["report"] = "reports/%s.md" % task_id
            details[task_id] = detail
            report_source = os.path.join(DATA, task_id, "report.md")
            if os.path.isfile(report_source):
                try:
                    shutil.copyfile(report_source, os.path.join(OUT, "reports", task_id + ".md"))
                except OSError as exc:
                    errors.append({"panel": "report:" + task_id, "detail": str(exc)})

    write_json(
        "task-details",
        {"available": True, "generated": generated, "details": details},
    )
    write_json(
        "meta",
        {
            "schema": "fm-fleet-ui.meta.v1",
            "version": VERSION,
            "home": FM_HOME,
            "out": OUT,
            "generated": generated,
            "read_only": True,
            "refresh_command": "bin/fm-fleet-ui.sh build",
            "errors": errors,
        },
    )

    print("fm-fleet-ui: built static dashboard in %s" % OUT, flush=True)
    print("fm-fleet-ui: data as of %s" % generated, flush=True)
    if errors:
        print(
            "fm-fleet-ui: %d panel(s) unavailable in this build" % len(errors),
            flush=True,
        )
        for error in errors:
            print(
                "fm-fleet-ui:   %s: %s" % (error.get("panel"), error.get("detail")),
                file=sys.stderr,
                flush=True,
            )
    print(
        "fm-fleet-ui: serve with: %s serve --out %s --host 127.0.0.1 --port 8765"
        % (os.path.join(FM_ROOT, "bin", "fm-fleet-ui.sh"), OUT),
        flush=True,
    )
    return 0


def serve_dashboard():
    if not loopback(HOST) and not HOST_EXPLICIT:
        raise SystemExit(
            "fm-fleet-ui: refusing non-loopback host %r without an explicit --host" % HOST
        )
    if not NO_BUILD:
        build_dashboard()
    index = os.path.join(OUT, "index.html")
    if not os.path.isfile(index):
        raise SystemExit(
            "fm-fleet-ui: missing built dashboard: %s (run build first)" % index
        )
    url = "http://%s:%d/" % (HOST, PORT)
    print("fm-fleet-ui: serving %s at %s" % (OUT, url), flush=True)
    # The Shipcat Rust fleet host owns the HTTP server. It serves the directory
    # we just built, so it must not rebuild on startup.
    command = [
        FLEET_HOST_BIN,
        "serve",
        "--no-build",
        "--out",
        OUT,
        "--host",
        HOST,
        "--port",
        str(PORT),
    ]
    process = subprocess.Popen(command)

    def shutdown(signum=None, frame=None):
        # A signal handler runs on the main thread, which may already be blocked
        # inside Popen.wait(); any Popen call here re-enters its wait lock and
        # hangs. Signal the child directly and let the parent exit.
        try:
            os.kill(process.pid, signal.SIGTERM)
        except OSError:
            pass
        raise SystemExit(0)

    signal.signal(signal.SIGTERM, shutdown)
    if OPEN:
        def open_browser():
            time.sleep(0.5)
            try:
                webbrowser.open(url)
            except Exception:  # noqa: BLE001 - opening is best-effort
                pass

        threading.Thread(target=open_browser, daemon=True).start()
    try:
        return process.wait()
    except KeyboardInterrupt:
        shutdown()


def install_refresh():
    label = "com.kayisrahman.fm-fleet-ui-refresh"
    plist_path = os.path.expanduser("~/Library/LaunchAgents/%s.plist" % label)
    os.makedirs(os.path.dirname(plist_path), exist_ok=True)
    cli = os.path.abspath(os.path.join(FM_ROOT, "bin", "fm-fleet-ui.sh"))
    stdout_log = os.path.join(FM_HOME, "state", "fleet-ui-refresh.stdout.log")
    stderr_log = os.path.join(FM_HOME, "state", "fleet-ui-refresh.stderr.log")
    content = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>%s</string>
  <key>ProgramArguments</key>
  <array>
    <string>%s</string>
    <string>build</string>
  </array>
  <key>StartInterval</key>
  <integer>60</integer>
  <key>RunAtLoad</key>
  <true/>
  <key>Nice</key>
  <integer>10</integer>
  <key>EnvironmentVariables</key>
  <dict>
    <key>FM_HOME</key>
    <string>%s</string>
  </dict>
  <key>StandardOutPath</key>
  <string>%s</string>
  <key>StandardErrorPath</key>
  <string>%s</string>
</dict>
</plist>
""" % (label, cli, FM_HOME, stdout_log, stderr_log)
    with open(plist_path, "w", encoding="utf-8") as handle:
        handle.write(content)
    print("fm-fleet-ui: label %s" % label, flush=True)
    print("fm-fleet-ui: plist %s" % plist_path, flush=True)
    print("fm-fleet-ui: load with: launchctl load %s" % plist_path, flush=True)
    return 0


def uninstall_refresh():
    label = "com.kayisrahman.fm-fleet-ui-refresh"
    plist_path = os.path.expanduser("~/Library/LaunchAgents/%s.plist" % label)
    try:
        os.remove(plist_path)
    except FileNotFoundError:
        pass
    print("fm-fleet-ui: removed %s" % plist_path, flush=True)
    print("fm-fleet-ui: unload first with: launchctl unload %s (if loaded)" % plist_path, flush=True)
    return 0


def main():
    if MODE == "build":
        return build_dashboard()
    if MODE == "install-refresh":
        return install_refresh()
    if MODE == "uninstall-refresh":
        return uninstall_refresh()
    if MODE == "serve":
        return serve_dashboard()
    raise SystemExit("fm-fleet-ui: unknown mode: %s" % MODE)


if __name__ == "__main__":
    sys.exit(main())
PY
