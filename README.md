# 🗂 Dotfiles

A complete, OS-aware dotfile management setup using [GNU Stow](https://www.gnu.org/software/stow/) to manage configuration files across macOS and Linux.  
This repository includes **cross-platform** and **platform-specific** configurations, plus scripts for automated package installation, wallpaper rotation, and blacklist management.

> 💡 Special thanks to [Managing dotfiles with Stow — Andreas Venthur](https://venthur.de/2021-12-19-managing-dotfiles-with-stow.html) for the initial inspiration and structure.

---

## 📌 Features

### ✅ Cross-Platform Dotfile Management
- Uses GNU Stow to symlink config files into `$HOME`
- Automatically detects **macOS vs Linux**
- Avoids deploying incompatible configs (e.g., ignores `mac/` on Linux)
- Supports **distro-specific** Linux directories (`linux/arch`, `linux/gentoo`, `linux/ubuntu`)

### ✅ Automated Dependency Installation
- **macOS**:  
  - `mac/install-dependencies.sh` installs all Homebrew taps, formulae, casks, and Mac App Store apps listed in `mac/packages.list`
  - `mac/export-brew-packages.sh` regenerates `mac/packages.list` from your current system state
- **Linux**:
  - Each `linux/<distro>/` can contain its own `install-deps.sh` or `install-dependencies.sh` to install packages listed in a `packages.list`
  - Supports multiple distros side-by-side

### ✅ Wallpaper Management
- **`wallpapers/set-random-wallpaper.sh`**: Picks a random wallpaper from `~/pictures/wallpapers` (recursive)  
  - Supports Linux (`feh`) and macOS (`osascript`)
  - Skips blacklisted images
- **`wallpapers/blacklist-wallpaper.sh`**: Adds the current wallpaper to a blacklist so it’s never shown again
- `.blacklist` file stored in `~/.config/wallpapers/`
- Central config loader (`_load_config.sh`) ensures consistent settings for all wallpaper scripts

### ✅ Unified Setup Script
- **`setup.sh`** in the repo root:
  - Detects platform and runs the correct dependency installers
  - On macOS → runs `mac/install-deps.sh` (or `install-dependencies.sh`)
  - On Linux → runs installers for all `linux/<distro>/` directories, or only a specified one via `--distro`
  - Supports:
    - `--restow` (for dotfile redeployment)
    - `--unstow` (to remove links)
    - `--dry-run` (preview actions)
    - `--adopt` (move existing configs into repo)
    - `--distro <name>` (Linux only, run a specific distro’s installer)

---

## 📂 Directory Structure

```
dotfiles/
├── setup.sh                  # Root bootstrapper for stow + dependency installs
├── mac/
│   ├── install-dependencies.sh
│   ├── export-brew-packages.sh
│   ├── packages.list
│   └── README.md
├── linux/
│   ├── arch/
│   │   ├── install-deps.sh
│   │   └── packages.list
│   ├── gentoo/
│   ├── ubuntu/
│   └── ...
├── wallpapers/
│   ├── set-random-wallpaper.sh
│   ├── blacklist-wallpaper.sh
│   ├── _load_config.sh
│   ├── .wallpaper_config
│   └── .blacklist
└── <other config directories> # e.g., bash, zsh, nvim, git
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
./setup.sh --restow
```

### 3. Install dependencies

#### On macOS:

```bash
cd mac
./install-dependencies.sh
```

#### On Linux:

```bash
# Install for all distros with installers
./setup.sh

# Install for one distro only
./setup.sh --distro arch
```

---

## 📦 Maintaining Packages

### On macOS

* Update the list after adding/removing packages:

```bash
cd mac
./export-brew-packages.sh
git add mac/packages.list
git commit -m "Update macOS packages list"
```

### On Linux

* Edit `linux/<distro>/packages.list` as needed
* Rerun `install-deps.sh` in that directory

---

## 🖼 Wallpaper Management

### Set a random wallpaper

```bash
./wallpapers/set-random-wallpaper.sh
```

### Blacklist the current wallpaper

```bash
./wallpapers/blacklist-wallpaper.sh
```

### Notes

* Images are stored in `~/pictures/wallpapers`
* Blacklisted files are tracked in `~/.config/wallpapers/.blacklist`
* Config values are centralized in `~/.config/wallpapers/.wallpaper_config`

---

## 🔄 Maintenance Workflow

1. **Make config changes locally**
2. **Restow** to apply changes:

   ```bash
   ./setup.sh --restow
   ```
3. **Update package lists** when you install/remove software
4. **Commit changes** to keep everything in sync across machines

---

## ⚠️ Notes

* Requires `stow` installed before running `setup.sh`
* macOS dependency installs require Homebrew and an App Store login (for `mas:` apps)
* All scripts are idempotent — safe to re-run anytime

---

## 📜 Credits

* **GNU Stow**: [https://www.gnu.org/software/stow/](https://www.gnu.org/software/stow/)
* **Inspiration**: [Managing dotfiles with Stow — Andreas Venthur](https://venthur.de/2021-12-19-managing-dotfiles-with-stow.html)
