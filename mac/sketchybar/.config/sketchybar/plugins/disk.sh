#!/bin/sh
# Free space on the data volume.
FREE="$(df -H /System/Volumes/Data | awk 'NR==2 {print $4}')"
sketchybar --set "$NAME" label="$FREE"
