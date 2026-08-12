#!/usr/bin/env bash
# Tmux status line component for OpenAI Codex usage.
# Displays nothing unless host-local pi auth has an OpenAI Codex OAuth credential.

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
  remaining=""
  reset_at=""
  IFS=$'\t' read -r remaining reset_at < <(
    jq -r '[.meter.remainingPercent // empty, .meter.resetAtMs // empty] | @tsv' "$CACHE" 2>/dev/null || true
  )

  if [ -n "$remaining" ]; then
    pct=$(awk -v n="$remaining" 'BEGIN { if (n < 0) n = 0; if (n > 100) n = 100; printf "%.0f", n }')
    usage_text="${pct}%"
    reset_at=$(tmux_usage_to_ms "$reset_at")
    if [ "$reset_at" -gt 0 ] 2>/dev/null; then
      now_ms=$(tmux_usage_now_ms)
      seconds=$(((reset_at - now_ms + 999) / 1000))
      if [ "$seconds" -lt 0 ]; then seconds=0; fi
      usage_text="$usage_text $(tmux_usage_format_duration "$seconds")"
    fi
  fi
fi

if [ -n "$usage_text" ]; then
  printf 'OpenAI %s' "$usage_text"
else
  printf 'OpenAI ⚙️ loading...'
fi
