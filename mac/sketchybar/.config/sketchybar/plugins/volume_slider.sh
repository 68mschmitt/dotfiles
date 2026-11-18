#!/bin/bash
# Volume slider in the volume popup: click/drag sets the output volume.
[ "$SENDER" = mouse.clicked ] && [ -n "$PERCENTAGE" ] && osascript -e "set volume output volume $PERCENTAGE"
exit 0
