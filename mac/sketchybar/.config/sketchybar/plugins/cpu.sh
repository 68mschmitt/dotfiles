#!/bin/sh
# CPU load across all cores (ps sum / core count), red when busy.
CPU="$(ps -A -o %cpu= | awk -v n="$(sysctl -n hw.ncpu)" '{s+=$1} END {printf "%.0f", s/n}')"
COLOR=0xffffffff
[ "$CPU" -ge 80 ] && COLOR=0xffed8796
sketchybar --set "$NAME" label="${CPU}%" label.color="$COLOR"
