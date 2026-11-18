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

# Hover, the popup auto-close timer (2s after the mouse leaves bar + popup,
# reset on re-entry) and clicks are handled by barsd; scripts only see clicks
# and their own events. handle_hover stays as a no-op guard for old callers.
handle_hover() { case "$SENDER" in mouse.entered|mouse.exited|mouse.exited.global) return 0 ;; esac; return 1; }

##### Popups: one open at a time, on the clicked monitor #####
POPUP_STATE="$STATE_DIR/popup_open"     # name of the open popup's owner item
BAR_DISPLAY="$HOME/.config/sketchybar/helpers/bin/bar_display"
BAR_NOTIFY="$HOME/.config/sketchybar/helpers/bin/bar_notify"

popup_current() { cat "$POPUP_STATE" 2>/dev/null; }

popup_close() { # [item]  (default: whichever is open)
  local item="${1:-$(popup_current)}"
  [ -n "$item" ] || return 0
  sketchybar --set "$item" popup.drawing=off 2>/dev/null
  [ "$(popup_current)" = "$item" ] && rm -f "$POPUP_STATE"
}

popup_cancel() { "$BAR_NOTIFY" cancel 2>/dev/null; }

# SketchyBar draws popups only on the display with the active menu bar, so
# make the display under the mouse active first: focus it through Rift when
# its workspace has windows, otherwise click its (empty) desktop.
popup_activate_display() {
  [ -x "$BAR_DISPLAY" ] || return 0
  local mx my uuid fx fy fw fh active n
  read -r mx my <<< "$("$BAR_DISPLAY" where)"
  IFS=$'\x1f' read -r uuid fx fy fw fh <<< "$(sketchybar --query displays | jq -r --argjson x "$mx" --argjson y "$my" '
    map(select($x >= .frame.x and $x < .frame.x + .frame.w and $y >= .frame.y and $y < .frame.y + .frame.h))
    | first // empty | [.UUID, (.frame.x|floor), (.frame.y|floor), (.frame.w|floor), (.frame.h|floor)]
    | map(tostring) | join("\u001f")')"
  [ -n "$uuid" ] || return 0
  active="$("$BAR_DISPLAY" active)"
  [ "$uuid" = "$active" ] && return 0
  n="$(rift-cli query workspaces --display "$uuid" 2>/dev/null | jq '[.[] | select(.is_active) | .window_count] | add // 0')"
  if [ "${n:-0}" -gt 0 ]; then
    "$BAR_DISPLAY" hold 600 & rift-cli execute display focus --uuid "$uuid" >/dev/null 2>&1
  else
    "$BAR_DISPLAY" click $((fx + fw / 2)) $((fy + fh / 2))
  fi
  for _ in 1 2 3 4 5 6 7 8; do [ "$("$BAR_DISPLAY" active)" = "$uuid" ] && break; sleep 0.05; done
}

popup_open() { # item
  local item="$1" prev; prev="$(popup_current)"
  [ -n "$prev" ] && [ "$prev" != "$item" ] && sketchybar --set "$prev" popup.drawing=off
  popup_cancel
  case "$SENDER" in mouse.clicked) popup_activate_display ;; esac
  mkdir -p "$STATE_DIR"; echo "$item" > "$POPUP_STATE"
  sketchybar --set "$item" popup.drawing=on
}

popup_toggle() { # item
  if [ "$(popup_current)" = "$1" ] && [ "$(sketchybar --query "$1" | jq -r .popup.drawing)" = on ]; then
    popup_close "$1"
  else
    popup_open "$1"
  fi
}

# Fill popup rows <parent>.row.1..N from stdin, one row per line:
#   icon<TAB>label<TAB>click<TAB>style
# style: h header | s section | r row (default) | m muted | a action |
#        g/y/x green/yellow/red status. A click starting with "+" keeps the
# popup open (e.g. to watch a toggle take effect); otherwise it closes.
# Modes: toggle | on | keep (refresh rows only, popup state untouched). Unused rows are hidden, then the popup
# is shown (mode: toggle | on | keep = refresh contents only).
row_style() { # sets STYLE=(...) for a style letter
  local f="Hack Nerd Font" ic=$WHITE lc=$WHITE font=Regular size=13.0
  case "$1" in
    h) ic=$ACCENT; font=Bold ;;
    s) ic=$GREY; lc=$GREY; font=Bold; size=11.0 ;;
    m) ic=$GREY; lc=$GREY; size=12.0 ;;
    a) ic=$ACCENT; lc=$ACCENT ;;
    g) ic=$GREEN ;;
    y) ic=$YELLOW ;;
    x) ic=$RED ;;
  esac
  STYLE=(icon.color="$ic" label.color="$lc" label.font="$f:$font:$size")
}

fill_popup() {
  local parent="$1" max="$2" mode="${3:-toggle}" i=0 args=() line rest rest2 icon label click cs style tab=$'\t'
  while IFS= read -r line; do
    # split by hand: `read` with IFS=tab would collapse empty fields
    icon="${line%%"$tab"*}"; rest="${line#*"$tab"}"; [ "$rest" = "$line" ] && rest=""
    label="${rest%%"$tab"*}"; rest2="${rest#*"$tab"}"; [ "$rest2" = "$rest" ] && rest2=""
    click="${rest2%%"$tab"*}"; style="${rest2#*"$tab"}"; [ "$style" = "$rest2" ] && style=r
    i=$((i + 1)); [ $i -gt "$max" ] && break
    row_style "$style"
    if [ "${click:0:1}" = "+" ]; then cs="${click:1}"
    else cs="${click:+$click; }$HOME/.config/sketchybar/plugins/popup.sh close $parent"; fi
    args+=(--set "$parent.row.$i" drawing=on icon="$icon" label="$label" "${STYLE[@]}"
           click_script="$cs")
  done
  for ((j = i + 1; j <= max; j++)); do args+=(--set "$parent.row.$j" drawing=off); done
  sketchybar "${args[@]}"
  case "$mode" in
    on) popup_open "$parent" ;;
    toggle) popup_toggle "$parent" ;;
  esac
}

# meter <percent> [width]: text progress bar, e.g. "▰▰▰▱▱▱▱▱▱▱"
meter() {
  local p=${1%%.*} w=${2:-10} n i out=""
  [ -z "$p" ] && p=0; [ "$p" -lt 0 ] && p=0; [ "$p" -gt 100 ] && p=100
  n=$(( (p * w + 50) / 100 ))
  for ((i = 0; i < w; i++)); do [ $i -lt $n ] && out+="▰" || out+="▱"; done
  printf '%s' "$out"
}

# human_age <epoch>: "<1m" / "5m" / "3h" / "2d"
human_age() {
  local s=$(( $(date +%s) - $1 ))
  if [ $s -lt 60 ]; then echo "<1m"; elif [ $s -lt 3600 ]; then echo "$((s / 60))m"
  elif [ $s -lt 86400 ]; then echo "$((s / 3600))h"; else echo "$((s / 86400))d"; fi
}

# app_name <bundle-id>: display name (cached; mdfind never launches the app)
app_name() {
  local b="$1" cache="$STATE_DIR/appnames.tsv" n apppath
  n="$(awk -F'\t' -v b="$b" '$1 == b {print $2; exit}' "$cache" 2>/dev/null)"
  if [ -z "$n" ]; then
    apppath="$(mdfind "kMDItemCFBundleIdentifier == '$b'c" 2>/dev/null | grep -m1 '\.app$')"
    n="$(basename "${apppath:-$b}" .app)"
    mkdir -p "$STATE_DIR"; printf '%s\t%s\n' "$b" "$n" >> "$cache"
  fi
  printf '%s' "$n"
}
