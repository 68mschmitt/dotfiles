#!/usr/bin/env bash

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BOLD='\033[1m'
RESET='\033[0m'

success=0
failed=0
skipped=0

while IFS= read -r gitdir; do
  repo_dir="$(dirname "$gitdir")"
  repo_name="$(basename "$repo_dir")"

  branch=$(git -C "$repo_dir" branch --show-current 2>/dev/null)
  printf "\n${BOLD}── %s${RESET} [${GREEN}%s${RESET}]\n" "$repo_name" "$branch"

  # Skip repos with uncommitted changes
  if ! git -C "$repo_dir" diff --quiet 2>/dev/null || ! git -C "$repo_dir" diff --cached --quiet 2>/dev/null; then
    printf "${YELLOW}  ⚠ skipped (uncommitted changes)${RESET}\n"
    ((skipped++))
    continue
  fi

  old_head=$(git -C "$repo_dir" rev-parse HEAD 2>/dev/null)

  if git -C "$repo_dir" pull --quiet 2>/dev/null; then
    new_head=$(git -C "$repo_dir" rev-parse HEAD 2>/dev/null)
    if [ "$old_head" = "$new_head" ]; then
      printf "${GREEN}  ✓ already up to date${RESET}\n"
    else
      stat=$(git -C "$repo_dir" diff --shortstat "$old_head" "$new_head")
      printf "${GREEN}  ✓${RESET} %s\n" "$stat"
    fi
    ((success++))
  else
    printf "${RED}  ✗ pull failed${RESET}\n"
    ((failed++))
  fi
done < <(find . -maxdepth 2 -name .git -type d | sort)

printf "\n${BOLD}Done:${RESET} ${GREEN}%d pulled${RESET}, ${YELLOW}%d skipped${RESET}, ${RED}%d failed${RESET}\n" "$success" "$skipped" "$failed"
