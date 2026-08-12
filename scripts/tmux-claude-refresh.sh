#!/usr/bin/env bash
# Background refresh trigger for Claude usage in tmux.
# Calls ~/.claude/statusline-usage.sh only when this host has Claude auth and
# the cache is missing/stale. The usage script performs the actual API request
# and owns its own 429 backoff/single-flight lock.

set -uo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tmux-usage-lib.sh
. "$SCRIPT_DIR/tmux-usage-lib.sh"

USAGE_REFRESH="$HOME/.claude/statusline-usage.sh"
USAGE_CACHE="$HOME/.claude/.usage-cache.json"
STALE_MS=300000

[ -x "$USAGE_REFRESH" ] || exit 0
tmux_usage_has_claude_auth || exit 0

now_ms=$(tmux_usage_now_ms)
cache_ts=0
cooldown_until=0
usage_text=""
if [ -f "$USAGE_CACHE" ]; then
  IFS=$'\t' read -r cache_ts cooldown_until usage_text < <(
    jq -r '[.ts // 0, .cooldownUntil // 0, .text // ""] | @tsv' "$USAGE_CACHE" 2>/dev/null || printf '0\t0\t\n'
  )
fi
cache_ts=$(tmux_usage_to_ms "$cache_ts")
cooldown_until=$(tmux_usage_to_ms "$cooldown_until")

[ "$now_ms" -ge "$cooldown_until" ] 2>/dev/null || exit 0

if [ ! -f "$USAGE_CACHE" ] || [ -z "$usage_text" ] || [ $((now_ms - cache_ts)) -ge "$STALE_MS" ]; then
  (nohup "$USAGE_REFRESH" >/dev/null 2>&1 &) >/dev/null 2>&1
fi

exit 0
