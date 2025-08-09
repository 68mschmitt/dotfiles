#!/bin/bash

source "$HOME/.config/my-wallpapers/_load_config.sh"

while true; do
    xset q &>/dev/null || exit 0
    $WALLPAPER_SCRIPTS_DIR/set-random-wallpaper.sh
	sleep $CHANGE_WALLPAPER_TIMEOUT
done &
