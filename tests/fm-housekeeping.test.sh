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
echo 'fm-housekeeping: PASS'
