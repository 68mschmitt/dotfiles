# 🗂 Dotfiles

Personal dotfile management setup using [GNU Stow](https://www.gnu.org/software/stow/) to manage configuration files across macOS and Linux.  
This repository includes platform-specific configurations for macOS, plus scripts for automated package installation, wallpaper rotation, and various utilities.

> 💡 Special thanks to [Managing dotfiles with Stow — Andreas Venthur](https://venthur.de/2021-12-19-managing-dotfiles-with-stow.html) for the initial inspiration and structure.

---

## 📌 Features

### ✅ Dotfile Management with Stow
- Uses GNU Stow to symlink config files into `$HOME`
- Automatically detects **macOS vs Linux**
- Avoids deploying incompatible configs (e.g., ignores `mac/` on Linux)
- Dedicated `stow-dots.sh` script for flexible stowing with `--restow`, `--unstow`, `--adopt`, and `--dry-run` options

### ✅ Automated Dependency Installation (macOS)
- **`mac/install-deps.sh`** installs all Homebrew taps, formulae, casks, and Mac App Store apps listed in `mac/packages.list`
- **`mac/export-brew-packages.sh`** regenerates `mac/packages.list` from your current system state
- Supports `tap:`, `brew:`, `cask:`, and `mas:` prefixes for organized package management

### ✅ Wallpaper Management
- **`scripts/.scripts/wallpaper-scripts/set-random-wallpaper.sh`**: Picks a random wallpaper from `~/pictures/wallpapers` (recursive)  
  - Supports Linux (`feh`) and macOS (`osascript`)
  - Skips blacklisted images
- **`scripts/.scripts/wallpaper-scripts/blacklist-wallpaper.sh`**: Adds the current wallpaper to a blacklist
- **`scripts/.scripts/wallpaper-scripts/loop-wallpapers.sh`**: Automatically rotates wallpapers at intervals
- Central config loader (`_load_config.sh`) ensures consistent settings for all wallpaper scripts
- Config stored in `~/.config/my-wallpapers/`

### ✅ Additional Utilities
- **DWM scripts**: Status bar management and loop scripts for DWM window manager
- **Git utilities**: Personal Git setup script
- **Quality of life**: YouTube audio/video scripts using yt-dlp
- **Fun scripts**: cowsay loop and other entertaining utilities

### ✅ Unified Setup Scripts
- **`setup.sh`**: Detects platform and runs the correct dependency installers
  - On macOS → runs `mac/install-deps.sh`
  - `--dry-run` to preview actions
  - `--distro <name>` for Linux distro-specific installers (infrastructure ready for future use)
- **`stow-dots.sh`**: Manages dotfile symlinking with GNU Stow
  - `--restow` to refresh links
  - `--unstow` to remove links
  - `--adopt` to move existing configs into repo
  - `--dry-run` to preview changes

---

## 📂 Directory Structure

```
dotfiles/
├── setup.sh                          # Dependency installer bootstrapper
├── stow-dots.sh                      # GNU Stow wrapper for managing dotfiles
├── mac/                              # macOS-specific configs and packages
│   ├── skhd/                         # Simple hotkey daemon config
│   ├── yabai/                        # Yabai tiling window manager
│   ├── .zshrc                        # macOS-specific zsh config
│   ├── install-deps.sh               # Homebrew package installer
│   ├── export-brew-packages.sh       # Export current packages to list
│   ├── packages.list                 # Homebrew packages, casks, taps, mas apps
│   └── README.md
├── my-wallpapers/                    # Wallpaper config directory
│   └── .config/my-wallpapers/
│       ├── _load_config.sh
│       ├── .blacklist
│       ├── .current_wallpaper
│       └── .wallpaper_config
├── neovim/                           # Neovim configuration
│   └── .config/nvim/
│       ├── lua/
│       │   ├── configs/              # Plugin configurations
│       │   └── mike/                 # Personal configs
│       ├── snippets/
│       ├── spell/
│       ├── init.lua
│       └── lazy-lock.json
├── plover/                           # Plover stenography config
│   └── personal-dictionary.json
├── scripts/                          # Utility scripts
│   └── .scripts/
│       ├── wallpaper-scripts/        # Wallpaper management
│       │   ├── set-random-wallpaper.sh
│       │   ├── blacklist-wallpaper.sh
│       │   ├── loop-wallpapers.sh
│       │   ├── init-wallpaper.sh
│       │   └── pull-wallpapers.sh
│       ├── dwm/                      # DWM window manager scripts
│       │   ├── set-status-bar.sh
│       │   └── loop.sh
│       ├── git-related/              # Git utilities
│       │   └── git-setup-personal.sh
│       ├── qol/                      # Quality of life scripts
│       │   ├── yt-audio.sh
│       │   └── ytplay.sh
│       ├── fun/                      # Fun/entertainment scripts
│       │   └── cowsay-loop.sh
│       └── init.sh
└── tmux/                             # Tmux configuration
    └── .tmux.conf
```

---

## 🚀 Getting Started

### 1. Clone the repo

```bash
git clone https://github.com/68mschmitt/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
```

### 2. Deploy dotfiles with Stow

```bash
./stow-dots.sh
```

Or use `--restow` to refresh existing symlinks:

```bash
./stow-dots.sh --restow
```

### 3. Install dependencies (macOS)

```bash
./setup.sh
```

Or install directly:

```bash
cd mac
./install-deps.sh
```

---

## 📦 Maintaining Packages

### On macOS

Update the list after adding/removing packages:

```bash
cd mac
./export-brew-packages.sh
git add mac/packages.list
git commit -m "Update macOS packages list"
```

---

## 🖼 Wallpaper Management

### Set a random wallpaper

```bash
~/.scripts/wallpaper-scripts/set-random-wallpaper.sh
```

### Blacklist the current wallpaper

```bash
~/.scripts/wallpaper-scripts/blacklist-wallpaper.sh
```

### Loop wallpapers (auto-rotate)

```bash
~/.scripts/wallpaper-scripts/loop-wallpapers.sh
```

### Notes

- Images are stored in `~/pictures/wallpapers`
- Blacklisted files are tracked in `~/.config/my-wallpapers/.blacklist`
- Config values are centralized in `~/.config/my-wallpapers/.wallpaper_config`

---

## 🔄 Maintenance Workflow

1. **Make config changes locally** in the appropriate directory
2. **Restow** to apply changes:

   ```bash
   ./stow-dots.sh --restow
   ```

3. **Update package lists** when you install/remove software (macOS):

   ```bash
   cd mac && ./export-brew-packages.sh
   ```

4. **Commit changes** to keep everything in sync across machines

---

## 📝 Configuration Highlights

### Neovim
- Lua-based configuration with lazy.nvim
- LSP, DAP, Copilot, and more plugin configs
- Custom keymaps, statusline, and utilities
- Personal knowledge management (PKM) setup

### macOS Window Management
- **skhd**: Hotkey daemon for system-wide shortcuts
- **yabai**: Tiling window manager configuration

### Plover
- Personal stenography dictionary for Plover

### Tmux
- Custom tmux configuration for terminal multiplexing

---

## ⚠️ Notes

- Requires `stow` installed before running `stow-dots.sh`
- macOS dependency installs require Homebrew and an App Store login (for `mas:` apps)
- All scripts are idempotent — safe to re-run anytime
- Linux support infrastructure is in place but currently unused

---

## 📜 Credits

- **GNU Stow**: [https://www.gnu.org/software/stow/](https://www.gnu.org/software/stow/)
- **Inspiration**: [Managing dotfiles with Stow — Andreas Venthur](https://venthur.de/2021-12-19-managing-dotfiles-with-stow.html)
