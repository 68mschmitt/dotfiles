#!/bin/bash
# Build dim-unfocused and (re)install it as a login LaunchAgent.
#   ~/.config/dim-unfocused/install.sh [--alpha 0.15] [--radius 16] [--padding 8]
# The plist is written (not symlinked) because launchd may skip symlinked
# agents at login.
set -euo pipefail
ALPHA=0.15 RADIUS=16 PADDING=8
while [[ $# -gt 0 ]]; do
  case "$1" in
    --alpha) ALPHA="$2"; shift 2 ;;
    --radius) RADIUS="$2"; shift 2 ;;
    --padding) PADDING="$2"; shift 2 ;;
    *) echo "unknown option $1" >&2; exit 1 ;;
  esac
done

SRC="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/main.swift"
BIN="$HOME/.local/bin/dim-unfocused"
LABEL=local.dim-unfocused
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

mkdir -p "$(dirname "$BIN")" "$(dirname "$PLIST")"
swiftc -O -swift-version 5 "$SRC" -o "$BIN"

cat > "$PLIST" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$BIN</string>
        <string>--alpha</string><string>$ALPHA</string>
        <string>--padding</string><string>$PADDING</string>
        <string>--radius</string><string>$RADIUS</string>
    </array>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><true/>
    <key>ProcessType</key><string>Interactive</string>
    <key>LimitLoadToSessionType</key><string>Aqua</string>
    <key>StandardErrorPath</key><string>/tmp/dim-unfocused.err.log</string>
</dict>
</plist>
PL

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "dim-unfocused installed (alpha=$ALPHA radius=$RADIUS padding=$PADDING)"
