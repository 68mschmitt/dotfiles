#!/bin/bash
# Shared helpers for plugins: palette, power profile, animation, hover, popups.
export PATH=/opt/homebrew/bin:/usr/sbin:/sbin:$PATH
source "$HOME/.config/sketchybar/colors.sh"
STATE_DIR="$HOME/.cache/sketchybar"

# Power profile written by providers.sh: ac | battery | lowpower
power_profile() { cat "$STATE_DIR/power" 2>/dev/null || echo ac; }

# "--animate tanh N" sized to the power profile (no animation in Low Power Mode).
anim() {
  case "$(power_profile)" in
    ac) echo "--animate tanh 15" ;;
    battery) echo "--animate tanh 8" ;;
    *) echo "" ;;
  esac
}

# Hover feedback: tint icon + label while the mouse is over the item.
# Returns 0 if the event was a hover event (caller should then exit).
handle_hover() {
  case "$SENDER" in
    mouse.entered) sketchybar $(anim) --set "$NAME" icon.highlight=on label.highlight=on; return 0 ;;
    mouse.exited)  sketchybar $(anim) --set "$NAME" icon.highlight=off label.highlight=off; return 0 ;;
    mouse.exited.global) sketchybar --set "$NAME" popup.drawing=off; return 0 ;;
  esac
  return 1
}

# Fill popup rows <parent>.row.1..N from stdin ("icon<TAB>label<TAB>click" per
# line), hide the unused rows, then show the popup (mode: toggle | on).
fill_popup() {
  local parent="$1" max="$2" mode="${3:-toggle}" i=0 args=() line rest icon label click tab=$'\t'
  while IFS= read -r line; do
    # split by hand: `read` with IFS=tab would collapse empty fields
    icon="${line%%"$tab"*}"; rest="${line#*"$tab"}"
    label="${rest%%"$tab"*}"; click="${rest#*"$tab"}"
    [ "$click" = "$rest" ] && click=""
    i=$((i + 1)); [ $i -gt "$max" ] && break
    args+=(--set "$parent.row.$i" drawing=on icon="$icon" label="$label"
           click_script="${click:+$click; }sketchybar --set $parent popup.drawing=off")
  done
  for ((j = i + 1; j <= max; j++)); do args+=(--set "$parent.row.$j" drawing=off); done
  sketchybar "${args[@]}" --set "$parent" popup.drawing="$mode"
}
