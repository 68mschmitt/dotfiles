#!/bin/bash
# move-stay.sh <workspace 0-8>: send the focused window to a workspace without
# following it. The cursor stays where it is and focus goes to the window under
# the cursor (Rift would otherwise focus a sibling and warp the mouse to it).
export PATH=/opt/homebrew/bin:$PATH
[[ "$1" =~ ^[0-9]+$ ]] || { echo "usage: $0 <workspace 0-8>" >&2; exit 1; }
DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
HOLD="$HOME/.local/bin/rift-cursor-hold"
if [ ! -x "$HOLD" ] || [ "$DIR/cursor-hold.swift" -nt "$HOLD" ]; then
  mkdir -p "$(dirname "$HOLD")"
  swiftc -O "$DIR/cursor-hold.swift" -o "$HOLD" || exit 1
fi
"$HOLD" 400 &
rift-cli execute workspace move-window "$1"
wait
