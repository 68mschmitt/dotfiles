#!/usr/bin/env bash
# Sync sketchybar workspace labels with Rift's global virtual workspaces.
# Called by Rift on workspace/window/focus events (see ~/.config/rift/config.toml run_on_start)
# and once when sketchybar starts.
#   each label is shown only on the monitor that owns the workspace
#   workspaces for monitors that aren't connected are hidden (unless they hold windows)
#   focused workspace       -> bright background
#   visible on its monitor  -> dim background
#   has windows / empty     -> white / grey number (empty also gets a fainter background)
#   app icons (sketchybar-app-font) for each distinct app on the workspace
export PATH=/opt/homebrew/bin:$PATH
source "$HOME/.config/sketchybar/plugins/icon_map.sh"

ws=$(rift-cli query workspaces 2>/dev/null) || exit 0
displays=$(sketchybar --query displays 2>/dev/null) || exit 0

args=()
while IFS=$'\t' read -r n focused active count disp used apps; do
  # Empty workspaces are dimmed everywhere: grey number and, when shown/focused,
  # a much fainter background than a workspace that holds windows.
  if [ "$count" -gt 0 ]; then col=0xffffffff; fb=0xa0ffffff; ab=0x40ffffff
  else col=0x50ffffff; fb=0x38ffffff; ab=0x18ffffff; fi
  if [ "$focused" = true ]; then bg=(background.drawing=on background.color=$fb)
  elif [ "$active" = true ]; then bg=(background.drawing=on background.color=$ab)
  else bg=(background.drawing=off); fi
  if [ "$used" = true ] || [ "$count" -gt 0 ]; then draw=on; else draw=off; fi

  icons=""
  if [ -n "$apps" ]; then
    IFS='|' read -ra names <<< "$apps"
    for app in "${names[@]}"; do
      __icon_map "$app"
      icons+="$icon_result "
    done
  fi
  if [ -n "$icons" ]; then label=(label="${icons% }" label.drawing=on label.color=$col)
  else label=(label="" label.drawing=off); fi

  args+=(--set "rift.ws.$n" drawing=$draw display=$disp "${bg[@]}" icon.color=$col "${label[@]}")
done < <(jq -rn --argjson w "$ws" --argjson d "$displays" '
  ($d | map({key: .UUID, value: ."arrangement-id"}) | from_entries) as $ids
  | ($d | length * 3) as $used
  | $w[]
  | (reduce (.windows[]?.app_name // empty) as $a ([]; if index([$a]) then . else . + [$a] end)) as $apps
  | [(.index + 1), .is_focused, .is_active, .window_count, ($ids[.display_uuid] // 1),
     (.index < $used), ($apps | join("|"))] | @tsv')

[ ${#args[@]} -gt 0 ] && sketchybar "${args[@]}"
