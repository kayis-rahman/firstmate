#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd -P)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/home"
cat >"$tmp/bin/lavish-axi" <<'EOF'
#!/usr/bin/env bash
printf 'status: feedback\nfeedback: FULL_RESPONSE_SENTINEL\n'
EOF
chmod +x "$tmp/bin/lavish-axi"
printf '<html></html>\n' >"$tmp/board.html"
out=$(PATH="$tmp/bin:$PATH" FM_HOME="$tmp/home" "$ROOT/bin/fm-lavish-capture.sh" "$tmp/board.html")
file=$(printf '%s\n' "$out" | awk '/Captured full Lavish response:/{print $NF}')
grep -q FULL_RESPONSE_SENTINEL "$file"
[ "$(stat -f %Lp "$file" 2>/dev/null || stat -c %a "$file")" = 600 ]
echo 'ok - poll output is durably captured before its path is reported'
# Health classification follows the actual owning process, not lsof's command label.
cat >"$tmp/bin/route" <<'EOF'
#!/usr/bin/env bash
echo 'interface: en0'
EOF
cat >"$tmp/bin/ipconfig" <<'EOF'
#!/usr/bin/env bash
echo 192.0.2.10
EOF
cat >"$tmp/bin/curl" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat >"$tmp/bin/lsof" <<'EOF'
#!/usr/bin/env bash
echo 7910
EOF
cat >"$tmp/bin/ps" <<'EOF'
#!/usr/bin/env bash
echo "${FAKE_PS_ARGS:-node /opt/lavish-axi/server.js}"
EOF
chmod +x "$tmp/bin/"*
: >"$tmp/server.log"
out=$(PATH="$tmp/bin:$PATH" FAKE_PS_ARGS='node /opt/lavish-axi/server.js' LAVISH_AXI_PORT=4387 LAVISH_AXI_LOG="$tmp/server.log" "$ROOT/bin/fm-lavish-health.sh")
grep -q 'Lavish server health: OK' <<<"$out"
if PATH="$tmp/bin:$PATH" FAKE_PS_ARGS='python unrelated.py' LAVISH_AXI_PORT=4387 LAVISH_AXI_LOG="$tmp/server.log" "$ROOT/bin/fm-lavish-health.sh" >"$tmp/health"; then
  echo 'expected foreign listener to be unhealthy' >&2; exit 1
fi
grep -q 'another process holds LAN port' "$tmp/health"
echo 'ok - health check distinguishes Lavish-owned and foreign LAN listeners'
# The health command must return actionable plain language when its endpoint is unavailable.
if LAVISH_AXI_PORT=1 LAVISH_AXI_LOG="$tmp/missing.log" "$ROOT/bin/fm-lavish-health.sh" >"$tmp/health"; then
  echo 'expected unhealthy result' >&2; exit 1
fi
grep -q LAVISH_AXI_HOST "$tmp/health"
echo 'ok - unhealthy server report names the restart environment'
