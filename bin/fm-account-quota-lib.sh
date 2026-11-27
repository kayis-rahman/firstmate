#!/usr/bin/env bash
# fm-account-quota-lib.sh - the single owner of measuring each account a home
# declares in a runner's account list (config/claude-accounts,
# config/codex-accounts, or config/agy-accounts), in isolation, and printing
# each one's quota facts.
# Sourced by bin/fm-claude-account-quota.sh, bin/fm-codex-account-quota.sh,
# and bin/fm-agy-account-quota.sh, which own only their argument parsing.
#
# fm_account_quota_report <harness> <config-dir> <model>
# For every declared entry, in file order, runs
#   <VAR>=<root> quota-axi --provider <harness> [--profile-only] --json
# where <VAR> is CLAUDE_CONFIG_DIR, CODEX_HOME, or HOME and <root> is the
# entry's own directory, or ~/.claude, ~/.codex, or $HOME for `ordinary`.
#
# FM_ACCOUNT_QUOTA_SECONDS bounds each read (default 60); per-harness
# FM_CLAUDE_ACCOUNT_QUOTA_SECONDS and FM_AGY_ACCOUNT_QUOTA_SECONDS are honored
# when FM_ACCOUNT_QUOTA_SECONDS is unset.

# shellcheck source=bin/fm-worker-account-lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/fm-worker-account-lib.sh"
# shellcheck source=bin/fm-quota-axi-lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/fm-quota-axi-lib.sh"

fm_account_quota_report() {
  local harness=$1 config=$2 model=$3 file var listed work entry root error rc=0 seconds=60
  local -a quota_args
  [ "$harness" != claude ] || seconds=${FM_CLAUDE_ACCOUNT_QUOTA_SECONDS:-60}
  [ "$harness" != agy ] || seconds=${FM_AGY_ACCOUNT_QUOTA_SECONDS:-60}
  seconds=${FM_ACCOUNT_QUOTA_SECONDS:-$seconds}
  file=$(fm_worker_account_list_file "$harness") || {
    printf 'error: %s has no declared account list\n' "$harness" >&2
    return 2
  }
  var=$(fm_worker_account_root_var "$harness")
  command -v jq >/dev/null 2>&1 || { printf 'error: jq is required\n' >&2; return 2; }
  listed=$(fm_worker_account_list "$harness" "$config") || return 2
  [ -n "$listed" ] || {
    printf 'error: this home declares no config/%s; there is nothing to measure\n' "$file" >&2
    return 2
  }

  if ! command -v quota-axi >/dev/null 2>&1; then
    printf '%s-account-quota:\n  error: quota-axi not installed\n' "$harness"
    return 0
  fi

  work=$(mktemp -d "${TMPDIR:-/tmp}/fm-$harness-account-quota.XXXXXX") || {
    printf 'error: cannot create a scratch directory\n' >&2
    return 2
  }

  quota_args=(--provider "$harness" --profile-only --json)
  [ "$harness" != agy ] || quota_args=(--provider "$harness" --json)

  # Every entry becomes {account, root, snapshot} or {account, root, error}.
  : > "$work/accounts.jsonl"
  while IFS= read -r entry; do
    root=$entry
    if [ "$entry" = ordinary ]; then
      if [ "$harness" = agy ]; then
        root="${HOME:?HOME is required to measure the ordinary account}"
      else
        root="${HOME:?HOME is required to measure the ordinary account}/.$harness"
      fi
    fi
    error=
    if fm_run_timed "$seconds" env -u QUOTA_AXI_SNAPSHOT "$var=$root" \
        quota-axi "${quota_args[@]}" > "$work/snapshot.json" 2>/dev/null </dev/null; then
      fm_quota_json_valid < "$work/snapshot.json" || error="quota-axi returned an invalid snapshot"
    elif ! fm_quota_json_valid < "$work/snapshot.json"; then
      error="quota-axi could not read this account"
    fi
    if [ -n "$error" ]; then
      jq -cn --arg account "$entry" --arg root "$root" --arg error "$error" '{account: $account, root: $root, error: $error}'
    else
      jq -c --arg account "$entry" --arg root "$root" '{account: $account, root: $root, snapshot: .}' "$work/snapshot.json"
    fi >> "$work/accounts.jsonl" || {
      printf 'error: cannot record the quota reading for %s\n' "$entry" >&2
      rm -rf "$work"
      return 2
    }
  done <<< "$listed"

  jq -rs --arg model "$model" --arg provider "$harness" '
    def flat: tostring | gsub("[\t\r\n]"; " ");
    def show($value): ($value // "-") | flat;
    def bare($m): ($m | split("/") | last);
    def applicable($row):
      bare($model) as $b |
      [$row.quotaSemantics.effectiveAvailability[]? | select(
        .scope == "all_models" or .scope == "all_products" or
        ($model != "" and (.scope == ("model:" + $b) or .scope == ("product:" + $b)))
      )];
    "\($provider)-account-quota:",
    (.[] | "  row: \(.account | flat)  root=\(.root | flat)" as $head |
      if .error then "\($head)  uncertainty: \(.error | flat)"
      else
        ([.snapshot.providers[]? | select(.provider == $provider)] | first) as $row |
        if $row == null then "\($head)  uncertainty: no \($provider) quota row"
        else
          applicable($row) as $rows |
          (if (["known", "partial"] | index($row.quotaSemantics.status)) == null then
            "\($head)  uncertainty: quota \(show($row.quotaSemantics.status))\(if $row.state.status then " (\($row.state.status | flat): \(show($row.state.error)))" else "" end)"
           else empty end),
          (if ($rows | length) == 0 then "\($head)  uncertainty: no applicable quota scope" else empty end),
          ($rows[] | "\($head)  scope=\(.scope | flat)  status=\(show(.status))  remaining=\(show(.effectivePercentRemaining))%  spendPriority=\(show(.selection.spendPriority))  runway=\(show(.runway.status))"
            + (if .runway.usableRunwaySeconds != null or .runway.status == "projected_exhaustion"
               then "  usableRunwaySeconds=\(show(.runway.usableRunwaySeconds))" else "" end)
            + ((.runway.projectionConfidence // .confidence) as $c | if $c then "  confidence=\($c | flat)" else "" end))
        end
      end)
  ' "$work/accounts.jsonl" || {
    printf 'error: cannot format the quota readings\n' >&2
    rc=2
  }
  rm -rf "$work"
  return "$rc"
}
