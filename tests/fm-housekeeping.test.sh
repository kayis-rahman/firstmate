#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/home/.no-mistakes" "$tmp/home/state" "$tmp/home/data" "$tmp/home/.cache/go-build" "$tmp/home/projects/sample" "$tmp/bin"
printf 'worktree=%s/shared\nkind=ship\n' "$tmp" > "$tmp/home/state/task-one.meta"
printf 'worktree=%s/shared\nkind=ship\n' "$tmp" > "$tmp/home/state/task-two.meta"
git -C "$tmp/home/projects/sample" init -b main >/dev/null
git -C "$tmp/home/projects/sample" config user.email test@example.invalid
git -C "$tmp/home/projects/sample" config user.name test
echo base > "$tmp/home/projects/sample/file"
git -C "$tmp/home/projects/sample" add file
git -C "$tmp/home/projects/sample" commit -m base >/dev/null
git -C "$tmp/home/projects/sample" branch merged
git -C "$tmp/home/projects/sample" switch -c unmerged >/dev/null
echo change >> "$tmp/home/projects/sample/file"
git -C "$tmp/home/projects/sample" commit -am unmerged >/dev/null
git -C "$tmp/home/projects/sample" switch main >/dev/null
mkdir -p "$tmp/home/data/finished-task"
printf 'worktree=%s/missing\nkind=ship\n' "$tmp" > "$tmp/home/state/finished-task.meta"
printf 'evidence\n' > "$tmp/home/data/finished-task/report.md"
cat > "$tmp/bin/lsof" <<'EOF'
#!/usr/bin/env bash
if [ "${LSOF_ACTIVE:-}" = 1 ]; then
  echo 'active process'
  exit 0
fi
exit 1
EOF
chmod +x "$tmp/bin/lsof"
HOME="$tmp/home" FM_HOME="$tmp/home" FM_ROOT_OVERRIDE="$ROOT" PATH="$tmp/bin:$PATH" bash "$ROOT/bin/fm-housekeeping.sh" scan "$tmp/report.tsv" >/dev/null
grep -q '^class[[:space:]]id[[:space:]]path' "$tmp/report.tsv"
grep -q '^keep[[:space:]].*finished-task' "$tmp/report.tsv"
grep -q 'merged-merged-to-main-local-only' "$tmp/report.tsv"
grep -q 'unmerged-not-proven-merged' "$tmp/report.tsv"
grep -q '^keep[[:space:]].*references=2' "$tmp/report.tsv"
keep_id=$(awk -F '\t' '$1 == "keep" { print $2; exit }' "$tmp/report.tsv")
printf '%s\n' "$keep_id" > "$tmp/approved.txt"
if HOME="$tmp/home" FM_HOME="$tmp/home" PATH="$tmp/bin:$PATH" bash "$ROOT/bin/fm-housekeeping.sh" apply "$tmp/report.tsv" "$tmp/approved.txt" >/dev/null 2>&1; then
  echo 'keep item unexpectedly applied' >&2
  exit 1
fi
[ -f "$tmp/home/data/finished-task/report.md" ]
branch_id=$(awk -F '\t' '$1 == "probably-safe" && $4 == "branch" && $5 ~ /merged-to-main-local-only/ { print $2; exit }' "$tmp/report.tsv")
test -n "$branch_id"
printf '%s\n' "$branch_id" > "$tmp/approved.txt"
HOME="$tmp/home" FM_HOME="$tmp/home" PATH="$tmp/bin:$PATH" bash "$ROOT/bin/fm-housekeeping.sh" apply "$tmp/report.tsv" "$tmp/approved.txt" >/dev/null
git -C "$tmp/home/projects/sample" show-ref --verify --quiet refs/heads/merged
HOME="$tmp/home" FM_HOME="$tmp/home" PATH="$tmp/bin:$PATH" bash "$ROOT/bin/fm-housekeeping.sh" apply "$tmp/report.tsv" "$tmp/approved.txt" --execute >/dev/null
if git -C "$tmp/home/projects/sample" show-ref --verify --quiet refs/heads/merged; then
  echo 'approved merged branch was not removed' >&2
  exit 1
fi
cache_id=$(awk -F '\t' '$1 == "probably-safe" && $4 == "cache" { print $2; exit }' "$tmp/report.tsv")
test -n "$cache_id"
printf '%s\n' "$cache_id" > "$tmp/approved.txt"
HOME="$tmp/home" FM_HOME="$tmp/home" PATH="$tmp/bin:$PATH" bash "$ROOT/bin/fm-housekeeping.sh" apply "$tmp/report.tsv" "$tmp/approved.txt" >/dev/null
[ -d "$tmp/home/.cache/go-build" ]
HOME="$tmp/home" FM_HOME="$tmp/home" PATH="$tmp/bin:$PATH" bash "$ROOT/bin/fm-housekeeping.sh" apply "$tmp/report.tsv" "$tmp/approved.txt" --execute >/dev/null
[ ! -e "$tmp/home/.cache/go-build" ]
grep -q "RECEIPT.*$cache_id" "$tmp/home/state/housekeeping-receipts.tsv"
mkdir -p "$tmp/home/.cache/go-build"
LSOF_ACTIVE=1 HOME="$tmp/home" FM_HOME="$tmp/home" FM_ROOT_OVERRIDE="$ROOT" PATH="$tmp/bin:$PATH" bash "$ROOT/bin/fm-housekeeping.sh" scan "$tmp/active-report.tsv" >/dev/null
active_id=$(awk -F '\t' '$1 == "keep" && $4 == "cache" { print $2; exit }' "$tmp/active-report.tsv")
test -n "$active_id"
printf '%s\n' "$active_id" > "$tmp/approved.txt"
if LSOF_ACTIVE=1 HOME="$tmp/home" FM_HOME="$tmp/home" PATH="$tmp/bin:$PATH" bash "$ROOT/bin/fm-housekeeping.sh" apply "$tmp/active-report.tsv" "$tmp/approved.txt" --execute >/dev/null 2>&1; then
  echo 'active cache unexpectedly applied' >&2
  exit 1
fi
[ -d "$tmp/home/.cache/go-build" ]
# An orphaned browser (parent already gone, a chrome executable, and a scratch /tmp
# profile) is a cleanup candidate. A browser with a live parent, and a process that is
# not a browser, are not. The scanner reads the process table through ps, so this case
# drives it with a ps stub plus one real disposable process to signal. The stub's
# process exits 0 on TERM so the suite's own output stays free of job-status noise.
bash -c 'trap "exit 0" TERM; while :; do sleep 1; done' &
orphan_pid=$!
live_pid=424242
chrome_cmdline="/tmp/fake/chrome-headless-shell --headless --remote-debugging-port=9299 --user-data-dir=/tmp/fm-test-chrome about:blank"
cat > "$tmp/bin/ps" <<EOF
#!/usr/bin/env bash
ax=0; want_ppid=0; want_cmd=0; pid=
while [ \$# -gt 0 ]; do
  case "\$1" in
    ax) ax=1 ;;
    *ppid=*) want_ppid=1 ;;
    *command=*) want_cmd=1 ;;
    -p) shift; pid=\$1 ;;
  esac
  shift
done
if [ "\$ax" = 1 ]; then
  printf '%s\n' "$orphan_pid $chrome_cmdline" "$live_pid $chrome_cmdline" "$orphan_pid /bin/sleep 300"
  exit 0
fi
if [ "\$want_ppid" = 1 ]; then
  [ "\$pid" = "$orphan_pid" ] && { echo 1; exit 0; }
  [ "\$pid" = "$live_pid" ] && { echo "$live_pid"; exit 0; }
  echo 0; exit 0
fi
if [ "\$want_cmd" = 1 ]; then
  echo "$chrome_cmdline"; exit 0
fi
exit 1
EOF
chmod +x "$tmp/bin/ps"
HOME="$tmp/home" FM_HOME="$tmp/home" FM_ROOT_OVERRIDE="$ROOT" PATH="$tmp/bin:$PATH" bash "$ROOT/bin/fm-housekeeping.sh" scan "$tmp/proc-report.tsv" >/dev/null
proc_id=$(awk -F '\t' '$1 == "probably-safe" && $4 == "process" { print $2; exit }' "$tmp/proc-report.tsv")
test -n "$proc_id"
grep -q "orphaned-browser pid=$orphan_pid" "$tmp/proc-report.tsv"
if grep -q "pid=$live_pid" "$tmp/proc-report.tsv"; then
  echo 'a browser with a live parent was reported as an orphan' >&2
  exit 1
fi
printf '%s\n' "$proc_id" > "$tmp/approved.txt"
HOME="$tmp/home" FM_HOME="$tmp/home" PATH="$tmp/bin:$PATH" bash "$ROOT/bin/fm-housekeeping.sh" apply "$tmp/proc-report.tsv" "$tmp/approved.txt" >/dev/null
kill -0 "$orphan_pid" || { echo 'the dry run signalled the process' >&2; exit 1; }
HOME="$tmp/home" FM_HOME="$tmp/home" PATH="$tmp/bin:$PATH" bash "$ROOT/bin/fm-housekeeping.sh" apply "$tmp/proc-report.tsv" "$tmp/approved.txt" --execute >/dev/null
wait "$orphan_pid" 2>/dev/null || true
if kill -0 "$orphan_pid" 2>/dev/null; then
  echo 'an approved orphaned browser was not signalled' >&2
  exit 1
fi
grep -q "RECEIPT.*$proc_id" "$tmp/home/state/housekeeping-receipts.tsv"
# A process the report never listed, and one whose parent is alive, both refuse.
printf 'pid:999999\n' > "$tmp/approved.txt"
if HOME="$tmp/home" FM_HOME="$tmp/home" PATH="$tmp/bin:$PATH" bash "$ROOT/bin/fm-housekeeping.sh" apply "$tmp/proc-report.tsv" "$tmp/approved.txt" --execute >/dev/null 2>&1; then
  echo 'an unapproved process id was applied' >&2
  exit 1
fi
echo 'fm-housekeeping: PASS'
