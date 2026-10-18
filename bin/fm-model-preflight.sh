#!/usr/bin/env bash
# fm-model-preflight.sh - pre-launch model health gate backed by free-model-axi.
#
# Usage: fm-model-preflight.sh <model>
#        FM_FREE_MODEL_AXI=<path|empty> fm-model-preflight.sh <model>
#
# WHY THIS EXISTS. bin/fm-spawn.sh already validates a model against each
# harness's own catalog (omp/agy/cursor listings), but catalog membership says
# nothing about whether the model currently WORKS: the fleet dispatched a
# worker onto a model whose recorded probe had gone unhealthy while the
# free-model-axi snapshot quietly aged past freshness (observed 2026-10-18,
# snapshot 16h old with as_of.stale=true). This command health-checks the
# chosen model BEFORE any endpoint, worktree, or record exists.
#
# DECISIONS, stated once (bin/fm-spawn.sh calls this on every launch and stops
# when it exits non-zero):
#   - Absent tool, absent jq, unreadable snapshot, a model the snapshot does
#     not know, an empty/default model, or a model never probed (health_status
#     "unchecked", healthy null) all PROCEED with at most a notice: none of
#     those is evidence of a bad model, and refusing on missing evidence would
#     block dispatch whenever the advisor is simply not installed.
#   - A recorded UNHEALTHY probe for the chosen model REFUSES (exit 1) and
#     prints the exact reason: health_status, checked_age, evidence,
#     rate_limit_event, and auth_error as the snapshot reports them.
#   - A snapshot older than the bound (default 24h, FM_MODEL_PREFLIGHT_MAX_AGE_S)
#     or one free-model-axi itself marks stale WARNs with the exact age but
#     still proceeds; staleness is missing evidence, not proof of failure, and
#     the warning repeats on every launch until `free-model-axi sync` refreshes
#     it.
#   - Both the refusal and the warning name the healthiest alternative the same
#     snapshot can offer, ranked healthy-probe-first (lowest latency), then a
#     ready model with no unhealthy probe recorded (same provider preferred),
#     with an explicit label saying which kind of evidence that name carries.
#   - This command NEVER switches the model and never edits any record: only
#     the captain chooses models, so the verdict goes back to the caller as an
#     exit code plus printed reasons and the caller decides what to dispatch.
#
# Exit codes: 0 proceed (including every tolerate case above), 1 refused
# (recorded unhealthy probe), 2 usage.
#
# FM_FREE_MODEL_AXI pins the tool binary (so tests and operators can point at a
# specific build); an explicitly EMPTY value disables the check entirely, which
# is an operator choice made visible in the command line, never a silent skip.
set -u
unset CDPATH

usage() {
  cat >&2 <<'EOF'
usage: fm-model-preflight.sh <model>
EOF
  exit 2
}

[ "$#" -eq 1 ] || usage
MODEL=$1
case "$MODEL" in '' | - | default) exit 0 ;; esac

if [ "${FM_FREE_MODEL_AXI+x}" = x ]; then
  TOOL=$FM_FREE_MODEL_AXI
else
  TOOL=$(command -v free-model-axi 2>/dev/null || true)
  if [ -z "$TOOL" ] && [ -x "$HOME/.local/bin/free-model-axi" ]; then
    TOOL=$HOME/.local/bin/free-model-axi
  fi
fi
[ -n "$TOOL" ] && [ -x "$TOOL" ] || exit 0

command -v jq >/dev/null 2>&1 || {
  echo "model health: jq is not installed; '$MODEL' launches unvalidated (run 'free-model-axi models --json' by hand to health-check it)" >&2
  exit 0
}

SNAPSHOT=$("$TOOL" models --json 2>/dev/null) || SNAPSHOT=
if [ -z "$SNAPSHOT" ] || ! printf '%s' "$SNAPSHOT" | jq -e '.models | type == "array"' >/dev/null 2>&1; then
  echo "model health: free-model-axi returned no readable model snapshot; '$MODEL' launches unvalidated (run 'free-model-axi sync' to restore it)" >&2
  exit 0
fi

HIT=$(printf '%s' "$SNAPSHOT" | jq -c --arg m "$MODEL" '[.models[] | select(.model == $m)][0] // empty')
[ -n "$HIT" ] || exit 0

now=$(date +%s)
bound=${FM_MODEL_PREFLIGHT_MAX_AGE_S:-86400}
case "$bound" in '' | *[!0-9]* | 0) bound=86400 ;; esac
age_info=$(printf '%s' "$SNAPSHOT" | jq -r --argjson now "$now" '
  [.models[].synced_at | select(type == "number")] | max // empty
  | ($now - .) | tostring')
stale_flag=$(printf '%s' "$SNAPSHOT" | jq -r '.as_of.stale // false')
stale=0
case "$age_info" in
'' | unknown) stale=1 ;;
*)
  [ "$age_info" -le "$bound" ] || stale=1
  ;;
esac
[ "$stale_flag" = true ] && stale=1

# One line of exact snapshot evidence for the chosen model, field by field.
reason() {
  printf '%s' "$HIT" | jq -r '
    "health_status=\(.health_status) checked_age=\(.checked_age)"
    + " evidence=\(.evidence)"
    + " rate_limit_event=\(.rate_limit_event // "none")"
    + " auth_error=\(.auth_error // "none")"'
}

# The healthiest alternative this same snapshot can support, labeled with the
# exact kind of evidence behind the name. Prints nothing when no other ready
# model exists.
alternative() {
  printf '%s' "$SNAPSHOT" | jq -r --arg m "$MODEL" --arg provider "$(printf '%s' "$HIT" | jq -r '.provider')" '
    [.models[] | select(.model != $m and .ready == true)] as $c
    | ($c | map(select(.healthy == true)) | sort_by(.latency_ms // 1000000))[0] as $healthy
    | if $healthy != null then
        "healthiest alternative: \($healthy.model) (last probe healthy \($healthy.checked_age), \($healthy.latency_display))"
      else
        ($c | map(select(.health_status != "unhealthy"))
          | sort_by(if .provider == $provider then 0 else 1 end, .model))[0] as $near
        | if $near != null then
            "nearest alternative with no unhealthy probe recorded: \($near.model) (never probed - health unknown, not known-good)"
          else
            "no other model in this snapshot has a healthy probe; every alternative is recorded unhealthy"
          end
      end'
}

if [ "$(printf '%s' "$HIT" | jq -r '(.healthy == false) or (.health_status == "unhealthy")')" = true ]; then
  echo "model health: REFUSED for $MODEL: last probe was unhealthy ($(reason))" >&2
  if [ "$stale" = 1 ]; then
    echo "model health: the free-model-axi snapshot is ${age_info}s old (bound ${bound}s, as_of.stale=$stale_flag), so that probe is also the newest evidence available; run 'free-model-axi sync' and probe again" >&2
  fi
  alt=$(alternative)
  [ -z "$alt" ] || echo "model health: $alt" >&2
  echo "model health: only the captain chooses models; re-dispatch with a different --model or ask the captain" >&2
  exit 1
fi

if [ "$stale" = 1 ]; then
  echo "model health: warning: free-model-axi snapshot is ${age_info}s old (bound ${bound}s, as_of.stale=$stale_flag); '$MODEL' has no fresh probe evidence (health_status=$(printf '%s' "$HIT" | jq -r '.health_status')); run 'free-model-axi sync'" >&2
fi
exit 0