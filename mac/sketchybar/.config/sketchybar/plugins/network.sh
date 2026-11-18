#!/bin/bash
# Network rate from the network_load provider (network_update: upload/download),
# interface icon from network_iface (sent by providers.sh); click = details.
source "$HOME/.config/sketchybar/plugins/lib.sh"
handle_hover && exit 0
fmt() { # "035KBps" -> "35K"
  local v="${1%%[!0-9]*}" u="${1##*[0-9]}"
  v=$((10#${v:-0})); case "$u" in MBps) u=M ;; KBps) u=K ;; *) u=B ;; esac
  printf '%s%s' "$v" "$u"
}
wifi_dev() { networksetup -listallhardwareports | awk '/Wi-Fi/ {getline; print $2}'; }
case "$SENDER" in
  network_update)
    sketchybar --set "$NAME" label="$(printf '↓%4s ↑%4s' "$(fmt "$download")" "$(fmt "$upload")")" ;;
  network_iface|forced)
    iface="${IFACE:-$(route -n get default 2>/dev/null | awk '/interface:/ {print $2}')}"
    if [ -z "$iface" ]; then icon=󰖪; col=$RED
    elif [ "$iface" = "$(wifi_dev)" ]; then icon=󰖩; col=$WHITE
    else icon=󰈀; col=$WHITE; fi
    [ -z "$iface" ] && sketchybar --set "$NAME" label="offline"
    sketchybar --set "$NAME" icon="$icon" icon.color="$col" ;;
  mouse.clicked)
    iface="$(route -n get default 2>/dev/null | awk '/interface:/ {print $2}')"
    gw="$(route -n get default 2>/dev/null | awk '/gateway:/ {print $2}')"
    if [ "$iface" = "$(wifi_dev)" ]; then kind=Wi-Fi; else kind=Ethernet; fi
    ip="$(ipconfig getifaddr "$iface" 2>/dev/null)"
    vpn="off"
    scutil --nc list 2>/dev/null | grep -q "(Connected)" && vpn="on"
    netstat -rn -f inet 2>/dev/null | awk '$1=="default" && $NF ~ /^utun/ {f=1} END {exit !f}' && vpn="on (tunnel)"
    settings="open 'x-apple.systempreferences:com.apple.Network-Settings.extension'"
    printf '%s\t%s\t%s\n' \
      󰈀 "${kind} (${iface:-none})" "$settings" \
      󰩟 "IP ${ip:-–}" "printf %s '$ip' | pbcopy" \
      󰑩 "Gateway ${gw:-–}" "" \
      󰖂 "VPN ${vpn}" "" | fill_popup "$NAME" 4 ;;
esac
