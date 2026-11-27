# shellcheck shell=bash
# Shared TypeSafe URL/path validation, credential-source reading, and
# dispatch-never-send checking for bin/fm-dispatch-resolve.sh and
# bin/fm-decision-api.sh.
# Usage: . bin/fm-typesafe-lib.sh

# shellcheck disable=SC2034 # Exported-by-sourcing to callers.
FM_TYPESAFE_CRED_ERR=''
# shellcheck disable=SC2034 # Exported-by-sourcing to callers.
FM_TYPESAFE_NEVER_SEND_REASON=''

# fm_typesafe_validate_base <base-url>
# Validate an http(s) base URL with a host and no userinfo, query, fragment,
# whitespace, or brackets in its path. Prints the normalized URL (trailing /
# stripped) on stdout and returns 0, or returns 1 on invalid input.
# Never echoes a rejected value (a misconfigured URL may contain credentials).
fm_typesafe_validate_base() {
  local base=${1:-}
  [ -n "$base" ] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  jq -en --arg base "$base" '
    def ipv4:
      split(".") | length == 4 and all(.[];
        test("\\A(0|[1-9][0-9]{0,2})\\z") and (tonumber <= 255));
    def ipv6:
      (if contains(".") then
        split(":") | if (.[-1] | ipv4) then .[-1] = "0:0" | join(":") else "!" end
       else . end) |
      split("::") as $sides |
      if ($sides | length) == 1 then
        test("\\A[0-9A-Fa-f]{1,4}(:[0-9A-Fa-f]{1,4}){7}\\z")
      elif ($sides | length) == 2 then
        all($sides[]; test("\\A([0-9A-Fa-f]{1,4}(:[0-9A-Fa-f]{1,4})*)?\\z")) and
        (split(":") | map(select(length > 0)) | length < 8)
      else false end;
    $base | capture("\\Ahttps?://(?<host>\\[[0-9A-Fa-f:.]+\\]|[A-Za-z0-9._-]+)(:(?<port>[0-9]+))?(?<path>/[^?#[:space:]\\\\]*)?\\z"; "i") |
    ((.path // "") | (contains("[") or contains("]")) | not) and
    (if .host | startswith("[") then .host[1:-1] | ipv6
     else true end) and
    (.port == null or (.port | tonumber | . >= 1 and . <= 65535))
  ' >/dev/null 2>&1 || return 1
  while [ "${base%/}" != "$base" ]; do base=${base%/}; done
  printf '%s\n' "$base"
}

# fm_typesafe_validate_path <path>
# Validate an optional request path that replaces /v1/systemone.
# Prints the validated path on stdout and returns 0, or returns 1.
# Never echoes a rejected value.
fm_typesafe_validate_path() {
  local path=${1:-}
  [ -n "$path" ] || return 1
  case "$path" in
    /*) ;;
    *) return 1 ;;
  esac
  case "$path" in
    *[[:space:][:cntrl:]\\?#]*|*/./*|*/../*|*/.|*/..) return 1 ;;
  esac
  printf '%s\n' "$path"
}

# fm_typesafe_read_declared_key <cred-path> <provider> <out-var> [<allowed-providers>...]
# Read <provider>'s key from <cred-path> via bin/fm-credential-source-lib.sh.
# Return codes:
#   0: key loaded into <out-var>
#   1: no declaration file or no entry for <provider>
#   2: configuration error (unreadable or malformed declaration; FM_TYPESAFE_CRED_ERR set)
#   3: runtime error (unsupported source, timeout, or unavailable key; FM_TYPESAFE_CRED_ERR set)
fm_typesafe_read_declared_key() {
  local cred_path=$1 provider=$2 out_var=$3
  shift 3
  local src problem value rc
  # shellcheck disable=SC2034 # Exported-by-sourcing to callers.
  FM_TYPESAFE_CRED_ERR=''
  [ -e "$cred_path" ] || [ -L "$cred_path" ] || return 1
  if [ ! -r "$cred_path" ]; then
    FM_TYPESAFE_CRED_ERR="credential source declaration not readable: $cred_path"
    return 2
  fi
  if ! command -v jq >/dev/null 2>&1; then
    FM_TYPESAFE_CRED_ERR="jq required"
    return 2
  fi
  if [ $# -eq 0 ]; then
    set -- typesafe openrouter
  fi
  problem=$(fm_credsrc_check "$cred_path" "$@") || {
    FM_TYPESAFE_CRED_ERR="malformed credential source declaration: $cred_path - $problem"
    return 2
  }
  fm_credsrc_declares "$cred_path" "$provider" || return 1
  src=$(fm_credsrc_field "$cred_path" "$provider" source)
  if ! fm_credsrc_supported "$src"; then
    FM_TYPESAFE_CRED_ERR="credential source $src declared for $provider is not supported on this host; nothing sent"
    return 3
  fi
  value=$(fm_credsrc_read "$cred_path" "$provider"); rc=$?
  if [ "$rc" -ne 0 ] || [ -z "$value" ]; then
    if fm_timed_out "$rc"; then
      FM_TYPESAFE_CRED_ERR="credential source $src declared for $provider did not answer in time; nothing sent"
    else
      FM_TYPESAFE_CRED_ERR="credential source $src declared for $provider is unavailable; nothing sent"
    fi
    return 3
  fi
  printf -v "$out_var" '%s' "$value"
  return 0
}

# fm_typesafe_never_send_check <never-send-path> <endpoint> <body-json>
# Checks <endpoint> and every string value in <body-json> against <never-send-path>.
# Returns 0 if safe to send (or list absent), 1 if matched or unreadable
# (setting FM_TYPESAFE_NEVER_SEND_REASON, never naming the matched value).
fm_typesafe_never_send_check() {
  local never_send_path=$1 endpoint=$2 body=$3
  local send_text list value n=0 rc
  # shellcheck disable=SC2034 # Exported-by-sourcing to callers.
  FM_TYPESAFE_NEVER_SEND_REASON=''
  [ -e "$never_send_path" ] || [ -L "$never_send_path" ] || return 0
  if [ ! -f "$never_send_path" ] || [ ! -r "$never_send_path" ]; then
    FM_TYPESAFE_NEVER_SEND_REASON="$never_send_path is not a readable regular file"
    return 1
  fi
  send_text=$(jq -r --arg endpoint "$endpoint" '
    $endpoint, (.. | strings | ., (try (fromjson | .. | strings) catch empty))
    | gsub("\\s+"; " ")' <<<"$body" 2>/dev/null) || {
    FM_TYPESAFE_NEVER_SEND_REASON="could not extract the request text to check"
    return 1
  }
  list=$(jq -Rr 'gsub("\\s+"; " ")' "$never_send_path" 2>/dev/null) || {
    FM_TYPESAFE_NEVER_SEND_REASON="could not read $never_send_path"
    return 1
  }
  while IFS= read -r value; do
    n=$((n + 1))
    value=${value# }
    value=${value% }
    case "$value" in
      ''|'#'*) continue ;;
    esac
    printf '%s\n' "$send_text" | grep -qiF -e "$value" 2>/dev/null; rc=$?
    case "$rc" in
      0)
        FM_TYPESAFE_NEVER_SEND_REASON="text matches $never_send_path line $n"
        return 1
        ;;
      1) ;;
      *)
        FM_TYPESAFE_NEVER_SEND_REASON="could not check the request text against $never_send_path line $n"
        return 1
        ;;
    esac
  done <<<"$list"
  return 0
}
