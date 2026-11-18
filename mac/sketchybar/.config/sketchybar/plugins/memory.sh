#!/bin/bash
# Memory item: label/graph are set directly by helpers/bin/memory_load.
# Click popup: live usage graph, pressure + swap, top processes.
source "$HOME/.config/sketchybar/plugins/lib.sh"
handle_hover && exit 0
case "$SENDER" in
  mouse.clicked)
    read -r used ugb tgb <<< "$("$HOME/.config/sketchybar/helpers/bin/memory_load" --print)"
    level=$(sysctl -n kern.memorystatus_vm_pressure_level 2>/dev/null)
    case "$level" in 1) pr="normal"; ps=g ;; 2) pr="warning"; ps=y ;; 4) pr="critical"; ps=x ;; *) pr="normal"; ps=g ;; esac
    swap="$(sysctl -n vm.swapusage | awk '{print $6}')"
    { printf '󰍛\tMemory %s%% · %s / %s GB\topen -a "Activity Monitor"\th\n' "${used:-?}" "${ugb:-?}" "${tgb:-?}"
      printf '󰓅\tPressure %s · swap %s\t\t%s\n' "$pr" "$swap" "$ps"
      printf '\tTOP PROCESSES\t\ts\n'
      ps -Arcmo rss=,comm= 2>/dev/null | head -6 | awk '{m=$1/1024; $1=""; sub(/^ /,""); u="MB"; if (m>=1024) {m/=1024; u="GB"}; printf "󰘚\t%6.1f %s  %s\topen -a \"Activity Monitor\"\tr\n", m, u, $0}'
      printf '󰍉\tOpen Activity Monitor\topen -a "Activity Monitor"\ta\n'
    } | fill_popup "$NAME" 10 ;;
esac
