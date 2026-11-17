#!/usr/bin/env bash
set -u
suite=$1; helper=$2; shift 2
selected=("$@")
. "$helper"
fm_test_run() {
  local test
  printf '1..%s\n' "${#selected[@]}"
  for test in "${selected[@]}"; do printf '# running %s\n' "$test"; "$test"; done
  printf 'FM_TEST_COMPLETE\n'
}
. "$suite"
