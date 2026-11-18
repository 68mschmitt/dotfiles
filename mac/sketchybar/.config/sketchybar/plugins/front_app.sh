#!/bin/sh
# Name of the focused app (front_app_switched supplies it in $INFO).
if [ "$SENDER" = "front_app_switched" ]; then
  sketchybar --set "$NAME" label="$INFO"
fi
