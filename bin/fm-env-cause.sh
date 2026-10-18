#!/usr/bin/env bash
# fm-env-cause.sh - named-cause diagnostics for environment failures that
# otherwise read as ordinary blockers.
#
# Usage: fm-env-cause.sh classify [--darwin <0|1|auto>] [file | -]
#        fm-env-cause.sh classify [--darwin <0|1|auto>] < file
#
# WHY THIS EXISTS. Two real failures from the fleet (2026-10-17/18) reached
# firstmate as bare blockers with no named cause: a freshly built Go program
# dialing the dev database at 192.168.0.100:5435 got `connect: no route to
# host` while shell `nc -z` to the very same address succeeded, and the worker
# could only guess at "a process-specific network restriction or firewall".
# On macOS that pattern - a fresh program cannot reach a reachable LAN address
# while other tools can - is usually Local Network privacy (the per-program
# permission macOS applies to link-local/private-range traffic), so the
# diagnosis should say so and name the setting instead of leaving a generic
# blocker.
#
# THIS COMMAND IS DATA-ONLY CLASSIFICATION, NOT A VERDICT. `classify` reads
# failure text (a file, or stdin via `-` or no file) and prints zero or more
# `cause:` lines on stdout; it never exits non-zero for a classification miss
# and never claims certainty - every message it emits carries its own hedge.
# A caller appends the printed lines to the error it already reports, so the
# original evidence always survives next to the named cause.
#
# The Local Network privacy rule fires only when ALL of these hold:
#   - the platform is macOS (Darwin), decided by `uname` unless --darwin pins
#     it for tests or cross-host diagnosis;
#   - the text contains a host-unreachable marker: "no route to host",
#     "EHOSTUNREACH", or "host is unreachable" (any case); and
#   - the text names a LAN address - an RFC1918 or link-local IPv4 - because
#     that is the shape Local Network privacy actually produces; a no-route
#     error with no LAN address may have ordinary routing causes and is left
#     unclassified rather than blamed on macOS.
# On non-macOS hosts the rule never fires: the same words there have ordinary
# routing causes and no such setting exists.
#
# The hook/plugin sibling case (a busy-state hook that fails silently on every
# use) is surfaced by bin/fm-bootstrap.sh's HOOK_LAST_ERROR line from the
# record bin/fm-busy-event.sh writes; this command owns only the failure-text
# classification.
set -u
unset CDPATH

usage() {
  cat >&2 <<'EOF'
usage: fm-env-cause.sh classify [--darwin <0|1|auto>] [file | -]
       (reads failure text from the file, or stdin when the file is - or absent)
EOF
  exit 2
}

CMD=${1:-}
case "$CMD" in
classify) shift ;;
*) usage ;;
esac

DARWIN=auto
if [ "${1:-}" = --darwin ]; then
  DARWIN=${2:-}
  case "$DARWIN" in 0 | 1 | auto) ;; *) usage ;; esac
  shift 2 || usage
fi
[ "$#" -le 1 ] || usage

case "$DARWIN" in
auto) [ "$(uname 2>/dev/null)" = Darwin ] && DARWIN=1 || DARWIN=0 ;;
esac
[ "$DARWIN" = 1 ] || exit 0

TEXT=
if [ "$#" -eq 1 ] && [ "$1" != - ]; then
  [ -f "$1" ] || exit 0
  TEXT=$(cat "$1" 2>/dev/null || true)
else
  TEXT=$(cat 2>/dev/null || true)
fi
[ -n "$TEXT" ] || exit 0

printf '%s\n' "$TEXT" | grep -Eqi 'no route to host|EHOSTUNREACH|host is unreachable' || exit 0
LAN=$(printf '%s\n' "$TEXT" | grep -Eo '\b(10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|192\.168\.[0-9]{1,3}\.[0-9]{1,3}|172\.(1[6-9]|2[0-9]|3[01])\.[0-9]{1,3}\.[0-9]{1,3}|169\.254\.[0-9]{1,3}\.[0-9]{1,3})\b(:[0-9]+)?' | head -n 1)
[ -n "$LAN" ] || exit 0

cat <<EOF
cause: (likely, not certain) $LAN is a local-network address and this failure pattern on macOS - a fresh program gets "No route to host" while other tools reach the same address - usually means Local Network privacy is blocking that program; allow it under System Settings > Privacy & Security > Local Network. The OS reports a blocked local-network connection exactly this way, so reachability from other tools does not rule it out.
EOF
exit 0