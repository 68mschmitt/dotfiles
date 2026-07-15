#!/bin/bash
set -euo pipefail

# Seed ~/.config/my-wallpapers/ from the checked-in templates.
#
# Uses an absolute path derived from this script's own location, so it works
# no matter what directory it's invoked from. Only copies files that don't
# already exist, so re-running this never clobbers a real blacklist or
# current-wallpaper history.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DEFAULTS_DIR="$SCRIPT_DIR/default-configs"
CONFIG_DIR="$HOME/.config/my-wallpapers"

mkdir -p "$CONFIG_DIR"

for src in "$DEFAULTS_DIR"/.wallpaper_config "$DEFAULTS_DIR"/.blacklist \
           "$DEFAULTS_DIR"/.current_wallpaper "$DEFAULTS_DIR"/_load_config.sh; do
  dest="$CONFIG_DIR/$(basename "$src")"
  if [[ -f "$dest" ]]; then
    echo "✅ $(basename "$dest") already exists, leaving it alone"
  else
    cp "$src" "$dest"
    echo "📄 Seeded $dest"
  fi
done

echo "✅ Wallpaper config ready at $CONFIG_DIR"
