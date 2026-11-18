#!/bin/bash
# media item: left click = popup with track info + controls, right click = play/pause.
source "$HOME/.config/sketchybar/plugins/lib.sh"
handle_hover && exit 0
[ "$SENDER" = mouse.clicked ] || exit 0
if [ "$BUTTON" = right ]; then media-control toggle-play-pause
else sketchybar --set "$NAME" popup.drawing=toggle; fi
