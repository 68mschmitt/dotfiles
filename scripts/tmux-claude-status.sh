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
if [ -f "$USAGE_CACHE" ]; then
  usage_text=$(jq -r '.text // empty' "$USAGE_CACHE" 2>/dev/null | sed 's/^credits //')
fi

if [ -n "$usage_text" ]; then
  printf "📊 %s" "$usage_text"
else
  printf "📊 ⚙️ loading..."
fi
