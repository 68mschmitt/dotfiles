#!/bin/bash
# rift_state item popup: focused workspace overview — its windows (click =
# focus), a layout switcher (current one ticked) and common Rift actions.
source "$HOME/.config/sketchybar/plugins/lib.sh"
source "$HOME/.config/sketchybar/plugins/icon_map.sh"
handle_hover && exit 0
case "$SENDER" in mouse.clicked) mode=toggle ;; refresh) mode=keep ;; *) exit 0 ;; esac
ws="$(rift-cli query workspaces 2>/dev/null)"
IFS=$'\x1f' read -r idx layout count <<< "$(jq -r '
  (map(select(.is_focused)) | first) // (map(select(.is_active)) | first)
  | [(.index + 1), .layout_mode, .window_count] | map(tostring) | join("\u001f")' <<< "$ws")"
refresh="sleep 0.3; NAME=$NAME SENDER=refresh $0"
{
  printf '󰕰\tWorkspace %s · %s · %s windows\topen -t %s/.config/rift/config.toml\th\n' "$idx" "$layout" "$count" "$HOME"
  printf '\tWINDOWS\t\ts\n'
  jq -r '((map(select(.is_focused)) | first) // (map(select(.is_active)) | first)) | .windows[]
         | [.app_name, (.title // "" | .[0:48]), (.id | tojson), .is_focused, .is_floating] | map(tostring) | join("\u001f")' <<< "$ws" |
    while IFS=$'\x1f' read -r app title id focused floating; do
      style=r; [ "$focused" = true ] && style=g
      extra=""; [ "$floating" = true ] && extra=" (float)"
      printf "󰖯\t%s — %s%s\trift-cli execute window focus --window-id '%s'\t%s\n" "$app" "${title:-untitled}" "$extra" "$id" "$style"
    done
  [ "${count:-0}" -eq 0 ] && printf '󰄬\tNo windows on this workspace\t\tm\n'
  printf '\tLAYOUT\t\ts\n'
  for m in bsp traditional scrolling master_stack; do
    if [ "$m" = "$layout" ]; then printf '󰄬\t%s\t\tg\n' "$m"
    else printf '󰕮\t%s\t+rift-cli execute workspace set-layout %s; %s\tr\n' "$m" "$m" "$refresh"; fi
  done
  printf '\tACTIONS\t\ts\n'
  printf '󰕰\tBalance windows\trift-cli execute layout balance\ta\n'
  printf '󰯌\tFlip split orientation\trift-cli execute layout toggle-orientation\ta\n'
  printf '󰖲\tToggle float (focused window)\trift-cli execute window toggle-float\ta\n'
  printf '󰔡\tToggle tiling for this space\trift-cli execute space toggle-activated\ta\n'
  printf '󰑓\tRestart Rift\trift service restart\tm\n'
} | fill_popup "$NAME" 20 "$mode"
