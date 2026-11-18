#!/bin/bash
# Build sketchybar-notifications (Notification Center previews for the
# SketchyBar badge bubbles) and (re)install it as a login LaunchAgent.
#   ~/.config/sketchybar/helpers/notifications/install.sh
# Then grant it Full Disk Access: System Settings > Privacy & Security >
# Full Disk Access > + > ~/.local/bin/sketchybar-notifications.
# Rebuilding changes the binary's signature, so macOS may need the grant again.
set -euo pipefail
DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BIN="$HOME/.local/bin/sketchybar-notifications"
LABEL=local.sketchybar-notifications
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

mkdir -p "$(dirname "$BIN")" "$(dirname "$PLIST")"
swiftc -O -swift-version 5 "$DIR/main.swift" -o "$BIN"
codesign -f -s - -i "$LABEL" "$BIN" 2>/dev/null

cat > "$PLIST" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>$LABEL</string>
    <key>ProgramArguments</key>
    <array><string>$BIN</string><string>3</string></array>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><true/>
    <key>ProcessType</key><string>Background</string>
    <key>LimitLoadToSessionType</key><string>Aqua</string>
    <key>StandardErrorPath</key><string>/tmp/sketchybar-notifications.err.log</string>
</dict>
</plist>
PL

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "sketchybar-notifications installed ($BIN) - grant it Full Disk Access"
