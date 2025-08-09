#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------------------
# Dotfiles bootstrapper: run platform-specific dependency installers
# - mac/install-deps.sh (or install-dependencies.sh) on macOS
# - linux/<distro>/install-deps.sh (or install-dependencies.sh) on Linux
#
# Options:
#   --dry-run          Show what would run without executing
#   --distro <name>    Only run a specific linux/<distro> installer (Linux only)
#   --help             Show help
# ------------------------------------------------------------------------------

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
OS="$(uname -s)"
DRY_RUN=false
TARGET_DISTRO=""

usage() {
  cat <<EOF
Usage: $(basename "$0") [--dry-run] [--distro <name>] [--help]

Behavior:
  macOS:
    - Runs mac/install-deps.sh (or mac/install-dependencies.sh) if present.
  Linux:
    - If --distro <name> is provided, runs linux/<name>/install-deps.sh
      (or install-dependencies.sh) if present.
    - Otherwise, runs installers for ALL linux/<distro>/ subdirectories
      that contain an installer script.

Options:
  --dry-run         Preview actions without executing installers
  --distro <name>   Only run installer for linux/<name>
  --help            Show this help
EOF
}

# --- args ----------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --distro)  TARGET_DISTRO="${2:-}"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

log() { printf '%b\n' "$*"; }
run() { "$@"; }
run_or_echo() { $DRY_RUN && log "[dry-run] $*" || run "$@"; }

# Ensure a given installer is executable, then run it
exec_installer() {
  local script_path="$1"
  if [[ ! -f "$script_path" ]]; then
    return 1
  fi
  if [[ ! -x "$script_path" ]]; then
    log "Making executable: $script_path"
    $DRY_RUN || chmod +x "$script_path"
  fi
  log "Running: $script_path"
  run_or_echo "$script_path"
  return 0
}

# Try both naming conventions
run_installer_if_exists() {
  local dir="$1"
  local ok=1
  if exec_installer "$dir/install-deps.sh"; then ok=0; fi
  if (( ok != 0 )); then
    if exec_installer "$dir/install-dependencies.sh"; then ok=0; fi
  fi
  return $ok
}

log "Repo: $REPO_DIR"
log "OS:   $OS"
$DRY_RUN && log "Mode: DRY-RUN (no changes)" || log "Mode: EXECUTE"
echo

case "$OS" in
  Darwin)
    # macOS
    MAC_DIR="$REPO_DIR/mac"
    if [[ -d "$MAC_DIR" ]]; then
      if ! run_installer_if_exists "$MAC_DIR"; then
        log "No installer found in $MAC_DIR (expected install-deps.sh or install-dependencies.sh)."
      fi
    else
      log "mac/ directory not found, skipping."
    fi
    ;;

  Linux)
    LINUX_DIR="$REPO_DIR/linux"
    if [[ ! -d "$LINUX_DIR" ]]; then
      log "linux/ directory not found, nothing to do."
      exit 0
    fi

    if [[ -n "$TARGET_DISTRO" ]]; then
      # Run specific linux/<distro>
      DISTRO_DIR="$LINUX_DIR/$TARGET_DISTRO"
      if [[ -d "$DISTRO_DIR" ]]; then
        if ! run_installer_if_exists "$DISTRO_DIR"; then
          log "No installer found in $DISTRO_DIR (expected install-deps.sh or install-dependencies.sh)."
        fi
      else
        log "Specified distro directory not found: $DISTRO_DIR"
        exit 1
      fi
    else
      # Run all linux/<distro> installers
      shopt -s nullglob
      mapfile -t DISTROS < <(find "$LINUX_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null || true)
      # Compatibility for BSD find (mac running Linux container, etc.)
      if [[ ${#DISTROS[@]} -eq 0 ]]; then
        # Fallback without -printf
        while IFS= read -r d; do
          DISTROS+=("$(basename "$d")")
        done < <(find "$LINUX_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
      fi

      if [[ ${#DISTROS[@]} -eq 0 ]]; then
        log "No linux/<distro> subdirectories found."
        exit 0
      fi

      for d in "${DISTROS[@]}"; do
        DISTRO_DIR="$LINUX_DIR/$d"
        log "==> linux/$d"
        if ! run_installer_if_exists "$DISTRO_DIR"; then
          log "   (no installer found, expected install-deps.sh or install-dependencies.sh)"
        fi
        echo
      done
    fi
    ;;

  *)
    log "Unsupported OS: $OS"
    exit 1
    ;;
esac

log "Done."
