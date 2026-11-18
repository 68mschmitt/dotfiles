#!/bin/bash
# Free space on the data volume (polled; interval set by providers.sh).
source "$HOME/.config/sketchybar/plugins/lib.sh"
handle_hover && exit 0
[ "$SENDER" = mouse.clicked ] && { open -a "Disk Utility"; exit 0; }
sketchybar --set "$NAME" label="$(df -H /System/Volumes/Data | awk 'NR==2 {print $4}')"
