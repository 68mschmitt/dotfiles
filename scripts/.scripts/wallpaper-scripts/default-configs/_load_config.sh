#!/bin/bash

# Centralized wallpaper config loader

CONFIG_DIR="$HOME/.config/my-wallpapers"
CONFIG_FILE="$CONFIG_DIR/.wallpaper_config"
BLACKLIST_FILE="$CONFIG_DIR/.blacklist"
CURRENT_FILE="$CONFIG_DIR/.current_wallpaper"

# Where the wallpaper-scripts package lives once stowed. Fixed default
# (override by exporting WALLPAPER_SCRIPTS_DIR before sourcing this file).
WALLPAPER_SCRIPTS_DIR="${WALLPAPER_SCRIPTS_DIR:-$HOME/.scripts/wallpaper-scripts}"

# Export so other scripts can use these
export CONFIG_DIR CONFIG_FILE BLACKLIST_FILE CURRENT_FILE WALLPAPER_SCRIPTS_DIR

# Load main config
if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
else
  echo "❌ Config file not found: $CONFIG_FILE"
  echo "   Run '$WALLPAPER_SCRIPTS_DIR/init-wallpaper.sh' once to set it up."
  exit 1
fi

# Validate required variables
if [[ -z "$WALLPAPER_DIR" ]]; then
  echo "❌ WALLPAPER_DIR is not defined in $CONFIG_FILE"
  exit 1
fi
