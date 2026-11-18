#!/usr/bin/env bash
# Sync sketchybar with Rift's global virtual workspaces + the rift_state item.
# Called by Rift on workspace/window/focus/layout/binding-mode events (see
# ~/.config/rift/config.toml run_on_start) and once when sketchybar starts.
#   each label is shown only on the monitor that owns the workspace
#   workspaces for monitors that aren't connected are hidden (unless they hold windows)
#   focused workspace       -> accent background
#   visible on its monitor  -> dim background
#   has windows / empty     -> white / grey number (empty also gets a fainter background)
#   app icons (sketchybar-app-font) for each distinct app on the workspace
source "$HOME/.config/sketchybar/plugins/lib.sh"
source "$HOME/.config/sketchybar/plugins/icon_map.sh"

ws=$(rift-cli query workspaces 2>/dev/null) || exit 0
displays=$(sketchybar --query displays 2>/dev/null)
# During sketchybar startup the query can come back empty; retry briefly.
for _ in 1 2 3 4 5; do
  jq -e 'type == "array"' >/dev/null 2>&1 <<< "$displays" && break
  sleep 0.5; displays=$(sketchybar --query displays 2>/dev/null)
done
jq -e 'type == "array"' >/dev/null 2>&1 <<< "$displays" || exit 0
jq -e 'type == "array"' >/dev/null 2>&1 <<< "$ws" || exit 0
mode=$(rift-cli query binding-mode 2>/dev/null | tr -d '"')

args=() seen=" "
while IFS=$'\t' read -r n focused active count disp used apps; do
  seen+="$n "
  if [ "$count" -gt 0 ]; then col=$WHITE; fb=$WS_FOCUSED_BG; ab=$WS_VISIBLE_BG
  else col=$GREY; fb=$WS_FOCUSED_EMPTY_BG; ab=$WS_VISIBLE_EMPTY_BG; fi
  if [ "$focused" = true ]; then
    bg=(background.drawing=on background.color=$fb); [ "$count" -gt 0 ] && col=$DARK
  elif [ "$active" = true ]; then bg=(background.drawing=on background.color=$ab)
  else bg=(background.drawing=on background.color=0x00ffffff); fi
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

# Workspaces Rift didn't report (their display is on an unmanaged macOS Space)
# are hidden instead of keeping a stale display assignment.
for n in 1 2 3 4 5 6 7 8 9; do
  [[ "$seen" == *" $n "* ]] || args+=(--set "rift.ws.$n" drawing=off)
done

# Rift state: layout of the focused workspace, floating focused window, binding mode.
IFS=$'\t' read -r layout floating <<< "$(jq -r '
  (map(select(.is_focused)) | first) as $f
  | (if $f == null then (map(select(.is_active)) | first) else $f end) as $f
  | [($f.layout_mode // "bsp"), ([$f.windows[]? | select(.is_focused) | .is_floating] | first // false)] | @tsv' <<< "$ws")"
case "$layout" in
  bsp) sicon=󰕰 ;; traditional) sicon=󰕴 ;; scrolling) sicon=󰯌 ;; master*|stack*) sicon=󰯋 ;; *) sicon=󰕮 ;;
esac
slabel="$layout"; scol=$WHITE
[ "$floating" = true ] && { sicon=󰖲; slabel="float"; }
[ -n "$mode" ] && [ "$mode" != default ] && { slabel="$mode"; scol=$ORANGE; }
args+=(--set rift_state icon="$sicon" icon.color=$scol label="$slabel" label.color=$scol)

[ ${#args[@]} -gt 0 ] && sketchybar $(anim) "${args[@]}"
