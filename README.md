# Dotfiles

Personal configuration files managed with GNU Stow.

## Overview

This repository contains configuration files for my development environment, including:

- **Neovim** - Modern Vim-based text editor with Lua configuration
- **Tmux** - Terminal multiplexer for managing multiple terminal sessions
- **Ghostty** - Terminal emulator configuration
- **Rift** - Tiling window manager for macOS (BSP, animations, no SIP changes) + all hotkeys
- **SketchyBar** - Menu bar with per-monitor Rift workspace labels and app icons
- **JankyBorders** - Accent-coloured border on the focused window
- **dim-unfocused** - Small Swift helper that dims unfocused windows
- **Pi** - Coding agent settings, extensions and prompts
- **Prime Agent** - Agent defaults and status extensions
- **Claude Code** - Global agent settings, statusline and subagents
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
`tmux`, `ghostty`, `scripts`, `plover`, `pi`, `prime`, `claude`), plus the macOS-specific
packages under `mac/` (`rift`, `sketchybar`, `borders`, `dim-unfocused`) when run on macOS. On first run it
also seeds the wallpaper config (`~/.config/my-wallpapers/`) automatically—
this one command is the entire setup, no follow-up steps required.

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
│   ├── rift/               # Tiling WM + hotkeys (.config/rift)
│   ├── sketchybar/         # Bar + Rift workspace plugin (.config/sketchybar)
│   ├── borders/            # JankyBorders focus border (.config/borders)
│   └── dim-unfocused/      # Swift dimming helper + installer (.config/dim-unfocused)
├── neovim/                 # Neovim configuration
│   └── .config/nvim/
│       ├── lua/             # Lua configuration modules
│       ├── snippets/        # Code snippets
│       └── init.lua         # Main config entry point
├── tmux/                   # Tmux configuration
│   └── .tmux.conf
├── ghostty/                # Ghostty terminal configuration
│   └── .config/ghostty/config
├── pi/                     # Pi coding agent configuration
│   └── .pi/
│       ├── agent/
│       │   ├── settings.json    # Core agent settings
│       │   ├── agents/          # Subagent definitions
│       │   ├── extensions/      # Custom TS extensions
│       │   ├── prompts/         # Prompt templates + assets
│       │   └── skills/          # Agent skills
│       └── voice/config.json    # pi-voice TTS settings
├── prime/                  # Prime Agent configuration
│   └── .prime/agent/
│       ├── settings.json          # Core agent settings
│       ├── extensions/            # Custom TS extensions
│       └── harness/               # Continual harness config
├── claude/                 # Claude Code (global) configuration
│   └── .claude/
│       ├── settings.json          # Global agent settings
│       ├── statusline-command.sh  # Statusline renderer
│       ├── statusline-usage.sh    # Background usage/credits fetcher
│       ├── agents/                # Subagent definitions
│       └── commands/              # Custom slash commands
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

Replaces the old yabai + skhd setup. Nothing here needs SIP disabled.

**Rift** (`mac/rift/.config/rift/config.toml`), tiling WM and all hotkeys:
- BSP layout, 0.25s animations, 50pt top / 20pt side gaps, 20pt inner gaps
- Focus follows the mouse; keyboard focus changes and window moves center the
  cursor on the newly focused window
- Global virtual workspaces: **1-3 built-in display, 4-6 / 7-9 external monitors
  left-to-right**. `assign-workspaces.py` auto-detects connected monitors and
  rewrites the `# BEGIN/END auto workspace_rules` block (triggered by
  SketchyBar's `display_change` and at Rift start). A git clean filter strips
  that block on commit so monitor changes don't create diffs (configured by
  `stow-dots.sh`).
- Hot-reloads on save; `run_on_start` changes need `rift service restart`

| Keys | Action |
|---|---|
| `cmd + arrows` | Focus window |
| `cmd + ctrl + arrows` | Move window in the tree |
| `cmd + ctrl + drag` | Mouse move (drop on center = swap, edge = insert) |
| `cmd + /` | Flip split orientation |
| `cmd + shift + arrows` | Resize: the edge moves in the arrow's direction (`resize.sh`) |
| `cmd + shift + e` / `space` | Balance / toggle float |
| `cmd + 1-9` | Switch to workspace |
| `cmd + shift + 1-9` | Send window to workspace and follow it (target becomes visible on its monitor) |
| `cmd + ctrl + 1-9` | Send window to workspace and stay: cursor doesn't move, focus goes to the window under it (`move-stay.sh`) |
| `cmd + tab` | Last workspace |
| `cmd + ctrl + shift + arrows` | Send window to monitor in that direction |
| `ctrl + alt + arrows` | Focus monitor in that direction |
| `alt + z` | Toggle tiling for the current space |
| `cmd + return` / `cmd + b` | Ghostty / Chrome |
| `cmd + ctrl + w` / `b` | Random wallpaper / blacklist wallpaper |
| `cmd + alt + d` / `w` | Dictation toggle / whisper mode |

**SketchyBar** (`mac/sketchybar`): rounded "islands" on a solid, theme-coloured
bar (palette in `colors.sh`). Every island shows identically on every monitor;
the workspaces island lists the workspaces of the monitor it sits on.

| Island | Contents | Click |
|---|---|---|
| Workspaces | per-monitor numbers + app icons (focused = accent, visible = dim, empty = grey) | switch |
| Rift state | layout (`bsp`), `float` for a floating window, binding mode in orange + front app | workspace windows (click = focus), layout switcher, actions |
| Date / time | | agenda: today/tomorrow, live meeting in green, one-click join |
| Meeting | "Standup in 12m" (orange <15m, red <5m), "· 8m left" in green during | join link, right-click agenda |
| Mic / camera | red mic / green camera while in use | |
| Badges | red bubble per app with a Dock badge (icon + count) | preview of its *unread* notifications (delivered since you last had that app in front) |
| Toast | new notification (Notification Center or GitHub: review requested, CI failed/passed) = pill + small card popup for 6s, paused while hovered | recent notifications across apps |
| Now playing | track — artist (grey when paused) | mini-player strip (artwork, prev/play/next, position); right-click play/pause, scroll = skip |
| GitHub | review requests (yellow when waiting) + your open PRs (icon = worst CI state) | review queue, your PRs with CI/review state (⌥-click = checks), notifications, refresh |
| AI usage | Claude credits % (+ Codex weekly % when its cache is fresh) | credit meter, Codex 5h/weekly windows with reset times, refresh |
| System | CPU, memory, free disk, network, volume, battery | CPU/memory/network: live graph + details + top processes (click focuses GUI apps); disk: usage, volumes (⌥-click ejects), Trash; volume: slider, mute, output device switcher (scroll = ±5%); battery: meter, health, energy users |

Everything hovers (accent tint) and animates (`--animate tanh`). Popups open on
**click only**, one at a time, on the monitor you clicked, and close 2s after
the mouse leaves the bar/popup (re-entering resets the timer). SketchyBar only
draws popups on the display with the active menu bar, so `lib.sh` first makes
the clicked display active: via Rift when it has windows (focus moves there),
otherwise with a click on its empty desktop (`helpers/bar_display.swift`).

**Notifications in the bar instead of banners:** the toast shows each new
notification. To stop macOS showing its own banner as well, turn on a Focus
(e.g. Do Not Disturb) or set each app's alert style to *None* in System
Settings › Notifications; notifications still land in Notification Center, which
is what the bar reads.

How it is fed (no shell runs on any hot path):
- `helpers/barsd/` (**barsd**, Swift + a small C Mach shim): every routed item has
  `mach_helper=git.felix.barsd`, so SketchyBar sends its events over Mach instead
  of forking a script. barsd does hover highlight, the popup auto-close timer,
  Rift workspace labels + Rift state, clock/date, front app (+ "last seen" per
  app) and Dock badges (Accessibility, in-process) natively, and forks the
  item's plugin from `~/.cache/sketchybar/routes.tsv` (written by `route` in
  `sketchybarrc`) only for clicks and rare events. Rift's subscriptions call
  `helpers/bin/bar_notify rift` (tiny C sender). Started by `sketchybarrc`.
- `helpers/event_providers/` C daemons (`cpu_load`, `network_load` from
  FelixKratz/dotfiles, `memory_load` in the same style) set the cpu/memory/
  network labels, colours and popup graphs directly over SketchyBar's Mach port
  (local "item" mode); built by `helpers/makefile` into `helpers/bin/`.
- `plugins/providers.sh` (hidden `power` item) restarts them and retunes
  polling for **AC / battery / Low Power Mode** (e.g. CPU every 2s / 5s / 10s, GitHub 2m / 5m / 15m;
  animations shorter on battery, off in Low Power Mode). It also follows the
  default network interface.
- `helpers/bar_events/` (`sketchybar-events` LaunchAgent, Swift): mic/camera
  via CoreAudio/CoreMediaIO listeners and the calendar via EventKit, written to
  `~/.cache/sketchybar/agenda.tsv`. Install with
  `~/.config/sketchybar/helpers/bar_events/install.sh`.
- `plugins/media_stream.sh` follows `media-control stream` (`brew install media-control`).
- `helpers/notifications/` (`sketchybar-notifications` LaunchAgent, Swift)
  mirrors Notification Center (read-only usernoted database) into
  `~/.cache/sketchybar/notifications.tsv` (mode 600) for previews and toasts.
  Install with `~/.config/sketchybar/helpers/notifications/install.sh`.
- `plugins/gh.sh`: one GraphQL query through `gh` (cached in `~/.cache/sketchybar/gh.json`).
- `plugins/ai.sh`: reads `~/.claude/.usage-cache.json` (refreshed via
  `scripts/tmux-claude-refresh.sh`, which throttles) and opencode's Codex cache.
- Popups share `lib.sh fill_popup` (row styles: header, section, muted, action, status).

Permissions: **Accessibility** for `sketchybar` (Dock badges, read by barsd), **Calendars**
for `sketchybar-events`, and **Full Disk Access** for
`~/.local/bin/sketchybar-notifications` only (notification previews; the
Notification Center database is FDA-protected). New Outlook keeps its calendar in the cloud, so the
meeting widget needs the work account added in System Settings > Internet
Accounts (Calendars on). `plugins/icon_map.sh` comes from sketchybar-app-font v3.0.27.

**JankyBorders** (`mac/borders`): 6pt rounded border in the theme accent on the
focused window. The animated rainbow (`rainbow.sh`) is off (`RAINBOW=on` in
`bordersrc` brings it back, AC power only).

**dim-unfocused** (`mac/dim-unfocused`): dims unfocused windows only (desktop,
menu bar, SketchyBar, Dock and notifications stay bright). After stowing, build
and register the login agent with:
```bash
~/.config/dim-unfocused/install.sh            # --alpha 0.15 --radius 16 --padding 8
```

**One-time setup on a new Mac** (Homebrew packages aren't managed by this repo):
```bash
brew install acsandmann/tap/rift jq
brew trust felixkratz/formulae
brew install felixkratz/formulae/sketchybar felixkratz/formulae/borders media-control switchaudio-osx
brew install --cask font-sketchybar-app-font font-hack-nerd-font
./stow-dots.sh
rift service install && rift service start   # grant Accessibility, then: rift service restart
brew services start sketchybar && brew services start borders
~/.config/dim-unfocused/install.sh
~/.config/sketchybar/helpers/bar_events/install.sh
~/.config/sketchybar/helpers/notifications/install.sh
```

### Wallpaper Management

Automatic wallpaper rotation with blacklist support, under
`scripts/.scripts/wallpaper-scripts/`:

- `init-wallpaper.sh` - One-time setup: seeds `~/.config/my-wallpapers/`
  from the checked-in defaults (run automatically by `stow-dots.sh` the
  first time; safe to re-run manually too)
- `set-random-wallpaper.sh` - Set random wallpaper from collection
- `blacklist-wallpaper.sh` - Add current wallpaper to blacklist
- `loop-wallpapers.sh` - Automatic rotation daemon
- `pull-wallpapers.sh` - Clone/update configured wallpaper source repos
- macOS only (uses `osascript`)

The checked-in files under `default-configs/` are just templates; your
actual config, blacklist, and current-wallpaper state live untracked in
`~/.config/my-wallpapers/` so day-to-day wallpaper changes never touch git.

### Pi Coding Agent

Only *declarative* pi config is tracked. Machine-local state and secrets stay
out of the repo (see `.gitignore`):

| Tracked | Deliberately untracked |
| --- | --- |
| `agent/settings.json` | `agent/auth.json` — **API credentials** |
| `agent/agents/`, `extensions/`, `prompts/`, `skills/` | `agent/sessions/`, `run-history.jsonl` — transcripts/logs |
| `voice/config.json` | `agent/trust.json` — per-machine trust decisions |
| | `agent/models-store.json`, `.claude-usage-cache.json`, `.openai-usage-cache.json` — caches |
| | `agent/npm/` — pi-managed installs of `settings.json` `packages` |
| | `voice/cache/`, `voice/manifest.json` — ~800MB TTS model weights |
| | `octo-review/` — review history + blind-spot profile (self-healing) |

After cloning, run `./stow-dots.sh`, then start pi once so it reinstalls the
declared `packages` and re-authenticates (`/login`).

### Prime Agent

Only declarative Prime Agent config is tracked. Machine-local state and secrets
stay out of the repo (see `.gitignore`):

| Tracked | Deliberately untracked |
| --- | --- |
| `agent/settings.json` | `agent/auth.json` — **API credentials** |
| `agent/extensions/` | `agent/sessions/`, `agent/session-artifacts/` — transcripts/kernel state |
| `agent/harness/` | `agent/logs/`, `agent/daemon-workers/`, `agent/session-leases/` — runtime state |
| | `agent/kernel-venv/` — generated Python environment |
| | `agent/telemetry.json`, `agent/.openai-usage-cache.json` — machine-local IDs/caches |

After cloning, run `./stow-dots.sh`, then start Prime Agent and authenticate
(`/login`).

### Claude Code

Global (`~/.claude`) config only — per-project `.claude/` dirs stay with their
own repos. `~/.claude` is a *real* directory that Claude Code fills with
runtime state, so this package deliberately does **not** fold it into a single
symlink: stow links only the tracked files below and leaves everything else
alone.

| Tracked | Deliberately untracked |
| --- | --- |
| `settings.json` | `projects/`, `sessions/`, `history.jsonl` — transcripts/state |
| `statusline-command.sh` | `~/.claude.json` — account, per-project history, MCP state |
| `statusline-usage.sh` | `daemon*`, `jobs/`, `shell-snapshots/` — runtime state |
| `agents/` — subagent definitions | `cache/`, `*-cache.json`, `policy-limits.json` — caches |
| `commands/` — custom slash commands | `remote-settings.json`, `settings.local.json` — server/per-machine |

`statusline-usage.sh` pulls the OAuth token from the macOS keychain
(`Claude Code-credentials`) on each fetch, so no credentials live in the repo,
but the credits segment of the statusline is macOS-only. After cloning, run
`./stow-dots.sh` and `claude` will pick up the settings on next launch — the
only manual step is authenticating (`/login`).

### Tmux

Terminal multiplexer configuration:
- `C-Space` prefix (instead of C-b)
- Vi mode keybindings
- Minimal status theme
- Claude/OpenAI usage segments that render only when host auth is present
- Image support for Neovim

The OpenAI metric prefers a local **Codex CLI** ChatGPT login when Codex and
Python 3 are installed. Run `codex login` and sign in to the same Plus/Pro account
you use in OpenCode. Quotas come from Codex's `account/rateLimits/read` API, which
refreshes its own OAuth credentials; no model requests are made. OpenCode's native
**Sign in with ChatGPT** token cannot read the legacy quota endpoint, and OpenCode
V2 no longer updates its old `auth.json` file.

Usage is cached in `$CODEX_HOME/.tmux-openai-usage-cache.json` (default
`~/.codex/.tmux-openai-usage-cache.json`) and refreshed in the background every two
minutes while the bar is visible. An expired/rejected login shows **OpenAI login
required** instead of old percentages; run `codex login` again to reconnect.
There are no hard-coded Plus/Pro allowances. Hosts without a Codex login retain
the legacy OpenCode/pi OAuth integration. `OPENAI_AUTH_PATH` or `PI_AUTH_PATH`
explicitly selects that legacy integration; `OPENAI_USAGE_CACHE_PATH` overrides
the cache location for either source.

Offline regression tests: `python3 -m unittest discover -s scripts/tests`.

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
- `cowfetch` - fastfetch with colorful cowsay ASCII art (via lolcat)
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
- **macOS** for the `mac/` packages (rift, sketchybar, borders, dim-unfocused) and the wallpaper scripts
  (they use `osascript`); the rest (neovim, tmux, ghostty, pi, claude, plover,
  git/qol/fun scripts) is platform-agnostic
- **jq** for the Claude Code statusline (`claude/.claude/statusline-*.sh`)

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
