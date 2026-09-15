#!/usr/bin/env bash
# Tmux status line component for Claude Code usage.
# Displays nothing unless this host has Claude Code OAuth credentials.

set -uo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tmux-usage-lib.sh
. "$SCRIPT_DIR/tmux-usage-lib.sh"

USAGE_CACHE="$HOME/.claude/.usage-cache.json"

# Do not render stale cache data (or a loading placeholder) on unauthenticated hosts.
tmux_usage_has_claude_auth || exit 0

# Kick off a detached refresh when stale; the refresh script owns throttling.
if [ -x "$SCRIPT_DIR/tmux-claude-refresh.sh" ]; then
  (nohup "$SCRIPT_DIR/tmux-claude-refresh.sh" >/dev/null 2>&1 &) >/dev/null 2>&1
fi

usage_text=""
cache_ts=0
if [ -f "$USAGE_CACHE" ]; then
  IFS=$'\t' read -r cache_ts usage_text < <(
    jq -r '[.ts // 0, (.text // "")] | @tsv' "$USAGE_CACHE" 2>/dev/null || printf '0\t\n'
  )
  usage_text="${usage_text#credits }"
fi

# Age of the cached value, shown to the left of the metric (e.g. "(4m)").
age=$(tmux_usage_format_age "$cache_ts" || true)

if [ -n "$usage_text" ]; then
  if [ -n "$age" ]; then
    printf "📊 (%s) %s" "$age" "$usage_text"
  else
    printf "📊 %s" "$usage_text"
  fi
else
  printf "📊 ⚙️ loading..."
fi
