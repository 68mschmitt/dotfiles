#!/bin/bash
# Directional resize: move the focused window's edge in the pushed direction.
#   resize.sh left|right|up|down
# Pushing toward a neighbouring window grows the focused window; pushing away
# from one (toward the screen edge) shrinks it. Rift's own resize_window_grow /
# shrink are direction-less, so we pick one based on where the neighbours are.
export PATH=/opt/homebrew/bin:$PATH
dir="$1"
case "$dir" in
  left|right) axis=horizontal ;;
  up|down)    axis=vertical ;;
  *) echo "usage: $0 left|right|up|down" >&2; exit 1 ;;
esac

action=$(jq -rn --arg dir "$dir" \
  --argjson w "$(rift-cli query windows)" --argjson d "$(rift-cli query displays)" '
  def box: {x: .frame.origin.x, y: .frame.origin.y,
            w: .frame.size.width, h: .frame.size.height};
  def mid: {x: (.x + .w / 2), y: (.y + .h / 2)};
  def inside($p): $p.x >= .x and $p.x < .x + .w and $p.y >= .y and $p.y < .y + .h;
  ($w | map(select(.is_focused)) | first) as $fw
  | if $fw == null then "none" else
    ($fw | box) as $f
    | ($d | map(box) | map(select(inside($f | mid))) | first) as $screen
    | [$w[] | select((.is_focused | not) and (.is_floating | not)) | box | . as $b
       | select($screen == null or ($screen | inside($b | mid)))] as $o
    | (if   $dir == "right" then any($o[]; .x >= $f.x + $f.w - 1)
       elif $dir == "left"  then any($o[]; .x + .w <= $f.x + 1)
       elif $dir == "down"  then any($o[]; .y >= $f.y + $f.h - 1)
       else                      any($o[]; .y + .h <= $f.y + 1) end) as $toward
    | if $fw.is_floating then (if $dir == "right" or $dir == "down" then "grow" else "shrink" end)
      elif $toward then "grow" else "shrink" end
    end')

[ "$action" = none ] && exit 0
[ -n "$DRY_RUN" ] && { echo "$action $axis"; exit 0; }
rift-cli execute window "resize-$action" --orientation "$axis"
