#!/bin/bash
# Animated rainbow border for the focused window (only on AC power;
# on battery it switches to a static gradient to save CPU).
# Rotates a two-colour gradient around the hue wheel by repeatedly updating the
# running `borders` instance (JankyBorders has no built-in animation).
#   STEPS frames per full cycle, FRAME seconds per frame -> cycle = STEPS*FRAME seconds
STEPS=40
FRAME=0.2
BORDERS=/opt/homebrew/bin/borders
STATIC="gradient(top_left=0xffff0000,bottom_right=0xff00aaff)"   # used on battery
POWER_CHECK=5   # seconds between power-source checks

on_ac() { /usr/bin/pmset -g ps | head -1 | grep -q "AC Power"; }

# Only one loop at a time (kill a previous one left over from a restart)
PIDFILE="${TMPDIR:-/tmp}/borders-rainbow.pid"
[ -f "$PIDFILE" ] && kill "$(cat "$PIDFILE")" 2>/dev/null
echo $$ > "$PIDFILE"

# Precompute the gradient for every frame once (full saturation/value HSV -> ARGB)
FRAMES=()
while IFS= read -r line; do FRAMES+=("$line"); done < <(awk -v n="$STEPS" '
  function rgb(h,  i,f,q,t,r,g,b) {
    h = (h % 360) / 60; i = int(h); f = h - i; q = 1 - f; t = f
    if (i==0){r=1;g=t;b=0} else if (i==1){r=q;g=1;b=0} else if (i==2){r=0;g=1;b=t}
    else if (i==3){r=0;g=q;b=1} else if (i==4){r=t;g=0;b=1} else {r=1;g=0;b=q}
    return sprintf("0xff%02x%02x%02x", r*255, g*255, b*255)
  }
  BEGIN { for (k=0;k<n;k++) { h=k*360/n
    printf "gradient(top_left=%s,bottom_right=%s)\n", rgb(h), rgb(h+150) } }')

# Wait for borders to be up, then animate; exit when borders goes away
for _ in $(seq 50); do pgrep -qx borders && break; sleep 0.2; done
i=0
frames_per_check=$(awk -v c="$POWER_CHECK" -v f="$FRAME" 'BEGIN{print int(c/f)}')
while pgrep -qx borders; do
  if on_ac; then
    for _ in $(seq "$frames_per_check"); do
      "$BORDERS" active_color="${FRAMES[i]}" >/dev/null 2>&1
      i=$(( (i + 1) % STEPS ))
      sleep "$FRAME"
    done
  else
    "$BORDERS" active_color="$STATIC" >/dev/null 2>&1
    sleep "$POWER_CHECK"
  fi
done
rm -f "$PIDFILE"
