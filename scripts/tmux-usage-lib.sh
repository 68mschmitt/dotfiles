#!/usr/bin/env bash
# Shared helpers for tmux usage status scripts.
# These helpers deliberately read host-local auth from $HOME, not the repo.

# shellcheck shell=bash

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

tmux_usage_openai_auth_path() {
  if [ -n "${PI_AUTH_PATH:-}" ]; then
    printf '%s\n' "$PI_AUTH_PATH"
  else
    printf '%s/auth.json\n' "$(tmux_usage_pi_agent_dir)"
  fi
}

tmux_usage_openai_cache_path() {
  printf '%s/.openai-usage-cache.json\n' "$(tmux_usage_pi_agent_dir)"
}

tmux_usage_read_openai_credential() {
  tmux_usage_have_jq || return 1

  local auth_path
  auth_path=$(tmux_usage_openai_auth_path)
  [ -f "$auth_path" ] || return 1

  jq -r --arg provider "openai-codex" --arg claim "https://api.openai.com/auth" '
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

    .[$provider] as $a
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
  printf 'pi (%s %s; %s)\n' "$(uname -s)" "$(uname -r)" "$(uname -m)"
}
