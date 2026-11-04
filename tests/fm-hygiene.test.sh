#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

HM="$tmp/home"
mkdir -p "$HM/state" "$HM/data/task1" "$HM/config"
printf 'state: done\n' > "$HM/state/task1.status"
printf 'big\n' > "$HM/data/task1/big.png"
dd if=/dev/zero of="$HM/data/task1/big.png" bs=1024 count=250 >/dev/null 2>&1
mkdir -p "$HM/data/task1/selectedfoo"
printf 'keep\n' > "$HM/data/task1/selectedfoo/x.png"
printf 'internal / 20\nexternal /Volumes/Nope 3\n' > "$HM/config/disk-thresholds"

FM_HOME="$HM" FM_ROOT_OVERRIDE="$ROOT" bash "$ROOT/bin/fm-hygiene.sh" report >/tmp/hygiene-report.txt
grep -q 'ALARM\|disk:' /tmp/hygiene-report.txt

# dry run does not delete
FM_HOME="$HM" FM_ROOT_OVERRIDE="$ROOT" bash "$ROOT/bin/fm-hygiene.sh" sweep >/tmp/hygiene-sweep.txt
test -f "$HM/data/task1/big.png"

# yes deletes large media only
FM_HOME="$HM" FM_ROOT_OVERRIDE="$ROOT" bash "$ROOT/bin/fm-hygiene.sh" sweep --yes >/tmp/hygiene-sweep2.txt
test ! -f "$HM/data/task1/big.png"
test -f "$HM/data/task1/selectedfoo/x.png"
echo PASS
