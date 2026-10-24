#!/usr/bin/env bash
# Report filesystem reserve policy and optionally remove inactive, known disposable caches.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: bin/fm-storage-policy.sh [--path PATH] [--large-work] [--clean]

Reports free space on PATH (default: /). --large-work exits nonzero below 10% free.
--clean removes only recognized Go build, uv, and Hugging Face Xet caches, and
only when lsof confirms the cache is not open. Without --clean this is a dry run.
EOF
}

path=/
clean=0
large_work=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --path) [ "$#" -ge 2 ] || { usage >&2; exit 2; }; path=$2; shift 2 ;;
    --clean) clean=1; shift ;;
    --large-work) large_work=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

[ -d "$path" ] || { echo "error: filesystem path is not a directory: $path" >&2; exit 2; }
read -r total_kb free_kb < <(df -Pk "$path" | awk 'NR == 2 { print $2, $4 }')
[[ "$total_kb" =~ ^[0-9]+$ && "$free_kb" =~ ^[0-9]+$ && "$total_kb" -gt 0 ]] || {
  echo "error: could not measure filesystem at $path" >&2
  exit 2
}
free_pct=$((free_kb * 100 / total_kb))
reserve_kb=$((30 * 1024 * 1024))
[ "$total_kb" -lt "$reserve_kb" ] && reserve_kb=$total_kb
printf 'filesystem=%s free=%s%% free_gib=%s reserve_target_gib=%s alert_below=15%% refuse_large_work_below=10%%\n' \
  "$path" "$free_pct" "$((free_kb / 1024 / 1024))" "$((reserve_kb / 1024 / 1024))"
if [ "$free_pct" -lt 15 ]; then echo 'alert=low-free-space'; else echo 'alert=none'; fi
if [ "$free_pct" -lt 10 ]; then echo 'large_work=refused'; elif [ "$free_kb" -lt "$reserve_kb" ]; then echo 'large_work=allowed-reserve-below-practical-target'; else echo 'large_work=allowed'; fi
if [ "$large_work" -eq 1 ] && [ "$free_pct" -lt 10 ]; then exit 3; fi

home=${HOME:?HOME must be set}
home_real=$(cd "$home" && pwd -P) || { echo "error: cannot resolve HOME: $home" >&2; exit 2; }
candidates=(
  "$home/Library/Caches/go-build"
  "$home/.cache/go-build"
  "$home/.cache/uv"
  "$home/Library/Caches/uv"
  "$home/.cache/huggingface/xet"
)
for candidate in "${candidates[@]}"; do
  [ -e "$candidate" ] || continue
  candidate_parent=$(cd "$(dirname "$candidate")" 2>/dev/null && pwd -P) || candidate_parent=
  case "$candidate_parent/" in
    "$home_real/"*) ;;
    *) printf 'cache=skipped reason=outside-home-or-unresolvable path=%s\n' "$candidate"; continue ;;
  esac
  if [ -L "$candidate" ] || [ ! -d "$candidate" ]; then
    printf 'cache=skipped reason=not-a-real-directory path=%s\n' "$candidate"
    continue
  fi
  printf 'cache=candidate path=%s\n' "$candidate"
  [ "$clean" -eq 1 ] || continue
  command -v lsof >/dev/null 2>&1 || { echo 'cache=skipped reason=lsof-unavailable'; continue; }
  lsof_output=$(lsof +D "$candidate" 2>&1) && lsof_rc=0 || lsof_rc=$?
  if [ -n "$lsof_output" ] || [ "$lsof_rc" -gt 1 ]; then
    printf 'cache=skipped reason=active-or-cannot-verify path=%s\n' "$candidate"
    continue
  fi
  rm -rf -- "$candidate"
  printf 'cache=removed path=%s\n' "$candidate"
done
