#!/usr/bin/env bash
# Read-only projection of the per-task steering inbox for current-state readers.
# The inbox format and acknowledgement owner remain bin/fm-task-inbox-lib.sh.

fm_task_inbox_read_state() {  # <state-dir> <task-id>
  local dir=$1/$2.inbox f best='' best_n=0 n handled=0 mtime now age
  for f in "$dir"/*.msg; do
    [ -f "$f" ] || continue
    n=${f##*/}; n=${n%.msg}
    case "$n" in ''|*[!0-9]*) continue ;; esac
    if [ -z "$best" ] || [ "$n" -lt "$best_n" ]; then
      best=$f
      best_n=$n
    fi
  done
  if [ -n "$best" ]; then
    if [ "$(uname -s 2>/dev/null || true)" = Darwin ]; then
      mtime=$(stat -f %m "$best" 2>/dev/null) || mtime=
    else
      mtime=$(stat -c %Y "$best" 2>/dev/null) || mtime=
    fi
    now=$(date +%s 2>/dev/null) || now=
    case "$mtime:$now" in *[!0-9:]*) age=0 ;; *) age=$((now - mtime)); [ "$age" -ge 0 ] || age=0 ;; esac
    printf 'unread age=%ss' "$age"
    return 0
  fi
  for f in "$dir/handled"/*.msg; do
    [ -f "$f" ] || continue
    handled=1
    break
  done
  if [ "$handled" -eq 1 ]; then printf acked; else printf none; fi
}
