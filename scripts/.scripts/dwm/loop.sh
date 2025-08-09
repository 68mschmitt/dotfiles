#!/bin/bash

while true; do
    xset q &>/dev/null || exit 0
	~/.scripts/dwm/set-status-bar.sh
	sleep 1
done &
