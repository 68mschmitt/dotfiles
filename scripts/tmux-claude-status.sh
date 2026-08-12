#!/usr/bin/env bash
# Tmux status line component for Claude Code usage
# Displays: "📊 $410.62/$750 (55%)" in a single color
# The percentage in the output itself is the visual indicator

set -uo pipefail

USAGE_CACHE="$HOME/.claude/.usage-cache.json"

# Default fallback
usage_text=""

if [ -f "$USAGE_CACHE" ]; then
  usage_text=$(jq -r '.text // empty' "$USAGE_CACHE" 2>/dev/null | sed 's/^credits //')
fi

# Return plain text
if [ -n "$usage_text" ]; then
  printf "📊 %s" "$usage_text"
else
  printf "⚙️  loading..."
fi
