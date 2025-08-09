# macOS Dotfiles — `mac/` Directory

This directory contains **macOS-specific configuration and helper scripts** for bootstrapping a new Mac and maintaining your package setup.

---

## 📂 Contents

- **`install-dependencies.sh`** — Installs all required Homebrew packages, taps, casks, and Mac App Store apps from a package list file.
- **`packages.list`** — A plain text list of all desired taps, Homebrew formulae, casks, and Mac App Store apps, in a machine-readable format.
- **`export-brew-packages.sh`** — Generates a new `packages.list` from the packages currently installed on your system.

---

## 🚀 Bootstrapping a New Mac

1. **Ensure you’re on macOS**  
   These scripts are **macOS-only**. Running them on Linux or Windows will fail intentionally.

2. **Run the dependency installer**  
   ```bash
   ./install-dependencies.sh
   ```
   This will:
   - Check that the OS is macOS
   - Ensure Homebrew is installed (installs it if not found)
   - Read `packages.list` and:
     - Tap any required brew taps
     - Install all missing brew formulae
     - Install all missing casks (GUI apps/fonts)
     - Install any missing Mac App Store apps (requires [`mas`](https://github.com/mas-cli/mas))

3. **Optional flags for `install-dependencies.sh`**
   - `--file <path>` — Use a different package list file instead of the default `packages.list`
   - `--dry-run` — Show what would be installed without making changes

   ```bash
   ./install-dependencies.sh --dry-run
   ./install-dependencies.sh --file mac/my-other-packages.list
   ```

---

## 📦 Maintaining `packages.list`

The `packages.list` file is the **source of truth** for what you want installed on your Mac.

### Adding new packages manually

Edit `packages.list` directly and add new entries in the appropriate section:

```text
# ---- taps ----
tap:homebrew/cask-fonts

# ---- brews (formulae) ----
brew:git
brew:jq

# ---- casks (GUI apps/fonts) ----
cask:iterm2

# ---- mac app store ----
mas:497799835  # Xcode
```

**Format rules:**
- `tap:<tap-name>`
- `brew:<formula>`
- `cask:<cask-name>`
- `mas:<app-id>` (optionally `mas:<app-name>=<app-id>`)

---

### Exporting your current system’s package list

You can regenerate a fresh package list from your current system at any time:

```bash
./export-brew-packages.sh
```

By default, this writes to `packages.list` in the current directory.  
You can specify a different output file:

```bash
./export-brew-packages.sh ~/Desktop/my-packages.txt
```

This is useful when:
- You’ve manually installed new packages outside the dotfiles workflow
- You want to sync your current system state into version control

**Tip:** After regenerating, review the diff before committing changes:

```bash
git diff mac/packages.list
```

---

## 🔄 Typical Maintenance Workflow

1. **Install missing packages on a fresh Mac**
   ```bash
   ./install-dependencies.sh
   ```

2. **Make changes locally**
   - Install new packages manually with `brew` or `mas`
   - Remove ones you don’t need

3. **Export an updated package list**
   ```bash
   ./export-brew-packages.sh
   ```

4. **Commit changes to your dotfiles repo**
   ```bash
   git add mac/packages.list
   git commit -m "Update macOS package list"
   ```

---

## ⚠️ Notes & Caveats

- **Mac App Store installs** require you to be signed in with your Apple ID in the App Store app before running `install-dependencies.sh`.
- `mas` only installs apps you already own/purchased.
- `brew` and `brew cask` installations are idempotent — running the installer multiple times won’t reinstall existing packages.
- These scripts are designed for **Apple Silicon and Intel Macs** — the installer auto-detects `/opt/homebrew` vs `/usr/local` brew paths.

---

## 🛠 Example One-Liner for Fresh Machine Setup

```bash
# Clone your dotfiles repo
git clone https://github.com/<your-username>/dotfiles.git ~/.dotfiles
cd ~/.dotfiles/mac

# Install everything from packages.list
./install-dependencies.sh

