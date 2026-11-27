#!/usr/bin/env bash
# fm-worker-account-lib.sh - the single owner of the opt-in per-home worker
# and per-secondmate account pins: which runners can be pinned, how a pin file
# is parsed and resolved, the launch-time sign-in check under it, and the
# environment credentials a pinned Claude launch sheds.
#
# docs/configuration.md "Worker account pin" owns the operator-facing contract.
# Sourced by bin/fm-spawn.sh and bin/fm-control.sh.
#
# Pinnable runners, each a credential store inside a root its vendor lets a
# process select:
#   claude          CLAUDE_CONFIG_DIR     config/claude-account
#   pi, pi-signed   PI_CODING_AGENT_DIR   config/pi-account
#
# The pin is opt-in: an absent file is no pin, and the launch keeps today's
# ambient behavior byte for byte. A present file must resolve, or the launch
# refuses; nothing falls back to an ambient or vendor-default login once a
# home has declared one. `ordinary` selects the vendor default: for Claude
# that is CLAUDE_CONFIG_DIR unset, because Claude reads $CLAUDE_CONFIG_DIR/
# .claude.json and keys its macOS Keychain entry to any CLAUDE_CONFIG_DIR that
# is set, even $HOME/.claude; for Pi it is $HOME/.pi/agent. Any other value is
# one absolute path to an existing readable, searchable directory. Firstmate
# never copies credentials or changes a global login.
#
# A Pi root can hold several provider identities, so config/pi-account names
# the root on line 1 and the providers that home may spend on line 2,
# separated by spaces. A pinned Pi launch must name its provider explicitly as
# --model <provider>/<id>, and that provider must be declared; Firstmate never
# guesses a provider for an unqualified model. The canonical launch also
# passes --provider <that provider>, because without it Pi may resolve a
# provider-prefixed model under another authenticated provider. A raw Pi
# launch command is launched verbatim and cannot receive that flag, so a home
# with config/pi-account refuses raw Pi launches. A raw Claude launch command
# runs after the pinned root and shed credentials are applied, so its own
# leading CLAUDE_CONFIG_DIR or shed-credential assignment would override the
# pin; a home with config/claude-account refuses such a command.
#
# The sign-in check asks the runner itself, with only HOME, PATH, TMPDIR,
# USER, LOGNAME, and the selected root in its environment, so a credential
# variable left in the caller cannot answer for a root that has no login:
#   Claude: `claude auth status`, which exits 0 only when signed in.
#   Pi:     `pi auth check --provider <p> --json --no-refresh`; status "ready"
#           passes. `pi auth check` loads no extensions, so it answers
#           not_ready/provider_not_found for an extension-registered provider,
#           and a Pi without the command (before 0.84.1) prints no JSON. Both
#           fall through to `pi --list-models <p>`, which lists only the models
#           a root can authenticate; a row whose provider column is exactly
#           <p> passes. --no-refresh keeps the check from rewriting a root's
#           tokens while other workers use them.
# A pinned Claude launch also unsets the environment credentials Claude ranks
# above the root's stored login, so an ambient API key or token cannot outrank
# the pin. Pi ranks a root's stored credentials above environment variables,
# and the check refuses a provider the root has not stored, so a pinned Pi
# launch unsets nothing.
#
# A home that spends several Claude or agy subscriptions declares them instead
# in config/claude-accounts or config/agy-accounts: one entry per line, each
# `ordinary` or an absolute path (CLAUDE_CONFIG_DIR for Claude, HOME for agy),
# with no blank lines, duplicates, or control characters, and an optional final
# newline. The list is opt-in in the same way: absent, nothing here changes.
# Present, for Claude it replaces the home-wide pin (which must then be absent),
# and every Claude or agy ship or scout launch names one declared entry with
# --account; Firstmate never defaults to the first entry, another entry, or the
# ambient account. The named entry passes the same root, raw-command, and
# sign-in refusals and is recorded as account=, which a ship or scout relaunch
# reuses unless an explicit --account moves it. A local secondmate's agent
# never draws from the list.

# shellcheck source=bin/fm-timeout-lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/fm-timeout-lib.sh"

FM_WORKER_ACCOUNT_CHECK_SECONDS=${FM_WORKER_ACCOUNT_CHECK_SECONDS:-30}

# Credentials Claude Code ranks above the /login stored in its config root
# (code.claude.com/docs/en/authentication, "Authentication precedence"; the
# Claude Platform on AWS and Bedrock Mantle switches from
# code.claude.com/docs/en/env-vars).
FM_WORKER_ACCOUNT_CLAUDE_SHED="CLAUDE_CODE_USE_BEDROCK CLAUDE_CODE_USE_VERTEX CLAUDE_CODE_USE_FOUNDRY CLAUDE_CODE_USE_ANTHROPIC_AWS CLAUDE_CODE_USE_MANTLE ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY CLAUDE_CODE_OAUTH_TOKEN ANTHROPIC_PROFILE ANTHROPIC_FEDERATION_RULE_ID"

# fm_worker_account_file <harness>
# Prints the pin file name for a pinnable runner; returns 1 for any other.
fm_worker_account_file() {
  case "$1" in
  claude) printf '%s\n' claude-account ;;
  pi | pi-signed) printf '%s\n' pi-account ;;
  *) return 1 ;;
  esac
}

# fm_worker_account_read <harness> <file>
# Prints "declared<TAB>providers" for a valid pin, where declared is
# `ordinary` or the absolute path and providers is empty for Claude. The final
# newline is optional; any other control byte, including a CR, is malformed.
# Parses bytes before the shell can drop NULs or trailing newlines; paths are
# literal, never shell expressions. Returns 0 on success, 3 when the file does
# not exist, 4 when it cannot be inspected (one error already printed), 5 when
# it is not a readable regular file, and 6 when it is malformed.
fm_worker_account_read() {
  perl -MErrno=ENOENT -e '
    my ($harness, $f) = @ARGV;
    unless (lstat $f) {
      exit 3 if $! == ENOENT;
      print STDERR "error: cannot inspect configuration source at $f: $!\n";
      exit 4;
    }
    (-f $f && -r _) or exit 5;
    open(my $fh, "<", $f) or exit 5;
    my $body = do { local $/; <$fh> } // "";
    if ($harness eq "claude") {
      $body =~ /\A(ordinary|\/[^\x00-\x1f\x7f]*)\n?\z/ or exit 6;
      print $1, "\t";
    } else {
      $body =~ /\A(ordinary|\/[^\x00-\x1f\x7f]*)\n([A-Za-z0-9][A-Za-z0-9._-]*(?: +[A-Za-z0-9][A-Za-z0-9._-]*)*)\n?\z/ or exit 6;
      print $1, "\t", $2;
    }
  ' -- "$1" "$2"
}

# fm_worker_account_config <harness> <config-dir> [<secondmate-id>]
# Prints the directory containing the applicable pin. Only a missing per-mate
# file falls back to the home pin; unreadable or malformed files still select
# the override so the ordinary parser refuses them. Non-pinnable runners and
# ordinary workers keep the supplied directory unchanged.
fm_worker_account_config() {
  local harness=$1 config=$2 mate=${3:-} file candidate rc
  if [ -z "$mate" ] || ! file=$(fm_worker_account_file "$harness"); then
    printf '%s\n' "$config"
    return 0
  fi
  candidate="$config/secondmate-accounts/$mate"
  fm_worker_account_read "$harness" "$candidate/$file" >/dev/null
  rc=$?
  case "$rc" in
  3) printf '%s\n' "$config" ;;
  4) return 1 ;;
  *) printf '%s\n' "$candidate" ;;
  esac
}

# fm_worker_account_resolve <harness> <config-dir> <setting>
# Prints "declared<TAB>root<TAB>providers" for a valid pin, where root is the
# directory the launch selects (empty for ordinary Claude, meaning
# CLAUDE_CONFIG_DIR unset). Prints nothing and returns 0 when the runner is
# not pinnable or the home has no pin. On refusal prints one error naming the
# file and returns 1.
fm_worker_account_resolve() {
  local harness=$1 config=$2 setting=$3 file cfg token rc declared root fallback
  file=$(fm_worker_account_file "$harness") || return 0
  cfg="$config/$file"
  token=$(fm_worker_account_read "$harness" "$cfg")
  rc=$?
  case "$rc" in
  0) ;;
  3) return 0 ;;
  4) return 1 ;;
  5)
    echo "error: $setting must be a readable regular file: $cfg" >&2
    return 1
    ;;
  *)
    if [ "$file" = pi-account ]; then
      echo "error: $setting must hold 'ordinary' or one absolute path on line 1 and the providers this home may spend on line 2, separated by spaces, with no other lines or control characters: $cfg" >&2
    else
      echo "error: $setting must hold 'ordinary' or one absolute path on a single line with no control characters: $cfg" >&2
    fi
    return 1
    ;;
  esac
  declared=${token%%$'\t'*}
  root=$declared
  # shellcheck disable=SC2088  # The fallbacks are literal text for the refusal.
  case "$harness" in
  claude) fallback='~/.claude with CLAUDE_CONFIG_DIR unset' ;;
  *) fallback='~/.pi/agent' ;;
  esac
  if [ "$declared" = ordinary ]; then
    case "$harness" in
    claude) root= ;;
    *) root="${HOME:?HOME is required to resolve an ordinary Pi account}/.pi/agent" ;;
    esac
  fi
  if [ -n "$root" ] && { [ ! -d "$root" ] || [ ! -r "$root" ] || [ ! -x "$root" ]; }; then
    echo "error: $setting must name a readable, searchable existing directory (ordinary means $fallback): $cfg -> $root" >&2
    return 1
  fi
  printf '%s\t%s\t%s\n' "$declared" "$root" "${token#*$'\t'}"
}

# fm_worker_account_list_file <harness>
# Prints the account-list file name for a multi-account runner; returns 1 for any other.
fm_worker_account_list_file() {
  case "$1" in
  claude) printf '%s\n' claude-accounts ;;
  agy) printf '%s\n' agy-accounts ;;
  *) return 1 ;;
  esac
}

# fm_worker_account_list <harness> <config-dir>
# Prints the entries config/claude-accounts or config/agy-accounts declares,
# one per line, for a supported launch. Prints nothing and returns 0 for another
# runner or when the list is absent. On a malformed or unreadable list prints
# one error naming the file and returns 1.
fm_worker_account_list() {
  local harness=$1 list_file cfg out rc
  list_file=$(fm_worker_account_list_file "$harness") || return 0
  cfg="$2/$list_file"
  out=$(perl -MErrno=ENOENT -e '
    my ($f) = @ARGV;
    unless (lstat $f) {
      exit 3 if $! == ENOENT;
      print STDERR "error: cannot inspect configuration source at $f: $!\n";
      exit 4;
    }
    (-f $f && -r _) or exit 5;
    open(my $fh, "<", $f) or exit 5;
    my $body = do { local $/; <$fh> } // "";
    $body =~ /\A(?:(?:ordinary|\/[^\x00-\x1f\x7f]*)\n)*(?:ordinary|\/[^\x00-\x1f\x7f]*)\n?\z/ or exit 6;
    my %seen;
    for my $entry (split /\n/, $body) {
      exit 7 if $seen{$entry}++;
      print $entry, "\n";
    }
  ' -- "$cfg")
  rc=$?
  case "$rc" in
  0) printf '%s\n' "$out" ;;
  3) return 0 ;;
  4) return 1 ;;
  5)
    echo "error: config/$list_file must be a readable regular file: $cfg" >&2
    return 1
    ;;
  7)
    echo "error: config/$list_file declares the same account twice: $cfg" >&2
    return 1
    ;;
  *)
    echo "error: config/$list_file must hold one account per line, each 'ordinary' or an absolute path, with no blank lines or control characters: $cfg" >&2
    return 1
    ;;
  esac
}

# fm_worker_account_relaunch_request <harness> <config-dir> <prior-harness> <recorded-account> <explicit-account> [<secondmate-id>]
# Prints the declared account a relaunch asks fm_worker_account_select for:
# the explicit one when given, otherwise the task's recorded account when the
# home declares an account list for <harness> and the ship or scout stays on
# that harness. Prints nothing otherwise, so a relaunch without a list re-reads
# the pin exactly as before. Returns 1 when the explicit account holds a control
# character or the list cannot be read.
fm_worker_account_relaunch_request() {
  local harness=$1 config=$2 prior=$3 recorded=$4 explicit=$5 mate=${6:-} listed list_file
  list_file=$(fm_worker_account_list_file "$harness" 2>/dev/null || printf '%s\n' claude-accounts)
  fm_worker_account_request_valid "$explicit" "$list_file" || return 1
  if [ -n "$explicit" ] || [ -n "$mate" ]; then
    printf '%s\n' "$explicit"
    return 0
  fi
  listed=$(fm_worker_account_list "$harness" "$config") || return 1
  [ -n "$listed" ] && [ "$prior" = "$harness" ] || return 0
  printf '%s\n' "$recorded"
}

# fm_worker_account_pi_provider <model>
# Prints the provider an explicit Pi --model <provider>/<id> names. Returns 1,
# silently, for anything else, so no caller can fall back to a guess.
fm_worker_account_pi_provider() {
  local model=$1
  case "$model" in
  */*)
    [ -n "${model%%/*}" ] && [ -n "${model#*/}" ] || return 1
    printf '%s\n' "${model%%/*}"
    ;;
  *) return 1 ;;
  esac
}

# fm_worker_account_check <harness> <declared> <root> <executable> [<provider>] [<setting>]
# Returns 0 only when the runner's own check says the selected root is signed
# in for this launch; otherwise prints one error and returns 1.
fm_worker_account_check() {
  local harness=$1 declared=$2 root=$3 executable=$4 provider=${5:-} setting=${6:-} out verdict name
  [ -n "$setting" ] || setting="config/$(fm_worker_account_file "$harness")"
  local -a clean=(env -i "HOME=${HOME:-}" "PATH=${PATH:-}")
  for name in TMPDIR USER LOGNAME; do
    [ -z "${!name:-}" ] || clean+=("$name=${!name}")
  done
  case "$harness" in
  claude)
    [ -z "$root" ] || clean+=("CLAUDE_CONFIG_DIR=$root")
    if fm_run_timed "$FM_WORKER_ACCOUNT_CHECK_SECONDS" "${clean[@]}" \
      "$executable" auth status >/dev/null 2>&1 </dev/null; then
      return 0
    fi
    if [ -n "$root" ]; then
      echo "error: $setting pins Claude workers to $root, which is not signed in (claude auth status); sign in with CLAUDE_CONFIG_DIR=$root claude, then /login, or change the pin" >&2
    else
      echo "error: $setting pins Claude workers to the ordinary account, which is not signed in (claude auth status); sign in with env -u CLAUDE_CONFIG_DIR claude, then /login, or change the pin" >&2
    fi
    return 1
    ;;
  pi | pi-signed)
    clean+=("PI_CODING_AGENT_DIR=$root")
    out=$(fm_run_timed "$FM_WORKER_ACCOUNT_CHECK_SECONDS" "${clean[@]}" \
      "$executable" auth check --provider "$provider" --json --no-refresh 2>/dev/null </dev/null)
    verdict=$(printf '%s\n' "$out" | jq -r '
      if type != "object" or (has("status") | not) then "list"
      elif .status == "ready" then "ready"
      elif .status == "not_ready" and .reason == "provider_not_found" then "list"
      else "\(.status) \(.reason // "")"
      end' 2>/dev/null)
    case "${verdict:-list}" in
    ready) return 0 ;;
    list)
      if out=$(fm_run_timed "$FM_WORKER_ACCOUNT_CHECK_SECONDS" "${clean[@]}" \
        "$executable" --list-models "$provider" 2>/dev/null </dev/null) &&
        printf '%s\n' "$out" | awk -v p="$provider" 'NR > 1 && $1 == p { found = 1; exit } END { exit !found }'; then
        return 0
      fi
      verdict="no model listed for provider $provider"
      ;;
    esac
    echo "error: $setting pins Pi workers to $declared, which is not signed in for provider '$provider' ($verdict); sign in with PI_CODING_AGENT_DIR=$root $harness, then /login, or change the pin" >&2
    return 1
    ;;
  agy)
    local agy_home=$root
    [ -n "$agy_home" ] || agy_home=${HOME:-}
    clean=(env -i "HOME=$agy_home" "PATH=${PATH:-}")
    for name in TMPDIR USER LOGNAME; do
      [ -z "${!name:-}" ] || clean+=("$name=${!name}")
    done
    if out=$(fm_run_timed "$FM_WORKER_ACCOUNT_CHECK_SECONDS" "${clean[@]}" \
      "$executable" models 2>&1 </dev/null); then
      return 0
    fi
    if printf '%s' "$out" | grep -qi 'sign in'; then
      if [ -n "$root" ]; then
        echo "error: $setting pins agy workers to $root, which is not signed in (agy models); sign in with HOME=$root agy, or change the list" >&2
      else
        echo "error: $setting pins agy workers to the ordinary account, which is not signed in (agy models); sign in with agy, or change the list" >&2
      fi
      return 1
    fi
    return 0
    ;;
  esac
  return 0
}

# fm_worker_account_request_valid <account>
# Refuses an --account value holding a control character. Declared entries
# never hold one, and a newline would otherwise split the value before the
# whole-entry membership check or the account= record sees it.
fm_worker_account_request_valid() {
  local list_file=${2:-claude-accounts}
  case "$1" in
  *[[:cntrl:]]*)
    echo "error: --account must name one config/$list_file entry exactly, with no control characters" >&2
    return 1
    ;;
  esac
}

# fm_worker_account_select <harness> <config-dir> <model> <executable> [<raw-command>] [<secondmate-id>] [<account>]
# The whole launch-time decision. Prints nothing for an unpinned runner, so
# the caller keeps today's launch unchanged. For a pinned one, or a Claude or
# agy ship or scout launching on a declared account-list entry named by
# <account>, prints "declared<TAB>root<TAB>provider", where provider is the
# Pi launch model's own (empty for Claude and agy), after the model guard and
# the sign-in check pass. On refusal prints one error and returns 1.
# bin/fm-spawn.sh runs it before any endpoint exists, and bin/fm-control.sh
# before a relaunch stops the live agent.
fm_worker_account_select() {
  local harness=$1 config=$2 model=$3 executable=$4 raw=${5:-} mate=${6:-} account=${7:-}
  local selection declared root providers word provider='' selected_config setting listed count list_file pin_file fallback runner_label
  list_file=$(fm_worker_account_list_file "$harness" 2>/dev/null || true)
  fm_worker_account_request_valid "$account" "${list_file:-claude-accounts}" || return 1
  if [ -n "$account" ] && [ "$harness" != claude ] && [ "$harness" != agy ]; then
    if [ -e "$config/agy-accounts" ]; then
      echo "error: --account names one of config/claude-accounts or config/agy-accounts and applies to Claude or agy workers only, not $harness" >&2
    else
      echo "error: --account names one of config/claude-accounts and applies to Claude workers only, not $harness" >&2
    fi
    return 1
  fi
  if [ -n "$account" ] && [ -n "$mate" ]; then
    echo "error: --account applies to ships and scouts; secondmate $mate cannot use --account" >&2
    return 1
  fi
  listed=$(fm_worker_account_list "$harness" "$config") || return 1
  if [ -z "$listed" ] && [ -n "$account" ]; then
    echo "error: --account '$account' needs config/$list_file, which this home does not declare" >&2
    return 1
  fi
  if [ "$harness" = claude ] && [ -n "$listed" ] && { [ -e "$config/claude-account" ] || [ -L "$config/claude-account" ]; }; then
    echo "error: config/claude-accounts and config/claude-account are both present; keep the account list or the single pin, not both" >&2
    return 1
  fi
  selected_config=$(fm_worker_account_config "$harness" "$config" "$mate") || return 1
  pin_file=$(fm_worker_account_file "$harness" 2>/dev/null || true)
  setting="config/${pin_file:-$list_file}"
  [ "$selected_config" = "$config" ] || setting="$selected_config/$pin_file"
  if [ -n "$listed" ] && [ -n "$mate" ]; then
    if [ "$harness" = claude ] && [ "$selected_config" = "$config" ]; then
      echo "error: config/claude-accounts chooses accounts for ships and scouts only; secondmate $mate needs its own pin in config/secondmate-accounts/$mate/claude-account" >&2
      return 1
    fi
    [ "$harness" = claude ] || return 0
  fi
  if [ -n "$listed" ] && [ -z "$mate" ]; then
    setting="config/$list_file"
    runner_label=$harness
    [ "$harness" != claude ] || runner_label=Claude
    if [ -z "$account" ]; then
      count=$(printf '%s\n' "$listed" | wc -l | tr -d ' ')
      echo "error: $setting declares $count $runner_label accounts, so a $runner_label ship or scout launch must name one with --account; bin/fm-${harness}-account-quota.sh measures each, and Firstmate never picks a default" >&2
      return 1
    fi
    declared=
    while IFS= read -r word; do
      [ "$word" != "$account" ] || { declared=$account; break; }
    done <<< "$listed"
    [ -n "$declared" ] || {
      echo "error: account '$account' is not declared in $setting; name a declared entry with --account" >&2
      return 1
    }
    declared=$account
    root=$account
    [ "$declared" != ordinary ] || root=
    if [ -n "$root" ] && { [ ! -d "$root" ] || [ ! -r "$root" ] || [ ! -x "$root" ]; }; then
      # shellcheck disable=SC2088  # Literal text for the refusal.
      fallback='~/.claude with CLAUDE_CONFIG_DIR unset'
      [ "$harness" != agy ] || fallback='default HOME'
      echo "error: $setting must name readable, searchable existing directories (ordinary means $fallback): $root" >&2
      return 1
    fi
    providers=
  else
    selection=$(fm_worker_account_resolve "$harness" "$selected_config" "$setting") || return 1
    if [ -z "$selection" ]; then
      [ "$selected_config" = "$config" ] && return 0
      echo "error: secondmate account pin disappeared during selection: $setting" >&2
      return 1
    fi
    declared=${selection%%$'\t'*}
    root=${selection#*$'\t'}
    providers=${root#*$'\t'}
    root=${root%%$'\t'*}
  fi
  if [ "$harness" = claude ]; then
    for word in $raw; do
      case "$word" in
      [A-Za-z_]*=*)
        case " CLAUDE_CONFIG_DIR $FM_WORKER_ACCOUNT_CLAUDE_SHED " in
        *" ${word%%=*} "*)
          echo "error: $setting pins Claude workers, but the raw launch command sets ${word%%=*}, which would override the pinned account; remove ${word%%=*} from the raw command, or change or remove $setting" >&2
          return 1
          ;;
        esac
        ;;
      *) break ;;
      esac
    done
  elif [ "$harness" = agy ]; then
    for word in $raw; do
      case "$word" in
      [A-Za-z_]*=*)
        if [ "${word%%=*}" = HOME ]; then
          echo "error: $setting selects agy worker accounts, but the raw launch command sets HOME, which would override the selected account; remove HOME from the raw command, or change or remove $setting" >&2
          return 1
        fi
        ;;
      *) break ;;
      esac
    done
  else
    if [ -n "$raw" ]; then
      echo "error: $setting pins Pi workers, and a raw Pi launch command runs verbatim, so it cannot carry the pinned --provider; launch with --harness $harness and --model <provider>/<id> instead" >&2
      return 1
    fi
    provider=$(fm_worker_account_pi_provider "$model") || {
      echo "error: $setting pins Pi workers to providers ($providers), so a Pi launch needs --model <provider>/<id> naming one of them; '${model:-none}' names no provider, and Firstmate does not guess one" >&2
      return 1
    }
    case " $providers " in
    *" $provider "*) ;;
    *)
      echo "error: $setting pins Pi workers to providers ($providers), but --model '$model' names provider '$provider'" >&2
      return 1
      ;;
    esac
  fi
  fm_worker_account_check "$harness" "$declared" "$root" "$executable" "$provider" "$setting" || return 1
  printf '%s\t%s\t%s\n' "$declared" "$root" "$provider"
}

# fm_worker_account_claude_shed
# Prints the `env` launch prefix that unsets the environment credentials Claude
# ranks above a pinned root's stored login. The caller appends the root
# assignment, or -u CLAUDE_CONFIG_DIR for the ordinary account.
fm_worker_account_claude_shed() {
  local var prefix=env
  for var in $FM_WORKER_ACCOUNT_CLAUDE_SHED; do
    prefix="$prefix -u $var"
  done
  printf '%s\n' "$prefix"
}
