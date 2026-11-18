#!/bin/bash
# Long-running: follows `media-control stream` and pushes now-playing info into
# the "media" item. Started (and restarted on reload) by sketchybarrc.
source "$HOME/.config/sketchybar/plugins/lib.sh"
source "$HOME/.config/sketchybar/plugins/icon_map.sh"
mkdir -p "$STATE_DIR"
media-control stream --no-diff 2>/dev/null | while IFS= read -r line; do
  info="$(jq -r '.payload | [(.title // ""), (.artist // ""), (.album // ""),
                             (.playing // false), (.bundleIdentifier // "")] | map(tostring) | join("\u001f")' <<< "$line" 2>/dev/null)" || continue
  # \x1f separator: tabs are IFS whitespace, so empty tab fields would collapse.
  IFS=$'\x1f' read -r title artist album playing bundle <<< "$info"
  printf '%s\n' "$info" > "$STATE_DIR/media"
  if [ -z "$title" ]; then
    sketchybar $(anim) --set media drawing=off popup.drawing=off
    continue
  fi
  # App display name from its bundle id (cached; mdfind never launches the app).
  if [ "$bundle" != "$last_bundle" ]; then
    last_bundle="$bundle"
    path="$(mdfind "kMDItemCFBundleIdentifier == '$bundle'" 2>/dev/null | head -1)"
    app="$(basename "${path:-$bundle}" .app)"
  fi
  __icon_map "${app:-Music}"
  if [ "$playing" = true ]; then icon=󰏤; col=$WHITE; else icon=󰐊; col=$GREY; fi
  sketchybar $(anim) --set media drawing=on icon="$icon" icon.color="$col" \
               label="$title${artist:+ — $artist}" label.color="$col" \
             --set media.app icon="$icon_result" label="${app:-$bundle}" \
             --set media.title label="$title" \
             --set media.artist label="${artist:-–}${album:+ · $album}" \
             --set media.play icon="$icon"
done
