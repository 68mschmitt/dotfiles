#!/bin/bash
# Battery level/charging (event + slow poll); click = time left, health, power mode.
source "$HOME/.config/sketchybar/plugins/lib.sh"
handle_hover && exit 0
BATT="$(pmset -g batt)"
PCT="$(grep -Eo '[0-9]+%' <<< "$BATT" | head -1 | tr -d %)"
[ -z "$PCT" ] && { sketchybar --set "$NAME" drawing=off; exit 0; }

if [ "$SENDER" = mouse.clicked ]; then
  state="$(awk -F'; ' 'NR==2 {print $2}' <<< "$BATT")"
  left="$(grep -Eo '[0-9]+:[0-9]+ remaining' <<< "$BATT")"
  src="$(head -1 <<< "$BATT" | grep -Eo "'.*'" | tr -d "'")"
  io="$(ioreg -rn AppleSmartBattery)"
  cycles="$(awk '/"CycleCount" =/ {print $3; exit}' <<< "$io")"
  maxc="$(awk '/"AppleRawMaxCapacity" =/ {print $3; exit}' <<< "$io")"
  design="$(awk '/"DesignCapacity" =/ {print $3; exit}' <<< "$io")"
  health="–"; [ -n "$maxc" ] && [ -n "$design" ] && [ "$design" -gt 0 ] && health="$((maxc * 100 / design))%"
  lpm="off"; [ "$(pmset -g | awk '/lowpowermode/ {print $2}')" = 1 ] && lpm="on"
  printf '%s\t%s\t%s\n' \
    󰂄 "${PCT}% · ${state:-unknown}" "open 'x-apple.systempreferences:com.apple.Battery-Settings.extension'" \
    󰔟 "${left:-No estimate}" "" \
    󰚥 "Source: ${src:-?}" "" \
    󰁹 "Health ${health} · ${cycles:-?} cycles" "" \
    󰌪 "Low Power Mode ${lpm}" "" | fill_popup "$NAME" 5
  exit 0
fi

case "$PCT" in
  9[0-9]|100) ICON=󰁹 ;; [6-8][0-9]) ICON=󰂀 ;; [3-5][0-9]) ICON=󰁾 ;; [1-2][0-9]) ICON=󰁻 ;; *) ICON=󰂃 ;;
esac
COL=$WHITE
[ "$PCT" -le 20 ] && COL=$RED
grep -q 'AC Power' <<< "$BATT" && { ICON=󰂄; COL=$GREEN; }
sketchybar --set "$NAME" drawing=on icon="$ICON" icon.color="$COL" label="${PCT}%"
