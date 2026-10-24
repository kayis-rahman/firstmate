#!/usr/bin/env bash
# Read-only Lavish server health report; exits nonzero when a problem is detected.
set -u
port=${LAVISH_AXI_PORT:-4387}
log=${LAVISH_AXI_LOG:-${LAVISH_AXI_STATE_DIR:-$HOME/.lavish-axi}/server.log}
lan=$(route -n get default 2>/dev/null | awk '/interface:/{i=$2} END{if(i) system("ipconfig getifaddr " i)}' | tail -1)
problems=()
curl --max-time 2 -fsS "http://127.0.0.1:$port/" >/dev/null 2>&1 || problems+=("Lavish does not answer on loopback port $port")
if [ -n "$lan" ]; then
  pid=$(lsof -t -nP -iTCP@"$lan":"$port" -sTCP:LISTEN 2>/dev/null | head -1 || true)
  [ -n "$pid" ] || problems+=("no listener bound to current LAN address $lan:$port")
  if [ -n "$pid" ]; then
    args=$(ps -p "$pid" -o args= 2>/dev/null || true)
    case "$args" in *lavish-axi*) ;; *) problems+=("another process holds LAN port $lan:$port (pid $pid)");; esac
  fi
fi
if [ -r "$log" ]; then
  count=$(awk -v since="$(date -u -v-1H '+%Y-%m-%dT%H:%M:%S' 2>/dev/null || date -u -d '1 hour ago' '+%Y-%m-%dT%H:%M:%S')" '/shutting down: shutdown-request/ && $1 >= since {n++} END{print n+0}' "$log")
  [ "$count" -lt 3 ] || problems+=("$count Lavish shutdown requests logged in the last hour")
else problems+=("Lavish server log is unavailable: $log"); fi
if [ "${#problems[@]}" -eq 0 ]; then echo 'Lavish server health: OK'; exit 0; fi
printf 'Lavish server problem: %s\n' "${problems[@]}"
printf 'Remedy: restart bound to current LAN address %s with LAVISH_AXI_HOST=%s LAVISH_AXI_LINK_HOST=%s LAVISH_AXI_ALLOWED_HOSTS=%s.\n' "${lan:-<LAN-IP>}" "${lan:-<LAN-IP>}" "${lan:-<LAN-IP>}" "${lan:-<LAN-IP>}"
exit 1
