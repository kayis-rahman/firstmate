#!/usr/bin/env bash
# fm-hygiene.sh - proactive disk and finished-work hygiene for a firstmate home.
# Usage:
#   fm-hygiene.sh report [--treehouse-root PATH]
#   fm-hygiene.sh sweep  [--yes] [--treehouse-root PATH]
#
# report: read-only inventory of free space, treehouse slot classification,
#         evidence size per finished task, and one-line disk alarms when under threshold.
# sweep:  dry run by default; --yes executes.
#
# Config: $FM_HOME/config/disk-thresholds (optional):
#   internal <mount-path> <gb>        (defaults: / 15)
#   external <mount-path> <gb>        (defaults: none)
#   internal-threshold-gb <n>         (compat: threshold for /)
#   external-volumes: <path> <gb>     (compat)
# Auto sweep opt-in: $FM_HOME/config/hygiene-auto-sweep contains "yes".
set -u
export LC_ALL=C
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
HOME_DIR="${FM_HOME:-$ROOT}"
STATE="${FM_STATE_OVERRIDE:-$HOME_DIR/state}"
DATA="${FM_DATA_OVERRIDE:-$HOME_DIR/data}"
CONFIG="${FM_CONFIG_OVERRIDE:-$HOME_DIR/config}"
TREEHOUSE_ROOT_OVERRIDE="${FM_TREEHOUSE_ROOT_OVERRIDE:-}"

usage() { echo 'Usage: fm-hygiene.sh report [--treehouse-root PATH] | sweep [--yes] [--treehouse-root PATH]'; }

bytes_for() { du -sk "$1" 2>/dev/null | awk '{print $1*1024}'; }
human() { awk -v b="$1" 'BEGIN{ if(b>=1073741824) printf "%.1fGB",b/1073741824; else if(b>=1048576) printf "%.1fMB",b/1048576; else if(b>=1024) printf "%.1fKB",b/1024; else printf "%dB",b }'; }

parse_thresholds() {
  # global arrays THRESHOLD_MOUNT[], THRESHOLD_GB[]
  THRESHOLD_MOUNT=(); THRESHOLD_GB=(); THRESHOLD_ROLE=()
  local f="$CONFIG/disk-thresholds"
  [ -f "$f" ] || { THRESHOLD_ROLE+=(internal); THRESHOLD_MOUNT+=(/); THRESHOLD_GB+=(15); THRESHOLD_ROLE+=(external); THRESHOLD_MOUNT+=("/Volumes/Mac Extended"); THRESHOLD_GB+=(5); return 0; }
  local line first rest mount_raw gb mount
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"
    line="$(printf '%s' "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    [ -z "$line" ] && continue
    read -r first rest <<< "$line"

    # helper inline: split a "rest" into mount_raw + gb using last whitespace run
    split_rest() {
      if [[ "$rest" =~ ^(.*)[[:space:]]+([^[:space:]]+)$ ]]; then
        mount_raw="${BASH_REMATCH[1]}"
        gb="${BASH_REMATCH[2]}"
      else
        mount_raw=""
        gb="$rest"
      fi
    }
    unescape_mount() {
      local m="$1"
      m="$(printf '%s' "$m" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")"
      printf '%s' "$m" | sed 's/\\ / /g'
    }

    case "$first" in
      internal)
        if [ -z "$rest" ]; then continue; fi
        if [[ "$rest" =~ ^[0-9]+$ ]]; then
          mount="/"; gb="$rest"
        else
          split_rest
          mount="$(unescape_mount "$mount_raw")"
        fi
        [[ "$gb" =~ ^[0-9]+$ ]] || continue
        [ -n "$mount" ] || mount="/"
        THRESHOLD_ROLE+=(internal); THRESHOLD_MOUNT+=("$mount"); THRESHOLD_GB+=("$gb") ;;
      external)
        if [ -z "$rest" ]; then continue; fi
        split_rest
        [ -n "$mount_raw" ] || continue
        mount="$(unescape_mount "$mount_raw")"
        [[ "$gb" =~ ^[0-9]+$ ]] || continue
        [ -n "$mount" ] || continue
        THRESHOLD_ROLE+=(external); THRESHOLD_MOUNT+=("$mount"); THRESHOLD_GB+=("$gb") ;;
      internal-threshold-gb|internal_threshold_gb)
        gb="$rest"
        [[ "$gb" =~ ^[0-9]+$ ]] || continue
        THRESHOLD_ROLE+=(internal); THRESHOLD_MOUNT+=(/); THRESHOLD_GB+=("$gb") ;;
      external-volumes|external-volumes:|external_volumes|external_volumes:)
        if [ -z "$rest" ]; then continue; fi
        split_rest
        [ -n "$mount_raw" ] || continue
        mount="$(unescape_mount "$mount_raw")"
        [[ "$gb" =~ ^[0-9]+$ ]] || continue
        [ -n "$mount" ] || continue
        THRESHOLD_ROLE+=(external); THRESHOLD_MOUNT+=("$mount"); THRESHOLD_GB+=("$gb") ;;
      *)
        if [[ "$first" == /* ]] && [[ "$rest" =~ ^[0-9]+$ ]]; then
          THRESHOLD_ROLE+=(external); THRESHOLD_MOUNT+=("$first"); THRESHOLD_GB+=("$rest")
        fi ;;
    esac
  done < "$f"
  if [ "${#THRESHOLD_MOUNT[@]}" -eq 0 ]; then
    THRESHOLD_ROLE+=(internal); THRESHOLD_MOUNT+=(/); THRESHOLD_GB+=(15)
  fi
}

TASK_IS_DONE() {
  local id="$1"
  local st
  st="$("$SCRIPT_DIR/fm-crew-state.sh" "$id" 2>/dev/null || true)"
  printf '%s' "$st" | grep -Eiq 'state:[[:space:]]*(done|failed)([[:space:]]|$)' && return 0
  [ -f "$STATE/$id.status" ] && grep -Eiq 'state:[[:space:]]*done([[:space:]]|$)|^[[:space:]]*done[[:space:]]*$' "$STATE/$id.status" && return 0
  # backlog fallback
  if [ -f "$DATA/backlog.md" ]; then grep -Eq "^\- \[[xX]\].*\b$id\b" "$DATA/backlog.md" && return 0; fi
  return 1
}

PR_MERGED_FOR_BRANCH() {
  # args: repo_slug branch worktree_path
  local slug="$1" branch="$2" wtpath="$3"
  local default_branch
  default_branch="$(git -C "$wtpath" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's#^refs/remotes/origin/##')"
  [ -z "$default_branch" ] && default_branch=main
  # remote branch exists?
  local remote_exists=0
  git -C "$wtpath" ls-remote --exit-code origin "refs/heads/$branch" >/dev/null 2>&1 && remote_exists=1
  # HEAD reachable from origin default
  local head_reachable=0
  git -C "$wtpath" fetch origin --quiet 2>/dev/null || true
  if git -C "$wtpath" merge-base --is-ancestor HEAD "origin/$default_branch" 2>/dev/null; then head_reachable=1; fi
  # gh PR state
  local pr_json
  if command -v gh-axi >/dev/null 2>&1; then
    pr_json="$(gh-axi pr list --repo "$slug" --head "$branch" --state all --json state,mergedAt 2>/dev/null || true)"
  elif command -v gh >/dev/null 2>&1; then
    pr_json="$(gh pr list --repo "$slug" --head "$branch" --state all --json state,mergedAt 2>/dev/null || true)"
  else
    pr_json=""
  fi
  if printf '%s' "$pr_json" | grep -qi '"mergedAt":[[:space:]]*"[^"]*"'; then return 0; fi
  if printf '%s' "$pr_json" | grep -qi '"state":[[:space:]]*"MERGED"'; then return 0; fi
  # fallback HEAD reachable from default
  [ "$head_reachable" -eq 1 ] && return 0
  return 1
}

TREEHOUSE_ROOT() {
  if [ -n "$TREEHOUSE_ROOT_OVERRIDE" ]; then echo "$TREEHOUSE_ROOT_OVERRIDE"; return; fi
  if [ -n "${TREEHOUSE_ROOT:-}" ]; then echo "$TREEHOUSE_ROOT"; return; fi
  echo "$HOME/.treehouse"
}

slot_lines() {
  if command -v treehouse >/dev/null 2>&1; then
    treehouse status 2>/dev/null
  fi
}

report() {
  local tr_override=""
  local args=("$@")
  local i=0
  while [ $i -lt ${#args[@]} ]; do
    case "${args[$i]}" in
      --treehouse-root) i=$((i+1)); tr_override="${args[$i]}" ;;
    esac
    i=$((i+1))
  done
  [ -n "$tr_override" ] && TREEHOUSE_ROOT_OVERRIDE="$tr_override"
  [ -n "$TREEHOUSE_ROOT_OVERRIDE" ] && export TREEHOUSE_ROOT="$TREEHOUSE_ROOT_OVERRIDE"
  parse_thresholds
  echo "=== fm-hygiene report ==="
  echo "-- disk --"
  local i mount thr avail_kb avail_b
  for i in "${!THRESHOLD_MOUNT[@]}"; do
    mount="${THRESHOLD_MOUNT[$i]}"
    thr="${THRESHOLD_GB[$i]}"
    if [ -d "$mount" ] || [ "$mount" = "/" ]; then
      read -r avail_kb _ < <(df -Pk "$mount" 2>/dev/null | awk 'NR==2{print $4}')
      if [[ "$avail_kb" =~ ^[0-9]+$ ]]; then
        avail_b=$((avail_kb*1024))
        echo "disk: $mount free=$(human "$avail_b") threshold=${thr}GB"
        local thrb=$((thr*1024*1024*1024))
        if [ "$avail_b" -lt "$thrb" ]; then echo "ALARM: $mount free below ${thr}GB"; fi
      else
        echo "disk: $mount unavailable"
      fi
    else
      echo "disk: $mount unavailable"
    fi
  done
  echo "-- treehouse slots --"
  # collect slots from treehouse status
  # parse treehouse status lines containing a path
  if command -v treehouse >/dev/null 2>&1; then
    treehouse status 2>/dev/null | while IFS= read -r line; do
      # format: "N     status       path  [branch] ..."
# shellcheck disable=SC2086
      set -- $line
      [ -n "${3:-}" ] || { set -- ; continue; }
      p3="${3/#\~/$HOME}"
      [ -d "$p3" ] || continue
      # extract status token (second column-ish) and path
# shellcheck disable=SC2086
      set -- $line
      # first token number
      num="$1"; shift || true
      # status
      st="$1"; shift || true
      # path may be next
      path="${1/#\~/$HOME}"; shift || true
      [ -d "$path" ] || continue
      # classification
      class="unknown"
      case "$st" in
        idle|available) class="idle/unleased" ;;
        in-use) class="held-live (in-use)" ;;
        leased) class="held-live (leased)" ;;
        *) class="$st" ;;
      esac
      # never-touch checks for idle
      if [ "$st" = "idle" ] || [ "$st" = "available" ]; then
        # uncommitted?
        if ! git -C "$path" diff --quiet 2>/dev/null || ! git -C "$path" diff --cached --quiet 2>/dev/null; then class="idle but uncommitted (NEVER TOUCH)"; 
        elif [ -n "$(git -C "$path" stash list 2>/dev/null)" ]; then class="idle but stashed (NEVER TOUCH)";
        else
          branch="$(git -C "$path" rev-parse --abbrev-ref HEAD 2>/dev/null)"
          if [ "$branch" = "HEAD" ]; then class="idle detached HEAD (NEVER TOUCH)";
          else class="idle/unleased (candidate)"; fi
        fi
      fi
      echo "slot: $num $path status=$st class=$class"
    done
  fi
  echo "-- evidence --"
  shopt -s nullglob
  for d in "$DATA"/*/; do
    [ -d "$d" ] || continue
    id="$(basename "$d")"
    size="$(bytes_for "$d")"
    printf 'evidence: %s size=%s\n' "$id" "$(human "$size")"
  done
  shopt -u nullglob
}

cleanup_slot() {
  local path="$1"
  treehouse destroy "$path" --include-unlanded --yes 2>/dev/null
}

sweep() {
  local yes=0
  # parse args properly
  local tr_override=""
  local args=("$@")
  local i=0
  yes=0
  while [ $i -lt ${#args[@]} ]; do
    case "${args[$i]}" in
      --yes|-y) yes=1 ;;
      --treehouse-root) i=$((i+1)); tr_override="${args[$i]}" ;;
    esac
    i=$((i+1))
  done
  [ -n "$tr_override" ] && TREEHOUSE_ROOT_OVERRIDE="$tr_override"
  [ -n "$TREEHOUSE_ROOT_OVERRIDE" ] && export TREEHOUSE_ROOT="$TREEHOUSE_ROOT_OVERRIDE"
  parse_thresholds

  echo "=== fm-hygiene sweep$([ $yes -eq 1 ] && echo " (execute)" || echo " (dry run)") ==="
  local removed_bytes=0

  # 1. treehouse
  echo "-- treehouse --"
  # held slots set from state/*.meta worktree lines
  local held_paths=""
  for m in "$STATE"/*.meta; do [ -f "$m" ] || continue; 
    while IFS= read -r w; do held_paths="$held_paths $w"; done < <(grep '^worktree=' "$m" | cut -d= -f2-)
  done

  if command -v treehouse >/dev/null 2>&1; then
    while IFS= read -r line; do
# shellcheck disable=SC2086
      set -- $line
      [ "$#" -ge 3 ] || continue
      num="$1"; shift || true
      st="$1"; shift || true
      path="${1/#\~/$HOME}"; shift || true
      [ -d "$path" ] || continue
      # only consider idle (unleased/unheld)
      [ "$st" = "idle" ] || [ "$st" = "available" ] || { echo "skip slot $num $path: $st (held live)"; continue; }
      # held by meta?
      case " $held_paths " in *" $path "*) echo "skip slot $num $path: held by live task"; continue ;; esac
      # never-touch checks
      reason=""
      if ! git -C "$path" diff --quiet 2>/dev/null || ! git -C "$path" diff --cached --quiet 2>/dev/null; then reason="uncommitted changes"; 
      elif [ -n "$(git -C "$path" stash list 2>/dev/null)" ]; then reason="stash present";
      else
        branch="$(git -C "$path" rev-parse --abbrev-ref HEAD 2>/dev/null)"
        if [ "$branch" = "HEAD" ]; then reason="detached HEAD (unclassifiable)";
        else
          # commits not on remote?
          remote_sha="$(git -C "$path" rev-parse "origin/$branch" 2>/dev/null || true)"
          head_sha="$(git -C "$path" rev-parse HEAD 2>/dev/null || true)"
          if ! git -C "$path" merge-base --is-ancestor "$head_sha" "origin/$branch" 2>/dev/null; then
            if ! git -C "$path" ls-remote --exit-code origin "refs/heads/$branch" >/dev/null 2>&1; then reason="branch not on remote"; else reason="local commits not on remote"; fi
          fi
        fi
      fi
      if [ -n "$reason" ]; then echo "skip slot $num $path: NEVER TOUCH ($reason)"; continue; fi

      branch="$(git -C "$path" rev-parse --abbrev-ref HEAD 2>/dev/null)"
      remote_url="$(git -C "$path" remote get-url origin 2>/dev/null || true)"
      slug="$(printf '%s' "$remote_url" | sed -E 's#^git@github.com:##; s#^https://github.com/##; s#\.git$##')"
      if PR_MERGED_FOR_BRANCH "$slug" "$branch" "$path"; then
        size="$(bytes_for "$path")"
        if [ $yes -eq 1 ]; then
          cleanup_slot "$path" >/dev/null 2>&1 || true
          echo "removed slot $num $path size=$(human "$size")"
          removed_bytes=$((removed_bytes+size))
        else
          echo "would remove slot $num $path size=$(human "$size") [merged]"
        fi
      else
        size="$(bytes_for "$path")"
        echo "skip slot $num $path: branch not merged/closed-recognised (size=$(human "$size"))"
      fi
    done < <(treehouse status 2>/dev/null)
  fi

  # 2. evidence
  echo "-- evidence --"
  shopt -s nullglob
  for d in "$DATA"/*/; do
    [ -d "$d" ] || continue
    id="$(basename "$d")"
    TASK_IS_DONE "$id" || { echo "skip evidence $id: task not done"; continue; }
    # media/archive deletion
    while IFS= read -r -d '' f; do
      sz="$(stat -f %z "$f" 2>/dev/null || stat -c %s "$f" 2>/dev/null || echo 0)"
      if [ "$sz" -gt 204800 ]; then
        if [ $yes -eq 1 ]; then rm -f "$f"; echo "removed media $f size=$(human "$sz")"; removed_bytes=$((removed_bytes+sz)); else echo "would remove media $f size=$(human "$sz")"; fi
      fi
    done < <(find "$d" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.mp4' -o -iname '*.mov' -o -iname '*.webm' -o -iname '*.gif' -o -iname '*.zip' -o -iname '*.tar' -o -iname '*.tar.gz' -o -iname '*.tgz' -o -iname '*.gz' -o -iname '*.aab' -o -iname '*.apk' \) -print0 2>/dev/null)
    # disposable dirs
    for sub in "$d"*; do
      [ -d "$sub" ] || continue
      base="$(basename "$sub")"
      # keep selected* final* and standard records
      case "$base" in selected*|final*|report.md|status*|brief*) continue ;; esac
      # candidate disposable dirs
      case "$base" in *sdk*|*SDK*|*checkout*|*rebase*|*toolkit*) 
        if [ $yes -eq 1 ]; then rm -rf "$sub"; echo "removed dir $sub"; else echo "would remove dir $sub"; fi ;;
      esac
    done
  done
  shopt -u nullglob
  echo "space freed (dry-run estimated if dry): $(human "$removed_bytes")"
}

cmd="${1:-}"
shift || true
case "$cmd" in
  report) report "$@" ;;
  sweep) sweep "$@" ;;
  "") usage; exit 2 ;;
  *) usage; exit 2 ;;
esac
