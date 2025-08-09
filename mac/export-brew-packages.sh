#!/usr/bin/env bash
set -euo pipefail

# Where to save the package list
OUTPUT_FILE="${1:-packages.list}"

echo "📦 Exporting Homebrew packages to: $OUTPUT_FILE"

{
  echo "# ---- taps ----"
  brew tap | sort | sed 's/^/tap:/'

  echo
  echo "# ---- brews (formulae) ----"
  brew list --formula | sort | sed 's/^/brew:/'

  echo
  echo "# ---- casks (GUI apps/fonts) ----"
  brew list --cask | sort | sed 's/^/cask:/'

  # Optional: Mac App Store apps if 'mas' is installed
  if command -v mas >/dev/null 2>&1; then
    echo
    echo "# ---- mac app store ----"
    mas list | sort | awk '{print "mas:" $1 " # " substr($0, index($0,$2))}'
  fi
} > "$OUTPUT_FILE"

echo "✅ Done. Package list saved to $OUTPUT_FILE"
