---
name: man-mem
description: >-
  Save durable, project-scoped notes to the user's semi-manual memory bank at
  ~/projects/pi-man-mem — a LOCAL git repo kept OUTSIDE the current project's
  tree. Use ONLY when the user explicitly asks to save/record/remember something
  to memory: a research finding, an implementation plan, a discovery about how
  the codebase works, a lesson learned, or a gotcha/footgun. Every save is
  auto-committed. Capture only — there is no recall. Do NOT trigger this for
  routine work or without an explicit request from the user.
---

# man-mem — semi-manual memory bank (capture only)

Persist knowledge that should outlive a session, kept **outside** the current
project's repo. The bank is a **local-only git repo** at `~/projects/pi-man-mem`
(no remote — nothing is ever pushed), organized per project:

```
~/projects/pi-man-mem/<owner>/<repo>/
  research/      external findings, API/library facts, evaluations   (file per item)
  plans/         implementation plans and designs                     (file per item)
  discoveries/   facts about how THIS codebase actually works          (file per item)
  lessons.md     what worked / what to do differently next time        (appended)
  gotchas.md     traps, footguns, surprising constraints               (appended)
```

## When to use

Only on an **explicit** request to remember something — e.g. "save this as a
gotcha", "record this plan", "add a lesson", "put this in the memory bank".
This skill is **capture-only**: there is no recall step. The user pulls notes
back into a session by hand. Use it **sparingly**, for durable, high-signal
notes — not for routine progress updates.

## How to save (the ONLY sanctioned path)

Never create files under `~/projects/pi-man-mem` with the `write`/`edit` tools.
Always go through the script, so the note gets frontmatter **and is
auto-committed** in a single step:

```bash
~/.pi/agent/skills/man-mem/scripts/man-mem.sh save \
  --bucket <research|plans|discoveries|lessons|gotchas> \
  --title "<short title>" \
  [--tags "tag1, tag2"] \
  [--project <owner/repo>] <<'EOF'
<the markdown body of the note>
EOF
```

- The **body** is read from stdin — use a **quoted** heredoc (`<<'EOF'`) so the
  note text is taken literally (no shell expansion).
- Run it from the working project directory so the project key is detected.
- On success it prints the saved relative path and the commit hash.

### Choosing the bucket

| Bucket | Use when… | Storage |
|--------|-----------|---------|
| `research` | you looked something up externally (APIs, libraries, comparisons) | one dated file per note |
| `plans` | you produced an implementation plan or design | one dated file per note |
| `discoveries` | you traced/learned how *this* codebase actually works | one dated file per note |
| `lessons` | there's a "next time, do it this way" takeaway | appended to `lessons.md` |
| `gotchas` | there's a trap/footgun/surprising constraint to warn future-you | appended to `gotchas.md` |

## Project key

The note is filed under `<owner>/<repo>`, resolved in this order:

1. `--project <key>` if you pass it (one-off override).
2. A `.pi-man-mem` file in the project — its first non-comment line is the key.
3. The `origin` git remote of the working directory (parsed to `owner/repo`).

If none apply (not a git repo, or no `origin` remote), the script errors — pass
`--project <owner/repo>` explicitly. Ask the user for the key if it's unclear.

## Notes

- Local git repo, **no remote**; commits stay on this machine.
- First use auto-initializes the repo; each save is its own commit.
- Keep entries concise and high-signal — the bank is curated, not a log.
