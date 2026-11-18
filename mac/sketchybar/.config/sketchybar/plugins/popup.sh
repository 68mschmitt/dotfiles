#!/bin/bash
# popup.sh close|open|toggle <item>: popup control for click_scripts.
source "$HOME/.config/sketchybar/plugins/lib.sh"
case "$1" in
  close) popup_close "$2" ;;
  open) popup_open "$2" ;;
  toggle) popup_toggle "$2" ;;
esac
