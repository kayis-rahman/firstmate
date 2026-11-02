#!/usr/bin/env bash
# PiG worker-harness boundary regression.
set -u
# shellcheck source=tests/fixtures.sh
. "$(dirname "${BASH_SOURCE[0]}")/fixtures.sh"

unset CLAUDECODE PI_CODING_AGENT FM_PI_HARNESS GROK_AGENT CURSOR_AGENT CURSOR_INVOKED_AS AI_AGENT FM_HOME FM_CONFIG_OVERRIDE
fakebin=$(mktemp -d)
home=$(mktemp -d)
trap 'rm -rf "$fakebin" "$home"' EXIT
cat >"$fakebin/ps" <<'SH'
#!/usr/bin/env bash
case "$*" in
  *'ppid='*) printf '%s\n' 1 ;;
  *) printf '%s\n' bash ;;
esac
SH
chmod +x "$fakebin/ps"
actual=$(AI_AGENT=pig PATH="$fakebin:$PATH" "$ROOT/bin/fm-harness.sh")
[ "$actual" = pig ] || fail "AI_AGENT=pig resolved '$actual', expected pig"
mkdir -p "$home/config"
printf '%s\n' pig >"$home/config/crew-harness"
if FM_HOME="$home" "$ROOT/bin/fm-harness.sh" crew >/dev/null 2>"$home/pig-crew.err"; then
  fail "config/crew-harness=pig resolved a worker harness, expected primary-only refusal"
else
  grep -q "PiG is verified as a primary-only harness" "$home/pig-crew.err" || fail "config/crew-harness=pig did not report the primary-only boundary"
fi

# Pin the documented CLI switches in a portable fake, without requiring PiG in CI.
cat >"$fakebin/pig" <<'SH'
#!/usr/bin/env bash
printf '%s\n' '--model --thinking --tui-mode --approve --exclude-tools --extension'
SH
chmod +x "$fakebin/pig"
help=$(PATH="$fakebin:$PATH" pig --help)
for flag in --model --thinking --tui-mode --approve --exclude-tools --extension; do
  printf '%s\n' "$help" | grep -q -- "$flag" || fail "fake pig --help lacks $flag"
done

printf '%s\n' "ok - PiG marker and CLI launch surface"
