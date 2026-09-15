#!/usr/bin/env bash
# Shared helpers for tmux usage status scripts.
# These helpers deliberately read host-local auth from $HOME, not the repo.

# shellcheck shell=bash

TMUX_USAGE_LIB_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# How stale a cached metric may get before a background refresh is triggered.
TMUX_USAGE_DEFAULT_REFRESH_SECONDS=120

tmux_usage_have_jq() {
  command -v jq >/dev/null 2>&1
}

tmux_usage_is_uint() {
  case "${1:-}" in
    ''|*[!0-9]*) return 1 ;;
    *) return 0 ;;
  esac
}

tmux_usage_now_ms() {
  printf '%s000\n' "$(date +%s)"
}

tmux_usage_to_ms() {
  local n="${1:-0}"
  awk -v n="$n" 'BEGIN {
    if (n !~ /^[0-9]+([.][0-9]+)?$/) { print 0; exit }
    if (n > 10000000000) printf "%.0f\n", n
    else                  printf "%.0f\n", n * 1000
  }'
}

tmux_usage_lock_mtime() {
  stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || printf '0\n'
}

tmux_usage_format_duration() {
  local seconds="${1:-0}"
  if ! tmux_usage_is_uint "$seconds"; then seconds=0; fi

  if [ "$seconds" -lt 60 ]; then
    printf '<1m'
    return
  fi

  local minutes=$(((seconds + 59) / 60))
  if [ "$minutes" -lt 60 ]; then
    printf '%sm' "$minutes"
    return
  fi

  local hours=$((minutes / 60))
  local mins=$((minutes % 60))
  if [ "$hours" -lt 24 ]; then
    printf '%sh%02dm' "$hours" "$mins"
    return
  fi

  local days=$((hours / 24))
  local hrs=$((hours % 24))
  if [ "$hrs" -gt 0 ]; then
    printf '%sd%sh' "$days" "$hrs"
  else
    printf '%sd' "$days"
  fi
}

# Candidate config files, in precedence order. A config file is an optional
# shell fragment that sets any of the TMUX_USAGE_*_REFRESH_SECONDS knobs.
tmux_usage_config_paths() {
  if [ -n "${TMUX_USAGE_CONFIG:-}" ]; then
    printf '%s\n' "$TMUX_USAGE_CONFIG"
    return 0
  fi
  printf '%s/tmux-usage/config\n' "${XDG_CONFIG_HOME:-$HOME/.config}"
  printf '%s/tmux-usage.conf\n' "$TMUX_USAGE_LIB_DIR"
}

# Source the first config file that exists. Environment variables always win,
# so a config file cannot override an explicit env setting (handy for testing
# and for one-off overrides in a single shell).
tmux_usage_load_config() {
  [ -z "${_tmux_usage_config_loaded:-}" ] || return 0
  _tmux_usage_config_loaded=1

  local env_shared="${TMUX_USAGE_REFRESH_SECONDS:-}"
  local env_claude="${TMUX_USAGE_CLAUDE_REFRESH_SECONDS:-}"
  local env_openai="${TMUX_USAGE_OPENAI_REFRESH_SECONDS:-}"

  local candidate
  while IFS= read -r candidate; do
    [ -n "$candidate" ] && [ -f "$candidate" ] || continue
    # shellcheck disable=SC1090
    . "$candidate" 2>/dev/null || true
    break
  done < <(tmux_usage_config_paths)

  [ -z "$env_shared" ] || TMUX_USAGE_REFRESH_SECONDS="$env_shared"
  [ -z "$env_claude" ] || TMUX_USAGE_CLAUDE_REFRESH_SECONDS="$env_claude"
  [ -z "$env_openai" ] || TMUX_USAGE_OPENAI_REFRESH_SECONDS="$env_openai"
  return 0
}

# Resolve the refresh interval in seconds for a provider ("claude"|"openai").
# Precedence: provider-specific setting, shared setting, built-in default.
# Non-numeric or non-positive values fall back to the default rather than
# disabling refresh or hammering the API.
tmux_usage_refresh_seconds() {
  local provider="${1:-}" value=""
  tmux_usage_load_config

  case "$provider" in
    claude) value="${TMUX_USAGE_CLAUDE_REFRESH_SECONDS:-}" ;;
    openai) value="${TMUX_USAGE_OPENAI_REFRESH_SECONDS:-}" ;;
  esac
  [ -n "$value" ] || value="${TMUX_USAGE_REFRESH_SECONDS:-}"

  if ! tmux_usage_is_uint "$value" || [ "$value" -le 0 ]; then
    value="$TMUX_USAGE_DEFAULT_REFRESH_SECONDS"
  fi
  printf '%s\n' "$value"
}

tmux_usage_refresh_ms() {
  printf '%s000\n' "$(tmux_usage_refresh_seconds "${1:-}")"
}

# Render the age of a cache timestamp for the status line:
#   < 1 minute : seconds in 5-second steps  -> "0s", "5s", ... "55s"
#   < 1 hour   : whole minutes              -> "1m", "2m", ... "59m"
#   >= 1 hour  : hours and minutes          -> "1h00m", "2h05m", "27h13m"
# Every step rounds down, so the value never overstates freshness.
# Accepts epoch seconds or milliseconds. Returns non-zero (and prints nothing)
# when the timestamp is missing or unusable so callers can omit the segment.
tmux_usage_format_age() {
  local ts_ms
  ts_ms=$(tmux_usage_to_ms "${1:-0}")
  tmux_usage_is_uint "$ts_ms" || return 1
  [ "$ts_ms" -gt 0 ] || return 1

  local now_ms seconds minutes
  now_ms=$(tmux_usage_now_ms)
  seconds=$(((now_ms - ts_ms) / 1000))
  if [ "$seconds" -lt 0 ]; then seconds=0; fi

  if [ "$seconds" -lt 60 ]; then
    printf '%ss' "$((seconds / 5 * 5))"
    return 0
  fi

  minutes=$((seconds / 60))
  if [ "$minutes" -lt 60 ]; then
    printf '%sm' "$minutes"
    return 0
  fi

  printf '%sh%02dm' "$((minutes / 60))" "$((minutes % 60))"
}

tmux_usage_has_claude_auth() {
  tmux_usage_have_jq || return 1
  command -v security >/dev/null 2>&1 || return 1

  local raw token
  raw=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null) || return 1
  token=$(printf '%s' "$raw" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null) || return 1
  [ -n "$token" ]
}

tmux_usage_pi_agent_dir() {
  printf '%s\n' "${PI_AGENT_DIR:-$HOME/.pi/agent}"
}

tmux_usage_opencode_data_dir() {
  printf '%s\n' "${OPENCODE_DATA_DIR:-$HOME/.local/share/opencode}"
}

tmux_usage_openai_auth_path() {
  if [ -n "${OPENAI_AUTH_PATH:-}" ]; then
    printf '%s\n' "$OPENAI_AUTH_PATH"
  elif [ -n "${PI_AUTH_PATH:-}" ]; then
    printf '%s\n' "$PI_AUTH_PATH"
  elif [ -f "$(tmux_usage_opencode_data_dir)/auth.json" ]; then
    printf '%s/auth.json\n' "$(tmux_usage_opencode_data_dir)"
  else
    printf '%s/auth.json\n' "$(tmux_usage_pi_agent_dir)"
  fi
}

tmux_usage_openai_cache_path() {
  if [ -n "${OPENAI_USAGE_CACHE_PATH:-}" ]; then
    printf '%s\n' "$OPENAI_USAGE_CACHE_PATH"
  elif [ "$(tmux_usage_openai_auth_path)" = "$(tmux_usage_opencode_data_dir)/auth.json" ]; then
    printf '%s/.openai-usage-cache.json\n' "$(tmux_usage_opencode_data_dir)"
  else
    printf '%s/.openai-usage-cache.json\n' "$(tmux_usage_pi_agent_dir)"
  fi
}

tmux_usage_read_openai_credential() {
  tmux_usage_have_jq || return 1

  local auth_path
  auth_path=$(tmux_usage_openai_auth_path)
  [ -f "$auth_path" ] || return 1

  jq -r --arg claim "https://api.openai.com/auth" '
    def b64url_decode:
      . as $s
      | ($s + (["", "===", "==", "="][($s | length) % 4]))
      | gsub("-"; "+")
      | gsub("_"; "/")
      | @base64d;
    def account_id_from_token($token):
      try (
        ($token | split(".")[1] // "" | b64url_decode | fromjson? // {})
        | .[$claim].chatgpt_account_id
      ) catch null;

    (.openai // .["openai-codex"]) as $a
    | if ($a.type == "oauth" and ($a.access | type) == "string" and ($a.access | length) > 0) then
        ($a.accountId // account_id_from_token($a.access) // "") as $accountId
        | if (($accountId | type) == "string" and ($accountId | length) > 0) then
            [$a.access, $accountId] | @tsv
          else empty end
      else empty end
  ' "$auth_path" 2>/dev/null
}

tmux_usage_has_openai_auth() {
  local token="" account_id=""
  IFS=$'\t' read -r token account_id < <(tmux_usage_read_openai_credential || true)
  [ -n "$token" ] && [ -n "$account_id" ]
}

tmux_usage_user_agent() {
  printf '%s (%s %s; %s)\n' "${OPENAI_ORIGINATOR:-opencode}" "$(uname -s)" "$(uname -r)" "$(uname -m)"
}
