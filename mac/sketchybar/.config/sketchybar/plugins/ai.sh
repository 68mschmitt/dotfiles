#!/bin/bash
# AI usage island: Claude credits (from ~/.claude/.usage-cache.json, refreshed
# through the existing tmux refresh script, which throttles + backs off) and
# Codex rate-limit windows (opencode's OpenAI usage cache, when fresh).
# Popup: credit meter + limits, Codex windows with reset times, refresh, usage pages.
source "$HOME/.config/sketchybar/plugins/lib.sh"
handle_hover && exit 0
SCRIPTS="$HOME/projects/dotfiles/scripts"
CLAUDE="$HOME/.claude/.usage-cache.json"
CODEX="$HOME/.local/share/opencode/.openai-usage-cache.json"
CODEX_FRESH=86400   # ignore Codex data older than a day

claude() { # pct used spent limit ts
  jq -r '(.text // "") as $t
    | ($t | capture("\\$(?<used>[0-9.]+)/\\$(?<limit>[0-9.]+) \\((?<pct>[0-9]+)%\\)") // {}) as $m
    | [($m.pct // ""), ($m.used // ""), ($m.limit // ""), (.ts // 0)] | map(tostring) | join("\u001f")' "$CLAUDE" 2>/dev/null
}
codex() { # weekly_used primary_used weekly_reset primary_reset ts(s)
  jq -r '[(100 - (.meters.weekly.remainingPercent // 100)), (100 - (.meters.primary.remainingPercent // 100)),
          ((.meters.weekly.resetAtMs // 0) / 1000 | floor), ((.meters.primary.resetAtMs // 0) / 1000 | floor),
          ((.ts // 0) / 1000 | floor)] | map(tostring) | join("\u001f")' "$CODEX" 2>/dev/null
}
until_str() { local s=$(( $1 - $(date +%s) )); [ $s -le 0 ] && { echo "now"; return; }
  [ $s -ge 86400 ] && echo "$((s / 86400))d $((s % 86400 / 3600))h" || echo "$((s / 3600))h $((s % 3600 / 60))m"; }
col_for() { if [ "${1:-0}" -ge 90 ]; then echo "$RED x"; elif [ "${1:-0}" -ge 70 ]; then echo "$YELLOW y"; else echo "$WHITE g"; fi; }

render() {
  IFS=$'\x1f' read -r cpct _ _ _ <<< "$(claude)"
  IFS=$'\x1f' read -r wk _ _ _ xts <<< "$(codex)"
  # "Claude ▰▱▱▱▱ 16%" (+ "Codex 55%" while its cache is fresh)
  if [ -n "$cpct" ]; then label="Claude $(meter "$cpct" 5) ${cpct}%"; else label="Claude –%"; fi
  [ -n "$xts" ] && [ $(( $(date +%s) - xts )) -lt $CODEX_FRESH ] && label+="  Codex ${wk}%"
  read -r c _ <<< "$(col_for "$cpct")"
  sketchybar $(anim) --set "$NAME" label="$label" label.color="$c"
}

popup() {
  IFS=$'\x1f' read -r cpct used limit cts <<< "$(claude)"
  IFS=$'\x1f' read -r wk pr wreset preset xts <<< "$(codex)"
  read -r _ cs <<< "$(col_for "$cpct")"
  refresh="+$HOME/.claude/statusline-usage.sh; NAME=ai SENDER=popup_refresh $0"
  {
    printf '󰚩\tAI usage · Claude updated %s ago\topen https://claude.ai/settings/usage\th\n' "$(human_age "${cts:-0}")"
    printf '\tCLAUDE\t\ts\n'
    if [ -n "$cpct" ]; then
      printf '󰠗\t%s  %s%%  · $%s of $%s credits\topen https://claude.ai/settings/usage\t%s\n' "$(meter "$cpct" 14)" "$cpct" "$used" "$limit" "$cs"
    else
      printf '󰠗\tNo Claude usage cached yet\t\tm\n'
    fi
    jq -r '.limits // {} | to_entries[] | [.key, ((.value.utilization // 0) | floor), (.value.resets_at // "")] | map(tostring) | join("\u001f")' "$CLAUDE" 2>/dev/null |
      while IFS=$'\x1f' read -r k u r; do
        printf '󰔟\t%s  %s%%  · %s\t\t%s\n' "$(meter "$u" 14)" "$u" "${k//_/ }${r:+, resets ${r:0:16}}" "$(col_for "$u" | cut -d' ' -f2)"
      done
    printf '\tCODEX\t\ts\n'
    if [ -n "$xts" ] && [ $(( $(date +%s) - xts )) -lt $CODEX_FRESH ]; then
      printf '󰔟\t%s  %s%%  · 5h window, resets in %s\topen https://chatgpt.com/codex/settings/usage\t%s\n' "$(meter "$pr" 14)" "$pr" "$(until_str "$preset")" "$(col_for "$pr" | cut -d' ' -f2)"
      printf '󰃭\t%s  %s%%  · weekly, resets in %s\topen https://chatgpt.com/codex/settings/usage\t%s\n' "$(meter "$wk" 14)" "$wk" "$(until_str "$wreset")" "$(col_for "$wk" | cut -d' ' -f2)"
    elif [ -n "$xts" ] && [ "$xts" -gt 0 ]; then
      printf '󰔟\tCodex data is %s old: use Codex/opencode to refresh it\topen https://chatgpt.com/codex/settings/usage\tm\n' "$(human_age "$xts")"
    else
      printf '󰔟\tNo Codex usage cache\t\tm\n'
    fi
    printf '󰑓\tRefresh Claude usage now\t%s\ta\n' "$refresh"
    printf '󰖟\tOpen Claude usage page\topen https://claude.ai/settings/usage\ta\n'
  } | fill_popup "$NAME" 10 "${1:-toggle}"
}

case "$SENDER" in
  mouse.clicked) popup ;;
  popup_refresh) render; popup keep ;;
  *)
    [ -x "$SCRIPTS/tmux-claude-refresh.sh" ] && "$SCRIPTS/tmux-claude-refresh.sh" >/dev/null 2>&1
    render ;;
esac
