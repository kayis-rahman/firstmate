#!/usr/bin/env bash
# fm-discord-front-desk-gate.sh - accept only an explicit primary front-desk steer.
#
# Read the trusted parent-to-mate instruction header from stdin and exit 0 only
# when the first line starts with the delegation marker. The caller must pass
# the internal steer, never the Discord payload; this cannot establish who
# authored arbitrary input or enforce the primary's busy-time threshold.
set -euo pipefail

if [ "$#" -ne 0 ]; then
  printf 'usage: %s < trusted-parent-steer\n' "${0##*/}" >&2
  exit 2
fi

header=
IFS= read -r header || [ -n "$header" ] || exit 1
case "$header" in
  'Front desk request'|'Front desk request:'*|'Front desk request '*) exit 0 ;;
  *) exit 1 ;;
esac
