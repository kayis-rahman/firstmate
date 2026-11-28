#!/usr/bin/env bash
# fm-agy-account-quota.sh - measure each agy account a home declares in
# config/agy-accounts, in isolation, and print each one's quota facts.
#
# Usage:
#   fm-agy-account-quota.sh [--model <model>]
#
# For every declared entry, in file order, runs
#   HOME=<root> quota-axi --provider agy --json
# where <root> is the entry's own HOME directory, or the caller's HOME for
# `ordinary`. QUOTA_AXI_SNAPSHOT is removed from each read so a fixture for one
# account cannot answer for all.
#
# Output (stdout, TOON-style block), one or more lines per declared entry in
# file order:
#   agy-account-quota:
#     row: <entry>  root=<dir>  scope=<scope>  status=..  remaining=..%  spendPriority=..  runway=..  usableRunwaySeconds=..  confidence=..
#     row: <entry>  root=<dir>  uncertainty: <why this account is not fully measured>
#
# Data only: this never launches agy, checks a sign-in, writes a credential,
# rotates accounts, or changes any home or account file. bin/fm-spawn.sh runs
# the sign-in check for the account a launch names.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
FM_HOME="${FM_HOME:-$FM_ROOT}"
CONFIG="${FM_CONFIG_OVERRIDE:-$FM_HOME/config}"

# shellcheck source=bin/fm-worker-account-lib.sh
. "$SCRIPT_DIR/fm-worker-account-lib.sh"
# shellcheck source=bin/fm-quota-axi-lib.sh
. "$SCRIPT_DIR/fm-quota-axi-lib.sh"
# shellcheck source=bin/fm-account-quota-lib.sh
. "$SCRIPT_DIR/fm-account-quota-lib.sh"

FM_AGY_ACCOUNT_QUOTA_SECONDS=${FM_AGY_ACCOUNT_QUOTA_SECONDS:-60}

die() { printf 'error: %s\n' "$1" >&2; exit 2; }
usage() {
  awk '
    NR == 1 { next }
    /^#/ { sub(/^# ?/, ""); print; next }
    { exit }
  ' "${BASH_SOURCE[0]}"
}

MODEL=
while [ "$#" -gt 0 ]; do
  case "$1" in
    --model)
      [ -n "${2-}" ] || die "--model needs a value"
      MODEL=$2
      shift 2
      ;;
    --model=*)
      MODEL=${1#--model=}
      [ -n "$MODEL" ] || die "--model needs a value"
      shift
      ;;
    -h|--help|help) usage; exit 0 ;;
    *) die "unexpected argument: $1" ;;
  esac
done
[ "$MODEL" != default ] || MODEL=

fm_account_quota_report agy "$CONFIG" "$MODEL"
