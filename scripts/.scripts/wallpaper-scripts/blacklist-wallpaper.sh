#!/bin/bash

source "$HOME/.config/my-wallpapers/_load_config.sh"

# Check that a wallpaper has been set
if [[ ! -f "$CURRENT_FILE" ]]; then
  echo "❌ No current wallpaper recorded."
  exit 1
fi

current_image="$(cat "$CURRENT_FILE")"

# Check if already blacklisted
if grep -Fxq "$current_image" "$BLACKLIST_FILE" 2>/dev/null; then
  echo "⚠️ Already blacklisted: $current_image"
  exit 0
fi

# Append to blacklist
echo "$current_image" >> "$BLACKLIST_FILE"
echo "🚫 Blacklisted wallpaper:"
echo "$current_image"

"$WALLPAPER_SCRIPTS_DIR"/set-random-wallpaper.sh
