#!/bin/bash
# Click on a notification bubble (badge.N, filled by barsd): preview that app's
# UNREAD notifications, i.e. the ones delivered since you last had the app in
# front (barsd records that in ~/.cache/sketchybar/seen.tsv). Never opens the
# app itself; the header row does that.
source "$HOME/.config/sketchybar/plugins/lib.sh"
[ "$SENDER" = mouse.clicked ] || exit 0
NOTIFS="$STATE_DIR/notifications.tsv"
IFS=$'\t' read -r app label bundle < "$STATE_DIR/$NAME" 2>/dev/null || exit 0
bundle="$(tr 'A-Z' 'a-z' <<< "$bundle")"
since="$(awk -F'\t' -v a="$app" '$1 == a {print $2}' "$STATE_DIR/seen.tsv" 2>/dev/null)"
status="$(cat "$STATE_DIR/notifications_status" 2>/dev/null)"
{
  printf '󰂚\t%s · %s unread\topen -a "%s"\th\n' "$app" "$label" "$app"
  if [ "$status" != ok ]; then
    printf '\tGrant Full Disk Access to sketchybar-notifications for previews\t%s\ty\n' \
      "open 'x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles'"
  else
    rows="$(awk -F'\t' -v b="$bundle" -v since="${since:-0}" -v now="$(date +%s)" -v app="$app" '
      $1 == b && $2 > since && $2 <= now + 5 {
        s = now - $2
        t = (s < 60) ? "now" : (s < 3600) ? int(s / 60) "m" : (s < 86400) ? int(s / 3600) "h" : int(s / 86400) "d"
        text = $3; if ($4 != "") text = text " · " $4; if ($5 != "") text = text " — " $5
        if (length(text) > 70) text = substr(text, 1, 69) "…"
        printf "󰍡\t%-3s %s\topen -a \"%s\"\tr\n", t, text, app
        if (++n >= 6) exit
      }' "$NOTIFS" 2>/dev/null)"
    if [ -n "$rows" ]; then printf '%s\n' "$rows"
    else printf '󰄬\tNo unread notifications since you last opened %s\t\tm\n' "$app"; fi
  fi
  printf '\tOpen %s\topen -a "%s"\ta\n' "$app" "$app"
} | fill_popup "$NAME" 8 toggle
