#!/usr/bin/env bash
# Claude Code status line - styled after Oh My Zsh "robbyrussell" theme
# Format: <arrow+cwd (robbyrussell style)> <git branch/status> | <model> | <context> | <credits>

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
model=$(echo "$input" | jq -r '.model.display_name // empty')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
used_tokens=$(echo "$input" | jq -r '(.context_window.total_input_tokens // 0) + (.context_window.total_output_tokens // 0)')
window_size=$(echo "$input" | jq -r '.context_window.context_window_size // empty')

# Format a raw token count as a compact K/M string (e.g. 100000 -> 100K, 1000000 -> 1M)
fmt_tokens() {
  awk -v n="$1" 'BEGIN {
    if (n >= 1000000) { v = n / 1000000; u = "M" }
    else             { v = n / 1000;    u = "K" }
    if (v == int(v)) printf "%d%s", v, u
    else             printf "%.1f%s", v, u
  }'
}

# Colors (dimmed-friendly ANSI codes, matching robbyrussell palette)
GREEN=$'\033[32m'
CYAN=$'\033[36m'
BLUE=$'\033[34m'
RED=$'\033[31m'
YELLOW=$'\033[33m'
DIM=$'\033[2m'
RESET=$'\033[0m'
C_WARN=$'\033[38;2;254;188;56m'  # #febc38 amber
C_CRIT=$'\033[38;2;215;95;95m'   # #d75f5f red

# --- robbyrussell-style prompt: arrow + cwd ---
dir_name=$(basename "$cwd")
prompt=$(printf "%s➜%s  %s%s%s" "$GREEN" "$RESET" "$CYAN" "$dir_name" "$RESET")

# --- git branch + dirty/clean status ---
git_segment=""
if git -C "$cwd" --no-optional-locks rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
  if [ -n "$branch" ]; then
    if [ -n "$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)" ]; then
      dirty_color="$RED"
      dirty_mark=" ${RED}✗${RESET}"
    else
      dirty_color="$BLUE"
      dirty_mark=""
    fi
    git_segment=$(printf " %sgit:(%s%s%s)%s%s" "$dirty_color" "$RED" "$branch" "$dirty_color" "$RESET" "$dirty_mark")
  fi
fi

# --- model name ---
model_segment=""
if [ -n "$model" ]; then
  model_segment=$(printf " %s|%s %s%s%s" "$DIM" "$RESET" "$YELLOW" "$model" "$RESET")
fi

# --- context usage: <used>/<total> (<pct>%) e.g. 100K/1M (10%) ---
context_segment=""
if [ -n "$window_size" ] && [ "$window_size" -gt 0 ] 2>/dev/null; then
  used_str=$(fmt_tokens "$used_tokens")
  total_str=$(fmt_tokens "$window_size")
  context_segment=$(printf " %s|%s %s%s/%s (%.0f%%)%s" "$DIM" "$RESET" "$DIM" "$used_str" "$total_str" "${used_pct:-0}" "$RESET")
fi

# --- usage credits: credits $363.70/$750 (48%) ---
# Read the disk cache written by statusline-usage.sh, then kick off a detached
# background refresh when the value is stale (the endpoint rate-limits hard, so
# never fetch inline and never more than once a minute).
usage_cache="$HOME/.claude/.usage-cache.json"
usage_refresh="$HOME/.claude/statusline-usage.sh"
MIN_INTERVAL=60      # never hit the network more than once/min
STALE=300            # refetch only if the cached value is older than this

usage_text=""
usage_ts=0
usage_cooldown=0
if [ -f "$usage_cache" ]; then
  eval "$(jq -r '@sh "usage_text=\(.text // "") usage_ts=\(.ts // 0) usage_cooldown=\(.cooldownUntil // 0)"' "$usage_cache" 2>/dev/null)"
fi

now=$(date +%s)
if [ $((now - usage_ts)) -ge "$MIN_INTERVAL" ] && [ "$now" -ge "$usage_cooldown" ] &&
   { [ -z "$usage_text" ] || [ $((now - usage_ts)) -ge "$STALE" ]; } && [ -x "$usage_refresh" ]; then
  (nohup "$usage_refresh" >/dev/null 2>&1 &) >/dev/null 2>&1
fi

usage_segment=""
if [ -n "$usage_text" ]; then
  usage_pct=$(printf '%s' "$usage_text" | sed -n 's/.*(\([0-9]*\)%).*/\1/p')
  usage_color="$DIM"
  if [ -n "$usage_pct" ]; then
    if [ "$usage_pct" -ge 80 ]; then usage_color="$C_CRIT"
    elif [ "$usage_pct" -ge 50 ]; then usage_color="$C_WARN"
    fi
  fi
  usage_segment=$(printf " %s|%s %s%s%s" "$DIM" "$RESET" "$usage_color" "$usage_text" "$RESET")
fi

printf "%s%s%s%s%s\n" "$prompt" "$git_segment" "$model_segment" "$context_segment" "$usage_segment"
