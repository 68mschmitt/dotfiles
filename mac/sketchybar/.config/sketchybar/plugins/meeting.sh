#!/bin/bash
# Next-meeting countdown from ~/.cache/sketchybar/agenda.tsv (written by
# sketchybar-events). Left click = join (Teams/Zoom/Meet link) or agenda,
# right click = agenda popup (on the date item).
source "$HOME/.config/sketchybar/plugins/lib.sh"
handle_hover && exit 0
AGENDA="$STATE_DIR/agenda.tsv"
now=$(date +%s)

# current (start<=now<end) else next (start>now, within 12h)
pick() {
  awk -F'\t' -v now="$now" '
    $1 <= now && now < $2 && !cur { cur = $0 }
    $1 > now && !nxt { nxt = $0 }
    END { if (cur) print "now\t" cur; else if (nxt && nxt + 0 - now < 43200) print "next\t" nxt }' \
    "$AGENDA" 2>/dev/null
}
dur() { local m=$(( ($1 + 59) / 60 )); [ $m -ge 60 ] && printf '%dh %dm' $((m / 60)) $((m % 60)) || printf '%dm' $m; }

IFS=$'\t' read -r kind start end title url <<< "$(pick)"

if [ "$SENDER" = mouse.clicked ]; then
  if [ "$BUTTON" != right ] && [ -n "$url" ]; then open "$url"
  else NAME=date SENDER=mouse.clicked "$HOME/.config/sketchybar/plugins/agenda.sh"; fi
  exit 0
fi

if [ -z "$kind" ]; then sketchybar $(anim) --set "$NAME" drawing=off; exit 0; fi
short="$title"; [ ${#short} -gt 28 ] && short="${short:0:27}…"
if [ "$kind" = now ]; then
  label="$short · $(dur $((end - now))) left"; col=$GREEN; icon=󰤙
else
  left=$((start - now)); label="$short in $(dur $left)"; icon=󰃰
  if [ $left -le 300 ]; then col=$RED; elif [ $left -le 900 ]; then col=$ORANGE; else col=$WHITE; fi
fi
[ -n "$url" ] && icon=󰤙
sketchybar $(anim) --set "$NAME" drawing=on icon="$icon" icon.color="$col" label="$label" label.color="$col"
