#!/usr/bin/env bash
# bin/fm-decision-api.sh - thin, fail-open client for the /v1/systemone
# typed-decision API (local MLX Serve shadow mode, or TypeSafe Jev monitoring).
#
# In default mlx mode, calls ONE fixed-choice question against the local
# decision API (MLX Serve) with a hard 3-second timeout and prints a compact
# JSON object on stdout:
#   {"choice": <string>, "confidence": <number>,
#    "probabilities": {<choice>: <number>, ...}, "latency_ms": <int>}
#
# In --mode jev, queries the configured TypeSafe host (TYPESAFE_BASE,
# TYPESAFE_PATH, TYPESAFE_API_KEY via env, $FM_HOME/.env, or
# config/dispatch-credential-sources.json) with only the job name and one-line
# status, honoring config/dispatch-never-send.
# The API key is kept in a non-exported shell variable and passed to curl
# through fd 3, never argv, logs, or child environments.
#
# Any API failure (timeout, connection refused, bad key, no credit, malformed
# response) prints nothing and exits 1. A local dispatch-never-send block in
# jev mode prints nothing and exits 2 (policy skip, not an API failure).
#
# Configuration (environment or $FM_HOME/.env):
#   TYPESAFE_BASE         base URL (default http://127.0.0.1:11234 in mlx mode,
#                         https://api.typesafe.ai in jev mode)
#   TYPESAFE_PATH         request path (default /v1/systemone)
#   TYPESAFE_MODEL        model id (default aselea/Kev-4B-MLX-Serve-8bit in mlx
#                         mode, jev-latest in jev mode)
#   TYPESAFE_API_KEY      bearer token (default local-mlx-serve in mlx mode;
#                         required from env, .env, or credential source in jev)
#   FM_DECISION_TIMEOUT   hard timeout in seconds (default 3)
#
# Usage:
#   fm-decision-api.sh [--mode mlx|jev] [--context <text>]
#                      [--job <name>] [--status-line <line>]
#                      [--question <text>] [--choices a,b,...] [--timeout SEC]
# Exit status: 0 on a parsed answer, 1 on failure, 2 on usage or policy skip.

set -u

TYPESAFE_API_KEY_PRIVATE=${TYPESAFE_API_KEY:-}
export -n TYPESAFE_API_KEY_PRIVATE 2>/dev/null || true
unset TYPESAFE_API_KEY

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=bin/fm-env-lib.sh
. "$SCRIPT_DIR/fm-env-lib.sh"
# shellcheck source=bin/fm-timing-lib.sh
. "$SCRIPT_DIR/fm-timing-lib.sh"
# shellcheck source=bin/fm-credential-source-lib.sh
. "$SCRIPT_DIR/fm-credential-source-lib.sh"
# shellcheck source=bin/fm-typesafe-lib.sh
. "$SCRIPT_DIR/fm-typesafe-lib.sh"

MODE='mlx'
CONTEXT=''
JOB=''
STATUS_LINE=''
QUESTION=''
CHOICES_CSV=''
TIMEOUT="${FM_DECISION_TIMEOUT:-3}"

while [ $# -gt 0 ]; do
  case "$1" in
    --mode) MODE=${2-}; shift 2 ;;
    --context) CONTEXT=${2-}; shift 2 ;;
    --job) JOB=${2-}; shift 2 ;;
    --status-line) STATUS_LINE=${2-}; shift 2 ;;
    --question) QUESTION=${2-}; shift 2 ;;
    --choices) CHOICES_CSV=${2-}; shift 2 ;;
    --timeout) TIMEOUT=${2-}; shift 2 ;;
    *) echo "fm-decision-api: unknown arg $1" >&2; exit 2 ;;
  esac
done

case "$MODE" in
  mlx)
    [ -n "$QUESTION" ] || QUESTION='status / wake classification: is this status line captain-relevant work firstmate must surface?'
    [ -n "$CHOICES_CSV" ] || CHOICES_CSV='captain-relevant,not-captain-relevant'
    ;;
  jev)
    [ -n "$QUESTION" ] || QUESTION='monitoring notice classification: is this worker status routine progress or does it need firstmate attention?'
    [ -n "$CHOICES_CSV" ] || CHOICES_CSV='routine,needs-firstmate'
    ;;
  *)
    echo "fm-decision-api: unknown mode $MODE" >&2
    exit 2
    ;;
esac

_HOME="${FM_HOME:-}"
if [ -z "$_HOME" ]; then _HOME="${PWD}"; fi
_ENV="$_HOME/.env"
_CONFIG="${FM_CONFIG_OVERRIDE:-$_HOME/config}"

command -v curl >/dev/null 2>&1 || exit 1
command -v jq >/dev/null 2>&1 || exit 1

RAW_BASE=${TYPESAFE_BASE:-}
[ -n "$RAW_BASE" ] || RAW_BASE=$(fmx_env_get TYPESAFE_BASE "$_ENV")
RAW_PATH=${TYPESAFE_PATH:-}
[ -n "$RAW_PATH" ] || RAW_PATH=$(fmx_env_get TYPESAFE_PATH "$_ENV")
RAW_MODEL=${TYPESAFE_MODEL:-}
[ -n "$RAW_MODEL" ] || RAW_MODEL=$(fmx_env_get TYPESAFE_MODEL "$_ENV")

if [ -z "$TYPESAFE_API_KEY_PRIVATE" ]; then
  TYPESAFE_API_KEY_PRIVATE=$(fmx_env_get TYPESAFE_API_KEY "$_ENV")
fi

if [ "$MODE" = jev ]; then
  if [ -z "$TYPESAFE_API_KEY_PRIVATE" ]; then
    fm_typesafe_read_declared_key "$_CONFIG/dispatch-credential-sources.json" typesafe TYPESAFE_API_KEY_PRIVATE typesafe openrouter || exit 1
  fi
  [ -n "$TYPESAFE_API_KEY_PRIVATE" ] || exit 1
  if [ -n "$RAW_BASE" ]; then
    BASE=$(fm_typesafe_validate_base "$RAW_BASE") || exit 1
  else
    BASE='https://api.typesafe.ai'
  fi
  if [ -n "$RAW_PATH" ]; then
    REQ_PATH=$(fm_typesafe_validate_path "$RAW_PATH") || exit 1
  else
    REQ_PATH='/v1/systemone'
  fi
  MODEL="${RAW_MODEL:-jev-latest}"
else
  BASE="${RAW_BASE:-http://127.0.0.1:11234}"
  BASE="${BASE%/}"
  REQ_PATH='/v1/systemone'
  MODEL="${RAW_MODEL:-aselea/Kev-4B-MLX-Serve-8bit}"
  if [ -z "$TYPESAFE_API_KEY_PRIVATE" ]; then
    TYPESAFE_API_KEY_PRIVATE='local-mlx-serve'
  fi
fi

ENDPOINT="${BASE}${REQ_PATH}"

IFS=',' read -ra CHOICE_ARR <<<"$CHOICES_CSV"
[ "${#CHOICE_ARR[@]}" -ge 2 ] || exit 1

if [ "$MODE" = jev ]; then
  REQUEST=$(jq -n \
    --arg model "$MODEL" \
    --arg job "$JOB" \
    --arg status_line "$STATUS_LINE" \
    --arg question "$QUESTION" \
    --arg choices "$(printf '%s\n' "${CHOICE_ARR[@]}")" \
    '{
        model: $model,
        state: { job: $job, status_line: $status_line },
        questions: {
          classification: {
            type: "choice",
            instructions: $question,
            criteria: ($choices | split("\n") | map(. as $c | {key: $c, value: $c}) | from_entries)
          }
        }
      }') || exit 1
  fm_typesafe_never_send_check "$_CONFIG/dispatch-never-send" "$ENDPOINT" "$REQUEST" || exit 2
else
  REQUEST=$(jq -n \
    --arg model "$MODEL" \
    --arg context "$CONTEXT" \
    --arg question "$QUESTION" \
    --arg choices "$(printf '%s\n' "${CHOICE_ARR[@]}")" \
    '{
        model: $model,
        state: { status_line: $context },
        questions: {
          classification: {
            type: "choice",
            instructions: $question,
            criteria: ($choices | split("\n") | map(. as $c | {key: $c, value: $c}) | from_entries)
          }
        }
      }') || exit 1
fi

RESP_FILE=$(mktemp 2>/dev/null) || exit 1
trap 'rm -f "$RESP_FILE"' EXIT

T0=$(fm_timing_now_ms)
HTTP=$(printf '%s' "$REQUEST" | curl --globoff -sS --max-time "$TIMEOUT" -o "$RESP_FILE" -w '%{http_code}' \
  -X POST "$ENDPOINT" -H 'Content-Type: application/json' \
  -H @/dev/fd/3 3< <(printf 'Authorization: Bearer %s\n' "$TYPESAFE_API_KEY_PRIVATE") \
  --data-binary @- 2>/dev/null) || HTTP=000
T1=$(fm_timing_now_ms)
LAT_MS=$(( T1 - T0 ))

[ "$HTTP" = "200" ] || exit 1

ALLOWED_JSON=$(printf '%s\n' "${CHOICE_ARR[@]}" | jq -Rsc 'split("\n") | map(select(length > 0))') || exit 1

jq -e --argjson allowed "$ALLOWED_JSON" '
  (.answers | type) == "object" and
  ((.answers | length) > 0) and
  (.answers | to_entries[0].value) as $v |
  ($v.type == "choice") and
  (($v.choice | type) == "string") and
  (($allowed | index($v.choice)) != null) and
  (if $v | has("confidence") then (($v.confidence | type) == "number" and $v.confidence >= 0 and $v.confidence <= 1) else true end)
' "$RESP_FILE" >/dev/null 2>&1 || exit 1

jq -c --argjson lat "$LAT_MS" '
  .answers as $a |
  ($a | to_entries[0].value) as $v |
  {
    choice: $v.choice,
    confidence: ($v.confidence // 0),
    probabilities: ($v.probabilities // {}),
    latency_ms: $lat
  }
' "$RESP_FILE" 2>/dev/null
