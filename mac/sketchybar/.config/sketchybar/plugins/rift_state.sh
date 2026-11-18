#!/bin/bash
# rift_state item: click = popup with common Rift actions.
source "$HOME/.config/sketchybar/plugins/lib.sh"
handle_hover && exit 0
[ "$SENDER" = mouse.clicked ] || exit 0
printf '%s\t%s\t%s\n' \
  󰕰 "Balance windows"          "rift-cli execute layout balance" \
  󰖲 "Toggle float (focused)"   "rift-cli execute window toggle-float" \
  󰯌 "Flip split orientation"   "rift-cli execute layout toggle-orientation" \
  󰔡 "Toggle tiling (space)"    "rift-cli execute space toggle-activated" \
  󰑓 "Restart Rift"             "rift service restart" \
  󰈙 "Edit config"              "open -t $HOME/.config/rift/config.toml" | fill_popup "$NAME" 6
