#!/bin/bash

# Colors
FG="#ffffff"
RED="#ff5555"
GREEN="#50fa7b"
YELLOW="#f1fa8c"
BLUE="#8be9fd"

# Battery
BAT_PATH="/sys/class/power_supply/BAT0"
BAT=$(cat "$BAT_PATH/capacity")
STATUS=$(cat "$BAT_PATH/status")

if [[ $STATUS == "Charging" ]]; then
  ICON="⚡"
else
  ICON="🔋"
fi

BAT_COLOR=$([ "$BAT" -ge 80 ] && echo "$GREEN" || ([ "$BAT" -ge 40 ] && echo "$YELLOW" || echo "$RED"))

# CPU Temp
TEMP=$(sensors | awk '/^Package id 0:/ {print int($4)}')

# WiFi SSID (fallback to iw or nmcli)
if command -v nmcli >/dev/null; then
  SSID=$(nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d: -f2)
elif command -v iw >/dev/null; then
  SSID=$(iw dev | awk '$1=="ssid"{print $2}')
else
  SSID="Unknown"
fi

# RAM usage
USED=$(free -m | awk '/Mem:/ {print int($3 / $2 * 100)}')

# Date and Time: MM/DD/YYYY Day HH:MM AM/PM
TIME=$(date "+%m/%d/%Y %a %I:%M %p")

# Final status2d string
STATUS="^c$BAT_COLOR^$ICON $BAT% ^d^| ^c$BLUE^📶 ${SSID:-Offline} ^d^| ^c$FG^🌡️ ${TEMP}°C ^d^| ^c$YELLOW^🧠 ${USED}% ^d^| ^c$GREEN^🕒 $TIME ^d^"

# Set status
xsetroot -name "$STATUS"
