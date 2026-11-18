#!/bin/bash
# Build sketchybar-events (mic/camera + calendar feed for SketchyBar) and
# (re)install it as a login LaunchAgent.
#   ~/.config/sketchybar/helpers/bar_events/install.sh
# The binary embeds an Info.plist (bundle id + calendar usage string) so macOS
# can ask for Calendar access for it. Rebuilding changes its signature, so
# macOS may ask again after edits to main.swift.
set -euo pipefail
DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BIN="$HOME/.local/bin/sketchybar-events"
LABEL=local.sketchybar-events
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
INFO="$(mktemp -t sbevents-info).plist"
trap 'rm -f "$INFO"' EXIT

cat > "$INFO" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>$LABEL</string>
    <key>CFBundleName</key><string>sketchybar-events</string>
    <key>NSCalendarsFullAccessUsageDescription</key>
    <string>Shows your next meeting in SketchyBar.</string>
    <key>NSCalendarsUsageDescription</key>
    <string>Shows your next meeting in SketchyBar.</string>
</dict>
</plist>
PL

mkdir -p "$(dirname "$BIN")" "$(dirname "$PLIST")"
swiftc -O -swift-version 5 "$DIR/main.swift" -o "$BIN" \
  -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker "$INFO"
codesign -f -s - -i "$LABEL" "$BIN" 2>/dev/null

cat > "$PLIST" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>$LABEL</string>
    <key>ProgramArguments</key>
    <array><string>$BIN</string></array>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><true/>
    <key>ProcessType</key><string>Background</string>
    <key>LimitLoadToSessionType</key><string>Aqua</string>
    <key>StandardErrorPath</key><string>/tmp/sketchybar-events.err.log</string>
</dict>
</plist>
PL

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "sketchybar-events installed ($BIN)"
