#!/usr/bin/env bash
# fm-slot-claim-lib.sh - which task records claim the same live working copy.
#
# WHY THIS EXISTS. One live path with two task records is the reuse collision
# itself, whichever record is stale: a stale, duplicated, or drifted worktree=
# record can name a slot a DIFFERENT live task now holds, and for a long time
# the only component that noticed was bin/fm-teardown.sh - the collision surfaced
# as a refusal after the work was already done, at cleanup time (observed
# 2026-10-08, learnings entry "two tasks ... recording the same pool copy").
# This file is the single owner of the RECORD SCAN, so bin/fm-spawn.sh can
# report the pair plainly at dispatch, session-start diagnostics can report it
# at session start, and bin/fm-teardown.sh keeps its
# refusal wording on top of the same scan instead of carrying a second copy of
# the matching rules.
#
# Detection only. Nothing here reads to edit, reconcile, or delete a record:
# reconciling a wrong record is an operator action (bin/fm-crew-state.sh), never
# an automatic side effect of a scan.
#
# CLAIM: a task record claims a live copy through its worktree= or home= field
# when that field resolves to an existing directory. Two records claim the same
# copy when their fields canonicalize (pwd -P) to the same existing directory.
# A field whose path is gone claims nothing; a record reached through a
# differently resolved state directory (e.g. a symlinked $FM_HOME) is matched by
# identity (same file name AND -ef), not by spelling.
#
# The walk over local homes is bin/fm-wake-lib.sh's
# fm_local_firstmate_state_dirs: this home first, then the local root and every
# locally registered secondmate home; remote homes are never walked because
# their records name paths on another machine. An unenumerable home is an error
# (return 2, FM_SLOT_CLAIM_ERROR), never "no tasks", so callers refuse or
# report rather than silently scanning a partial set.
#
# Requires bin/fm-wake-lib.sh, bin/fm-secondmate-registry-lib.sh (read by the
# local-homes walk), and bin/fm-backend.sh (fm_meta_get) to be sourced first.
# No side effects on source.
#
# Functions, each returning 0 with rows set, 1 with no rows, or 2 with
# FM_SLOT_CLAIM_ERROR set when the local homes could not be enumerated:
#
#   fm_slot_claim_rows <first-state> <self-meta-or-empty> <path>
#     Sets FM_SLOT_CLAIM_ROWS to one newline-terminated row per OTHER record
#     claiming <path>: "<task-id><TAB>field<TAB>state-dir>".
#     Rows and the error are RETURNED IN VARIABLES rather than printed, so a
#     caller reads them directly and an error string never dies in a command-
#     substitution subshell.
#     <path> must already exist and be canonicalizable; a path that cannot be
#     canonicalized claims nothing, so the answer is 1 (no rows).
#
#   fm_slot_shared_rows <first-state>
#     Sets FM_SLOT_CLAIM_SHARED_ROWS to one newline-terminated row per live
#     path claimed by two or more DISTINCT records across the local homes:
#     "<canonical-path><TAB><id>/<field>(<state-dir>)[<TAB>...]".
#     Two fields of the SAME record claiming one path count as one claimant.
#
# shellcheck shell=bash
# shellcheck disable=SC2034 # All three globals are read by the calling script.
FM_SLOT_CLAIM_ERROR=
FM_SLOT_CLAIM_ROWS=
FM_SLOT_CLAIM_SHARED_ROWS=

fm_slot_claim_canonical_dir() { # <path>
  local target=$1
  [ -n "$target" ] || return 1
  [ -d "$target" ] || return 1
  ( CDPATH='' cd -- "$target" 2>/dev/null && pwd -P )
}

# Same record identity rule as bin/fm-teardown.sh's historic scan: file name
# AND the underlying file must match, so a differently named hardlink is still
# another task's record.
fm_slot_claim_same_record() { # <meta-a> <meta-b>
  [ -n "$1" ] && [ -n "$2" ] || return 1
  [ "${1##*/}" = "${2##*/}" ] || return 1
  [ "$1" -ef "$2" ]
}

# Parallel-array collector: FM_SLOT_CLAIM_{PATHS,IDS,FIELDS,METAS,STATES}.
# Every record field that canonicalizes to a live directory becomes one row; a
# dead or unresolvable field is skipped (it claims nothing).
fm_slot_claim_collect() { # <first-state>
  local first=$1 state_dir meta id field path canon
  FM_SLOT_CLAIM_PATHS=()
  FM_SLOT_CLAIM_IDS=()
  FM_SLOT_CLAIM_FIELDS=()
  FM_SLOT_CLAIM_METAS=()
  FM_SLOT_CLAIM_STATES=()
  FM_SLOT_CLAIM_ERROR=
  fm_local_firstmate_state_dirs "$first" || {
    FM_SLOT_CLAIM_ERROR=$FM_LOCAL_FIRSTMATE_ERROR
    return 2
  }
  for state_dir in "${FM_LOCAL_FIRSTMATE_STATES[@]}"; do
    for meta in "$state_dir"/*.meta; do
      [ -f "$meta" ] && [ ! -L "$meta" ] || continue
      id=$(basename "$meta" .meta)
      for field in worktree home; do
        path=$(fm_meta_get "$meta" "$field")
        [ -n "$path" ] || continue
        canon=$(fm_slot_claim_canonical_dir "$path") || continue
        FM_SLOT_CLAIM_PATHS+=("$canon")
        FM_SLOT_CLAIM_IDS+=("$id")
        FM_SLOT_CLAIM_FIELDS+=("$field")
        FM_SLOT_CLAIM_METAS+=("$meta")
        FM_SLOT_CLAIM_STATES+=("$state_dir")
      done
    done
  done
  return 0
}

fm_slot_claim_rows() { # <first-state> <self-meta-or-empty> <path>
  local first=$1 self=$2 want=$3 i
  local want_canon
  FM_SLOT_CLAIM_ROWS=
  FM_SLOT_CLAIM_ERROR=
  want_canon=$(fm_slot_claim_canonical_dir "$want") || return 1
  fm_slot_claim_collect "$first" || return 2
  i=0
  while [ "$i" -lt "${#FM_SLOT_CLAIM_PATHS[@]}" ]; do
    if [ -n "$self" ] && fm_slot_claim_same_record "${FM_SLOT_CLAIM_METAS[$i]}" "$self"; then
      i=$((i + 1))
      continue
    fi
    if [ "${FM_SLOT_CLAIM_PATHS[$i]}" = "$want_canon" ]; then
      FM_SLOT_CLAIM_ROWS+="${FM_SLOT_CLAIM_IDS[$i]}"$'\t'"${FM_SLOT_CLAIM_FIELDS[$i]}"$'\t'"${FM_SLOT_CLAIM_STATES[$i]}"$'\n'
    fi
    i=$((i + 1))
  done
  [ -n "$FM_SLOT_CLAIM_ROWS" ] || return 1
  return 0
}

fm_slot_shared_rows() { # <first-state>
  local first=$1 i j distinct claimants
  FM_SLOT_CLAIM_SHARED_ROWS=
  FM_SLOT_CLAIM_ERROR=
  fm_slot_claim_collect "$first" || return 2
  i=0
  while [ "$i" -lt "${#FM_SLOT_CLAIM_PATHS[@]}" ]; do
    # Emit the group only from its first row so one path appears exactly once.
    j=0
    while [ "$j" -lt "$i" ]; do
      [ "${FM_SLOT_CLAIM_PATHS[$j]}" != "${FM_SLOT_CLAIM_PATHS[$i]}" ] || break
      j=$((j + 1))
    done
    if [ "$j" -eq "$i" ]; then
      distinct="${FM_SLOT_CLAIM_IDS[$i]}/${FM_SLOT_CLAIM_FIELDS[$i]}(${FM_SLOT_CLAIM_STATES[$i]})"
      claimants=1
      j=0
      while [ "$j" -lt "${#FM_SLOT_CLAIM_PATHS[@]}" ]; do
        if [ "$j" -ne "$i" ] && [ "${FM_SLOT_CLAIM_PATHS[$j]}" = "${FM_SLOT_CLAIM_PATHS[$i]}" ]; then
          if ! fm_slot_claim_same_record "${FM_SLOT_CLAIM_METAS[$j]}" "${FM_SLOT_CLAIM_METAS[$i]}"; then
            distinct+=$'\t'"${FM_SLOT_CLAIM_IDS[$j]}/${FM_SLOT_CLAIM_FIELDS[$j]}(${FM_SLOT_CLAIM_STATES[$j]})"
            claimants=$((claimants + 1))
          fi
        fi
        j=$((j + 1))
      done
      # Distinct records, not fields: one record claiming through both worktree=
      # and home= still has only one claimant.
      if [ "$claimants" -ge 2 ]; then
        FM_SLOT_CLAIM_SHARED_ROWS+="${FM_SLOT_CLAIM_PATHS[$i]}"$'\t'"$distinct"$'\n'
      fi
    fi
    i=$((i + 1))
  done
  [ -n "$FM_SLOT_CLAIM_SHARED_ROWS" ] || return 1
  return 0
}