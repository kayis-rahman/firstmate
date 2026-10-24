#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/bin/fm-storage-policy.sh"
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/fm-storage-policy.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT
mkdir -p "$TMP_ROOT/bin" "$TMP_ROOT/home/.cache/uv" "$TMP_ROOT/home/.cache/go-build" "$TMP_ROOT/home/.cache/huggingface/hub" "$TMP_ROOT/mount point"
printf keep > "$TMP_ROOT/home/.cache/uv/keep"
cat > "$TMP_ROOT/bin/df" <<'SH'
#!/usr/bin/env bash
printf 'Filesystem 1024-blocks Used Available Capacity Mounted on\n/dev/fake %s %s %s 80%% /\n' "${FM_TEST_TOTAL:-100000000}" "${FM_TEST_USED:-80000000}" "${FM_TEST_FREE:-20000000}"
SH
cat > "$TMP_ROOT/bin/lsof" <<'SH'
#!/usr/bin/env bash
if [ "${FM_TEST_ACTIVE:-0}" = 1 ]; then
  printf 'COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME\nworker 12 me 3r REG 1 1 1 %s/file\n' "$2"
  exit 0
fi
exit 1
SH
chmod +x "$TMP_ROOT/bin/df" "$TMP_ROOT/bin/lsof"
run() { HOME="$TMP_ROOT/home" PATH="$TMP_ROOT/bin:$PATH" "$SCRIPT" "$@"; }

out=$(run --path "$TMP_ROOT/mount point")
[[ "$out" == *'free=20%'* && "$out" == *'reserve_target_gib=30'* ]] || { echo "threshold calculation failed: $out" >&2; exit 1; }
[[ "$out" == *"cache=candidate path=$TMP_ROOT/home/.cache/uv"* ]] || { echo "known cache not identified: $out" >&2; exit 1; }
[ -f "$TMP_ROOT/home/.cache/uv/keep" ] || { echo 'dry run removed a cache entry' >&2; exit 1; }
printf 'ok - threshold calculation and dry-run preservation\n'

set +e
FM_TEST_FREE=9000000 FM_TEST_USED=91000000 HOME="$TMP_ROOT/home" PATH="$TMP_ROOT/bin:$PATH" "$SCRIPT" --path "$TMP_ROOT/mount point" --large-work >/dev/null
rc=$?
set -e
[ "$rc" -eq 3 ] || { echo "below-10-percent work was not refused (exit=$rc)" >&2; exit 1; }
printf 'ok - large work refused below ten percent free\n'

out=$(HOME="$TMP_ROOT/home" PATH="$TMP_ROOT/bin:$PATH" FM_TEST_FREE=14000000 FM_TEST_USED=86000000 "$SCRIPT" --path "$TMP_ROOT/mount point")
[[ "$out" == *'free=14%'* && "$out" == *'alert=low-free-space'* ]] || { echo "15-percent alert failed: $out" >&2; exit 1; }
printf 'ok - alert threshold below fifteen percent free\n'

out=$(FM_TEST_ACTIVE=1 run --path "$TMP_ROOT/mount point" --clean)
[[ "$out" == *'reason=active-or-cannot-verify'* ]] || { echo "active cache was not skipped: $out" >&2; exit 1; }
[ -f "$TMP_ROOT/home/.cache/uv/keep" ] || { echo 'active cache was removed' >&2; exit 1; }
printf 'ok - active cache safeguard\n'

out=$(run --path "$TMP_ROOT/mount point" --clean)
[ ! -e "$TMP_ROOT/home/.cache/uv" ] || { echo 'inactive known cache was not removed' >&2; exit 1; }
[ -d "$TMP_ROOT/home/.cache/huggingface/hub" ] || { echo 'Hugging Face model cache was removed' >&2; exit 1; }
printf 'ok - explicit cleanup removes known cache but preserves model data\n'

mkdir -p "$TMP_ROOT/elsewhere"
ln -s "$TMP_ROOT/elsewhere" "$TMP_ROOT/home/.cache/huggingface/xet"
out=$(run --path "$TMP_ROOT/mount point" --clean)
[[ "$out" == *'reason=not-a-real-directory'* ]] || { echo "symlink cache path was not rejected: $out" >&2; exit 1; }
[ -d "$TMP_ROOT/elsewhere" ] || { echo 'symlink target was affected' >&2; exit 1; }
printf 'ok - symlink cache path rejected\n'

mkdir -p "$TMP_ROOT/linked-home" "$TMP_ROOT/elsewhere/uv"
ln -s "$TMP_ROOT/elsewhere" "$TMP_ROOT/linked-home/.cache"
out=$(HOME="$TMP_ROOT/linked-home" PATH="$TMP_ROOT/bin:$PATH" "$SCRIPT" --path "$TMP_ROOT/mount point" --clean)
[[ "$out" == *'reason=outside-home-or-unresolvable'* ]] || { echo "cache parent escaping home was not rejected: $out" >&2; exit 1; }
[ -d "$TMP_ROOT/elsewhere" ] || { echo 'external cache target was affected' >&2; exit 1; }
printf 'ok - cache parent escaping home rejected\n'
