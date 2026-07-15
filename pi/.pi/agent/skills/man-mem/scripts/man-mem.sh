#!/usr/bin/env bash
# man-mem.sh — capture-only, project-scoped memory bank with auto-commit.
#
# Writes a markdown note into ~/projects/pi-man-mem (a LOCAL git repo, no remote)
# under <owner>/<repo>/<bucket>, then commits it. Capture only; no recall.
#
# Usage:
#   man-mem.sh init
#   man-mem.sh save --bucket <bucket> --title "<title>" \
#       [--project <owner/repo>] [--tags "a, b"] [--cwd <dir>]   # body on stdin
#
# Env:
#   PI_MAN_MEM_DIR   override bank location (default: ~/projects/pi-man-mem)

set -euo pipefail

BANK="${PI_MAN_MEM_DIR:-$HOME/projects/pi-man-mem}"
BUCKETS="research plans discoveries lessons gotchas"
APPEND_BUCKETS="lessons gotchas"

die() { echo "man-mem: error: $*" >&2; exit 1; }

usage() {
  cat >&2 <<'USAGE'
Usage:
  man-mem.sh init
  man-mem.sh save --bucket <research|plans|discoveries|lessons|gotchas> \
      --title "<title>" [--project <owner/repo>] [--tags "a, b"] [--cwd <dir>]
  # the note body is read from stdin (use a quoted heredoc)

Buckets:
  research     external findings, API/library facts, evaluations   (file per item)
  plans        implementation plans and designs                     (file per item)
  discoveries  facts about how THIS codebase actually works         (file per item)
  lessons      what worked / what to do differently next time       (appended)
  gotchas      traps, footguns, surprising constraints              (appended)
USAGE
  exit 2
}

in_list() {
  # in_list <needle> <space-separated-haystack>
  local needle=$1 word
  for word in $2; do
    if [ "$word" = "$needle" ]; then return 0; fi
  done
  return 1
}

slugify() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/-+/-/g; s/^-//; s/-$//'
}

bucket_label() {
  case "$1" in
    research)    echo "Research" ;;
    plans)       echo "Plans" ;;
    discoveries) echo "Discoveries" ;;
    lessons)     echo "Lessons" ;;
    gotchas)     echo "Gotchas" ;;
    *)           echo "$1" ;;
  esac
}

sanitize_key() {
  local key=$1 seg IFS
  if [ -z "$key" ]; then die "empty project key"; fi
  case "$key" in
    /*)   die "project key must be relative, got: $key" ;;
    *..*) die "project key must not contain '..': $key" ;;
  esac
  key=${key%/}
  IFS='/'
  for seg in $key; do
    if [ -z "$seg" ]; then die "project key has an empty path segment: $1"; fi
    if ! printf '%s' "$seg" | grep -Eq '^[A-Za-z0-9._-]+$'; then
      die "project key segment has invalid characters: $seg"
    fi
  done
  printf '%s' "$key"
}

resolve_key_from_git() {
  local dir=$1 url repo rest owner
  url=$(cd "$dir" 2>/dev/null && git remote get-url origin 2>/dev/null) || return 1
  if [ -z "$url" ]; then return 1; fi
  url=${url%.git}
  # drop scheme://, drop user@, turn scp ':' into '/'
  url=$(printf '%s' "$url" | sed -E 's#^[a-zA-Z]+://##; s#^[^/@]*@##; s#:#/#')
  repo=${url##*/}
  if [ -z "$repo" ]; then return 1; fi
  rest=${url%/*}
  if [ "$rest" = "$url" ]; then
    printf '%s' "$repo"; return 0
  fi
  owner=${rest##*/}
  if [ -n "$owner" ]; then
    printf '%s/%s' "$owner" "$repo"
  else
    printf '%s' "$repo"
  fi
}

read_marker() {
  local dir=$1 root f line
  root=$(cd "$dir" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null || true)
  for f in "$dir/.pi-man-mem" "${root:+$root/.pi-man-mem}"; do
    if [ -z "$f" ] || [ ! -f "$f" ]; then continue; fi
    line=$(sed -e 's/#.*//' -e 's/[[:space:]]//g' "$f" | grep -m1 . || true)
    if [ -n "$line" ]; then printf '%s' "$line"; return 0; fi
  done
  return 1
}

ensure_identity() {
  local email name
  email=$(git -C "$BANK" config user.email 2>/dev/null || true)
  name=$(git -C "$BANK" config user.name 2>/dev/null || true)
  if [ -z "$email" ]; then git -C "$BANK" config user.email "pi-man-mem@localhost"; fi
  if [ -z "$name" ]; then git -C "$BANK" config user.name "pi-man-mem"; fi
}

bootstrap() {
  if [ -d "$BANK/.git" ]; then ensure_identity; return 0; fi
  mkdir -p "$BANK"
  git -C "$BANK" init -q
  ensure_identity
  if [ ! -f "$BANK/.gitignore" ]; then printf '.DS_Store\n' > "$BANK/.gitignore"; fi
  if [ ! -f "$BANK/README.md" ]; then
    cat > "$BANK/README.md" <<'READ'
# pi-man-mem

Semi-manual, project-scoped memory bank. A **local** git repo (no remote).
Written to only via the `man-mem` pi skill; every write is auto-committed.
Capture only — notes are pulled back into a session by hand.

Layout: `<owner>/<repo>/{research,plans,discoveries,lessons.md,gotchas.md}`
READ
  fi
  git -C "$BANK" add -A
  if ! git -C "$BANK" diff --cached --quiet; then
    git -C "$BANK" commit -q -m "man-mem: initialize bank"
  fi
}

git_commit() {
  local msg=$1 tries=0
  while [ -f "$BANK/.git/index.lock" ] && [ "$tries" -lt 10 ]; do
    sleep 0.3; tries=$((tries + 1))
  done
  if [ -f "$BANK/.git/index.lock" ]; then
    die "bank git index is locked (another session?); file was written but NOT committed"
  fi
  git -C "$BANK" add -A
  if git -C "$BANK" diff --cached --quiet; then
    echo "man-mem: nothing changed; no commit"
    return 0
  fi
  git -C "$BANK" commit -q -m "$msg"
}

cmd_init() {
  bootstrap
  echo "man-mem: bank ready at $BANK"
}

cmd_save() {
  local bucket="" title="" project="" tags="" cwd="$PWD"
  while [ $# -gt 0 ]; do
    case "$1" in
      --bucket)  bucket=${2:-}; shift 2 ;;
      --title)   title=${2:-}; shift 2 ;;
      --project) project=${2:-}; shift 2 ;;
      --tags)    tags=${2:-}; shift 2 ;;
      --cwd)     cwd=${2:-}; shift 2 ;;
      -h|--help) usage ;;
      *) die "unknown argument: $1" ;;
    esac
  done

  if [ -z "$bucket" ]; then echo "man-mem: --bucket is required" >&2; usage; fi
  if [ -z "$title" ]; then echo "man-mem: --title is required" >&2; usage; fi
  if ! in_list "$bucket" "$BUCKETS"; then die "invalid bucket '$bucket' (expected: $BUCKETS)"; fi

  local key=""
  if [ -n "$project" ]; then
    key=$project
  elif key=$(read_marker "$cwd"); then
    :
  elif key=$(resolve_key_from_git "$cwd"); then
    :
  else
    die "could not determine project key: no --project, no .pi-man-mem marker, and no git 'origin' remote in '$cwd'. Pass --project <owner/repo>."
  fi
  key=$(sanitize_key "$key")

  bootstrap

  local body today now dir target relpath label
  body=$(cat)
  today=$(date "+%Y-%m-%d")
  now=$(date "+%Y-%m-%dT%H:%M:%S%z")
  dir="$BANK/$key"
  label=$(bucket_label "$bucket")

  if in_list "$bucket" "$APPEND_BUCKETS"; then
    target="$dir/$bucket.md"
    mkdir -p "$dir"
    if [ ! -f "$target" ]; then
      printf -- '---\ntitle: %s — %s\nproject: %s\nbucket: %s\ncreated: %s\n---\n\n# %s — `%s`\n' \
        "$label" "$key" "$key" "$bucket" "$now" "$label" "$key" > "$target"
    fi
    local meta
    meta=$(printf '_added: %s' "$today")
    if [ -n "$tags" ]; then meta=$(printf '%s · tags: %s' "$meta" "$tags"); fi
    meta=$(printf '%s · last-verified: %s_' "$meta" "$today")
    {
      printf '\n## %s — %s\n' "$today" "$title"
      printf '%s\n\n' "$meta"
      printf '%s\n' "$body"
    } >> "$target"
    relpath="$key/$bucket.md"
  else
    mkdir -p "$dir/$bucket"
    local slug base n fm
    slug=$(slugify "$title")
    if [ -z "$slug" ]; then slug="untitled"; fi
    base="$today-$slug"
    target="$dir/$bucket/$base.md"
    n=2
    while [ -e "$target" ]; do
      target="$dir/$bucket/$base-$n.md"; n=$((n + 1))
    done
    fm=$(printf -- '---\ntitle: %s\nproject: %s\nbucket: %s\ncreated: %s' \
      "$title" "$key" "$bucket" "$now")
    if [ -n "$tags" ]; then fm=$(printf '%s\ntags: [%s]' "$fm" "$tags"); fi
    fm=$(printf '%s\n---' "$fm")
    printf '%s\n\n# %s\n\n%s\n' "$fm" "$title" "$body" > "$target"
    relpath=${target#"$BANK"/}
  fi

  git_commit "man-mem($key/$bucket): $title"
  local hash
  hash=$(git -C "$BANK" rev-parse --short HEAD 2>/dev/null || echo "?")
  echo "man-mem: saved $relpath  [$hash]"
}

main() {
  local sub=${1:-}
  case "$sub" in
    init)         shift; cmd_init "$@" ;;
    save)         shift; cmd_save "$@" ;;
    ""|-h|--help) usage ;;
    *)            die "unknown subcommand '$sub' (expected 'init' or 'save')" ;;
  esac
}

main "$@"
