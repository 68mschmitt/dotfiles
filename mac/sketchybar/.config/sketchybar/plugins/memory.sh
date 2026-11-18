#!/bin/bash
# Memory used from the memory_load provider (memory_update); click = top processes.
source "$HOME/.config/sketchybar/plugins/lib.sh"
handle_hover && exit 0
case "$SENDER" in
  memory_update)
    used=${used_percent:-0}
    col=$WHITE; [ "$used" -ge 85 ] && col=$RED || { [ "$used" -ge 70 ] && col=$YELLOW; }
    sketchybar --set "$NAME" label="${used}%" label.color="$col" ;;
  mouse.clicked)
    { printf '󰍛\tTop memory\topen -a "Activity Monitor"\n'
      ps -Arcmo rss=,comm= 2>/dev/null | head -5 | awk '{m=$1/1024; $1=""; sub(/^ /,""); u="MB"; if (m>=1024) {m/=1024; u="GB"}; printf "\t%6.1f%s  %s\t\n", m, u, $0}'
    } | fill_popup "$NAME" 6 ;;
esac
