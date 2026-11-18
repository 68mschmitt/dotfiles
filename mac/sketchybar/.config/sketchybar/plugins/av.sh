#!/bin/bash
# Mic / camera in-use indicators, driven by sketchybar-events (av_update MIC= CAM=).
source "$HOME/.config/sketchybar/plugins/lib.sh"
[ "$SENDER" = av_update ] || exit 0
mic=off cam=off; [ "$MIC" = on ] && mic=on; [ "$CAM" = on ] && cam=on
sketchybar $(anim) --set av.mic drawing=$mic --set av.cam drawing=$cam
