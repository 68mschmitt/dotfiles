#!/usr/bin/env bash
set -euo pipefail

# Defaults
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKG_FILE="${PKG_FILE:-"$SCRIPT_DIR/packages.list"}"
DRY_RUN="${DRY_RUN:-false}"

usage() {
  cat <<EOF
Usage: $(basename "$0") [--file PATH] [--dry-run]

Options:
  --file PATH   Path to package list (default: mac/packages.list)
  --dry-run     Show actions without executing

Package list format (lines, '#' comments allowed):
  tap:homebrew/cask-fonts
  brew:git
  brew:mas
  cask:iterm2
  cask:font-jetbrains-mono
  mas:497799835             # Xcode by ID
  mas:Things=904280696      # Named (ignored by script), uses ID after '='

EOF
}

# ---- arg parse -----------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --file) PKG_FILE="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

log()  { printf '%b\n' "$*"; }
run()  { "$@"; }
run_or_echo() { $DRY_RUN && log "[dry-run] $*" || run "$@"; }

# ---- guards --------------------------------------------------------------------
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "❌ This script only supports macOS." >&2
  exit 1
fi

if [[ ! -f "$PKG_FILE" ]]; then
  echo "❌ Package file not found: $PKG_FILE" >&2
  exit 1
fi

# ---- ensure Homebrew -----------------------------------------------------------
ensure_brew() {
  if command -v brew >/dev/null 2>&1; then
    return 0
  fi

  log "🍺 Homebrew not found. Installing Homebrew..."
  if $DRY_RUN; then
    log "[dry-run] /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
  else
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi

  # Activate brew for current shell (Apple Silicon vs Intel)
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  else
    echo "❌ Brew installed but not found on PATH." >&2
    exit 1
  fi
}

# Always ensure brew is in this shell, even if already installed.
activate_brew_shellenv() {
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

ensure_brew
activate_brew_shellenv

# ---- helpers for checks --------------------------------------------------------
have_tap()   { brew tap | grep -qx "$1"; }
have_brew()  { brew list --formula --versions "$1" >/dev/null 2>&1; }
have_cask()  { brew list --cask --versions "$1" >/dev/null 2>&1; }
have_mas()   { command -v mas >/dev/null 2>&1; }
have_mas_app_by_id() { mas list | awk '{print $1}' | grep -qx "$1"; }

install_tap() {
  local tap="$1"
  if have_tap "$tap"; then
    log "✅ tap: $tap (already tapped)"
  else
    run_or_echo brew tap "$tap"
  fi
}

install_brew() {
  local formula="$1"
  if have_brew "$formula"; then
    log "✅ brew: $formula (installed)"
  else
    run_or_echo brew install "$formula"
  fi
}

install_cask() {
  local cask="$1"
  if have_cask "$cask"; then
    log "✅ cask: $cask (installed)"
  else
    run_or_echo brew install --cask "$cask"
  fi
}

install_mas() {
  local spec="$1" id
  # Accept "name=ID" or just "ID"
  if [[ "$spec" == *"="* ]]; then
    id="${spec#*=}"
  else
    id="$spec"
  fi

  if ! have_mas; then
    log "ℹ️  'mas' not installed; installing with Homebrew..."
    install_brew mas
  fi

  if have_mas_app_by_id "$id"; then
    log "✅ mas: $id (installed)"
  else
    run_or_echo mas install "$id"
  fi
}

# ---- process package file ------------------------------------------------------
log "📦 Using package file: $PKG_FILE"
while IFS= read -r line || [[ -n "$line" ]]; do
  # trim leading/trailing space
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
  # skip blanks/comments
  [[ -z "$line" || "$line" =~ ^# ]] && continue

  type="${line%%:*}"
  rest="${line#*:}"

  case "$type" in
    tap)   install_tap "$rest" ;;
    brew)  install_brew "$rest" ;;
    cask)  install_cask "$rest" ;;
    mas)   install_mas "$rest" ;;
    *)
      echo "⚠️  Unknown type '$type' in line: $line" >&2
      ;;
  esac
done < "$PKG_FILE"

log "🎉 Done."
