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

# Set the wallpaper (macOS only)
osascript -e "tell application \"System Events\" to tell every desktop to set picture to \"$random_image\" as POSIX file"

# Save to current wallpaper tracker
mkdir -p "$CONFIG_DIR"
echo "$random_image" > "$CURRENT_FILE"

echo "✅ Wallpaper set to: $random_image"
