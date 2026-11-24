#!/usr/bin/env bash
# Behavior tests for bin/fm-agy-account-quota.sh: each account declared in
# config/agy-accounts is measured under its own HOME and its quota facts and
# uncertainty are printed, never a choice.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

TMP_ROOT=$(fm_test_tmproot fm-agy-account-quota)
TOOL="$ROOT/bin/fm-agy-account-quota.sh"

new_case() {
  CASE="$TMP_ROOT/$1"
  HOME_DIR="$CASE/home"
  FAKEBIN="$CASE/fakebin"
  mkdir -p "$HOME_DIR/config" "$FAKEBIN" "$CASE/user-home"
  cat > "$FAKEBIN/quota-axi" <<SH
#!/usr/bin/env bash
printf '%s %s %s\n' "\${HOME-unset}" "\${QUOTA_AXI_SNAPSHOT-unset}" "\$*" >> '$CASE/reads'
[ -f "\$HOME/quota.json" ] || exit 1
cat "\$HOME/quota.json"
[ ! -f "\$HOME/exit-1" ] || exit 1
SH
  chmod +x "$FAKEBIN/quota-axi"
}

account() {
  local dir=$1 pct=$2 sp=$3 runway=${4:-through_reset}
  mkdir -p "$dir"
  jq -n --argjson pct "$pct" --argjson sp "$sp" --arg runway "$runway" '{
    schemaVersion: 5,
    providers: [{
      provider: "agy",
      quotaSemantics: {
        status: "known",
        effectiveAvailability: [
          {scope: "all_models", status: "known", effectivePercentRemaining: $pct,
           runway: {status: $runway},
           selection: {spendPriority: $sp}}
        ]
      }
    }]
  }' > "$dir/quota.json"
}

run_tool() {
  env -i HOME="$CASE/user-home" PATH="$FAKEBIN:$PATH" FM_HOME="$HOME_DIR" \
    QUOTA_AXI_SNAPSHOT="$CASE/shared-fixture.json" "$TOOL" "$@" 2>&1
}

test_two_accounts_print_their_own_rows() {
  local out rc
  new_case two
  account "$CASE/a" 32 0.2
  account "$CASE/b" 100 0.8
  printf '%s\n%s\n' "$CASE/a" "$CASE/b" > "$HOME_DIR/config/agy-accounts"
  out=$(run_tool); rc=$?
  expect_code 0 "$rc" "measuring two declared agy accounts should succeed: $out"
  assert_contains "$out" "agy-account-quota:" "header should identify agy-account-quota"
  assert_contains "$out" "row: $CASE/a  root=$CASE/a  scope=all_models  status=known  remaining=32%  spendPriority=0.2  runway=through_reset" "account a's own row should be shown"
  assert_contains "$out" "row: $CASE/b  root=$CASE/b  scope=all_models  status=known  remaining=100%  spendPriority=0.8  runway=through_reset" "account b's own row should be shown"
  assert_not_contains "$out" "--account" "the tool must not print a chosen account"
  assert_grep "$CASE/a unset --provider agy --json" "$CASE/reads" "account a should be read in isolation under its own HOME"
  assert_grep "$CASE/b unset --provider agy --json" "$CASE/reads" "account b should be read in isolation under its own HOME"
  pass "each declared agy account prints its own quota row, read under its own HOME"
}

test_ordinary_is_measured_from_caller_home() {
  local out
  new_case ordinary
  account "$CASE/user-home" 65 0.4
  printf 'ordinary\n' > "$HOME_DIR/config/agy-accounts"
  out=$(run_tool)
  assert_contains "$out" "row: ordinary  root=$CASE/user-home  scope=all_models  status=known  remaining=65%  spendPriority=0.4" "ordinary should be measured from caller HOME"
  assert_grep "$CASE/user-home unset --provider agy --json" "$CASE/reads" "ordinary should be read from caller HOME"
  pass "ordinary is measured from the caller HOME"
}

test_absent_or_malformed_lists_refuse() {
  local out rc
  new_case refuse
  out=$(run_tool); rc=$?
  expect_code 2 "$rc" "an absent list must refuse"
  assert_contains "$out" "declares no config/agy-accounts" "the refusal should name the missing list"
  printf 'relative\n' > "$HOME_DIR/config/agy-accounts"
  out=$(run_tool); rc=$?
  expect_code 2 "$rc" "a malformed list must refuse"
  assert_contains "$out" "config/agy-accounts must hold one account per line" "the refusal should name the format"
  assert_absent "$CASE/reads" "a refused list must not read any quota"
  pass "an absent or malformed agy list refuses before any quota read"
}

test_two_accounts_print_their_own_rows
test_ordinary_is_measured_from_caller_home
test_absent_or_malformed_lists_refuse

echo "# all fm-agy-account-quota tests passed"
