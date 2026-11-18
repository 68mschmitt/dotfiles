#!/usr/bin/env bash
# Notification bubbles next to the clock: one red pill per app with a Dock badge
# (app icon + count), on every display. Fills the pre-created badge.1..badge.$MAX
# items. Hovering a bubble shows a preview of that app's notifications from
# ~/.cache/sketchybar/notifications.tsv (written by sketchybar-notifications).
source "$HOME/.config/sketchybar/plugins/lib.sh"
source "$HOME/.config/sketchybar/plugins/icon_map.sh"
MAX=6
BIN="$HOME/.config/sketchybar/helpers/bin/dock_badges"   # built by helpers/makefile
NOTIFS="$STATE_DIR/notifications.tsv"

preview() { # rows for badge $NAME: header + latest notifications of its app
  local app bundle label status n=0
  IFS=$'\t' read -r app label bundle < "$STATE_DIR/$NAME" 2>/dev/null || return
  bundle="$(tr 'A-Z' 'a-z' <<< "$bundle")"
  status="$(cat "$STATE_DIR/notifications_status" 2>/dev/null)"
  printf '󰂚\t%s\t%s\n' "$app · $label" "open -a \"$app\""
  if [ "$status" != ok ]; then
    printf '\tGrant Full Disk Access to sketchybar-notifications for previews\t%s\n' \
      "open 'x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles'"
    return
  fi
  local rows
  rows="$(awk -F'\t' -v b="$bundle" -v now="$(date +%s)" -v app="$app" '
    $1 == b {
      s = now - $2
      t = (s < 60) ? "now" : (s < 3600) ? int(s / 60) "m" : (s < 86400) ? int(s / 3600) "h" : int(s / 86400) "d"
      text = $3; if ($4 != "") text = text " · " $4; if ($5 != "") text = text " — " $5
      if (length(text) > 90) text = substr(text, 1, 89) "…"
      printf "\t%-3s %s\topen -a \"%s\"\n", t, text, app
      if (++n >= 5) exit
    }' "$NOTIFS" 2>/dev/null)"
  [ -n "$rows" ] && { printf '%s\n' "$rows"; n=1; }
  [ $n -eq 0 ] && printf '\tNo notifications in Notification Center\t\n'
}

if [[ "$NAME" == badge.* ]]; then
  case "$SENDER" in
    mouse.entered)
      sketchybar $(anim) --set "$NAME" background.color=$RED
      preview | fill_popup "$NAME" 6 on ;;
    mouse.exited) sketchybar $(anim) --set "$NAME" background.color=$BADGE_RED ;;
    mouse.exited.global) sketchybar --set "$NAME" popup.drawing=off ;;
    mouse.clicked)
      IFS=$'\t' read -r app _ < "$STATE_DIR/$NAME" 2>/dev/null
      sketchybar --set "$NAME" popup.drawing=off; [ -n "$app" ] && open -a "$app" ;;
  esac
  exit 0
fi

[ -x "$BIN" ] || exit 0
mkdir -p "$STATE_DIR"
args=() i=0
while IFS=$'\t' read -r app label bundle; do
  [ -z "$app" ] && continue
  i=$((i + 1)); [ $i -gt $MAX ] && break
  # Exact counts up to 9999 (so reading mail visibly lowers them), then "12k".
  if [[ "$label" =~ ^[0-9]+$ ]] && [ "$label" -gt 9999 ]; then label="$((label / 1000))k"; fi
  printf '%s\t%s\t%s\n' "$app" "$label" "$bundle" > "$STATE_DIR/badge.$i"
  __icon_map "$app"
  args+=(--set "badge.$i" drawing=on icon="$icon_result" label="$label")
done < <("$BIN" 2>/dev/null)

for ((j = i + 1; j <= MAX; j++)); do args+=(--set "badge.$j" drawing=off popup.drawing=off); done
# Only redraw when something changed.
sig="${args[*]}"
[ "$SENDER" != forced ] && [ "$sig" = "$(cat "$STATE_DIR/badges" 2>/dev/null)" ] && exit 0
printf %s "$sig" > "$STATE_DIR/badges"
sketchybar $(anim) "${args[@]}"
