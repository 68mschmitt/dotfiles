#!/usr/bin/env bash
# Re-apply the pi-voice chunked-TTS patch after a package install/update.
#
# WHY THIS EXISTS
#   pi-voice lives in ~/.pi/agent/npm/node_modules, which `pi install` and every
#   package update overwrite wholesale. The patch fixes silent audio truncation
#   (see README.md in this directory), so losing it means voice notes quietly
#   get cut off again — with no error to notice. Run this after any pi-voice
#   update; it is idempotent and safe to run when already applied.
#
# Usage: ./apply-pi-voice-patch.sh [--check]
#   --check   report status only, change nothing (exit 1 if unpatched)

set -euo pipefail

PATCH_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PATCH="${PATCH_DIR}/pi-voice-3.0.0-chunked-tts.patch"
PKG="${HOME}/.pi/agent/npm/node_modules/@s1m0n38/pi-voice"
CHECK_ONLY=false
[[ "${1:-}" == "--check" ]] && CHECK_ONLY=true

die() { echo "error: $*" >&2; exit 1; }

[[ -f "$PATCH" ]] || die "patch not found: $PATCH"
[[ -d "$PKG" ]] || die "pi-voice not installed at $PKG"

installed_version="$(node -p "require('${PKG}/package.json').version" 2>/dev/null || echo unknown)"
if [[ "$installed_version" != "3.0.0" ]]; then
  echo "warning: patch was built against pi-voice 3.0.0 but ${installed_version} is installed."
  echo "         Check whether upstream fixed this (grep for splitForSynthesis or"
  echo "         TextSplitterStream in extensions/) before forcing it on."
fi

if grep -q "splitForSynthesis" "${PKG}/extensions/server.ts" 2>/dev/null; then
  echo "already patched (extensions/server.ts calls splitForSynthesis)"
  exit 0
fi

if $CHECK_ONLY; then
  echo "NOT patched — voice notes longer than ~450 characters will be silently truncated."
  echo "Run: ${BASH_SOURCE[0]}"
  exit 1
fi

echo "applying $(basename "$PATCH") to $PKG ..."
patch -p1 -d "$PKG" --forward < "$PATCH"

# `server start` always loads config.defaultModel (falling back to q4), so a
# restart would silently downgrade a session running a higher-quality dtype.
# Remember what is loaded now and put it back afterwards.
active_dtype="$(curl -s --max-time 3 http://127.0.0.1:8181/health 2>/dev/null \
  | sed -n 's/.*"activeDtype":"\([^"]*\)".*/\1/p')"

echo "restarting the TTS server so the change takes effect ..."
if node "${PKG}/bin/pi-voice.mjs" server restart; then
  if [[ -n "$active_dtype" ]]; then
    reloaded="$(curl -s --max-time 3 http://127.0.0.1:8181/health 2>/dev/null \
      | sed -n 's/.*"activeDtype":"\([^"]*\)".*/\1/p')"
    if [[ "$reloaded" != "$active_dtype" ]]; then
      echo "restoring the previously active model (${active_dtype}) ..."
      node "${PKG}/bin/pi-voice.mjs" model load "$active_dtype"
    fi
  fi
  echo "done."
else
  echo "note: server restart failed — start it yourself with:"
  echo "      node ${PKG}/bin/pi-voice.mjs server start"
fi
