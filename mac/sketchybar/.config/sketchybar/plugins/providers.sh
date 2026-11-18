#!/bin/bash
# Power-aware driver (hidden "power" item). Picks a profile from the power
# source and Low Power Mode, then (re)starts the C event providers and retunes
# polled items. Runs at start (forced), on power_source_change / system_woke /
# wifi_change and every 60s; does nothing unless profile or interface changed.
source "$HOME/.config/sketchybar/plugins/lib.sh"
HELPERS="$HOME/.config/sketchybar/helpers"
BIN="$HELPERS/bin"
mkdir -p "$STATE_DIR"

if pmset -g ps | head -1 | grep -q "AC Power"; then profile=ac; else profile=battery; fi
[ "$(pmset -g | awk '/lowpowermode/ {print $2}')" = 1 ] && profile=lowpower
iface="$(route -n get default 2>/dev/null | awk '/interface:/ {print $2}')"
key="$profile ${iface:-none}"

if [ "$SENDER" != forced ] && [ "$(cat "$STATE_DIR/providers" 2>/dev/null)" = "$key" ] \
   && pgrep -x cpu_load >/dev/null; then
  exit 0
fi
echo "$profile" > "$STATE_DIR/power"
echo "$key" > "$STATE_DIR/providers"

#            cpu mem net badges meeting disk  battery clock
case "$profile" in
  ac)       set -- 2   4   2   3      30      300   120     10 ;;
  battery)  set -- 5   10  5   10     60      900   300     20 ;;
  lowpower) set -- 10  20  10  30     120     1800  600     30 ;;
esac

make -s -C "$HELPERS" >/dev/null 2>&1
pkill -x cpu_load; pkill -x memory_load; pkill -x network_load
"$BIN/cpu_load" cpu_update "$1" >/dev/null 2>&1 &
"$BIN/memory_load" memory_update "$2" >/dev/null 2>&1 &
if [ -n "$iface" ]; then
  "$BIN/network_load" "$iface" network_update "$3" >/dev/null 2>&1 &
fi

sketchybar --set badges update_freq="$4" \
           --set meeting update_freq="$5" \
           --set disk update_freq="$6" \
           --set battery update_freq="$7" \
           --set clock update_freq="$8" \
           --trigger network_iface IFACE="${iface:-}"
