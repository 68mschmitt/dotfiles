#!/bin/bash

# Centralized wallpaper config loader

CONFIG_DIR="$HOME/.config/my-wallpapers"
CONFIG_FILE="$CONFIG_DIR/.wallpaper_config"
BLACKLIST_FILE="$CONFIG_DIR/.blacklist"
CURRENT_FILE="$CONFIG_DIR/.current_wallpaper"

# Export so other scripts can use these
export CONFIG_DIR CONFIG_FILE BLACKLIST_FILE CURRENT_FILE

# Load main config
if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
else
  echo "❌ Config file not found: $CONFIG_FILE"
  exit 1
fi

# Validate required variables
if [[ -z "$WALLPAPER_DIR" ]]; then
  echo "❌ WALLPAPER_DIR is not defined in $CONFIG_FILE"
  exit 1
fi
