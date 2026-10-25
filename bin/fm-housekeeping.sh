#!/usr/bin/env bash
# Read-only housekeeping inventory and explicitly approved cleanup.
# Usage: fm-housekeeping.sh scan [report] | apply <report> <approved-list> [--execute]
# Scan never deletes. Apply accepts only candidate IDs present in the selected report.
set -u
export LC_ALL=C
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
HOME_DIR="${FM_HOME:-$ROOT}"
STATE="${FM_STATE_OVERRIDE:-$HOME_DIR/state}"
REPORT=${2:-"$HOME_DIR/data/housekeeping-report-$(date +%Y%m%d-%H%M%S).tsv"}
usage() { echo 'Usage: fm-housekeeping.sh scan [report-path] | apply <report-path> <approved-list-file> | arm'; }
size_bytes() { du -sk "$1" 2>/dev/null | awk '{print $1 * 1024}'; }
item_id() { printf '%s' "$1" | cksum | awk '{print $1}'; }
add() { printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$(item_id "$2:$3:$4")" "$2" "$3" "$4" >> "$OUT"; }
# Orphaned browser automation outlives the session that started it: a chrome reparented
# to launchd keeps its pinned debugging port and hundreds of megabytes until a person
# finds it by hand. Only a process whose parent is already gone, whose executable is a
# chrome binary, and whose profile is a scratch /tmp profile is a candidate, and apply
# re-checks all three before it signals anything.
scan_orphaned_browsers() {
  command -v ps >/dev/null 2>&1 || return 0
  local line pid ppid profile
  while IFS= read -r line; do
    pid=${line%% *}
    case "$pid" in ''|*[!0-9]*) continue ;; esac
    ppid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
    [ "$ppid" = 1 ] || continue
    profile=$(printf '%s' "$line" | sed -n 's/.*[[:space:]]--user-data-dir=\([^[:space:]]*\).*/\1/p')
    case "$profile" in /tmp/*|/private/tmp/*) ;; *) continue ;; esac
    add probably-safe "pid:$pid" process "orphaned-browser pid=$pid profile=$profile"
  done < <(ps ax -o pid=,command= 2>/dev/null | awk '{ exe=$2; sub(/.*\//, "", exe); if (exe == "chrome" || exe == "chrome-headless-shell" || exe == "Chromium" || exe == "chromium") print }')
}
scan_size() {
  local path=$1 cap=$2 size
  [ -e "$path" ] || return 0
  size=$(size_bytes "$path") || return 0
  if [ "$size" -gt "$cap" ]; then add probably-safe "$path" cap "${size}bytes-over-${cap}bytes-limit-check-only"; else add safe "$path" cap "${size}bytes-within-${cap}bytes"; fi
}
scan() {
  local output=$1 path branch
  umask 077
  mkdir -p "$(dirname "$output")" || return 1
  OUT=$output
  printf 'class\tid\tpath\taction\tdetail\n' > "$OUT" || return 1
  scan_size "${HOME:-$HOME_DIR}/.treehouse" $((8*1024*1024*1024))
  scan_size "${HOME:-$HOME_DIR}/.no-mistakes" $((7*1024*1024*1024))
  scan_size "${HOME:-$HOME_DIR}/Models/huggingface" $((40*1024*1024*1024))
  if [ ! -L "${HOME:-$HOME_DIR}/.cache/huggingface" ]; then scan_size "${HOME:-$HOME_DIR}/.cache/huggingface" $((40*1024*1024*1024)); fi
  for path in "${HOME:-$HOME_DIR}"/.cache/Homebrew "${HOME:-$HOME_DIR}"/.cache/ms-playwright "${HOME:-$HOME_DIR}"/.cache/go-build "${HOME:-$HOME_DIR}"/Library/Caches/Homebrew "${HOME:-$HOME_DIR}"/Library/Caches/ms-playwright "${HOME:-$HOME_DIR}"/Library/Caches/go-build "${HOME:-$HOME_DIR}"/.cache/uv "${HOME:-$HOME_DIR}"/Library/Caches/uv "${HOME:-$HOME_DIR}"/.cache/huggingface/xet; do
    scan_size "$path" $((2*1024*1024*1024))
    [ -e "$path" ] || continue
    if [ -L "$path" ] || [ ! -d "$path" ]; then add keep "$path" cache 'not-a-real-directory';
    elif ! command -v lsof >/dev/null 2>&1; then add keep "$path" cache 'lsof-unavailable';
    else
      lsof_output=$(lsof +D "$path" 2>&1) && lsof_rc=0 || lsof_rc=$?
      if [ -n "$lsof_output" ] || [ "$lsof_rc" -gt 1 ]; then add keep "$path" cache 'active-or-cannot-verify'; else add probably-safe "$path" cache 'inactive-recognized-cache-review-required'; fi
    fi
  done
  for path in "${TMPDIR:-/tmp}" "${HOME:-$HOME_DIR}"/tmp "${HOME:-$HOME_DIR}"/.cache/tmp "${HOME:-$HOME_DIR}"/Library/Caches/*build*; do scan_size "$path" $((1024*1024*1024)); done
  for path in "${HOME:-$HOME_DIR}"/.treehouse/*/worktrees/* "${HOME:-$HOME_DIR}"/.treehouse/*/*/worktrees/*; do
    [ -e "$path" ] || continue
    add keep "$path" treehouse-slot "shared-work-area-requires-live-task-reconciliation"
  done
  for path in "${HOME:-$HOME_DIR}"/no-mistakes/logs/* "${HOME:-$HOME_DIR}"/.no-mistakes/logs/*; do
    [ -e "$path" ] || continue
    if find "$path" -prune -mtime +7 -print -quit | grep -q .; then add safe "$path" log "older-than-7-days"; else add keep "$path" log "within-7-days"; fi
  done
  for path in "$HOME_DIR"/data/*; do
    [ -d "$path" ] || continue
    task=${path##*/}
    meta="$HOME_DIR/state/$task.meta"
    [ -f "$meta" ] || continue
    task_state=$("$SCRIPT_DIR/fm-crew-state.sh" "$task" 2>/dev/null || printf 'state: unknown')
    printf '%s' "$task_state" | grep -q 'state: done\|state: failed' || { add keep "$path" evidence 'task-not-proven-finished'; continue; }
    if find "$path" -prune -mtime +20 -print -quit | grep -q .; then add probably-safe "$path" evidence "older-than-20-days-archive-before-removal"; else add keep "$path" evidence "within-20-days"; fi
  done
  for path in "$HOME_DIR"/state/*.meta; do
    [ -f "$path" ] || continue
    task=${path##*/}; task=${task%.meta}
    workarea=$(grep '^worktree=' "$path" | tail -1 | cut -d= -f2-)
    [ -n "$workarea" ] || continue
    references=$(grep -lFx "worktree=$workarea" "$HOME_DIR"/state/*.meta 2>/dev/null | wc -l | tr -d ' ')
    live_state=$("$SCRIPT_DIR/fm-crew-state.sh" "$task" 2>/dev/null || printf 'state: unknown')
    if [ "$references" -gt 1 ] || ! printf '%s' "$live_state" | grep -q 'state: done\|state: failed'; then
      add keep "$workarea" worker "task=$task references=$references $live_state"
    else
      add probably-safe "$workarea" worker "task=$task references=$references $live_state; guarded-fm-teardown-required"
    fi
  done
  for path in "$HOME_DIR"/state/*.status; do [ -f "$path" ] || continue; add keep "$path" worker-record "status-history-is-not-current-state"; done
  scan_orphaned_browsers
  if [ -d "$HOME_DIR/.treehouse" ]; then
    read -r total_kb free_kb < <(df -Pk "$HOME_DIR/.treehouse" | awk 'NR == 2 { print $2, $4 }')
    if [[ "$total_kb" =~ ^[0-9]+$ && "$free_kb" =~ ^[0-9]+$ && "$total_kb" -gt 0 ]]; then
      free_pct=$((free_kb * 100 / total_kb))
      printf 'capacity\tfilesystem\t%s\tfree-space\t%s%%-free-alert-below-15-refuse-large-work-below-10\n' "$HOME_DIR/.treehouse" "$free_pct" >> "$OUT"
    fi
  fi
  for path in "$HOME_DIR"/projects/*; do
    [ -d "$path" ] || continue
    git -C "$path" rev-parse --git-dir >/dev/null 2>&1 || continue
    remote_url=$(git -C "$path" remote get-url origin 2>/dev/null || true)
    repo_slug=$(printf '%s' "$remote_url" | sed -E 's#^git@github.com:##; s#^https://github.com/##; s#\.git$##')
    merged_pr_heads=
    case "$repo_slug" in */*) merged_pr_heads=$(gh-axi api "/repos/$repo_slug/pulls?state=closed&per_page=100" --paginate --jq '.[] | select(.merged_at != null) | .head.ref' 2>/dev/null || true) ;; esac
    while IFS= read -r branch; do
      [ -n "$branch" ] || continue
      if git -C "$path" worktree list --porcelain | grep -Fqx "branch refs/heads/$branch"; then add keep "$path" branch "$branch-checked-out-in-worktree"; continue; fi
      dirty_worktree=
      while IFS= read -r worktree_path; do
        [ -d "$worktree_path" ] || continue
        if git -C "$worktree_path" status --porcelain | grep -q .; then dirty_worktree=$worktree_path; break; fi
      done < <(git -C "$path" worktree list --porcelain | awk '$1 == "worktree" { print $2 }')
      if [ -n "$dirty_worktree" ]; then add keep "$path" branch "$branch-unlanded-work-in-$dirty_worktree"; continue; fi
      case "$branch" in archive/*|refs/archive/*) add keep "$path" branch "$branch-archive-ref"; continue ;; esac
      if git -C "$path" worktree list --porcelain | awk -v b="refs/heads/$branch" '$1 == "branch" && $2 == b { found=1 } END { exit !found }'; then add keep "$path" branch "$branch-checked-out-in-worktree"; continue; fi
      if git -C "$path" merge-base --is-ancestor "$branch" main 2>/dev/null; then add probably-safe "$path" branch "$branch-merged-to-main-local-only"; elif printf '%s\n' "$merged_pr_heads" | grep -Fxq "$branch"; then add probably-safe "$path" branch "$branch-merged-github-pr"; else add keep "$path" branch "$branch-not-proven-merged"; fi
    done < <(git -C "$path" for-each-ref --format='%(refname:short)' refs/heads)
    while IFS= read -r archived; do [ -n "$archived" ] && add keep "$path" branch "$archived-archive-ref"; done < <(git -C "$path" for-each-ref --format='%(refname:short)' refs/archive)
  done
  for path in "$HOME_DIR"/data/*lavish* "$HOME_DIR"/state/*lavish*; do
    [ -e "$path" ] || continue
    if find "$path" -prune -mtime +30 -print -quit | grep -q .; then add probably-safe "$path" board 'board-older-than-30-days'; else add keep "$path" board 'recent-board'; fi
  done
  printf 'Scan report: %s\n' "$output"
}
apply() {
  local report=$1 approved=$2 mode=${3:-} requested id class path action detail matched receipt pid
  [ "$mode" = "" ] || [ "$mode" = --execute ] || { echo 'invalid apply mode' >&2; return 2; }
  receipt="$STATE/housekeeping-receipts.tsv"
  [ -f "$report" ] && [ ! -L "$report" ] || { echo 'invalid report' >&2; return 1; }
  [ -f "$approved" ] && [ ! -L "$approved" ] || { echo 'invalid approval list' >&2; return 1; }
  while IFS= read -r requested || [ -n "$requested" ]; do
    [ -n "$requested" ] || continue
    matched=0
    while IFS=$'\t' read -r class id path action detail; do
      [ "$requested" = "$id" ] || continue
      matched=1
      case "$class:$action" in
        keep:*) echo "refusing keep item: $requested" >&2; return 1 ;;
        safe:cap) echo "nothing to remove for within-limit item: $requested" >&2; return 1 ;;
        probably-safe:cache)
          [ -d "$path" ] && [ ! -L "$path" ] || { echo "refusing non-directory cache: $path" >&2; return 1; }
          home_real=$(cd "${HOME:-$HOME_DIR}" && pwd -P) || return 1
          parent_real=$(cd "$(dirname "$path")" 2>/dev/null && pwd -P) || return 1
          case "$parent_real/" in "$home_real/"*) ;; *) echo "refusing cache outside home: $path" >&2; return 1 ;; esac
          command -v lsof >/dev/null 2>&1 || { echo 'refusing cache cleanup: lsof unavailable' >&2; return 1; }
          lsof_output=$(lsof +D "$path" 2>&1) && lsof_rc=0 || lsof_rc=$?
          [ -z "$lsof_output" ] && [ "$lsof_rc" -le 1 ] || { echo "refusing active or unverifiable cache: $path" >&2; return 1; }
          if [ "$mode" = --execute ]; then rm -rf -- "$path" || return 1; else printf 'DRY-RUN\t%s\t%s\n' "$requested" "$path"; fi
          ;;
        probably-safe:evidence)
          archive="$HOME_DIR/data/archive/$(basename "$path")"
          [ ! -e "$archive" ] || { echo "refusing archive collision: $archive" >&2; return 1; }
          if [ "$mode" = --execute ]; then mkdir -p "$(dirname "$archive")" && mv -- "$path" "$archive" || return 1; else printf 'DRY-RUN\t%s\tarchive-to\t%s\n' "$requested" "$archive"; fi
          ;;
        safe:log)
          [ -f "$path" ] && [ ! -L "$path" ] || { echo "refusing non-regular log: $path" >&2; return 1; }
          find "$path" -prune -mtime +7 -print -quit | grep -q . || { echo "refusing recent log: $path" >&2; return 1; }
          if [ "$mode" = --execute ]; then
            rm -- "$path" || return 1
          else
            printf 'DRY-RUN\t%s\t%s\n' "$requested" "$path"
          fi
          ;;
        probably-safe:worker)
          [ "$mode" = --execute ] || { printf 'DRY-RUN\t%s\tguarded-fm-teardown-required\n' "$requested"; continue; }
          task=${detail#task=}; task=${task%% *}
          [ -n "$task" ] || { echo 'refusing worker item without task id' >&2; return 1; }
          "$SCRIPT_DIR/fm-teardown.sh" "$task" || return 1
          ;;
        probably-safe:process)
          case "$path" in pid:*) pid=${path#pid:} ;; *) echo "refusing malformed process item: $path" >&2; return 1 ;; esac
          case "$pid" in ''|*[!0-9]*) echo "refusing non-numeric process item: $path" >&2; return 1 ;; esac
          command -v ps >/dev/null 2>&1 || { echo 'refusing process cleanup: ps unavailable' >&2; return 1; }
          kill -0 "$pid" 2>/dev/null || { echo "refusing missing process: $pid" >&2; return 1; }
          [ "$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')" = 1 ] || { echo "refusing process with a live parent: $pid" >&2; return 1; }
          ps -o command= -p "$pid" 2>/dev/null | grep -qE -- '--user-data-dir=(/tmp|/private/tmp)/' || { echo "refusing unverified browser process: $pid" >&2; return 1; }
          if [ "$mode" = --execute ]; then
            kill -TERM "$pid" 2>/dev/null || return 1
            for _ in 1 2 3 4 5 6; do kill -0 "$pid" 2>/dev/null || break; sleep 0.5; done
            kill -0 "$pid" 2>/dev/null && { kill -KILL "$pid" 2>/dev/null || return 1; }
          else
            printf 'DRY-RUN\t%s\tkill\t%s\n' "$requested" "$pid"
          fi
          ;;
        probably-safe:branch)
          [ -d "$path/.git" ] || { echo "refusing changed project: $path" >&2; return 1; }
          case "$detail" in
            *-merged-to-main-local-only) branch=${detail%-merged-to-main-local-only} ;;
            *-merged-github-pr) branch=${detail%-merged-github-pr} ;;
            *) echo "refusing branch without merge evidence: $detail" >&2; return 1 ;;
          esac
          case "$branch" in archive/*|refs/archive/*) echo "refusing archive ref: $branch" >&2; return 1 ;; esac
          git -C "$path" worktree list --porcelain | grep -Fqx "branch refs/heads/$branch" && { echo "refusing checked-out branch: $branch" >&2; return 1; }
          while IFS= read -r worktree_path; do
            [ -d "$worktree_path" ] || continue
            git -C "$worktree_path" status --porcelain | grep -q . && { echo "refusing project with unlanded work: $worktree_path" >&2; return 1; }
          done < <(git -C "$path" worktree list --porcelain | awk '$1 == "worktree" { print $2 }')
          if [ "$detail" = "${branch}-merged-to-main-local-only" ]; then
            git -C "$path" merge-base --is-ancestor "$branch" main || { echo "refusing unmerged branch: $branch" >&2; return 1; }
          else
            remote_url=$(git -C "$path" remote get-url origin 2>/dev/null || true)
            repo_slug=$(printf '%s' "$remote_url" | sed -E 's#^git@github.com:##; s#^https://github.com/##; s#\\.git$##')
            merged_pr_heads=$(gh-axi api "/repos/$repo_slug/pulls?state=closed&per_page=100" --paginate --jq '.[] | select(.merged_at != null) | .head.ref' 2>/dev/null || true)
            printf '%s\\n' "$merged_pr_heads" | grep -Fxq "$branch" || { echo "refusing branch without current merged-PR evidence: $branch" >&2; return 1; }
          fi
          if [ "$mode" = --execute ]; then git -C "$path" branch -d -- "$branch" || return 1; else printf 'DRY-RUN\\t%s\\t%s\\n' "$requested" "$branch"; fi
          ;;
        *) echo "item is review-only and cannot be applied automatically: $requested" >&2; return 1 ;;
      esac
      if [ "$mode" = --execute ]; then
        mkdir -p "$STATE" || return 1
        printf 'RECEIPT\t%s\t%s\t%s\n' "$requested" "$action" "$(date -u +%FT%TZ)" >> "$receipt" || return 1
      fi
    done < "$report"
    [ "$matched" = 1 ] || { echo "unapproved item: $requested" >&2; return 1; }
  done < "$approved"
}
arm() {
  mkdir -p "$STATE" || return 1
  cat > "$STATE/housekeeping-weekly.check.sh" <<EOF
#!/usr/bin/env bash
exec "$SCRIPT_DIR/fm-housekeeping.sh" check
EOF
  chmod 700 "$STATE/housekeeping-weekly.check.sh" || return 1
  "$SCRIPT_DIR/fm-check-register.sh" housekeeping-weekly
}
check_weekly() {
  local record="$STATE/.housekeeping-last-scan" now previous
  now=$(date +%s)
  previous=0
  [ ! -f "$record" ] || read -r previous < "$record"
  case "$previous" in ''|*[!0-9]*) previous=0 ;; esac
  [ $((now - previous)) -ge 604800 ] || return 0
  scan "$HOME_DIR/data/housekeeping-report-$(date +%Y%m%d).tsv" || return 1
  printf '%s\n' "$now" > "$record"
}
case "${1:-}" in
  scan) scan "$REPORT" ;;
  check) check_weekly ;;
  apply) [ "$#" -eq 3 ] || [ "$#" -eq 4 ] || { usage >&2; exit 2; }; apply "$2" "$3" "${4:-}" ;;
  arm) [ "$#" -eq 1 ] || { usage >&2; exit 2; }; arm ;;
  -h|--help) usage ;;
  *) usage >&2; exit 2 ;;
esac
