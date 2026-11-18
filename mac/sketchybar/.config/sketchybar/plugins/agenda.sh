#!/bin/bash
# Agenda popup on the date item: remaining events today + tomorrow.
source "$HOME/.config/sketchybar/plugins/lib.sh"
handle_hover && exit 0
[ "$SENDER" = mouse.clicked ] || exit 0
AGENDA="$STATE_DIR/agenda.tsv"
status="$(cat "$STATE_DIR/calendar_status" 2>/dev/null)"
now=$(date +%s); today_end=$(date -v23H -v59M -v59S +%s)
{
  printf '󰃭\t%s\topen -a "Microsoft Outlook"\n' "$(date '+%A, %B %-d')"
  case "$status" in
    ok|no-calendars) ;;
    pending) printf '\tAllow Calendar access for sketchybar-events\t\n' ;;
    *) printf '\tNo Calendar access (System Settings › Privacy › Calendars)\topen "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars"\n' ;;
  esac
  n=0
  while IFS=$'\t' read -r start end title url; do
    [ "$end" -le "$now" ] && continue
    day=""; [ "$start" -gt "$today_end" ] && day="Tomorrow "
    when="$day$(date -r "$start" '+%-I:%M')–$(date -r "$end" '+%-I:%M %p')"
    icon=; [ "$start" -le "$now" ] && icon=󰤙
    click=""; [ -n "$url" ] && click="open '$url'"
    printf '%s\t%s  %s%s\t%s\n' "$icon" "$when" "$title" "${url:+  ·  join}" "$click"
    n=$((n + 1))
  done < <(cat "$AGENDA" 2>/dev/null)
  [ "$n" -eq 0 ] && [ "$status" = ok ] && printf '󰄬\tNo more meetings\t\n'
  [ "$status" = no-calendars ] && printf '\tNo calendars — add your work account in Internet Accounts\topen "x-apple.systempreferences:com.apple.Internet-Accounts-Settings.extension"\n'
} | fill_popup "$NAME" 10
