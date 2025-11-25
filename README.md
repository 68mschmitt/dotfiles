# Dotfiles

Personal macOS configuration files managed with GNU Stow.

## Overview

This repository contains configuration files for my development environment, including:

- **Neovim** - Modern Vim-based text editor with Lua configuration
- **Tmux** - Terminal multiplexer for managing multiple terminal sessions
- **Yabai** - Tiling window manager for macOS
- **Skhd** - Simple hotkey daemon for macOS keyboard shortcuts
- **Zsh** - Shell configuration with Oh My Zsh, Starship prompt, and Zoxide
- **Scripts** - Utility scripts for wallpaper management, Git setup, and QoL improvements

## Quick Start

```bash
# Clone the repository
git clone https://github.com/68mschmitt/dotfiles.git ~/.dotfiles
cd ~/.dotfiles

# Install dependencies (macOS only)
./setup.sh

# Deploy dotfiles using GNU Stow
./stow-dots.sh
```

## Installation

### 1. Install Dependencies

The `setup.sh` script automatically detects your platform and installs required packages:

```bash
./setup.sh
```

On macOS, this will:
- Install Homebrew if not present
- Install all packages listed in `mac/packages.list`
- Install formulae, casks, and Mac App Store apps via `mas`

Options:
- `--dry-run` - Preview actions without executing
- `--help` - Show usage information

### 2. Deploy Configurations

Use GNU Stow to symlink configurations to your home directory:

```bash
./stow-dots.sh
```

This creates symlinks for:
- Root-level packages (neovim, tmux, scripts, plover, my-wallpapers)
- macOS-specific packages (from `mac/` directory)

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
│   ├── skhd/              # Keyboard shortcuts
│   ├── yabai/             # Window manager settings
│   ├── .zshrc             # Shell configuration
│   ├── install-deps.sh    # Dependency installer
│   └── packages.list      # Homebrew packages
├── neovim/                # Neovim configuration
│   └── .config/nvim/
│       ├── lua/           # Lua configuration modules
│       ├── snippets/      # Code snippets
│       └── init.lua       # Main config entry point
├── tmux/                  # Tmux configuration
│   └── .tmux.conf
├── scripts/               # Utility scripts
│   └── .scripts/
│       ├── wallpaper-scripts/  # Dynamic wallpaper management
│       ├── git-related/        # Git setup utilities
│       ├── qol/                # Quality of life scripts
│       └── fun/                # Entertainment scripts
├── plover/                # Plover stenography dictionary
├── my-wallpapers/         # Wallpaper manager configs
├── setup.sh               # Platform-aware dependency installer
└── stow-dots.sh           # GNU Stow deployment script
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

Automatic wallpaper rotation with blacklist support:
- `set-random-wallpaper.sh` - Set random wallpaper from collection
- `blacklist-wallpaper.sh` - Add current wallpaper to blacklist
- `loop-wallpapers.sh` - Automatic rotation daemon
- Supports both macOS (AppleScript) and Linux (feh)

### Shell (Zsh)

Enhanced shell experience with:
- Oh My Zsh plugin framework
- Starship cross-shell prompt
- Zoxide smart directory jumping
- Syntax highlighting and autosuggestions
- Fastfetch system info on launch

Aliases:
- `tnotes` - Open second-brain vault in Neovim
- `cwp` - Change wallpaper
- `bwp` - Blacklist wallpaper

### Tmux

Terminal multiplexer configuration:
- `C-Space` prefix (instead of C-b)
- Vi mode keybindings
- Minimal status theme
- TPM plugin manager
- Image support for Neovim

## Package Management

### Homebrew Packages

All macOS dependencies are declared in `mac/packages.list`:

```
tap:koekeishiya/formulae
brew:neovim
brew:tmux
brew:stow
brew:ripgrep
brew:fzf
brew:starship
brew:zoxide
cask:docker-desktop
cask:kitty
```

To export current Homebrew packages:
```bash
./mac/export-brew-packages.sh
```

## Scripts

### Wallpaper Scripts

Located in `scripts/.scripts/wallpaper-scripts/`:
- Set random wallpaper from directory
- Blacklist unwanted images
- Initialize wallpaper configs
- Automated rotation loop

### Git Scripts

Located in `scripts/.scripts/git-related/`:
- `git-setup-personal.sh` - Configure personal Git settings

### QoL Scripts

Located in `scripts/.scripts/qol/`:
- `ytplay.sh` - Play YouTube videos
- `yt-audio.sh` - Download YouTube audio

### Fun Scripts

Located in `scripts/.scripts/fun/`:
- `cowsay-loop.sh` - Endless wisdom from the cow

## Customization

### Adding New Packages

Edit `mac/packages.list` using the format:
```
tap:tap-name
brew:formula-name
cask:cask-name
mas:app-name=app-id
```

Then run:
```bash
./setup.sh
```

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

- **macOS** (primary platform)
- **GNU Stow** (installed via setup.sh)
- **Homebrew** (installed automatically)

## Maintenance

### Update Packages

```bash
brew update && brew upgrade
```

### Refresh Symlinks

After making changes to the repository:
```bash
./stow-dots.sh --restow
```

### Backup Current Packages

```bash
./mac/export-brew-packages.sh > mac/packages.list
```

## Notes

- The repository uses GNU Stow for symlink management
- macOS-specific configs are isolated in the `mac/` directory
- Scripts are automatically made executable via `scripts/.scripts/init.sh`
- Neovim uses Lazy.nvim for plugin management
- Wallpaper scripts support both macOS and Linux

## License

Personal use. Feel free to fork and modify for your own setup.
