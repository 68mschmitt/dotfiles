#!/bin/bash

source "$HOME/.config/my-wallpapers/_load_config.sh"

while true; do
    "$WALLPAPER_SCRIPTS_DIR/set-random-wallpaper.sh"
    sleep "$CHANGE_WALLPAPER_TIMEOUT"
done &
