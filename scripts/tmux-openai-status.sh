#!/usr/bin/env bash
# Tmux status line component for OpenAI usage.
# Displays nothing unless host-local OpenAI OAuth credentials are available.

set -uo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tmux-usage-lib.sh
. "$SCRIPT_DIR/tmux-usage-lib.sh"

CACHE="$(tmux_usage_openai_cache_path)"

# Do not render stale cache data on machines that are not authenticated.
tmux_usage_has_openai_auth || exit 0

# Kick off a detached refresh when stale; the refresh script owns throttling.
if [ -x "$SCRIPT_DIR/tmux-openai-refresh.sh" ]; then
  (nohup "$SCRIPT_DIR/tmux-openai-refresh.sh" >/dev/null 2>&1 &) >/dev/null 2>&1
fi

usage_text=""
if [ -f "$CACHE" ]; then
  primary_remaining=""
  primary_reset_at=""
  weekly_remaining=""
  weekly_reset_at=""
  last_refresh=0
  IFS=$'\t' read -r last_refresh primary_remaining primary_reset_at weekly_remaining weekly_reset_at < <(
    jq -r '[.ts // 0, .meters.primary.remainingPercent // "", .meters.primary.resetAtMs // "", .meters.weekly.remainingPercent // "", .meters.weekly.resetAtMs // ""] | @tsv' "$CACHE" 2>/dev/null || true
  )

  if [ -n "$primary_remaining" ]; then
    primary_pct=$(awk -v n="$primary_remaining" 'BEGIN { if (n < 0) n = 0; if (n > 100) n = 100; printf "%.0f", n }')
    primary_text="${primary_pct}%"
    primary_reset_at=$(tmux_usage_to_ms "$primary_reset_at")
    if [ "$primary_reset_at" -gt 0 ] 2>/dev/null; then
      now_ms=$(tmux_usage_now_ms)
      seconds=$(((primary_reset_at - now_ms + 999) / 1000))
      if [ "$seconds" -lt 0 ]; then seconds=0; fi
      primary_text="$primary_text $(tmux_usage_format_duration "$seconds")"
    fi
    usage_text="$primary_text"
  fi

  if [ -n "$weekly_remaining" ]; then
    weekly_pct=$(awk -v n="$weekly_remaining" 'BEGIN { if (n < 0) n = 0; if (n > 100) n = 100; printf "%.0f", n }')
    weekly_text="${weekly_pct}%"
    weekly_reset_at=$(tmux_usage_to_ms "$weekly_reset_at")
    if [ "$weekly_reset_at" -gt 0 ] 2>/dev/null; then
      now_ms=$(tmux_usage_now_ms)
      seconds=$(((weekly_reset_at - now_ms + 999) / 1000))
      if [ "$seconds" -lt 0 ]; then seconds=0; fi
      weekly_text="$weekly_text $(tmux_usage_format_duration "$seconds")"
    fi
    if [ -n "$usage_text" ]; then
      usage_text="$usage_text | $weekly_text"
    else
      usage_text="$weekly_text"
    fi
  fi

  last_refresh=$(tmux_usage_to_ms "$last_refresh")
  if [ -n "$usage_text" ] && [ "$last_refresh" -gt 0 ]; then
    age_minutes=$((($(tmux_usage_now_ms) - last_refresh) / 60000))
    if [ "$age_minutes" -lt 0 ]; then age_minutes=0; fi
    usage_text="${age_minutes}m | $usage_text"
  fi
fi

if [ -n "$usage_text" ]; then
  printf 'OpenAI %s' "$usage_text"
else
  printf 'OpenAI ⚙️ loading...'
fi
