#!/usr/bin/env bash
# Background refresh trigger/client for OpenAI Codex usage in tmux.
# Mirrors pi/.pi/agent/extensions/openai-usage.ts, but writes a host-local cache
# that tmux can read without doing network I/O in the status render path.

set -uo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tmux-usage-lib.sh
. "$SCRIPT_DIR/tmux-usage-lib.sh"

USAGE_URL="https://chatgpt.com/backend-api/wham/usage"
CACHE="$(tmux_usage_openai_cache_path)"
LOCK="$CACHE.lock"
MIN_INTERVAL_MS=60000
STALE_MS=300000
COOLDOWN_429_MS=900000
FETCH_TIMEOUT=8
LOCK_STALE=60

credential=$(tmux_usage_read_openai_credential || true)
[ -n "$credential" ] || exit 0
IFS=$'\t' read -r token account_id <<< "$credential"
[ -n "${token:-}" ] && [ -n "${account_id:-}" ] || exit 0

mkdir -p "$(dirname "$CACHE")" 2>/dev/null || exit 0

now_ms=$(tmux_usage_now_ms)
now_s=$((now_ms / 1000))
last_ts=0
cooldown_until=0
has_meter=0
reset_at=0
if [ -f "$CACHE" ]; then
  IFS=$'\t' read -r last_ts cooldown_until has_meter reset_at < <(
    jq -r '[.ts // 0, .cooldownUntil // 0, (if .meter.remainingPercent? == null then 0 else 1 end), .meter.resetAtMs // 0] | @tsv' "$CACHE" 2>/dev/null || printf '0\t0\t0\t0\n'
  )
fi
last_ts=$(tmux_usage_to_ms "$last_ts")
cooldown_until=$(tmux_usage_to_ms "$cooldown_until")
reset_at=$(tmux_usage_to_ms "$reset_at")

[ "$now_ms" -ge "$cooldown_until" ] 2>/dev/null || exit 0

age=$((now_ms - last_ts))
reset_passed=0
if [ "$has_meter" = "1" ] && [ "$reset_at" -gt 0 ] && [ "$now_ms" -ge "$reset_at" ]; then
  reset_passed=1
fi

if [ "$has_meter" = "1" ] && [ "$reset_passed" = "0" ] && [ "$age" -lt "$STALE_MS" ]; then
  exit 0
fi
if [ "$age" -lt "$MIN_INTERVAL_MS" ]; then
  exit 0
fi

# Single-flight lock; reclaim stale lock directories.
if ! mkdir "$LOCK" 2>/dev/null; then
  lock_ts=$(tmux_usage_lock_mtime "$LOCK")
  if [ $((now_s - lock_ts)) -lt "$LOCK_STALE" ]; then exit 0; fi
  rm -rf "$LOCK" 2>/dev/null
  mkdir "$LOCK" 2>/dev/null || exit 0
fi
trap 'rm -rf "$LOCK"' EXIT

response=$(curl -s --max-time "$FETCH_TIMEOUT" -w '\n%{http_code}' "$USAGE_URL" \
  -H "Authorization: Bearer $token" \
  -H "chatgpt-account-id: $account_id" \
  -H "originator: pi" \
  -H "User-Agent: $(tmux_usage_user_agent)" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" 2>/dev/null)
[ -n "$response" ] || exit 0

status="${response##*$'\n'}"
body="${response%$'\n'*}"

write_json() {
  local json="${1:-}"
  local tmp="$CACHE.$$"
  [ -n "$json" ] || return 1
  printf '%s\n' "$json" >"$tmp" && mv "$tmp" "$CACHE"
}

if [ "$status" = "429" ]; then
  cooldown_ms=$((now_ms + COOLDOWN_429_MS))
  next_cache=""
  if [ -f "$CACHE" ]; then
    next_cache=$(jq -c --argjson ts "$now_ms" --argjson cooldown "$cooldown_ms" '.ts = $ts | .cooldownUntil = $cooldown' "$CACHE" 2>/dev/null || true)
  fi
  if [ -z "$next_cache" ]; then
    next_cache=$(jq -n -c --argjson ts "$now_ms" --argjson cooldown "$cooldown_ms" '{ts: $ts, cooldownUntil: $cooldown}')
  fi
  write_json "$next_cache"
  exit 0
fi

# Do not delete the cache on auth/API failures; keep showing the last known value
# while valid host auth remains present.
[ "$status" = "200" ] || exit 0

meter=$(printf '%s' "$body" | jq -c --argjson now "$now_ms" '
  def number_value:
    if type == "number" then .
    elif type == "string" and length > 0 then tonumber?
    else null end;
  def epoch_ms:
    (number_value) as $n
    | if $n == null then null
      elif $n > 10000000000 then $n
      else ($n * 1000) end;
  def clamp($n): if $n < 0 then 0 elif $n > 100 then 100 else $n end;
  def window:
    if type != "object" then empty
    else
      ((.remaining_percent // .percent_left) | number_value) as $remaining0
      | (.used_percent | number_value) as $used
      | (if $remaining0 != null then $remaining0 elif $used != null then (100 - $used) else null end) as $remaining
      | if $remaining == null then empty
        else
          ((.reset_at // .reset_time_ms) | epoch_ms) as $reset0
          | (.reset_after_seconds | number_value) as $reset_after
          | (.limit_window_seconds // .window_seconds | number_value) as $window_seconds
          | {
              remainingPercent: clamp($remaining),
              resetAtMs: ($reset0 // (if $reset_after != null then ($now + ($reset_after * 1000)) else null end)),
              windowSeconds: $window_seconds
            }
          | with_entries(select(.value != null))
        end
    end;

  (.rate_limit // .rate_limits // .) as $r
  | [
      $r.primary_window,
      $r.secondary_window,
      $r.primary,
      $r.secondary,
      $r.five_hour,
      $r.five_hour_limit,
      $r.five_hour_rate_limit,
      $r.weekly,
      $r.weekly_limit,
      $r.weekly_rate_limit
    ]
  | map(window)
  | if length == 0 then empty
    else sort_by(.remainingPercent, (.resetAtMs // 9999999999999999)) | .[0]
    end
' 2>/dev/null)

[ -n "$meter" ] || exit 0
next_cache=$(jq -n -c --argjson ts "$now_ms" --argjson meter "$meter" '{ts: $ts, cooldownUntil: 0, meter: $meter}')
write_json "$next_cache"
