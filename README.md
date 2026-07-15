# Dotfiles

Personal configuration files managed with GNU Stow.

## Overview

This repository contains configuration files for my development environment, including:

- **Neovim** - Modern Vim-based text editor with Lua configuration
- **Tmux** - Terminal multiplexer for managing multiple terminal sessions
- **Ghostty** - Terminal emulator configuration
- **Yabai** - Tiling window manager for macOS
- **Skhd** - Simple hotkey daemon for macOS keyboard shortcuts
- **Pi** - Coding agent settings, extensions and prompts
- **Scripts** - Utility scripts for wallpaper management, Git setup, and QoL improvements
- **Plover** - Stenography dictionary

Package installation (Homebrew, etc.) is intentionally **not** managed by this
repo — it only manages dotfiles/config, deployed via GNU Stow.

## Quick Start

```bash
# Clone the repository
git clone https://github.com/68mschmitt/dotfiles.git ~/.dotfiles
cd ~/.dotfiles

# Deploy dotfiles using GNU Stow
./stow-dots.sh
```

## Installation

Use GNU Stow to symlink configurations into your home directory:

```bash
./stow-dots.sh
```

This creates symlinks for every top-level package in this repo (`neovim`,
`tmux`, `ghostty`, `scripts`, `plover`, `pi`), plus the macOS-specific
packages under `mac/` (`skhd`, `yabai`) when run on macOS.

Options:
- `--dry-run` - Preview changes without creating symlinks
- `--restow` - Refresh existing symlinks
- `--unstow` - Remove all symlinks
- `--adopt` - Move existing files into the repository (use with caution)
- `--target PATH` - Override target directory (default: `$HOME`)

## Structure

```
dotfiles/
├── mac/                    # macOS-specific configurations
│   ├── skhd/               # Keyboard shortcuts
│   └── yabai/              # Window manager settings
├── neovim/                 # Neovim configuration
│   └── .config/nvim/
│       ├── lua/             # Lua configuration modules
│       ├── snippets/        # Code snippets
│       └── init.lua         # Main config entry point
├── tmux/                   # Tmux configuration
│   └── .tmux.conf
├── ghostty/                # Ghostty terminal configuration
│   └── .config/ghostty/config
├── pi/                     # Pi coding agent settings/extensions/prompts
│   └── .pi/agent/
├── scripts/                # Utility scripts
│   └── .scripts/
│       ├── wallpaper-scripts/  # Dynamic wallpaper management
│       ├── git-related/        # Git setup utilities
│       ├── qol/                 # Quality of life scripts
│       └── fun/                 # Entertainment scripts
├── plover/                 # Plover stenography dictionary
└── stow-dots.sh            # GNU Stow deployment script
```

## Key Features

### Neovim

Lua-based configuration featuring:
- LSP support with completion (nvim-cmp)
- GitHub Copilot integration
- DAP debugging
- Snacks.nvim for dashboard, picker, and notifications
- Treesitter syntax highlighting
- Git integration
- Custom statusline
- Personal Knowledge Management (PKM) workflow

### Window Management (macOS)

**Yabai** tiling window manager with:
- BSP layout by default
- Custom padding and gaps
- 50pt top padding, 20pt other sides

**Skhd** keyboard shortcuts:
- `cmd + return` - Open Ghostty terminal
- `cmd + b` - Open Chrome
- `cmd + arrow keys` - Focus windows
- `cmd + ctrl + arrow keys` - Swap windows
- `cmd + shift + space` - Toggle float
- `cmd + shift + e` - Balance window sizes
- `cmd + ctrl + w` - Change wallpaper
- `cmd + ctrl + b` - Blacklist current wallpaper

### Wallpaper Management

Automatic wallpaper rotation with blacklist support, under
`scripts/.scripts/wallpaper-scripts/`:

- `init-wallpaper.sh` - One-time setup: seeds `~/.config/my-wallpapers/`
  from the checked-in defaults (run this once after stowing)
- `set-random-wallpaper.sh` - Set random wallpaper from collection
- `blacklist-wallpaper.sh` - Add current wallpaper to blacklist
- `loop-wallpapers.sh` - Automatic rotation daemon
- `pull-wallpapers.sh` - Clone/update configured wallpaper source repos
- Supports both macOS (AppleScript) and Linux (feh)

The checked-in files under `default-configs/` are just templates; your
actual config, blacklist, and current-wallpaper state live untracked in
`~/.config/my-wallpapers/` so day-to-day wallpaper changes never touch git.

### Tmux

Terminal multiplexer configuration:
- `C-Space` prefix (instead of C-b)
- Vi mode keybindings
- Minimal status theme
- TPM plugin manager
- Image support for Neovim

## Scripts

### Wallpaper Scripts

Located in `scripts/.scripts/wallpaper-scripts/` — see
[Wallpaper Management](#wallpaper-management) above.

### Git Scripts

Located in `scripts/.scripts/git-related/`:
- `git-setup-personal.sh` - Configure personal Git remote/identity for a repo
- `git-autocommit.sh` / `setup-git-autocommit.sh` - AI-generated commit messages via Ollama
- `pull-latest-for-all.sh` - `git pull` across every repo one level deep

### QoL Scripts

Located in `scripts/.scripts/qol/`:
- `ytplay.sh` - Play YouTube videos
- `yt-audio.sh` - Play/download YouTube audio

### Fun Scripts

Located in `scripts/.scripts/fun/`:
- `cowsay-loop.sh` - Endless wisdom from the cow
- `fastfetch_demo.sh` - Demo of fastfetch's output styles

## Customization

### Adding New Dotfiles

1. Create a new directory in the repository root
2. Structure it to mirror your home directory
3. Run `./stow-dots.sh --restow` to update symlinks

Example for adding `.gitconfig`:
```bash
mkdir -p git
cp ~/.gitconfig git/.gitconfig
./stow-dots.sh --restow
```

## Requirements

- **GNU Stow**
- **macOS** for the `mac/` packages (skhd, yabai); everything else is
  platform-agnostic

## Maintenance

### Refresh Symlinks

After making changes to the repository:
```bash
./stow-dots.sh --restow
```

## Notes

- The repository uses GNU Stow for symlink management; package installation
  (Homebrew/apt/etc.) is out of scope for this repo
- macOS-specific configs are isolated in the `mac/` directory
- Neovim uses Lazy.nvim for plugin management

## License

Personal use. Feel free to fork and modify for your own setup.
