#!/bin/bash
# media item: left click = mini-player popup (artwork, track, prev/play/next,
# position), right click = play/pause, scroll = previous/next track.
source "$HOME/.config/sketchybar/plugins/lib.sh"
handle_hover && exit 0
fmt() { local s=${1%%.*}; [ -z "$s" ] && s=0; printf '%d:%02d' $((s / 60)) $((s % 60)); }
case "$SENDER" in
  mouse.scrolled)
    if [ "${SCROLL_DELTA:-0}" -gt 0 ]; then media-control next-track; else media-control previous-track; fi ;;
  mouse.clicked)
    if [ "$BUTTON" = right ]; then media-control toggle-play-pause; exit 0; fi
    IFS=$'\x1f' read -r title artist album playing bundle elapsed duration stamp < "$STATE_DIR/media" 2>/dev/null
    # current position = elapsed at $stamp + time since, while playing
    pos=${elapsed%%.*}
    if [ "$playing" = true ] && [ -n "$stamp" ]; then
      t0=$(date -j -u -f '%Y-%m-%dT%H:%M:%S' "${stamp%%.*}" +%s 2>/dev/null)
      [ -n "$t0" ] && pos=$(( ${pos:-0} + $(date +%s) - t0 ))
    fi
    time=""; [ "${duration%%.*}" -gt 0 ] 2>/dev/null && time="$(fmt "$pos") / $(fmt "$duration")"
    sketchybar --set media.time label="$time" drawing=$([ -n "$time" ] && echo on || echo off)
    popup_toggle "$NAME" ;;
esac
