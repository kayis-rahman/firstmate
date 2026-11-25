# shellcheck shell=bash
# Jev monitoring mode, protection gates, redaction, circuit breaker, watch
# logging, act-mode record-before-suppress, drain presentation, and missed-blocker
# auto-off helpers.
# Usage: . bin/fm-jev-monitor-lib.sh

_FM_JEV_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case $- in *u*) _fm_jev_nounset=on ;; *) _fm_jev_nounset=off ;; esac
# shellcheck source=bin/fm-typesafe-lib.sh
. "$_FM_JEV_LIB_DIR/fm-typesafe-lib.sh"
[ "$_fm_jev_nounset" = on ] || set +u
unset _fm_jev_nounset

_fm_jev_lock_acquire() {  # <lock-dir> [<timeout-secs>]
  local lock=$1 timeout=${2:-2} i=0 max_iters
  if command -v fm_lock_acquire_wait_bounded >/dev/null 2>&1; then
    fm_lock_acquire_wait_bounded "$lock" "$timeout"
    return $?
  fi
  max_iters=$((timeout * 20))
  while ! mkdir "$lock" 2>/dev/null; do
    i=$((i + 1))
    [ "$i" -lt "$max_iters" ] || return 1
    sleep 0.05
  done
  printf '%s\n' "$$" > "$lock/pid" 2>/dev/null || true
  return 0
}

_fm_jev_lock_release() {  # <lock-dir>
  local lock=$1
  if command -v fm_lock_release >/dev/null 2>&1; then
    fm_lock_release "$lock"
    return $?
  fi
  rm -rf -- "$lock" 2>/dev/null || true
}

FM_JEV_CIRCUIT_FAIL_THRESHOLD=${FM_JEV_CIRCUIT_FAIL_THRESHOLD:-3}
FM_JEV_CIRCUIT_PAUSE_SECS=${FM_JEV_CIRCUIT_PAUSE_SECS:-1800}
FM_JEV_CONFIDENCE_THRESHOLD=${FM_JEV_CONFIDENCE_THRESHOLD:-0.95}
FM_JEV_WATCH_MAX_BYTES=${FM_JEV_WATCH_MAX_BYTES:-524288}
FM_JEV_WATCH_KEEP_LINES=${FM_JEV_WATCH_KEEP_LINES:-1000}
FM_JEV_WATCH_MAX_CONCURRENT=${FM_JEV_WATCH_MAX_CONCURRENT:-4}
FM_JEV_SUPPRESSED_KEEP_LINES=${FM_JEV_SUPPRESSED_KEEP_LINES:-500}

_fm_jev_config_dir() {
  printf '%s' "${FM_CONFIG_OVERRIDE:-${FM_HOME:-.}/config}"
}

_fm_jev_state_dir() {
  printf '%s' "${FM_STATE_OVERRIDE:-${FM_HOME:-.}/state}"
}

_fm_jev_now() {
  if [ -n "${FM_JEV_NOW_OVERRIDE:-}" ]; then
    printf '%s' "$FM_JEV_NOW_OVERRIDE"
  else
    date +%s
  fi
}

_fm_jev_atomic_write() {  # <target> <content>
  local target=$1 content=$2 dir tmp
  dir=$(dirname -- "$target")
  mkdir -p "$dir" 2>/dev/null || return 1
  tmp=$(mktemp "$dir/.jev-tmp.XXXXXX" 2>/dev/null) || return 1
  if printf '%s\n' "$content" > "$tmp" 2>/dev/null && mv -f -- "$tmp" "$target" 2>/dev/null; then
    return 0
  fi
  rm -f -- "$tmp" 2>/dev/null || true
  return 1
}

# fm_jev_mode
# Prints one of: off, watch, act.
# Absent config/jev-monitoring -> off.
# Invalid or unreadable config/jev-monitoring -> behaves as off with one notice.
fm_jev_mode() {
  local cfg state notice raw val prev=''
  cfg="$(_fm_jev_config_dir)/jev-monitoring"
  state=$(_fm_jev_state_dir)
  notice="$state/.jev-monitoring-invalid-notice"
  if [ ! -e "$cfg" ] && [ ! -L "$cfg" ]; then
    rm -f -- "$notice" 2>/dev/null || true
    printf 'off'
    return 0
  fi
  if [ ! -f "$cfg" ] || [ ! -r "$cfg" ]; then
    if [ -f "$notice" ]; then prev=$(cat "$notice" 2>/dev/null || true); fi
    if [ "$prev" != "unreadable" ]; then
      mkdir -p "$state" 2>/dev/null || true
      printf 'unreadable\n' > "$notice" 2>/dev/null || true
      printf 'jev-monitoring: invalid or unreadable setting in %s; behaving as off\n' "$cfg" >&2
    fi
    printf 'off'
    return 0
  fi
  raw=$(cat "$cfg" 2>/dev/null || true)
  val=$(printf '%s' "$raw" | tr -d '\r' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | head -n 1)
  case "$val" in
    off|watch|act)
      rm -f -- "$notice" 2>/dev/null || true
      printf '%s' "$val"
      return 0
      ;;
    *)
      if [ -f "$notice" ]; then prev=$(cat "$notice" 2>/dev/null || true); fi
      if [ "$prev" != "invalid:$val" ]; then
        mkdir -p "$state" 2>/dev/null || true
        printf 'invalid:%s\n' "$val" > "$notice" 2>/dev/null || true
        printf 'jev-monitoring: invalid setting in %s; behaving as off\n' "$cfg" >&2
      fi
      printf 'off'
      return 0
      ;;
  esac
}

# fm_jev_is_protected_status <status-line>
# Returns 0 if <status-line> belongs to a protected kind (blockers, decisions,
# failures, finished jobs, PR/merge notices, captain-held, or unrecognized verbs).
fm_jev_is_protected_status() {
  local line=${1:-}
  [ -n "$line" ] || return 1
  if command -v status_is_captain_relevant >/dev/null 2>&1; then
    if FM_JEV_IN_CLASSIFY_CHECK=1 status_is_captain_relevant "$line"; then
      return 0
    fi
  fi
  if command -v status_is_captain_held >/dev/null 2>&1; then
    if status_is_captain_held "$line"; then
      return 0
    fi
  fi
  return 1
}

# fm_jev_is_protected_wake <kind> <reason> [<status-line>]
# Returns 0 if the wake must never be sent to Jev and must always reach firstmate.
fm_jev_is_protected_wake() {
  local kind=${1:-} reason=${2:-} line=${3:-}
  case "$kind" in
    check|heartbeat) return 0 ;;
  esac
  case "$reason" in
    needs-decision:*|check:*) return 0 ;;
    *"blocked-on-prompt"*|*"recorded worker endpoint disappeared"*|*"stuck-busy"*|*"wait overdue"*|*"captain-held"*|*"unreadable status span"*|*"stale + actionable status"*|*"possible wedge"*)
      return 0 ;;
  esac
  if [ -n "$line" ] && fm_jev_is_protected_status "$line"; then
    return 0
  fi
  return 1
}

# fm_jev_has_sensitive_content <text>
# Returns 0 if <text> looks like it holds a link, key, login, or matches
# config/dispatch-never-send (so it must stay local). Returns 1 if safe.
fm_jev_has_sensitive_content() {
  local text=${1:-} cfg never_send
  [ -n "$text" ] || return 1
  local restore_case=0 matched=1
  shopt -q nocasematch || { shopt -s nocasematch; restore_case=1; }
  if [[ "$text" =~ (https?://|ftp://|ssh://|www\.[A-Za-z0-9.-]+) ]] \
    || [[ "$text" =~ (sk-[A-Za-z0-9_-]{8,}|ghp_[A-Za-z0-9]{8,}|gho_[A-Za-z0-9]{8,}|github_pat_[A-Za-z0-9_]{8,}|xox[bpas]-[A-Za-z0-9-]+|AIza[0-9A-Za-z_-]{10,}|AKIA[0-9A-Z]{10,}|-----BEGIN[[:space:]]) ]] \
    || [[ "$text" =~ (^|[^A-Za-z0-9_])(bearer[[:space:]]+[A-Za-z0-9._-]{8,}|(api[_-]?key|apikey|secret|token|password|passwd|private[_-]?key|auth[_-]?token)[[:space:]]*[:=]) ]] \
    || [[ "$text" =~ (^|[^A-Za-z0-9_])(login|log[_-]?in|sign[_-]?in|username|user[_-]?id|credentials?|authenticate)([^A-Za-z0-9_]|$) ]] \
    || [[ "$text" =~ [A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,} ]] \
    || [[ "$text" =~ ://[^[:space:]]*:[^[:space:]]*@ ]]; then
    matched=0
  fi
  [ "$restore_case" -eq 0 ] || shopt -u nocasematch
  [ "$matched" -eq 0 ] && return 0

  cfg=$(_fm_jev_config_dir)
  never_send="$cfg/dispatch-never-send"
  if [ -e "$never_send" ] || [ -L "$never_send" ]; then
    local payload
    payload=$(jq -cn --arg t "$text" '{text: $t}' 2>/dev/null) || return 0
    fm_typesafe_never_send_check "$never_send" "local://check" "$payload" || return 0
  fi
  return 1
}

# ---- Circuit breaker (3 failures -> pause 30 minutes -> retry) ---------------
_fm_jev_circuit_path() {
  printf '%s/jev-circuit.json' "$(_fm_jev_state_dir)"
}

fm_jev_circuit_allows() {  # [<now-epoch>]
  local now=${1:-$(_fm_jev_now)} path paused_until=0
  path=$(_fm_jev_circuit_path)
  [ -f "$path" ] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  paused_until=$(jq -r '.paused_until // 0' "$path" 2>/dev/null || echo 0)
  case "$paused_until" in ''|*[!0-9]*) paused_until=0 ;; esac
  [ "$now" -ge "$paused_until" ]
}

fm_jev_circuit_record_success() {
  local path lock body
  path=$(_fm_jev_circuit_path)
  [ -f "$path" ] || return 0
  lock="$(_fm_jev_state_dir)/.jev-circuit.lock"
  mkdir -p "$(_fm_jev_state_dir)" 2>/dev/null || return 0
  _fm_jev_lock_acquire "$lock" 2 || return 0
  body='{"failures":0,"paused_until":0,"last_failure_at":0}'
  _fm_jev_atomic_write "$path" "$body" || true
  _fm_jev_lock_release "$lock"
}

fm_jev_circuit_record_failure() {  # [<now-epoch>]
  local now=${1:-$(_fm_jev_now)} path lock failures=0 paused_until=0 body
  path=$(_fm_jev_circuit_path)
  lock="$(_fm_jev_state_dir)/.jev-circuit.lock"
  mkdir -p "$(_fm_jev_state_dir)" 2>/dev/null || return 0
  _fm_jev_lock_acquire "$lock" 2 || return 0
  if [ -f "$path" ] && command -v jq >/dev/null 2>&1; then
    failures=$(jq -r '.failures // 0' "$path" 2>/dev/null || echo 0)
  fi
  case "$failures" in ''|*[!0-9]*) failures=0 ;; esac
  failures=$((failures + 1))
  if [ "$failures" -ge "$FM_JEV_CIRCUIT_FAIL_THRESHOLD" ]; then
    paused_until=$((now + FM_JEV_CIRCUIT_PAUSE_SECS))
  fi
  body=$(jq -cn --argjson f "$failures" --argjson p "$paused_until" --argjson n "$now" \
    '{failures: $f, paused_until: $p, last_failure_at: $n}' 2>/dev/null) || {
    _fm_jev_lock_release "$lock"
    return 0
  }
  _fm_jev_atomic_write "$path" "$body" || true
  _fm_jev_lock_release "$lock"
}

# ---- Watch mode logging & evaluation -----------------------------------------
fm_jev_watch_log_append() {  # <task> <local_verdict> <jev_label> <confidence-or-null> <latency_ms-or-null> <status_line>
  local task=$1 local_v=$2 jev_label=$3 conf=$4 lat=$5 line=$6
  local state log lock rec sz tmp
  state=$(_fm_jev_state_dir)
  log="$state/jev-watch.jsonl"
  lock="$state/.jev-watch.lock"
  mkdir -p "$state" 2>/dev/null || return 0
  command -v jq >/dev/null 2>&1 || return 0
  [ -n "$conf" ] || conf='null'
  [ -n "$lat" ] || lat='null'
  rec=$(jq -cn \
    --argjson ts "$(_fm_jev_now)" \
    --arg task "$task" \
    --arg local_verdict "$local_v" \
    --arg jev_label "$jev_label" \
    --argjson confidence "$conf" \
    --argjson latency_ms "$lat" \
    --arg status_line "$line" \
    '{ts: $ts, task: $task, local_verdict: $local_verdict, jev_label: $jev_label, confidence: $confidence, latency_ms: $latency_ms, status_line: $status_line}' 2>/dev/null) || return 0
  _fm_jev_lock_acquire "$lock" 2 || return 0
  printf '%s\n' "$rec" >> "$log" 2>/dev/null || true
  sz=$(wc -c < "$log" 2>/dev/null || echo 0)
  sz=${sz//[[:space:]]/}
  case "$sz" in ''|*[!0-9]*) sz=0 ;; esac
  if [ "$sz" -gt "$FM_JEV_WATCH_MAX_BYTES" ]; then
    tmp=$(mktemp "$state/.jev-watch.trim.XXXXXX" 2>/dev/null) || tmp=''
    if [ -n "$tmp" ]; then
      if tail -n "$FM_JEV_WATCH_KEEP_LINES" "$log" > "$tmp" 2>/dev/null; then
        mv -f -- "$tmp" "$log" 2>/dev/null || rm -f -- "$tmp" 2>/dev/null || true
      else
        rm -f -- "$tmp" 2>/dev/null || true
      fi
    fi
  fi
  _fm_jev_lock_release "$lock"
}

# fm_jev_watch_evaluate <task> <local_verdict> <status_line>
# Synchronously evaluates one non-protected status line in watch mode and logs
# the result to state/jev-watch.jsonl. Deduplicates per task and exact status
# line. Never alters any wake.
fm_jev_watch_evaluate() {
  local task=$1 local_v=$2 line=$3
  local helper out rc choice conf lat state safe_task seen_file seen_lock prev_key cur_key
  if fm_jev_is_protected_status "$line"; then
    return 0
  fi
  state=$(_fm_jev_state_dir)
  safe_task=$(printf '%s' "$task" | tr -c 'A-Za-z0-9._-' '_')
  seen_file="$state/.jev-watch-seen-$safe_task"
  seen_lock="$state/.jev-watch-seen.lock"
  cur_key="${local_v}:${line}"
  mkdir -p "$state" 2>/dev/null || return 0
  if _fm_jev_lock_acquire "$seen_lock" 2; then
    prev_key=$(cat "$seen_file" 2>/dev/null || true)
    if [ "$prev_key" = "$cur_key" ]; then
      _fm_jev_lock_release "$seen_lock"
      return 0
    fi
    printf '%s\n' "$cur_key" > "$seen_file" 2>/dev/null || true
    _fm_jev_lock_release "$seen_lock"
  fi
  if fm_jev_has_sensitive_content "$line" || fm_jev_has_sensitive_content "$task"; then
    fm_jev_watch_log_append "$task" "$local_v" "skipped_sensitive" "null" "null" "[REDACTED]"
    return 0
  fi
  if ! fm_jev_circuit_allows; then
    fm_jev_watch_log_append "$task" "$local_v" "skipped_circuit" "null" "null" "$line"
    return 0
  fi
  helper="${FM_JEV_DECISION_API_BIN:-$_FM_JEV_LIB_DIR/fm-decision-api.sh}"
  [ -x "$helper" ] || return 0
  out=$("$helper" --mode jev --job "$task" --status-line "$line" 2>/dev/null)
  rc=$?
  if [ "$rc" -eq 2 ]; then
    fm_jev_watch_log_append "$task" "$local_v" "skipped_policy" "null" "null" "[REDACTED]"
    return 0
  fi
  if [ "$rc" -ne 0 ] || [ -z "$out" ]; then
    fm_jev_circuit_record_failure
    fm_jev_watch_log_append "$task" "$local_v" "error" "null" "null" "$line"
    return 0
  fi
  choice=$(printf '%s' "$out" | jq -r '.choice // empty' 2>/dev/null) || choice=''
  conf=$(printf '%s' "$out" | jq -r '.confidence // "null"' 2>/dev/null) || conf='null'
  lat=$(printf '%s' "$out" | jq -r '.latency_ms // "null"' 2>/dev/null) || lat='null'
  if [ "$choice" != "routine" ] && [ "$choice" != "needs-firstmate" ]; then
    fm_jev_circuit_record_failure
    fm_jev_watch_log_append "$task" "$local_v" "error" "null" "null" "$line"
    return 0
  fi
  fm_jev_circuit_record_success
  fm_jev_watch_log_append "$task" "$local_v" "$choice" "$conf" "$lat" "$line"
  return 0
}

# fm_jev_watch_dispatch <task> <local_verdict> <status_line>
# Non-blocking, concurrency-bounded wrapper for watchers unless FM_JEV_WATCH_SYNC=1.
fm_jev_watch_dispatch() {
  if [ "${FM_JEV_WATCH_SYNC:-0}" = "1" ]; then
    fm_jev_watch_evaluate "$@"
    return 0
  fi
  local state pids_dir pid_f pid active=0 bg_pid
  state=$(_fm_jev_state_dir)
  pids_dir="$state/.jev-watch-pids"
  mkdir -p "$pids_dir" 2>/dev/null || return 0
  for pid_f in "$pids_dir"/*; do
    [ -e "$pid_f" ] || continue
    pid=${pid_f##*/}
    if kill -0 "$pid" 2>/dev/null; then
      active=$((active + 1))
    else
      rm -f -- "$pid_f" 2>/dev/null || true
    fi
  done
  [ "$active" -lt "$FM_JEV_WATCH_MAX_CONCURRENT" ] || return 0
  (
    trap 'rm -f -- "'"$pids_dir"'/$BASHPID" 2>/dev/null || true' EXIT
    fm_jev_watch_evaluate "$@"
  ) >/dev/null 2>&1 &
  bg_pid=$!
  printf '%s\n' "$bg_pid" > "$pids_dir/$bg_pid" 2>/dev/null || true
}

# ---- Act mode: record-before-suppress, drain, missed-blocker auto-off --------
_fm_jev_suppressed_path() {
  printf '%s/jev-suppressed.jsonl' "$(_fm_jev_state_dir)"
}

_fm_jev_task_status_size() {  # <task>
  local f sz
  f="$(_fm_jev_state_dir)/$1.status"
  [ -f "$f" ] || { printf '0'; return 0; }
  sz=$(wc -c < "$f" 2>/dev/null || echo 0)
  sz=${sz//[[:space:]]/}
  case "$sz" in ''|*[!0-9]*) sz=0 ;; esac
  printf '%s' "$sz"
}

fm_jev_record_suppressed() {  # <task> <kind> <reason> <status_line> <status_offset> <confidence> <latency_ms>
  local task=$1 kind=$2 reason=$3 line=$4 offset=${5:-0} conf=${6:-0} lat=${7:-0}
  local state store lock rec
  state=$(_fm_jev_state_dir)
  store=$(_fm_jev_suppressed_path)
  lock="$state/.jev-suppressed.lock"
  mkdir -p "$state" 2>/dev/null || return 1
  command -v jq >/dev/null 2>&1 || return 1
  case "$offset" in ''|*[!0-9]*) offset=0 ;; esac
  rec=$(jq -cn \
    --argjson ts "$(_fm_jev_now)" \
    --arg task "$task" \
    --arg kind "$kind" \
    --arg reason "$reason" \
    --arg status_line "$line" \
    --argjson status_offset "$offset" \
    --argjson confidence "$conf" \
    --argjson latency_ms "$lat" \
    '{ts: $ts, task: $task, kind: $kind, reason: $reason, status_line: $status_line, status_offset: $status_offset, confidence: $confidence, latency_ms: $latency_ms, drained: false, auto_off_triggered: false}' 2>/dev/null) || return 1
  _fm_jev_lock_acquire "$lock" 2 || return 1
  if ! printf '%s\n' "$rec" >> "$store" 2>/dev/null; then
    _fm_jev_lock_release "$lock"
    return 1
  fi
  _fm_jev_lock_release "$lock"
  return 0
}

# fm_jev_act_check <task> <kind> <reason> <status_line> [<status_offset>]
# Evaluates Jev in act mode WITHOUT recording yet. Sets FM_JEV_ACT_CONF,
# FM_JEV_ACT_LAT, and FM_JEV_ACT_OFFSET on return 0 (routine >= threshold).
fm_jev_act_check() {
  local task=$1 kind=$2 reason=$3 line=$4 offset=${5:-0}
  local helper out rc choice conf lat
  FM_JEV_ACT_CONF=''
  FM_JEV_ACT_LAT=''
  FM_JEV_ACT_OFFSET=''
  [ "$(fm_jev_mode)" = "act" ] || return 1
  fm_jev_is_protected_wake "$kind" "$reason" "$line" && return 1
  if fm_jev_has_sensitive_content "$line" || fm_jev_has_sensitive_content "$task"; then
    return 1
  fi
  fm_jev_circuit_allows || return 1
  helper="${FM_JEV_DECISION_API_BIN:-$_FM_JEV_LIB_DIR/fm-decision-api.sh}"
  [ -x "$helper" ] || return 1
  out=$("$helper" --mode jev --job "$task" --status-line "$line" 2>/dev/null)
  rc=$?
  if [ "$rc" -eq 2 ]; then
    return 1
  fi
  if [ "$rc" -ne 0 ] || [ -z "$out" ]; then
    fm_jev_circuit_record_failure
    return 1
  fi
  choice=$(printf '%s' "$out" | jq -r '.choice // empty' 2>/dev/null) || choice=''
  conf=$(printf '%s' "$out" | jq -r '.confidence // 0' 2>/dev/null) || conf=0
  lat=$(printf '%s' "$out" | jq -r '.latency_ms // 0' 2>/dev/null) || lat=0
  if [ "$choice" != "routine" ] && [ "$choice" != "needs-firstmate" ]; then
    fm_jev_circuit_record_failure
    return 1
  fi
  fm_jev_circuit_record_success
  [ "$choice" = "routine" ] || return 1
  awk -v c="$conf" -v t="$FM_JEV_CONFIDENCE_THRESHOLD" 'BEGIN{exit !(c+0 >= t+0)}' 2>/dev/null || return 1
  case "$offset" in ''|0|*[!0-9]*) offset=$(_fm_jev_task_status_size "$task") ;; esac
  FM_JEV_ACT_CONF=$conf
  FM_JEV_ACT_LAT=$lat
  FM_JEV_ACT_OFFSET=$offset
  return 0
}

# fm_jev_act_evaluate <task> <kind> <reason> <status_line> [<status_offset>]
# Returns 0 ONLY if Jev classified the notice as routine >= 0.95 AND it was
# durably recorded before suppression. Returns 1 otherwise (caller wakes as today).
fm_jev_act_evaluate() {
  local task=$1 kind=$2 reason=$3 line=$4 offset=${5:-0}
  fm_jev_act_check "$task" "$kind" "$reason" "$line" "$offset" || return 1
  fm_jev_record_suppressed "$task" "$kind" "$reason" "$line" "$FM_JEV_ACT_OFFSET" "$FM_JEV_ACT_CONF" "$FM_JEV_ACT_LAT" || return 1
  return 0
}

# fm_jev_act_signal_batch <pending-tab-lines> <reason>
# Evaluates every file in a multi-file signal batch before recording any
# suppression. If any file is not routine >= 0.95 (or fails/redacts/protected),
# nothing is recorded and returns 1 so the caller wakes firstmate.
fm_jev_act_signal_batch() {
  local pending=$1 reason=$2
  local state sf sig f task line
  local items=()
  [ "$(fm_jev_mode)" = "act" ] || return 1
  state=$(_fm_jev_state_dir)
  while IFS=$(printf '\t') read -r sf sig f; do
    [ -n "$sf" ] || continue
    task=$(basename "$f"); task=${task%.status}; task=${task%.turn-ended}
    line=$(last_status_line "$state/$task.status")
    fm_jev_act_check "$task" "signal" "$reason" "$line" 0 || return 1
    items+=("$task"$'\t'"$line"$'\t'"$FM_JEV_ACT_OFFSET"$'\t'"$FM_JEV_ACT_CONF"$'\t'"$FM_JEV_ACT_LAT")
  done <<EOF
$pending
EOF
  [ "${#items[@]}" -gt 0 ] || return 1
  local item t l off c lat
  for item in "${items[@]}"; do
    IFS=$(printf '\t') read -r t l off c lat <<<"$item"
    fm_jev_record_suppressed "$t" "signal" "$reason" "$l" "$off" "$c" "$lat" || return 1
  done
  return 0
}

# fm_jev_drain_suppressed
# Prints un-drained suppressed rows for fm-wake-drain.sh and marks them drained
# only after printing succeeds.
fm_jev_drain_suppressed() {
  local state store lock out tmp
  state=$(_fm_jev_state_dir)
  store=$(_fm_jev_suppressed_path)
  lock="$state/.jev-suppressed.lock"
  [ -s "$store" ] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  _fm_jev_lock_acquire "$lock" 2 || return 1
  out=$(jq -r 'select((.drained // false) | not) | "  - \(.task): \(.status_line) (confidence=\(.confidence), at=\(.ts))"' "$store" 2>/dev/null) || {
    _fm_jev_lock_release "$lock"
    return 1
  }
  if [ -n "$out" ]; then
    if ! printf 'JEV MONITORING, SUPPRESSED ROUTINE (recorded without waking; for your awareness):\n%s\n' "$out"; then
      _fm_jev_lock_release "$lock"
      return 1
    fi
    tmp=$(mktemp "$state/.jev-suppressed.drain.XXXXXX" 2>/dev/null) || {
      _fm_jev_lock_release "$lock"
      return 1
    }
    if jq -c '.drained = true' "$store" 2>/dev/null | tail -n "$FM_JEV_SUPPRESSED_KEEP_LINES" > "$tmp" 2>/dev/null \
      && mv -f -- "$tmp" "$store" 2>/dev/null; then
      :
    else
      rm -f -- "$tmp" 2>/dev/null || true
      _fm_jev_lock_release "$lock"
      return 1
    fi
  fi
  _fm_jev_lock_release "$lock"
  return 0
}

# fm_jev_check_missed_blocker <task> <event-desc> [<event-offset>]
# If jev-monitoring is in act mode and <task> has a suppressed row whose
# recorded status_offset covers <event-offset> (event_offset <= status_offset)
# and has not yet triggered auto-off, durably switch config/jev-monitoring to
# off and mark the row(s). Returns 0 if auto-off triggered, 1 otherwise.
fm_jev_check_missed_blocker() {
  local task=$1 _desc=${2:-} event_offset=${3:-}
  local state store lock cfg matched tmp
  [ -n "$task" ] || return 1
  [ "$(fm_jev_mode)" = "act" ] || return 1
  state=$(_fm_jev_state_dir)
  store=$(_fm_jev_suppressed_path)
  lock="$state/.jev-suppressed.lock"
  cfg="$(_fm_jev_config_dir)/jev-monitoring"
  [ -s "$store" ] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  case "$event_offset" in ''|*[!0-9]*) event_offset=$(_fm_jev_task_status_size "$task") ;; esac
  _fm_jev_lock_acquire "$lock" 2 || return 1
  matched=$(jq -e --arg t "$task" --argjson ev "$event_offset" \
    'select(.task == $t and ((.auto_off_triggered // false) | not) and ((.status_offset // 0) >= $ev))' \
    "$store" 2>/dev/null) || matched=''
  if [ -z "$matched" ]; then
    _fm_jev_lock_release "$lock"
    return 1
  fi
  if ! _fm_jev_atomic_write "$cfg" "off"; then
    _fm_jev_lock_release "$lock"
    return 1
  fi
  tmp=$(mktemp "$state/.jev-suppressed.off.XXXXXX" 2>/dev/null) || tmp=''
  if [ -n "$tmp" ]; then
    if jq -c --arg t "$task" --argjson ev "$event_offset" \
      'if (.task == $t and ((.status_offset // 0) >= $ev)) then .auto_off_triggered = true else . end' \
      "$store" > "$tmp" 2>/dev/null; then
      mv -f -- "$tmp" "$store" 2>/dev/null || rm -f -- "$tmp" 2>/dev/null || true
    else
      rm -f -- "$tmp" 2>/dev/null || true
    fi
  fi
  _fm_jev_lock_release "$lock"
  return 0
}
