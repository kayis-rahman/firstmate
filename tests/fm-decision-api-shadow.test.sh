#!/usr/bin/env bash
# tests/fm-decision-api-shadow.test.sh - portable shadow helper check.
set -u
# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

TMP_ROOT=$(fm_test_tmproot fm-decision-api-shadow-tests)
H=$(mktemp -d)
mkdir -p "$H/config" "$H/state"
export FM_HOME="$H"

# fake curl
FAKEBIN="$TMP_ROOT/fakebin"
mkdir -p "$FAKEBIN"
cat > "$FAKEBIN/curl" <<'CURL'
#!/usr/bin/env bash
out=''
while [ $# -gt 0 ]; do
  case "$1" in
    -o) out="$2"; shift 2 ;;
    *) shift ;;
  esac
done
printf '{"answers":{"classification":{"type":"choice","choice":"captain-relevant","confidence":0.9,"probabilities":{"captain-relevant":0.9,"not-captain-relevant":0.1}}}}' > "$out"
printf '200'
CURL
chmod +x "$FAKEBIN/curl"
export PATH="$FAKEBIN:$PATH"

# config .env points to local
cat > "$H/.env" <<'ENV'
TYPESAFE_BASE=http://127.0.0.1:11234
TYPESAFE_MODEL=aselea/Kev-4B-MLX-Serve-8bit
TYPESAFE_API_KEY=local-mlx-serve
ENV

out=$("$ROOT/bin/fm-decision-api.sh" --context "done: shipped")
echo "$out" | jq -e '.choice=="captain-relevant"' >/dev/null || fail "helper did not parse answer"
pass "helper parses a stubbed /v1/systemone answer"

# fail-open: simulating curl failure
cat > "$FAKEBIN/curl" <<'CURL'
#!/usr/bin/env bash
exit 28
CURL
out=$("$ROOT/bin/fm-decision-api.sh" --context "done: shipped" 2>/dev/null) || true
[ -z "$out" ] || fail "helper did not fail silently"
pass "helper is silent when the endpoint is down"

cat > "$FAKEBIN/curl" <<'CURL'
#!/usr/bin/env bash
out=''
while [ $# -gt 0 ]; do
  case "$1" in
    -o) out="$2"; shift 2 ;;
    *) shift ;;
  esac
done
printf '{"answers":{"classification":{"type":"choice","choice":"captain-relevant","confidence":0.9,"probabilities":{"captain-relevant":0.9,"not-captain-relevant":0.1}}}}' > "$out"
printf '200'
CURL
chmod +x "$FAKEBIN/curl"
# shadow integration: flag on
touch "$H/config/decision-api-shadow"
. "$ROOT/bin/fm-classify-lib.sh"
status_is_captain_relevant "working: routine progress" >/dev/null 2>&1 || true
[ -f "$H/state/decision-shadow.log" ] || fail "shadow log was not created"
pass "classification path writes the shadow log when enabled"
