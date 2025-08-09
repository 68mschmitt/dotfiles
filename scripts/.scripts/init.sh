#!/bin/bash

echo "🔍 Making .sh files executable under: $TARGET_DIR"

# Find and chmod all *.sh files
find "./" -type f -name "*.sh" -exec sh -c 'echo "Making executable: $1"; chmod +x "$1"' _ {} \;

echo "✅ Done: All .sh files under '$TARGET_DIR' are now executable."
