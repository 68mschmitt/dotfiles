#!/usr/bin/env bash
# Combined tmux AI usage status: render Claude and/or OpenAI segments when the
# corresponding host-local auth exists. A trailing space is emitted only when at
# least one segment is present, so tmux time formatting stays clean.

set -uo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
out=""

append_segment() {
  local segment="${1:-}"
  [ -n "$segment" ] || return 0
  if [ -n "$out" ]; then
    out="$out  $segment"
  else
    out="$segment"
  fi
}

if [ -x "$SCRIPT_DIR/tmux-claude-status.sh" ]; then
  append_segment "$("$SCRIPT_DIR/tmux-claude-status.sh" 2>/dev/null || true)"
fi
if [ -x "$SCRIPT_DIR/tmux-openai-status.sh" ]; then
  append_segment "$("$SCRIPT_DIR/tmux-openai-status.sh" 2>/dev/null || true)"
fi

if [ -n "$out" ]; then
  printf '%s ' "$out"
fi
exit 0
