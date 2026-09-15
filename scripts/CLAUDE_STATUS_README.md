# Claude Code Usage in Tmux Status Bar

This setup displays your Claude Code usage metrics in your tmux status bar in real-time without getting rate limited.

## What You'll See

Your tmux status bar now displays:
- **Session name** on the left (highlighted in blue)
- **Window list** in the center with current window highlighted
- **Claude usage + time** on the right:
  - 📊 (30s) $403.96/$750 (54%) - displayed in amber when 50-79% used, red when 80%+
  - The leading `(30s)` is the age of the cached value, i.e. how long ago the
    metric was last refreshed:
    - under a minute: seconds in 5-second steps - `0s`, `5s`, ... `55s`
    - under an hour: whole minutes - `1m`, `2m`, ... `59m`
    - an hour or more: hours and minutes - `1h00m`, `2h05m`
  - Current time (HH:MM)

Example status bar:
```
main  1: zsh  2: editor  3: build  | 📊 (30s) $403.96/$750 (54%) 14:32
```

When an OpenAI Codex credential is also present, that segment renders the same
way next to the Claude one:
```
📊 (30s) $403.96/$750 (54%)  OpenAI (5s) 45% 2h15m 14:32
```

Note the OpenAI segment can show two durations: the leading `(5s)` is cache age,
while the trailing `2h15m` is time remaining until the quota window resets.

## How It Works

### Components

1. **~/.claude/statusline-usage.sh** (existing)
   - Fetches Claude usage from the API: `GET /api/oauth/usage`
   - Implements intelligent rate limiting:
     - Single-flight lock prevents concurrent requests
     - Backs off 15 minutes after a 429 rate limit error
     - Never fetches more than once per minute
   - Caches results in `~/.claude/.usage-cache.json` with timestamps and cooldown state
   - Runs as a background job from tmux

2. **~/projects/dotfiles/scripts/tmux-claude-status.sh** (new)
   - Reads the cached usage data from `~/.claude/.usage-cache.json`
   - Renders the cache age (`.ts`) to the left of the metric, so a stale value
     is visibly stale instead of silently old. Rounds down through seconds
     (5-second steps), minutes, then hours+minutes. The age is omitted when the
     cache has no usable timestamp.
   - Extracts percentage and applies color coding:
     - Dim (gray) for 0-49%
     - Amber for 50-79%
     - Red for 80%+
   - Returns immediately (no blocking I/O)
   - Called every 10 seconds by tmux (see status-interval)

3. **~/projects/dotfiles/scripts/tmux-claude-refresh.sh** (new)
   - Background refresh trigger, spawned detached on every status render
   - Decides *whether* to fetch; `statusline-usage.sh` does the fetching
   - Triggers a fetch when the cache is missing, has no text, or is older than
     the configured refresh interval (default 120s - see Configuration below)
   - Never fetches while a 429 cooldown is active

4. **~/projects/dotfiles/tmux/.tmux.conf** (updated)
   - Status bar configuration
   - Calls tmux-claude-status.sh via tmux's command substitution
   - Refreshes every 10 seconds

### Rate Limiting Strategy

The setup uses a **pull-on-display** model:

1. **tmux status bar refresh** (every 10 seconds)
   - Calls `tmux-claude-status.sh`
   - Script reads cached data (instant, no API call)
   - Returns immediately with current value

2. **Background API refresh** (trigger scripts + statusline-usage.sh)
   - API is polled at most once per **refresh interval** (default 120s,
     configurable - see Configuration below)
   - On 429 rate limit, backs off **15 minutes** (COOLDOWN_429=900), regardless
     of the configured interval
   - Single-flight lock prevents concurrent requests
   - On any other failure (timeout, auth, 5xx) the cache is left untouched, so
     the last known good value keeps rendering
   - Only runs when cache is stale enough AND cooldown expired

Result: You can view the status bar as much as you want (10s per redraw = instant,
no network I/O), but the actual API is called at most once per refresh interval,
with intelligent backoff.

## Installation

The scripts are already created and added to your dotfiles:

```bash
# Make sure they're executable
chmod +x ~/projects/dotfiles/scripts/tmux-claude-status.sh
chmod +x ~/projects/dotfiles/scripts/tmux-claude-refresh.sh

# Reload your tmux config
tmux source ~/.tmux.conf
# or kill and restart tmux
```

If you're already running tmux, the status bar should appear immediately after reload.

## Configuration

### Refresh interval

How often the usage APIs are polled. **Default: 120 seconds.**

Set it persistently by copying the example config:

```bash
mkdir -p ~/.config/tmux-usage
cp ~/projects/dotfiles/scripts/tmux-usage.conf.example ~/.config/tmux-usage/config
$EDITOR ~/.config/tmux-usage/config
```

Config files are looked up in this order, and the first one found is used:

1. `$TMUX_USAGE_CONFIG` (explicit path)
2. `${XDG_CONFIG_HOME:-$HOME/.config}/tmux-usage/config`
3. `~/projects/dotfiles/scripts/tmux-usage.conf` (version-controlled with the
   scripts; not tracked by git unless you add it)

Recognised settings, highest precedence first:

| Setting | Effect |
| --- | --- |
| `TMUX_USAGE_CLAUDE_REFRESH_SECONDS` | Claude interval only |
| `TMUX_USAGE_OPENAI_REFRESH_SECONDS` | OpenAI interval only |
| `TMUX_USAGE_REFRESH_SECONDS` | Both providers |
| *(unset)* | Built-in default, 120s |

Environment variables always beat the config file, which makes one-off testing easy:

```bash
TMUX_USAGE_REFRESH_SECONDS=300 ~/projects/dotfiles/scripts/tmux-claude-refresh.sh
```

Notes:

- This is the **API poll interval**, not the status-line redraw interval. Redraw
  cadence is `status-interval` in `.tmux.conf` (10s) and does no network I/O.
- Non-numeric, zero, or negative values are ignored in favour of the 120s default,
  so a typo cannot disable refresh or hammer the API.
- A 429 backoff (15 minutes) always takes precedence over the interval.
- Both endpoints are undocumented and rate-limit aggressively; lowering this
  much below 60s is not recommended.

### Status bar appearance

To customize the status bar, edit `~/projects/dotfiles/tmux/.tmux.conf`:

```tmux
# Change refresh interval (seconds) - lower = more responsive, but still rate-limited
set -g status-interval 10

# Change colors - use hex colors like #569cd6
set -g status-bg '#1e1e1e'
set -g status-fg '#e0e0e0'

# Add/remove status line components
set -g status-right "#[fg=#e0e0e0]#($HOME/projects/dotfiles/scripts/tmux-claude-status.sh) #[fg=#858585]%H:%M"
```

## Troubleshooting

### "loading..." is stuck

The cache file doesn't exist yet. Run:
```bash
~/.claude/statusline-usage.sh
```

This will fetch your usage and create the cache.

### Getting rate limited (429 errors)

The system is designed to prevent this, but if it happens:
1. The script will automatically back off 15 minutes
2. You'll see the last cached value during the cooldown
3. The ~/ should automatically recover after 15 minutes

To manually check for rate limit status:
```bash
cat ~/.claude/.usage-cache.json | jq .
# If cooldownUntil > current_timestamp, you're in backoff
# Once cooldownUntil passes, fetches resume
```

### Scripts not running

Check if the scripts are executable:
```bash
ls -la ~/projects/dotfiles/scripts/tmux-claude-*.sh
```

Should show `rwxr-xr-x`. If not:
```bash
chmod +x ~/projects/dotfiles/scripts/tmux-claude-*.sh
```

### Usage not updating

Check the cache:
```bash
cat ~/.claude/.usage-cache.json | jq .
```

Check the API response directly (if you want):
```bash
token=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null | jq -r '.claudeAiOauth.accessToken')
curl -s https://api.anthropic.com/api/oauth/usage \
  -H "Authorization: Bearer $token" \
  -H "anthropic-beta: oauth-2025-04-20"
```

## Testing

To test the status script directly:
```bash
bash ~/projects/dotfiles/scripts/tmux-claude-status.sh
```

To see what percentage triggers different colors, check the cache:
```bash
jq . ~/.claude/.usage-cache.json
```

## Related Files

- `~/.tmux.conf` - Main tmux configuration (sourced by tmux on startup)
- `~/projects/dotfiles/tmux/.tmux.conf` - Your dotfiles version (stow-managed)
- `~/.claude/.usage-cache.json` - Live cache of usage data
- `~/.claude/statusline-usage.sh` - API client with rate limiting
- `~/projects/dotfiles/scripts/tmux-claude-status.sh` - Tmux display formatter
- `~/projects/dotfiles/scripts/tmux-claude-refresh.sh` - Background refresh helper (optional)
