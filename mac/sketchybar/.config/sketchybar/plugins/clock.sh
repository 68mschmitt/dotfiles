#!/bin/sh
# Centered date + time. $NAME is "date" or "clock".
case "$NAME" in
  date) sketchybar --set "$NAME" label="$(date '+%a %b %-d')" ;;
  *)    sketchybar --set "$NAME" label="$(date '+%-I:%M %p')" ;;
esac
