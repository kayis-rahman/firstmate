#!/usr/bin/env bash
# bin/fm-decision-api.sh - thin, fail-open client for the local MLX Serve
# /v1/systemone typed-decision API in shadow mode.
#
# Calls ONE fixed-choice question against the local decision API (MLX Serve,
# never another engine) with a hard 3-second timeout and prints a compact JSON
# object on stdout for the caller to compare against its own verdict:
#   {"choice": <string>, "confidence": <number>,
#    "probabilities": {<choice>: <number>, ...}}
# Any failure (timeout, connection refused, malformed response) prints nothing
# and exits non-zero. The caller is expected to treat that as "no opinion"
# and keep its own answer.
#
# Configuration (environment or $FM_HOME/.env):
#   TYPESAFE_BASE   base URL of the local decision API
#                   (default http://127.0.0.1:11234)
#   TYPESAFE_MODEL  model id to query
#                   (default aselea/Kev-4B-MLX-Serve-8bit)
#   TYPESAFE_API_KEY bearer token (default local-mlx-serve)
#   FM_DECISION_TIMEOUT  hard timeout in seconds (default 3)
#
# Usage:
#   fm-decision-api.sh [--context <text>] [--question <text>]
#                      [--choices a,b,...] [--timeout SEC]
# Exit status: 0 on a parsed answer, 1 otherwise.

set -u

CONTEXT=''
QUESTION='status / wake classification: is this status line captain-relevant work firstmate must surface?'
CHOICES_CSV='captain-relevant,not-captain-relevant'
TIMEOUT="${FM_DECISION_TIMEOUT:-3}"

while [ $# -gt 0 ]; do
  case "$1" in
    --context) CONTEXT=${2-}; shift 2 ;;
    --question) QUESTION=${2-}; shift 2 ;;
    --choices) CHOICES_CSV=${2-}; shift 2 ;;
    --timeout) TIMEOUT=${2-}; shift 2 ;;
    *) echo "fm-decision-api: unknown arg $1" >&2; exit 2 ;;
  esac
done

# Resolve FM_HOME the same way the rest of the fleet does.
_HOME="${FM_HOME:-}"
if [ -z "$_HOME" ]; then _HOME="${PWD}"; fi
_ENV="$_HOME/.env"
if [ -z "${TYPESAFE_BASE:-}" ] && [ -r "$_ENV" ]; then
  TYPESAFE_BASE=$(grep -E '^TYPESAFE_BASE=' "$_ENV" 2>/dev/null | tail -1 | cut -d= -f2-)
fi
if [ -z "${TYPESAFE_MODEL:-}" ] && [ -r "$_ENV" ]; then
  TYPESAFE_MODEL=$(grep -E '^TYPESAFE_MODEL=' "$_ENV" 2>/dev/null | tail -1 | cut -d= -f2-)
fi
if [ -z "${TYPESAFE_API_KEY:-}" ] && [ -r "$_ENV" ]; then
  TYPESAFE_API_KEY=$(grep -E '^TYPESAFE_API_KEY=' "$_ENV" 2>/dev/null | tail -1 | cut -d= -f2-)
fi
BASE="${TYPESAFE_BASE:-http://127.0.0.1:11234}"
BASE="${BASE%/}"
MODEL="${TYPESAFE_MODEL:-aselea/Kev-4B-MLX-Serve-8bit}"
KEY="${TYPESAFE_API_KEY:-local-mlx-serve}"

command -v curl >/dev/null 2>&1 || exit 1
command -v jq >/dev/null 2>&1 || exit 1

# Build the choices array and an allowed set in jq-friendly form.
IFS=',' read -ra CHOICE_ARR <<<"$CHOICES_CSV"
[ "${#CHOICE_ARR[@]}" -ge 2 ] || exit 1

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
    }')

RESP_FILE=$(mktemp 2>/dev/null) || exit 1
trap 'rm -f "$RESP_FILE"' EXIT

HTTP=$(printf '%s' "$REQUEST" | curl -sS --max-time "$TIMEOUT" -o "$RESP_FILE" -w '%{http_code}' \
  -X POST "$BASE/v1/systemone" -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $KEY" \
  --data-binary @- 2>/dev/null) || HTTP=000

[ "$HTTP" = "200" ] || exit 1

# Normalize the answer into a compact object, tolerating any question key in
# "answers".
jq -e '
  (.answers | type) == "object" and
  ((.answers | length) > 0) and
  ((.answers | to_entries[0].value.type) == "choice")
' "$RESP_FILE" >/dev/null 2>&1 || exit 1

jq -c '
  .answers as $a |
  ($a | to_entries[0].value) as $v |
  {
    choice: $v.choice,
    confidence: ($v.confidence // 0),
    probabilities: ($v.probabilities // {})
  }
' "$RESP_FILE" 2>/dev/null
