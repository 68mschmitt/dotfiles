#!/bin/bash
# Network item: rate label/graph are set directly by helpers/bin/network_load;
# this script sets the interface icon (network_iface from providers.sh).
# Popup: download graph, interface/IP/gateway/DNS/VPN, copy IP, Wi-Fi toggle.
source "$HOME/.config/sketchybar/plugins/lib.sh"
handle_hover && exit 0
wifi_dev() { networksetup -listallhardwareports | awk '/Wi-Fi/ {getline; print $2}'; }
case "$SENDER" in
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
    wdev="$(wifi_dev)"
    if [ "$iface" = "$wdev" ]; then kind=Wi-Fi; kicon=󰖩; else kind=Ethernet; kicon=󰈀; fi
    ip="$(ipconfig getifaddr "$iface" 2>/dev/null)"
    dns="$(scutil --dns 2>/dev/null | awk '/nameserver\[0\]/ {print $3; exit}')"
    vpn="off"; vs=m
    netstat -rn -f inet 2>/dev/null | awk '$1=="default" && $NF ~ /^utun/ {f=1} END {exit !f}' && { vpn="on (tunnel)"; vs=g; }
    scutil --nc list 2>/dev/null | grep -q "(Connected)" && { vpn="on"; vs=g; }
    rate="$(sketchybar --query network | jq -r .label.value)"
    wpower="$(networksetup -getairportpower "$wdev" 2>/dev/null | awk '{print $NF}')"
    if [ "$wpower" = On ]; then wnext=off; wlabel="Turn Wi-Fi off"; else wnext=on; wlabel="Turn Wi-Fi on"; fi
    settings="open 'x-apple.systempreferences:com.apple.Network-Settings.extension'"
    { printf '%s\t%s · %s · %s\t%s\th\n' "$kicon" "$kind" "${iface:-offline}" "$rate" "$settings"
      printf '󰩟\tIP %s   (click to copy)\tprintf %%s %s | pbcopy\tr\n' "${ip:-–}" "$ip"
      printf '󰑩\tGateway %s · DNS %s\t\tm\n' "${gw:-–}" "${dns:-–}"
      printf '󰖂\tVPN %s\t\t%s\n' "$vpn" "$vs"
      [ -n "$wdev" ] && printf '󰖩\t%s\t+networksetup -setairportpower %s %s; sleep 1; $HOME/.config/sketchybar/plugins/popup.sh close %s\ta\n' "$wlabel" "$wdev" "$wnext" "$NAME"
      printf '\tNetwork settings\t%s\ta\n' "$settings"
    } | fill_popup "$NAME" 7 ;;
esac
