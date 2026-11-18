#!/bin/bash
# Centered date + time. Clicking either opens the agenda popup (on "date").
source "$HOME/.config/sketchybar/plugins/lib.sh"
handle_hover && exit 0
if [ "$SENDER" = mouse.clicked ]; then
  NAME=date "$HOME/.config/sketchybar/plugins/agenda.sh"; exit 0
fi
case "$NAME" in
  date) sketchybar --set "$NAME" label="$(date '+%a %b %-d')" ;;
  *)    sketchybar --set "$NAME" label="$(date '+%-I:%M %p')" ;;
esac
