#!/bin/bash
# Output volume (volume_change). Scroll on the item = ±5%.
# Popup: draggable volume slider, mute toggle, output device switcher.
source "$HOME/.config/sketchybar/plugins/lib.sh"
handle_hover && exit 0
icon_for() {
  case "$1" in [6-9][0-9]|100) echo 󰕾 ;; [3-5][0-9]) echo 󰖀 ;; [1-9]|[1-2][0-9]) echo 󰕿 ;; *) echo 󰖁 ;; esac
}
case "$SENDER" in
  volume_change|forced)
    VOLUME="${INFO:-$(osascript -e 'output volume of (get volume settings)')}"
    [ "$(osascript -e 'output muted of (get volume settings)')" = true ] && VOLUME=0
    sketchybar --set "$NAME" icon="$(icon_for "$VOLUME")" label="$VOLUME%" \
               --set volume.slider slider.percentage="$VOLUME" ;;
  mouse.scrolled)
    cur="$(osascript -e 'output volume of (get volume settings)')"
    step=5; [ "${SCROLL_DELTA:-0}" -lt 0 ] && step=-5
    osascript -e "set volume output volume $((cur + step))" ;;
  mouse.clicked)
    muted="$(osascript -e 'output muted of (get volume settings)')"
    cur="$(SwitchAudioSource -c -t output 2>/dev/null)"
    { printf '󰓃\t%s\topen "x-apple.systempreferences:com.apple.Sound-Settings.extension"\th\n' "${cur:-Output}"
      if [ "$muted" = true ]; then printf '󰖁\tUnmute\t+osascript -e "set volume without output muted"\ta\n'
      else printf '󰝟\tMute\t+osascript -e "set volume with output muted"\ta\n'; fi
      printf '\tOUTPUT DEVICE\t\ts\n'
      SwitchAudioSource -a -t output 2>/dev/null | while IFS= read -r dev; do
        if [ "$dev" = "$cur" ]; then printf '󰄬\t%s\t\tg\n' "$dev"
        else printf '󰓃\t%s\tSwitchAudioSource -t output -s "%s" >/dev/null\tr\n' "$dev" "$dev"; fi
      done
    } | fill_popup "$NAME" 10 ;;
esac
