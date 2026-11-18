#!/bin/sh
# Active interface (ethernet / Wi-Fi / offline) plus down/up throughput.
# Keeps the previous byte counters in $TMPDIR to compute the rate.
IFACE="$(route -n get default 2>/dev/null | awk '/interface:/ {print $2}')"
if [ -z "$IFACE" ]; then
  sketchybar --set "$NAME" icon="󰖪" label="offline"
  exit 0
fi

WIFI="$(networksetup -listallhardwareports | awk '/Wi-Fi/ {getline; print $2}')"
if [ "$IFACE" = "$WIFI" ]; then ICON="󰖩"; else ICON="󰈀"; fi

STATE="${TMPDIR:-/tmp}/sketchybar_net_$IFACE"
read -r IN OUT <<EOT
$(netstat -ibn -I "$IFACE" | awk 'NR==2 {print $7, $10}')
EOT
NOW="$(date +%s)"
if [ -f "$STATE" ]; then
  read -r PIN POUT PNOW < "$STATE"
fi
echo "$IN $OUT $NOW" > "$STATE"

LABEL="$(awk -v i="$IN" -v o="$OUT" -v pi="${PIN:-$IN}" -v po="${POUT:-$OUT}" \
             -v t="$NOW" -v pt="${PNOW:-0}" '
  function h(b) {
    if (b >= 1048576) return sprintf("%.1fM", b / 1048576)
    if (b >= 1024)    return sprintf("%.0fK", b / 1024)
    return sprintf("%dB", b)
  }
  BEGIN {
    dt = t - pt; if (dt <= 0 || pt == 0) dt = 1
    d = (i - pi) / dt; u = (o - po) / dt
    if (d < 0) d = 0; if (u < 0) u = 0
    printf "↓%5s ↑%5s", h(d), h(u)
  }')"
sketchybar --set "$NAME" icon="$ICON" label="$LABEL"
