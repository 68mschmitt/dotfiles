#!/usr/bin/env bash
# octo-ctx.sh — hand the PR that is open in octo.nvim to pi, via gh.
#
# octo answers the small stable question (which PR / where am I) through
# .pi/octo-ctx.json; gh answers the heavy question (diff, threads, CI, meta).
#
#   octo-ctx.sh where            resolved {repo, number, file, line}
#   octo-ctx.sh pr [number]      PR summary JSON (+ existing inline comments)
#   octo-ctx.sh diff [number] [file]   unified diff, whole PR or one file
set -euo pipefail

STATE_DIR="${PI_OCTO_STATE:-$HOME/.pi/octo-review}"
CTX_FILE="${PWD}/.pi/octo-ctx.json"
mkdir -p "$STATE_DIR"

die() { echo "octo-ctx: $*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

have gh || die "gh not found (brew install gh)"
have jq || die "jq not found (brew install jq)"

# Resolve "repo|number|file|line". Order: octo-ctx.json -> live nvim -> gh branch.
resolve_identity() {
  local repo="" number="" file="null" line="null"

  if [[ -f "$CTX_FILE" ]]; then
    repo=$(jq -r '.repo // empty'   "$CTX_FILE" 2>/dev/null || true)
    number=$(jq -r '.number // empty' "$CTX_FILE" 2>/dev/null || true)
    file=$(jq -r '(.file // "null")|tostring' "$CTX_FILE" 2>/dev/null || echo null)
    line=$(jq -r '(.line // "null")|tostring' "$CTX_FILE" 2>/dev/null || echo null)
  fi

  # Best-effort live refresh if pi runs inside an nvim :terminal ($NVIM set).
  if [[ -z "$number" && -n "${NVIM:-}" ]] && have nvim; then
    nvim --server "$NVIM" --remote-send '<C-\><C-N>:PiOctoDump<CR>' >/dev/null 2>&1 || true
    sleep 0.15
    if [[ -f "$CTX_FILE" ]]; then
      repo=$(jq -r '.repo // empty'   "$CTX_FILE" 2>/dev/null || true)
      number=$(jq -r '.number // empty' "$CTX_FILE" 2>/dev/null || true)
    fi
  fi

  # Fall back to the PR for the current branch.
  [[ -z "$number" ]] && number=$(gh pr view --json number -q .number 2>/dev/null || true)
  [[ -n "$number" ]] || die "no PR number (focus the octo PR buffer + :PiOctoDump, or pass a number)"
  [[ -z "$repo" ]] && repo=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)

  printf '%s|%s|%s|%s\n' "$repo" "$number" "$file" "$line"
}

cmd_where() {
  local id; id=$(resolve_identity)
  IFS='|' read -r repo number file line <<<"$id"
  jq -n --arg repo "$repo" --arg number "$number" --arg file "$file" --arg line "$line" \
     '{repo:$repo, number:($number|tonumber? // $number), file:$file, line:$line}'
}

cmd_pr() {
  local override="${1:-}" id repo number file line
  id=$(resolve_identity); IFS='|' read -r repo number file line <<<"$id"
  [[ -n "$override" ]] && number="$override"

  local view=(pr view "$number" --json \
    number,title,url,author,headRefName,baseRefName,additions,deletions,changedFiles,files,reviewDecision,statusCheckRollup,comments,reviews,isDraft,mergeable)
  [[ -n "$repo" ]] && view+=(--repo "$repo")
  local pr_json; pr_json=$(gh "${view[@]}")

  local threads="[]"
  if [[ -n "$repo" ]]; then
    threads=$(gh api "repos/$repo/pulls/$number/comments" --paginate 2>/dev/null \
              | jq -s 'add // []' 2>/dev/null || echo "[]")
  fi

  jq -n --argjson pr "$pr_json" --argjson threads "$threads" \
        --arg file "$file" --arg line "$line" \
     '{pr:$pr, existing_inline_comments:$threads, position:{file:$file, line:$line}}' \
     | tee "$STATE_DIR/ctx.$number.json"
}

cmd_diff() {
  local override="${1:-}" target="${2:-}" id repo number file line
  # allow `diff <file>` with no number
  if [[ -n "$override" && ! "$override" =~ ^[0-9]+$ ]]; then target="$override"; override=""; fi
  id=$(resolve_identity); IFS='|' read -r repo number file line <<<"$id"
  [[ -n "$override" ]] && number="$override"

  local args=(pr diff "$number")
  [[ -n "$repo" ]] && args+=(--repo "$repo")

  if [[ -n "$target" ]]; then
    gh "${args[@]}" | awk -v f="$target" '
      /^diff --git / { p = (index($0, f) > 0) }
      p { print }'
  else
    gh "${args[@]}"
  fi
}

case "${1:-pr}" in
  where) cmd_where ;;
  pr)    shift || true; cmd_pr  "${1:-}" ;;
  diff)  shift || true; cmd_diff "${1:-}" "${2:-}" ;;
  *)     die "unknown subcommand '$1' (use: where | pr | diff)" ;;
esac
