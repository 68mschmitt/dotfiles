#!/usr/bin/env bash
# Background refresh trigger for Claude usage in tmux
# This is called periodically by tmux to kick off a background fetch.
# It respects the rate-limiting built into ~/.claude/statusline-usage.sh

set -uo pipefail

USAGE_REFRESH="$HOME/.claude/statusline-usage.sh"
USAGE_CACHE="$HOME/.claude/.usage-cache.json"

# Only run the refresh if the script exists
[ -x "$USAGE_REFRESH" ] || exit 0

# Check cache age: refresh if older than 60 seconds
cache_age=0
if [ -f "$USAGE_CACHE" ]; then
  cache_ts=$(jq -r '.ts // 0' "$USAGE_CACHE" 2>/dev/null | awk '{print int($1/1000)}')
  now=$(date +%s)
  cache_age=$((now - cache_ts))
fi

# Only run refresh if cache is older than 60 seconds
# (the script itself enforces min 1 minute intervals + 429 backoff)
if [ "$cache_age" -gt 60 ]; then
  (nohup "$USAGE_REFRESH" >/dev/null 2>&1 &) >/dev/null 2>&1
fi

exit 0
