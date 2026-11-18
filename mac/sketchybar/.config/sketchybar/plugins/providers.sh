#!/bin/bash
# Power-aware driver (hidden "power" item). Picks a profile from the power
# source and Low Power Mode, then (re)starts the C event providers and retunes
# polled items. Runs at start (forced), on power_source_change / system_woke /
# wifi_change and every 60s; does nothing unless profile or interface changed.
source "$HOME/.config/sketchybar/plugins/lib.sh"
HELPERS="$HOME/.config/sketchybar/helpers"
BIN="$HELPERS/bin"
mkdir -p "$STATE_DIR"

# single-flight: forced + power/wake events can arrive together at startup
LOCK="$STATE_DIR/providers.lock"
mkdir "$LOCK" 2>/dev/null || { [ $(( $(date +%s) - $(stat -f %m "$LOCK" 2>/dev/null || echo 0) )) -lt 20 ] && exit 0; }
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

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

# (badge polling and the clock live in barsd, which reads $STATE_DIR/power)
#            cpu mem net meeting disk  battery gh   ai
case "$profile" in
  ac)       set -- 2   4   2   30      300   120     120  300 ;;
  battery)  set -- 5   10  5   60      900   300     300  600 ;;
  lowpower) set -- 10  20  10  120     1800  600     900  1800 ;;
esac

make -s -C "$HELPERS" >/dev/null 2>&1
pkill -x cpu_load; pkill -x memory_load; pkill -x network_load
# last argument = item to update directly (no event/script per tick)
"$BIN/cpu_load" cpu_update "$1" cpu >/dev/null 2>&1 &
"$BIN/memory_load" memory_update "$2" memory >/dev/null 2>&1 &
if [ -n "$iface" ]; then
  "$BIN/network_load" "$iface" network_update "$3" network >/dev/null 2>&1 &
fi

"$HELPERS/bin/bar_notify" power
sketchybar --set meeting update_freq="$4" \
           --set disk update_freq="$5" \
           --set battery update_freq="$6" \
           --set gh.prs update_freq="$7" \
           --set ai update_freq="$8" \
           --trigger network_iface IFACE="${iface:-}"
