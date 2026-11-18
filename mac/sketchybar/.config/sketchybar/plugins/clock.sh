#!/bin/bash
# The clock/date labels are set by barsd; clicking the time opens the agenda
# popup on the date item.
[ "$SENDER" = mouse.clicked ] && NAME=date exec "$HOME/.config/sketchybar/plugins/agenda.sh"
exit 0
