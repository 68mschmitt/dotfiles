#!/bin/bash
# CPU item: label/graph are set directly by helpers/bin/cpu_load.
# Click popup: live load graph, load averages, top processes (click = focus that app,
# or Activity Monitor for background processes).
source "$HOME/.config/sketchybar/plugins/lib.sh"
handle_hover && exit 0
case "$SENDER" in
  mouse.clicked)
    cores=$(sysctl -n hw.ncpu)
    la="$(sysctl -n vm.loadavg | awk '{print $2, $3, $4}')"
    { printf '󰻠\tCPU %s · %s cores · load %s\topen -a "Activity Monitor"\th\n' \
        "$(sketchybar --query cpu | jq -r .label.value)" "$cores" "$la"
      printf '\tTOP PROCESSES\t\ts\n'
      # full command path tells GUI apps (…/Foo.app/Contents/MacOS/…) from daemons
      ps -Ar -o pcpu=,comm= 2>/dev/null | head -6 | while read -r pct path; do
        name="${path##*/}"; app=""
        [[ "$path" == *.app/Contents/MacOS/* ]] && { app="${path%%.app/*}.app"; name="$(basename "$app" .app)"; }
        if [ -n "$app" ]; then click="open \"$app\""; icon=󰣆; else click='open -a "Activity Monitor"'; icon=󰘚; fi
        style=r; awk -v p="$pct" 'BEGIN {exit !(p >= 50)}' && style=y
        printf '%s\t%5.1f%%  %s\t%s\t%s\n' "$icon" "$pct" "$name" "$click" "$style"
      done
      printf '󰍉\tOpen Activity Monitor\topen -a "Activity Monitor"\ta\n'
    } | fill_popup "$NAME" 9 ;;
esac
