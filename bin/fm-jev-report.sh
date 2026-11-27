#!/usr/bin/env bash
# bin/fm-jev-report.sh - summarize state/jev-watch.jsonl for watch-mode review.
#
# Prints counts of watched notices by Jev label and local verdict, plus any
# line Jev labeled routine that firstmate's own rules surfaced (needs-firstmate).
#
# Usage:
#   fm-jev-report.sh [--json]

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=bin/fm-jev-monitor-lib.sh
. "$SCRIPT_DIR/fm-jev-monitor-lib.sh"

AS_JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --json) AS_JSON=1; shift ;;
    -h|--help)
      awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
      exit 0
      ;;
    *) echo "fm-jev-report: unknown arg $1" >&2; exit 2 ;;
  esac
done

command -v jq >/dev/null 2>&1 || { echo "fm-jev-report: jq required" >&2; exit 1; }

STATE=$(_fm_jev_state_dir)
LOG="$STATE/jev-watch.jsonl"
MODE=$(fm_jev_mode)

if [ ! -s "$LOG" ]; then
  if [ "$AS_JSON" -eq 1 ]; then
    jq -cn --arg mode "$MODE" '{mode: $mode, total: 0, jev_counts: {}, local_counts: {}, missed_candidates: []}'
  else
    printf 'jev-monitoring mode: %s\n' "$MODE"
    printf 'watch log: %s (empty or absent)\n' "$LOG"
  fi
  exit 0
fi

SUMMARY=$(jq -s --arg mode "$MODE" '
  {
    mode: $mode,
    total: length,
    jev_counts: (group_by(.jev_label) | map({key: .[0].jev_label, value: length}) | from_entries),
    local_counts: (group_by(.local_verdict) | map({key: .[0].local_verdict, value: length}) | from_entries),
    potential_savings: [.[] | select(.jev_label == "routine" and .local_verdict == "routine" and ((.confidence // 0) >= 0.95))] | length,
    missed_candidates: [.[] | select(.jev_label == "routine" and .local_verdict == "needs-firstmate") | {ts, task, confidence, latency_ms, status_line}]
  }
' "$LOG") || exit 1

if [ "$AS_JSON" -eq 1 ]; then
  printf '%s\n' "$SUMMARY"
else
  printf '%s\n' "$SUMMARY" | jq -r '
    "jev-monitoring mode: \(.mode)",
    "total entries: \(.total)",
    "jev routine: \(.jev_counts.routine // 0), needs-firstmate: \(.jev_counts["needs-firstmate"] // 0), error: \(.jev_counts.error // 0), skipped: \((.jev_counts.skipped_sensitive // 0) + (.jev_counts.skipped_circuit // 0) + (.jev_counts.skipped_policy // 0))",
    "local routine: \(.local_counts.routine // 0), needs-firstmate: \(.local_counts["needs-firstmate"] // 0)",
    "potential savings (jev routine >= 0.95 & local routine): \(.potential_savings)",
    "jev routine but surfaced by firstmate (\(.missed_candidates | length)):",
    (.missed_candidates[] | "  - [\(.task)] (conf=\(.confidence), lat=\(.latency_ms)ms) \(.status_line)")
  '
fi
