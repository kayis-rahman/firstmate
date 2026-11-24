#!/usr/bin/env bash
# fm-account-quota-lib.sh - shared quota measurement and TOON-style formatting
# for multi-account lists (config/claude-accounts and config/agy-accounts).
# Sourced by bin/fm-claude-account-quota.sh and bin/fm-agy-account-quota.sh.

# fm_account_quota_run <harness> <provider> <header> <list_file> <env_var> <timeout_seconds> <model> <extra_args_count> [quota_axi_args...]
fm_account_quota_run() {
  local harness=$1 provider=$2 header=$3 list_file=$4 env_var=$5 timeout_seconds=$6 model=$7
  shift 7
  local -a quota_args=("$@")
  local listed work entry root error

  command -v jq >/dev/null 2>&1 || die "jq is required"
  listed=$(fm_worker_account_list "$harness" "$CONFIG") || exit 2
  [ -n "$listed" ] || die "this home declares no $list_file; there is nothing to measure"

  if ! command -v quota-axi >/dev/null 2>&1; then
    printf '%s\n  error: quota-axi not installed\n' "$header"
    return 0
  fi

  work=$(mktemp -d "${TMPDIR:-/tmp}/fm-${harness}-account-quota.XXXXXX") || die "cannot create a scratch directory"
  trap 'rm -rf "$work"' RETURN

  : > "$work/accounts.jsonl"
  while IFS= read -r entry; do
    root=$entry
    if [ "$entry" = ordinary ]; then
      if [ "$harness" = claude ]; then
        root="${HOME:?HOME is required to measure the ordinary account}/.claude"
      else
        root="${HOME:?HOME is required to measure the ordinary account}"
      fi
    fi
    error=
    if fm_run_timed "$timeout_seconds" env -u QUOTA_AXI_SNAPSHOT "$env_var=$root" \
        quota-axi "${quota_args[@]}" > "$work/snapshot.json" 2>/dev/null </dev/null; then
      fm_quota_json_valid < "$work/snapshot.json" || error="quota-axi returned an invalid snapshot"
    elif ! fm_quota_json_valid < "$work/snapshot.json"; then
      error="quota-axi could not read this account"
    fi
    if [ -n "$error" ]; then
      jq -cn --arg account "$entry" --arg root "$root" --arg error "$error" '{account: $account, root: $root, error: $error}'
    else
      jq -c --arg account "$entry" --arg root "$root" '{account: $account, root: $root, snapshot: .}' "$work/snapshot.json"
    fi >> "$work/accounts.jsonl" || die "cannot record the quota reading for $entry"
  done <<< "$listed"

  jq -rs --arg model "$model" --arg header "$header" --arg provider "$provider" '
    def flat: tostring | gsub("[\t\r\n]"; " ");
    def show($value): ($value // "-") | flat;
    def bare($m): ($m | split("/") | last);
    def applicable($row):
      bare($model) as $b |
      [$row.quotaSemantics.effectiveAvailability[]? | select(
        .scope == "all_models" or .scope == "all_products" or
        ($model != "" and (.scope == ("model:" + $b) or .scope == ("product:" + $b)))
      )];
    $header,
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
  ' "$work/accounts.jsonl" || die "cannot format the quota readings"
}
