#!/bin/bash
# CPU load from the cpu_load provider (cpu_update: total_load); click = top processes.
source "$HOME/.config/sketchybar/plugins/lib.sh"
handle_hover && exit 0
case "$SENDER" in
  cpu_update)
    load=$((10#${total_load:-0}))
    col=$WHITE; [ "$load" -ge 80 ] && col=$RED || { [ "$load" -ge 50 ] && col=$YELLOW; }
    sketchybar --set "$NAME" label="${load}%" label.color="$col" ;;
  mouse.clicked)
    { printf '󰻠\tTop CPU\topen -a "Activity Monitor"\n'
      ps -Arco pcpu=,comm= 2>/dev/null | head -5 | awk '{p=$1; $1=""; sub(/^ /,""); printf "\t%5.1f%%  %s\t\n", p, $0}'
    } | fill_popup "$NAME" 6 ;;
esac
