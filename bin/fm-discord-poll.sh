#!/usr/bin/env bash
# fm-discord-poll.sh - post an opinionated Discord poll for a captain decision.
#
# Usage:
#   fm-discord-poll.sh "Question text" "Recommended option" "Alternative 1" ["Alternative 2" ...]
#
# The recommended option is always listed first and marked "(Recommended)".
# At least one alternative is required: a poll with no choice is not a poll.
# The question and every option are passed through verbatim; keep them short.
#
# This wraps ~/.firstmate-discord/poll.py, which owns the Discord API call,
# reaction numbering, and poll-state persistence. This script only enforces the
# opinionated shape: one recommended option first, then the alternatives.
set -euo pipefail

if [ "$#" -lt 3 ]; then
  echo "usage: $0 \"<question>\" \"<recommended option>\" \"<alternative>\" [\"<alternative>\" ...]" >&2
  exit 2
fi

question=$1
recommended=$2
shift 2

# Mark the recommended option if the caller did not already.
case "$recommended" in
  *"(Recommended)"*|*"(recommended)"*) ;;
  *) recommended="$recommended (Recommended)" ;;
esac

# Build the option list: recommended first, then alternatives.
options=("$recommended")
for alt in "$@"; do
  options+=("$alt")
done

POLL=${FM_DISCORD_POLL:-$HOME/.firstmate-discord/poll.py}
exec python3 "$POLL" "$question" "${options[@]}"
