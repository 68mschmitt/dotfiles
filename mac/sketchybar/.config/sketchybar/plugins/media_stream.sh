#!/bin/bash
# Long-running: follows `media-control stream` and pushes now-playing info into
# the "media" item and its mini-player popup (artwork, title, controls).
# Started (and restarted on reload) by sketchybarrc.
source "$HOME/.config/sketchybar/plugins/lib.sh"
source "$HOME/.config/sketchybar/plugins/icon_map.sh"
mkdir -p "$STATE_DIR"
SEP=$'\x1f'   # tabs are IFS whitespace, so empty tab fields would collapse
media-control stream --no-diff 2>/dev/null | while IFS= read -r line; do
  info="$(jq -r '.payload | [(.title // ""), (.artist // ""), (.album // ""), (.playing // false),
                             (.bundleIdentifier // ""), (.elapsedTime // 0), (.duration // 0),
                             (.timestamp // "")] | map(tostring) | join("\u001f")' <<< "$line" 2>/dev/null)" || continue
  IFS="$SEP" read -r title artist album playing bundle elapsed duration stamp <<< "$info"
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
  # Artwork (only when the track changes): decode, then scale to ~44pt tall.
  key="$title|$artist|$album"
  art=()
  if [ "$key" != "$last_key" ]; then
    last_key="$key"
    rm -f "$STATE_DIR"/cover.*
    if jq -e '.payload.artworkData' <<< "$line" >/dev/null 2>&1; then
      jq -r '.payload.artworkData' <<< "$line" | base64 -d > "$STATE_DIR/cover.raw" 2>/dev/null
      sips -s format png -Z 88 "$STATE_DIR/cover.raw" --out "$STATE_DIR/cover.png" >/dev/null 2>&1
      rm -f "$STATE_DIR/cover.raw"
    fi
    if [ -f "$STATE_DIR/cover.png" ]; then
      art=(--set media.art drawing=on background.image="$STATE_DIR/cover.png" background.image.scale=0.5)
    else
      art=(--set media.art drawing=off)
    fi
  fi
  __icon_map "${app:-Music}"
  if [ "$playing" = true ]; then icon=󰏤; col=$WHITE; else icon=󰐊; col=$GREY; fi
  sketchybar $(anim) --set media drawing=on icon="$icon" icon.color="$col" \
               label="$title${artist:+ — $artist}" label.color="$col" \
             "${art[@]}" \
             --set media.app icon="$icon_result" \
             --set media.info label="$title${artist:+ — $artist}" \
             --set media.play icon="$icon"
done
