#!/bin/bash
# Agenda popup on the date item: remaining events today + tomorrow.
# Current meeting in green, upcoming within 15m in yellow; rows with a
# Teams/Zoom/Meet link join on click.
source "$HOME/.config/sketchybar/plugins/lib.sh"
handle_hover && exit 0
[ "$SENDER" = mouse.clicked ] || exit 0
AGENDA="$STATE_DIR/agenda.tsv"
status="$(cat "$STATE_DIR/calendar_status" 2>/dev/null)"
now=$(date +%s); today_end=$(date -v23H -v59M -v59S +%s)
outlook='open -a "Microsoft Outlook"'
{
  printf '󰃭\t%s · week %s\t%s\th\n' "$(date '+%A, %B %-d')" "$(date +%V)" "$outlook"
  case "$status" in
    ok|no-calendars) ;;
    pending) printf '\tAllow Calendar access for sketchybar-events\t\ty\n' ;;
    *) printf '\tNo Calendar access — open Privacy settings\topen "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars"\tx\n' ;;
  esac
  n=0 section=""
  # awk keeps empty fields (bash read would collapse an empty title/url)
  while IFS=$'\x1f' read -r start end title url; do
    [ -z "$start" ] && continue
    sec=TODAY; [ "$start" -gt "$today_end" ] && sec=TOMORROW
    [ "$sec" != "$section" ] && { section=$sec; printf '\t%s\t\ts\n' "$sec"; }
    when="$(date -r "$start" '+%-I:%M')–$(date -r "$end" '+%-I:%M %p')"
    style=r icon=󰃰
    if [ "$start" -le "$now" ]; then style=g; icon=󰤙; when="now · $(( (end - now + 59) / 60 ))m left"
    elif [ $((start - now)) -le 900 ]; then style=y; when="in $(( (start - now + 59) / 60 ))m"; fi
    click="$outlook"; [ -n "$url" ] && { click="open '$url'"; icon=󰤙; }
    short="$title"; [ ${#short} -gt 44 ] && short="${short:0:43}…"
    printf '%s\t%-17s %s%s\t%s\t%s\n' "$icon" "$when" "$short" "${url:+   join ›}" "$click" "$style"
    n=$((n + 1)); [ $n -ge 9 ] && break
  done < <(awk -F'\t' -v now="$now" '$2 > now {print $1 "\x1f" $2 "\x1f" $3 "\x1f" $4}' "$AGENDA" 2>/dev/null)
  [ "$n" -eq 0 ] && [ "$status" = ok ] && printf '󰄬\tNo more meetings — enjoy the focus time\t\tg\n'
  [ "$status" = no-calendars ] && printf '\tNo calendars: add your work account in Internet Accounts\topen "x-apple.systempreferences:com.apple.Internet-Accounts-Settings.extension"\ty\n'
  printf '󰃭\tOpen calendar\t%s\ta\n' "$outlook"
} | fill_popup "$NAME" 14
