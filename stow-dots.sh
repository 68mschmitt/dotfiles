#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${HOME}"
OS="$(uname -s)"

ACTION="stow"      # stow | restow | unstow
DRY_RUN=false
ADOPT=false

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --dry-run           Preview only (no changes)
  --restow            Update/refresh links
  --unstow            Remove links
  --adopt             Move existing files in \$HOME into repo (DANGEROUS)
  --target PATH       Override target directory (default: \$HOME)
  --help              Show this help

Behavior:
- Stows all first-level package dirs in repo root, excluding ".git" and "mac".
- On macOS, also stows all first-level package dirs inside "mac/".
- Package names never contain slashes; we pass --dir to stow.
- After a successful stow/restow to \$HOME, one-time-initializes the
  wallpaper config (~/.config/my-wallpapers) if it doesn't exist yet, so
  a single run of this script is the entire setup.
EOF
}

# ---- parse args ---------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --restow)  ACTION="restow"; shift ;;
    --unstow)  ACTION="unstow"; shift ;;
    --adopt)   ADOPT=true; shift ;;
    --target)  TARGET="$2"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

# ---- checks -------------------------------------------------------------------
if ! command -v stow >/dev/null 2>&1; then
  echo "Error: 'stow' is not installed." >&2
  exit 1
fi

echo "Repo:   $REPO_DIR"
echo "Target: $TARGET"
echo "OS:     $OS"
mode_suffix=""
$DRY_RUN && mode_suffix+=" (dry-run)"
$ADOPT && mode_suffix+=" (adopt)"
echo "Mode:   $ACTION$mode_suffix"
echo

# ---- list packages (names only) -----------------------------------------------
list_packages() {
  local parent="$1"
  # First-level directories only → print basenames
  # (BSD/mac and GNU friendly)
  find "$parent" -mindepth 1 -maxdepth 1 -type d -print0 \
  | xargs -0 -I{} basename "{}"
}

# Root-level packages (exclude .git and mac)
common_pkgs=()
while IFS= read -r pkg; do
  [[ "$pkg" == ".git" || "$pkg" == "mac" ]] && continue
  common_pkgs+=("$pkg")
done < <(list_packages "$REPO_DIR")

# mac/ packages (only on macOS)
mac_pkgs=()
if [[ "$OS" == "Darwin" && -d "$REPO_DIR/mac" ]]; then
  while IFS= read -r pkg; do
    mac_pkgs+=("$pkg")
  done < <(list_packages "$REPO_DIR/mac")
fi

# ---- stow flags ----------------------------------------------------------------
flags=( "--target=$TARGET" )
$DRY_RUN && flags+=( "--no" )
[[ "$ACTION" == "restow" ]] && flags+=( "--restow" )
[[ "$ACTION" == "unstow" ]] && flags+=( "--delete" )
$ADOPT && flags+=( "--adopt" )   # WARNING: moves files into repo

stow_group() {
  local dir="$1"; shift
  local -a pkgs=( "$@" )
  [[ ${#pkgs[@]} -eq 0 ]] && return 0

  echo "Directory: $dir"
  echo "Packages:"
  for p in "${pkgs[@]}"; do echo "  - $p"; done
  echo

  # Run from parent dir using --dir so package names have no slashes
  stow --dir "$dir" "${flags[@]}" "${pkgs[@]}"
}

# ---- run -----------------------------------------------------------------------
# Root-level packages
stow_group "$REPO_DIR" "${common_pkgs[@]}"

# mac/ packages only on macOS
if [[ "$OS" == "Darwin" && ${#mac_pkgs[@]} -gt 0 ]]; then
  stow_group "$REPO_DIR/mac" "${mac_pkgs[@]}"
fi

# ---- one-time wallpaper config init --------------------------------------------
# Fold wallpaper setup into this single entrypoint: on a real stow/restow to the
# real $HOME (i.e. not --unstow, --dry-run, or a --target override), seed the
# wallpaper config the first time so there's no separate manual step to remember.
if [[ "$ACTION" != "unstow" && "$DRY_RUN" == "false" && "$TARGET" == "$HOME" ]]; then
  init_script="$REPO_DIR/scripts/.scripts/wallpaper-scripts/init-wallpaper.sh"
  if [[ -x "$init_script" && ! -f "$HOME/.config/my-wallpapers/.wallpaper_config" ]]; then
    echo
    echo "Initializing wallpaper config (first run)..."
    "$init_script"
  fi
fi

echo
echo "Done. Tips:"
echo "  - Use '--restow' after repo changes"
echo "  - Use '--dry-run' to preview"
echo "  - Use '--adopt' with caution (it moves files into the repo)"
