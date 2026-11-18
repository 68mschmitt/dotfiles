#!/bin/bash
# New-notification toast: a pill in the bar plus a small card popup under it
# (app, time, title, body, open action) for a few seconds. Sources:
#   - notifications_update (sketchybar-notifications mirrors Notification Center)
#   - `toast.sh post <app> <title> <body> <click> [icon-app]` (e.g. gh.sh)
# The card only opens when no other popup is open (otherwise just the pill).
# barsd hides both after SHOW seconds, pauses while hovered, 2s after leaving.
# Click on the pill = recent notifications across apps.
source "$HOME/.config/sketchybar/plugins/lib.sh"
source "$HOME/.config/sketchybar/plugins/icon_map.sh"
NOTIFS="$STATE_DIR/notifications.tsv"
LAST="$STATE_DIR/toast_last"
SHOW=6

wrap() { # wrap text into lines of ~52 chars (max 2), "…" if longer
  awk -v w=52 '{ s = $0; n = 0
    while (length(s) > 0 && n < 2) {
      if (length(s) <= w) { print s; s = ""; break }
      cut = w; while (cut > 20 && substr(s, cut, 1) != " ") cut--
      line = substr(s, 1, cut); s = substr(s, cut + 1); sub(/^ +/, "", s); n++
      if (n == 2 && length(s) > 0) line = substr(line, 1, w - 1) "…"
      print line } }'
}

post() { # app title body click [icon-app]
  local app="$1" title="$2" body="$3" click="$4" iapp="${5:-$1}" short
  __icon_map "$iapp"
  short="$title"; [ ${#short} -gt 40 ] && short="${short:0:39}…"
  sketchybar $(anim) --set toast drawing=on icon="$icon_result" label="$app · $short"
  local open; open="$(popup_current)"
  if [ -z "$open" ] || [ "$open" = toast ]; then
    { printf '󰂚\t%s · now\t%s\th\n' "$app" "$click"
      printf '\t%s\t%s\tr\n' "$title" "$click"
      [ -n "$body" ] && printf '%s\n' "$body" | wrap | while IFS= read -r l; do printf '\t%s\t%s\tm\n' "$l" "$click"; done
      [ -n "$click" ] && printf '󰏌\tOpen\t%s\ta\n' "$click"
    } | SENDER=post fill_popup toast 10 keep
    mkdir -p "$STATE_DIR"; echo toast > "$POPUP_STATE"
    sketchybar --set toast popup.drawing=on
  fi
  "$BAR_NOTIFY" arm ITEM=toast DELAY=$SHOW
}

# delivered notifications only (calendar alerts are stored with future dates)
delivered() { awk -F'\t' -v now="$(date +%s)" '$2 <= now + 5' "$NOTIFS" 2>/dev/null; }

[ "$1" = post ] && SENDER=post
case "$SENDER" in
  post) ;;
  mouse.clicked)
    {
      printf '󰂚\tRecent notifications\topen "x-apple.systempreferences:com.apple.Notifications-Settings.extension"\th\n'
      delivered | head -8 | awk -F'\t' -v now="$(date +%s)" '{
          s = now - $2; t = (s < 60) ? "now" : (s < 3600) ? int(s / 60) "m" : (s < 86400) ? int(s / 3600) "h" : int(s / 86400) "d"
          text = $3; if ($5 != "") text = text " — " $5
          if (length(text) > 48) text = substr(text, 1, 47) "…"
          print $1 "\t" t "\t" text }' |
        while IFS=$'\t' read -r b t text; do
          app="$(app_name "$b")"
          printf '󰍡\t%s · %s  %s\topen -a "%s"\tr\n' "$app" "$t" "$text" "$app"
        done
      printf '󰅖\tDismiss\tsketchybar --set toast drawing=off\ta\n'
    } | fill_popup toast 10 toggle
    exit 0 ;;
  notifications_update|forced) ;;
  *) exit 0 ;;
esac

if [ "$SENDER" = post ] || [ "$1" = post ]; then
  shift; post "$@"; exit 0
fi

newest="$(delivered | head -1)"
[ -n "$newest" ] || exit 0
IFS=$'\t' read -r b when _ <<< "$newest"
key="$(printf '%s' "$newest" | cksum | cut -d' ' -f1)"
last_when="$(cut -d' ' -f1 "$LAST" 2>/dev/null)"; last_key="$(cut -d' ' -f2 "$LAST" 2>/dev/null)"
echo "$when $key" > "$LAST"
# first run (no state) or nothing new: just remember, don't toast old stuff
[ "$SENDER" = forced ] || [ -z "$last_when" ] || [ "$key" = "$last_key" ] && exit 0
[ "$when" -lt "${last_when:-0}" ] && exit 0
[ $(( $(date +%s) - when )) -gt 120 ] && exit 0

IFS=$'\x1f' read -r title subtitle body <<< "$(awk -F'\t' '{print $3 "\x1f" $4 "\x1f" $5}' <<< "$newest")"
app="$(app_name "$b")"
count="$(delivered | awk -F'\t' -v t="$last_when" '$2 > t' | wc -l | tr -d ' ')"
[ "${count:-1}" -gt 1 ] && app="$app (+$((count - 1)))"
post "$app" "${title}${subtitle:+ · $subtitle}" "$body" "open -a \"$(app_name "$b")\"" "$(app_name "$b")"
