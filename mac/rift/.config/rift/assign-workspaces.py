#!/usr/bin/python3 -I
"""Auto-assign Rift global workspaces to whatever displays are connected.

  built-in display      -> workspaces 1-3
  1st external (by x)   -> workspaces 4-6
  2nd external          -> workspaces 7-9
  (no matching external -> falls back to the built-in display)

Rewrites the block between the BEGIN/END markers in ~/.config/rift/config.toml
(Rift hot-reloads it). Only writes when the assignment actually changes.
Triggered by sketchybar's display_change event and at Rift startup.
In the dotfiles repo a git clean filter (see .gitattributes) strips the generated
block, so display changes don't show up as diffs.
"""
import json, os, subprocess, sys, time

# realpath: the config is a stow symlink into ~/projects/dotfiles; write through it
# instead of replacing the link with a regular file.
CONFIG = os.path.realpath(os.path.expanduser("~/.config/rift/config.toml"))
RIFT_CLI = "/opt/homebrew/bin/rift-cli"
SYNC = os.path.expanduser("~/.config/sketchybar/plugins/rift_workspaces.sh")
PER_DISPLAY = 3
TOTAL = 9
BEGIN = "# BEGIN auto workspace_rules"
END = "# END auto workspace_rules"

def displays():
    out = subprocess.run([RIFT_CLI, "query", "displays"], capture_output=True, text=True, timeout=5)
    return json.loads(out.stdout) if out.returncode == 0 else None

def build_block(ds):
    externals = sorted(
        (d for d in ds if not (d.get("name") or "").startswith("Built-in")),
        key=lambda d: (d["frame"]["origin"]["x"], d["frame"]["origin"]["y"]),
    )
    lines = [BEGIN + " (managed by assign-workspaces.py, do not edit by hand)"]
    lines.append("# built-in: 1-%d" % PER_DISPLAY)
    for k, d in enumerate(externals[: TOTAL // PER_DISPLAY - 1], start=1):
        lines.append("# %s: %d-%d" % (d.get("name"), k * PER_DISPLAY + 1, (k + 1) * PER_DISPLAY))
    lines.append("workspace_rules = [")
    for ws in range(TOTAL):
        group = ws // PER_DISPLAY
        if group == 0 or group > len(externals):
            prefs = ["builtin"]
        else:
            prefs = [externals[group - 1]["uuid"], "builtin"]
        lines.append("  { workspace = %d, display = [%s] }," % (ws, ", ".join('"%s"' % p for p in prefs)))
    lines.append("]")
    lines.append(END)
    return "\n".join(lines)

def main():
    time.sleep(1)  # let macOS/Rift settle after a display change
    ds = displays()
    if not ds:
        return
    text = open(CONFIG).read()
    start, end = text.find(BEGIN), text.find(END)
    if start == -1 or end == -1:
        sys.exit("markers not found in " + CONFIG)
    end = text.index("\n", end) if "\n" in text[end:] else len(text)
    new = text[:start] + build_block(ds) + text[end:]
    if new != text:
        tmp = CONFIG + ".tmp"
        with open(tmp, "w") as f:
            f.write(new)
        os.replace(tmp, CONFIG)
        time.sleep(1)  # give Rift time to hot-reload
    if os.access(SYNC, os.X_OK):
        subprocess.run([SYNC])

if __name__ == "__main__":
    main()
