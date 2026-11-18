#!/bin/bash
# Free space on the data volume (polled; interval set by providers.sh).
# Popup: usage meter, mounted volumes (click = reveal / eject), Trash size, storage settings.
source "$HOME/.config/sketchybar/plugins/lib.sh"
handle_hover && exit 0
if [ "$SENDER" = mouse.clicked ]; then
  read -r size used avail pct <<< "$(df -H /System/Volumes/Data | awk 'NR==2 {print $2, $3, $4, $5}')"
  trash="$(du -sh "$HOME/.Trash" 2>/dev/null | awk '{print $1}')"
  p=${pct%\%}; st=r; [ "$p" -ge 90 ] && st=x || { [ "$p" -ge 75 ] && st=y; }
  { printf '󰋊\tMacintosh HD · %s free of %s\topen -a "Disk Utility"\th\n' "$avail" "$size"
    printf '󰋊\t%s  %s used\t\t%s\n' "$(meter "$p" 16)" "$pct" "$st"
    printf '\tVOLUMES\t\ts\n'
    df -H 2>/dev/null | awk 'NR>1 && $NF ~ /^\/Volumes\// {mp=$9; for (i=10;i<=NF;i++) mp=mp" "$i; print $4 "\t" mp}' |
      while IFS=$'\t' read -r free mp; do
        printf '󰋊\t%s · %s free  (click = Finder, ⌥ = eject)\t[ "$MODIFIER" = alt ] && diskutil eject "%s" >/dev/null || open "%s"\tr\n' \
          "${mp#/Volumes/}" "$free" "$mp" "$mp"
      done
    printf '󰩹\tTrash %s\topen "%s/.Trash"\tm\n' "${trash:-0B}" "$HOME"
    printf '\tStorage settings\topen "x-apple.systempreferences:com.apple.settings.Storage"\ta\n'
  } | fill_popup "$NAME" 10
  exit 0
fi
sketchybar --set "$NAME" label="$(df -H /System/Volumes/Data | awk 'NR==2 {print $4}')"
