# Event providers

Small C daemons that push metrics to SketchyBar over its Mach port (no shell
process per update). Started/restarted by `plugins/providers.sh` with
power-source dependent intervals.

- `cpu_load`, `network_load`, `sketchybar.h`: copied from FelixKratz/dotfiles
  (`.config/sketchybar/helpers/event_providers`, commit 67ad686), GPL-3.0.
  Only local change: `network.h` scans IFMIB rows 1..count (1-based), so the
  last interface (e.g. a dock's ethernet) is found.
- `memory_load`: written here in the same style (Activity Monitor style
  "memory used" = app + wired + compressed).

Build with `make -C ~/.config/sketchybar/helpers` (binaries land in `bin/`).
