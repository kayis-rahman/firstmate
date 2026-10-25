#!/usr/bin/env bash
# fm-fleet-ui.sh - read-only local web UI for the firstmate fleet ledger.
#
# Serves assets/fleet-ui/index.html and a small JSON API from the resolved home.
# Every request reads live state; nothing is cached and nothing is written.
#
# Routes:
#   GET /               the static page from assets/fleet-ui/index.html
#   GET /api/snapshot   bin/fm-fleet-snapshot.sh --json output, unchanged
#   GET /api/memories   data/captain.md, data/captain-shared.md, data/learnings.md
#   GET /api/health     {version, home}
#   GET /api/task-status?id=<id>  recent status-log lines, newest first
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
FM_HOME="${FM_HOME:-${FM_ROOT_OVERRIDE:-$FM_ROOT}}"
STATE="${FM_STATE_OVERRIDE:-$FM_HOME/state}"
DATA="${FM_DATA_OVERRIDE:-$FM_HOME/data}"
CONFIG="${FM_CONFIG_OVERRIDE:-$FM_HOME/config}"
ASSETS_DIR="$FM_ROOT/assets/fleet-ui"
INDEX_FILE="$ASSETS_DIR/index.html"
SNAPSHOT_SCRIPT="$SCRIPT_DIR/fm-fleet-snapshot.sh"

HOST=""
HOST_EXPLICIT=0
PORT=8765
OPEN=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --port)
      [ "$#" -ge 2 ] || { echo "fm-fleet-ui: --port requires a value" >&2; exit 2; }
      PORT=$2; shift 2 ;;
    --host)
      [ "$#" -ge 2 ] || { echo "fm-fleet-ui: --host requires a value" >&2; exit 2; }
      HOST=$2; HOST_EXPLICIT=1; shift 2 ;;
    --open)
      OPEN=1; shift ;;
    -h|--help)
      echo "usage: fm-fleet-ui.sh [--port <n>] [--host <addr>] [--open]"; exit 0 ;;
    *)
      echo "fm-fleet-ui: unknown argument: $1" >&2; exit 2 ;;
  esac
done

# Loopback only by default. A non-loopback address is used only when the
# caller passed --host explicitly.
if [ "$HOST_EXPLICIT" -eq 0 ]; then
  HOST="127.0.0.1"
fi

if [ ! -f "$INDEX_FILE" ]; then
  echo "fm-fleet-ui: missing page: $INDEX_FILE" >&2
  exit 1
fi

export FM_ROOT FM_HOME STATE DATA CONFIG
export FM_FLEET_UI_ASSETS="$ASSETS_DIR"
export FM_FLEET_UI_INDEX="$INDEX_FILE"
export FM_FLEET_UI_SNAPSHOT="$SNAPSHOT_SCRIPT"
export FM_FLEET_UI_HOST="$HOST"
export FM_FLEET_UI_PORT="$PORT"
export FM_FLEET_UI_OPEN="$OPEN"
export FM_FLEET_UI_HOST_EXPLICIT="$HOST_EXPLICIT"

exec python3 - <<'PY'
import json
import os
import re
import socket
import socketserver
import subprocess
import threading
import time
import urllib.parse
import webbrowser
from http.server import BaseHTTPRequestHandler, HTTPServer

FM_ROOT = os.environ["FM_ROOT"]
FM_HOME = os.environ["FM_HOME"]
STATE = os.environ["STATE"]
DATA = os.environ["DATA"]
CONFIG = os.environ["CONFIG"]
ASSETS = os.environ["FM_FLEET_UI_ASSETS"]
INDEX = os.environ["FM_FLEET_UI_INDEX"]
SNAPSHOT = os.environ["FM_FLEET_UI_SNAPSHOT"]
HOST = os.environ["FM_FLEET_UI_HOST"]
PORT = int(os.environ["FM_FLEET_UI_PORT"])
OPEN = os.environ["FM_FLEET_UI_OPEN"] == "1"
HOST_EXPLICIT = os.environ["FM_FLEET_UI_HOST_EXPLICIT"] == "1"

VERSION = "fm-fleet-ui.v1"
LOOPBACK = {"127.0.0.1", "localhost", "::1", "0:0:0:0:0:0:0:1"}
ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")

MEMORY_FILES = [
    ("captain", "Captain preferences", "captain.md", False),
    ("captain_shared", "Shared captain preferences", "captain-shared.md", True),
    ("learnings", "Learnings", "learnings.md", False),
]


def loopback(host):
    if host in LOOPBACK:
        return True
    try:
        return socket.gethostbyname(host).startswith("127.")
    except OSError:
        return False


def read_text(path):
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as handle:
            return handle.read()
    except OSError:
        return None


def mtime(path):
    try:
        return os.path.getmtime(path)
    except OSError:
        return None


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


def parse_status(text):
    rows = []
    for raw in text.splitlines():
        line = raw.strip()
        if not line:
            continue
        state = ""
        at = None
        note = line
        if ":" in line:
            left, _, right = line.partition(":")
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
        rows.append({"raw": raw, "state": state, "at": at, "note": note})
    return rows


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


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def send_bytes(self, code, body, content_type):
        if isinstance(body, str):
            body = body.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        try:
            self.wfile.write(body)
        except (BrokenPipeError, ConnectionResetError):
            pass

    def send_json(self, code, payload):
        self.send_bytes(code, json.dumps(payload), "application/json; charset=utf-8")

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path

        if path == "/":
            try:
                with open(INDEX, "rb") as handle:
                    page = handle.read()
            except OSError:
                self.send_bytes(404, b"not found", "text/plain; charset=utf-8")
                return
            self.send_bytes(200, page, "text/html; charset=utf-8")
            return

        if path == "/api/health":
            self.send_json(200, {"version": VERSION, "home": FM_HOME})
            return

        if path == "/api/memories":
            self.send_json(200, memories_payload())
            return

        if path == "/api/snapshot":
            try:
                proc = subprocess.run(
                    [SNAPSHOT, "--json"],
                    capture_output=True,
                    env=os.environ.copy(),
                    timeout=300,
                )
            except Exception as exc:  # noqa: BLE001 - surface the failure as JSON
                self.send_json(500, {"error": str(exc)})
                return
            if proc.returncode != 0:
                detail = proc.stderr.decode("utf-8", errors="replace")
                self.send_json(502, {"error": "snapshot failed", "detail": detail})
                return
            self.send_bytes(200, proc.stdout, "application/json; charset=utf-8")
            return

        if path == "/api/task-status":
            query = urllib.parse.parse_qs(parsed.query)
            task_id = (query.get("id") or [""])[0]
            payload = task_status_payload(task_id)
            if payload is None:
                self.send_json(400, {"error": "invalid task id"})
                return
            self.send_json(200, payload)
            return

        self.send_json(404, {"error": "not found"})

    def log_message(self, *_args):
        pass


class ThreadedServer(socketserver.ThreadingMixIn, HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


def main():
    if not loopback(HOST) and not HOST_EXPLICIT:
        raise SystemExit(
            "fm-fleet-ui: refusing non-loopback host %r without an explicit --host" % HOST
        )
    server = ThreadedServer((HOST, PORT), Handler)
    actual_port = server.server_address[1]
    print("fm-fleet-ui: listening on http://%s:%d/" % (HOST, actual_port), flush=True)

    if OPEN:
        def open_browser():
            time.sleep(0.3)
            try:
                webbrowser.open("http://%s:%d/" % (HOST, actual_port))
            except Exception:  # noqa: BLE001 - opening is best-effort
                pass
        threading.Thread(target=open_browser, daemon=True).start()

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
PY
