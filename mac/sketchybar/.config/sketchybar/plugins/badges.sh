#!/usr/bin/env bash
# Notification bubbles next to the clock: one red pill per app with a Dock badge
# (app icon + count). Fills the pre-created badge.1..badge.$MAX items.
export PATH=/opt/homebrew/bin:$PATH
source "$HOME/.config/sketchybar/plugins/icon_map.sh"
MAX=6
SRC="$HOME/.config/sketchybar/helpers/dock_badges.swift"
BIN="$HOME/.local/bin/sketchybar-dock-badges"

# (Re)build the helper when missing or older than its source.
if [ ! -x "$BIN" ] || [ "$SRC" -nt "$BIN" ]; then
  mkdir -p "$(dirname "$BIN")"
  swiftc -O "$SRC" -o "$BIN" 2>/dev/null || exit 0
fi

args=() i=0
while IFS=$'\t' read -r app label; do
  [ -z "$app" ] && continue
  i=$((i + 1)); [ $i -gt $MAX ] && break
  # Exact counts up to 9999 (so reading mail visibly lowers them), then "12k".
  if [[ "$label" =~ ^[0-9]+$ ]] && [ "$label" -gt 9999 ]; then label="$((label / 1000))k"; fi
  __icon_map "$app"
  args+=(--set "badge.$i" drawing=on icon="$icon_result" label="$label"
         click_script="open -a \"$app\"")
done < <("$BIN" 2>/dev/null)

for ((j = i + 1; j <= MAX; j++)); do args+=(--set "badge.$j" drawing=off); done
sketchybar "${args[@]}"
