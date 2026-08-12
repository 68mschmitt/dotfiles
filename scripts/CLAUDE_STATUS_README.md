# Claude Code Usage in Tmux Status Bar

This setup displays your Claude Code usage metrics in your tmux status bar in real-time without getting rate limited.

## What You'll See

Your tmux status bar now displays:
- **Session name** on the left (highlighted in blue)
- **Window list** in the center with current window highlighted
- **Claude usage + time** on the right:
  - 📊 $403.96/$750 (54%) - displayed in amber when 50-79% used, red when 80%+
  - Current time (HH:MM)

Example status bar:
```
main  1: zsh  2: editor  3: build  | 📊 $403.96/$750 (54%) 14:32
```

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
   - Extracts percentage and applies color coding:
     - Dim (gray) for 0-49%
     - Amber for 50-79%
     - Red for 80%+
   - Returns immediately (no blocking I/O)
   - Called every 10 seconds by tmux (see status-interval)

3. **~/projects/dotfiles/scripts/tmux-claude-refresh.sh** (new)
   - Optional background refresh helper
   - Checks if cache is older than 60 seconds
   - Triggers a background fetch if needed
   - Not currently active in the default setup

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

2. **Background API refresh** (controlled by stateline-usage.sh)
   - API is polled at most **once per minute** (MIN_INTERVAL=60)
   - On 429 rate limit, backs off **15 minutes** (COOLDOWN_429=900)
   - Single-flight lock prevents concurrent requests
   - Only runs when cache is stale enough AND cooldown expired

Result: You can view the status bar as much as you want (10s per refresh = instant),
but the actual API is called at most once per minute, with intelligent backoff.

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
