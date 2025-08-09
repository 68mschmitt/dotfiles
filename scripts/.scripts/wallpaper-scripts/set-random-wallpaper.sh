#!/bin/bash

source "$HOME/.config/my-wallpapers/_load_config.sh"

# Read blacklist into array (if it exists)
BLACKLIST=()
if [[ -f "$BLACKLIST_FILE" ]]; then
  while IFS= read -r line; do
    # Skip empty lines and comments
    [[ "$line" =~ ^\s*$ || "$line" =~ ^\s*# ]] && continue
    BLACKLIST+=("$line")
  done < "$BLACKLIST_FILE"
fi

# Collect all image paths
all_images=()
while IFS= read -r -d '' file; do
  all_images+=("$file")
done < <(find "$WALLPAPER_DIR" -type f \( \
  -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o \
  -iname '*.bmp' -o -iname '*.webp' \) -print0)

# Filter blacklisted images
images=()
for img in "${all_images[@]}"; do
  skip=false
  for blk in "${BLACKLIST[@]}"; do
    [[ "$img" == "$blk" ]] && skip=true && break
  done
  $skip || images+=("$img")
done

# Abort if no usable images
if [[ ${#images[@]} -eq 0 ]]; then
  echo "❌ No usable images found. (All may be blacklisted)"
  exit 1
fi

# Pick random image
random_image="${images[RANDOM % ${#images[@]}]}"

# ✅ Detect platform and set wallpaper
uname_out="$(uname)"
case "$uname_out" in
  Darwin)
    osascript -e "tell application \"Finder\" to set desktop picture to POSIX file \"$random_image\""
    ;;
  Linux)
    feh --bg-scale "$random_image"
    ;;
  *)
    echo "❌ Unsupported OS: $uname_out"
    exit 1
    ;;
esac

# Save to current wallpaper tracker
mkdir -p "$CONFIG_DIR"
echo "$random_image" > "$CURRENT_FILE"

echo "✅ Wallpaper set to: $random_image"
