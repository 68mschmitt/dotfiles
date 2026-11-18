#!/bin/sh
# Memory in use (100 - system-wide free percentage), red when tight.
FREE="$(memory_pressure -Q | awk -F': ' '/free percentage/ {gsub("%","",$2); print $2}')"
[ -z "$FREE" ] && exit 0
USED=$((100 - FREE))
COLOR=0xffffffff
[ "$USED" -ge 85 ] && COLOR=0xffed8796
sketchybar --set "$NAME" label="${USED}%" label.color="$COLOR"
