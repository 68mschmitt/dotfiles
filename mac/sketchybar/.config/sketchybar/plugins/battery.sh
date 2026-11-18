#!/bin/bash
# Battery level/charging (event + slow poll).
# Popup: charge meter, time left, health/cycles, power source, top energy users,
# Low Power Mode state, battery settings.
source "$HOME/.config/sketchybar/plugins/lib.sh"
handle_hover && exit 0
BATT="$(pmset -g batt)"
PCT="$(grep -Eo '[0-9]+%' <<< "$BATT" | head -1 | tr -d %)"
[ -z "$PCT" ] && { sketchybar --set "$NAME" drawing=off; exit 0; }

if [ "$SENDER" = mouse.clicked ]; then
  state="$(awk -F'; ' 'NR==2 {print $2}' <<< "$BATT")"
  left="$(grep -Eo '[0-9]+:[0-9]+ remaining' <<< "$BATT")"
  [ "$left" = "0:00 remaining" ] && left=""
  [ -z "$left" ] && grep -qi 'charged' <<< "$BATT" && left="fully charged"
  src="$(head -1 <<< "$BATT" | grep -Eo "'.*'" | tr -d "'")"
  io="$(ioreg -rn AppleSmartBattery)"
  num() { grep -Eo "\"$1\" ?= ?[0-9]+" <<< "$io" | head -1 | grep -Eo '[0-9]+$'; }
  cycles="$(num CycleCount)"; maxc="$(num AppleRawMaxCapacity)"; design="$(num DesignCapacity)"
  health="–"; [ -n "$maxc" ] && [ -n "$design" ] && [ "$design" -gt 0 ] && health="$((maxc * 100 / design))%"
  lpm="off"; [ "$(pmset -g | awk '/lowpowermode/ {print $2}')" = 1 ] && lpm="on"
  st=g; [ "$PCT" -le 50 ] && st=y; [ "$PCT" -le 20 ] && st=x
  settings="open 'x-apple.systempreferences:com.apple.Battery-Settings.extension'"
  rows() { # $1 = energy lines (or a placeholder)
    printf '󰂄\tBattery %s%% · %s\t%s\th\n' "$PCT" "${state:-unknown}" "$settings"
    printf '󰁹\t%s  %s\t\t%s\n' "$(meter "$PCT" 16)" "${left:-no estimate}" "$st"
    printf '󰚥\t%s · Low Power Mode %s · profile %s\t\tm\n' "${src:-?}" "$lpm" "$(power_profile)"
    printf '󰁹\tHealth %s · %s cycles\t\tm\n' "$health" "${cycles:-?}"
    printf '\tUSING SIGNIFICANT ENERGY\t\ts\n'
    printf '%s\n' "$1"
    printf '\tBattery settings\t%s\ta\n' "$settings"
  }
  rows "$(printf '󰔟\tsampling…\t\tm')" | fill_popup "$NAME" 10
  [ "$(sketchybar --query "$NAME" | jq -r .popup.drawing)" = on ] || exit 0
  # top's power column over a 1s sample (second block), skipping top itself
  energy="$(top -l 2 -s 1 -n 10 -o power -stats power,command 2>/dev/null |
    awk '/^POWER/ {blk++; next} blk == 2 && NF >= 2 && $1+0 > 1 && $2 != "top" {printf "󰚥\t%5.1f  %s\topen -a \"Activity Monitor\"\tr\n", $1, $2}' | head -4)"
  rows "${energy:-$(printf '󰄬\tnothing notable\t\tg')}" | fill_popup "$NAME" 10 keep
  exit 0
fi

case "$PCT" in
  9[0-9]|100) ICON=󰁹 ;; [6-8][0-9]) ICON=󰂀 ;; [3-5][0-9]) ICON=󰁾 ;; [1-2][0-9]) ICON=󰁻 ;; *) ICON=󰂃 ;;
esac
COL=$WHITE
[ "$PCT" -le 20 ] && COL=$RED
grep -q 'AC Power' <<< "$BATT" && { ICON=󰂄; COL=$GREEN; }
sketchybar --set "$NAME" drawing=on icon="$ICON" icon.color="$COL" label="${PCT}%"
