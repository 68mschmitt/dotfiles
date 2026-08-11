#!/usr/bin/env bash
# Fetch Claude subscription "usage credits" spend and cache it for the status line.
#
# Mirrors the pi `claude-usage` extension: GET /api/oauth/usage with the
# `anthropic-beta: oauth-2025-04-20` header, read the `spend` block (falling back
# to `extra_usage`), and render e.g. `credits $363.70/$750 (48%)`.
#
# The OAuth token is read fresh from the macOS keychain each fetch, so it tracks
# Claude Code's own token refresh — no separate OAuth flow needed.
#
# /api/oauth/usage is undocumented and rate-limits hard if polled, so this only
# runs in the background from the status line (throttled) and backs off 15m on 429.

set -uo pipefail

CACHE="$HOME/.claude/.usage-cache.json"
LOCK="$HOME/.claude/.usage-cache.lock"
USAGE_URL="https://api.anthropic.com/api/oauth/usage"
OAUTH_BETA="oauth-2025-04-20"
COOLDOWN_429=900   # back off 15m after a 429
FETCH_TIMEOUT=8
LOCK_STALE=60

now=$(date +%s)

# --- single-flight lock (stale locks are reclaimed) ---
if ! mkdir "$LOCK" 2>/dev/null; then
  lock_ts=$(stat -f %m "$LOCK" 2>/dev/null || echo 0)
  if [ $((now - lock_ts)) -lt "$LOCK_STALE" ]; then exit 0; fi
  rm -rf "$LOCK" 2>/dev/null
  mkdir "$LOCK" 2>/dev/null || exit 0
fi
trap 'rm -rf "$LOCK"' EXIT

write_cache() { # ts cooldown_until text
  printf '{"ts":%s,"cooldownUntil":%s,"text":%s}\n' "$1" "$2" "$(jq -Rn --arg t "$3" '$t')" >"$CACHE"
}

prev_text=$(jq -r '.text // ""' "$CACHE" 2>/dev/null)

token=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null \
        | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
[ -n "$token" ] || exit 0

response=$(curl -s --max-time "$FETCH_TIMEOUT" -w '\n%{http_code}' "$USAGE_URL" \
  -H "Authorization: Bearer $token" \
  -H "anthropic-beta: $OAUTH_BETA" \
  -H "Accept: application/json" 2>/dev/null)
[ -n "$response" ] || exit 0

status="${response##*$'\n'}"
body="${response%$'\n'*}"

if [ "$status" = "429" ]; then
  write_cache "$now" "$((now + COOLDOWN_429))" "$prev_text"
  exit 0
fi
[ "$status" = "200" ] || exit 0

# `spend` (amount_minor + exponent) preferred; `extra_usage` is the fallback.
# money: whole dollars render bare ($750), otherwise two decimals ($363.70).
text=$(printf '%s' "$body" | jq -r '
  def money:
    (. * 100 | round) as $c
    | ($c / 100 | floor) as $d
    | ($c % 100) as $r
    | if $r == 0 then "$\($d)"
      else "$\($d).\(if $r < 10 then "0" else "" end)\($r)" end;
  (if (.spend.used and .spend.limit) then
     { used: (.spend.used.amount_minor / pow(10; .spend.used.exponent // 2)),
       limit: (.spend.limit.amount_minor / pow(10; .spend.limit.exponent // 2)),
       percent: (.spend.percent // 0),
       enabled: (.spend.enabled != false) }
   elif (.extra_usage and (.extra_usage.monthly_limit or .extra_usage.used_credits)) then
     (.extra_usage | (.decimal_places // 2) as $dp |
       { used: ((.used_credits // 0) / pow(10; $dp)),
         limit: ((.monthly_limit // 0) / pow(10; $dp)),
         percent: (.utilization // 0),
         enabled: (.is_enabled != false) })
   else null end)
  | if . == null then empty
    elif .enabled == false then "credits off"
    else "credits \(.used | money)/\(.limit | money) (\(.percent | round)%)"
    end' 2>/dev/null)

[ -n "$text" ] || exit 0
write_cache "$now" 0 "$text"
