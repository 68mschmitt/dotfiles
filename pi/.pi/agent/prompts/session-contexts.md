---
description: Compile this session into durable reference docs under second-brain/session-contexts
argument-hint: "[theme slug or focus hint]"
---
## Compile session context

Compile this session into durable reference documents. Theme hint: **${@:-derive it from the session}**.

A session's value evaporates when it ends: the hard-won insights, the why behind decisions, the dead ends that must not be re-walked. Produce a small set of reference documents that a future session (or human) can load cold. You are a distiller, not a logger — write up what mattered, never replay what happened.

Mid-session invocation is fine (compile what exists so far). If the session contains nothing durable (no real work, decisions, findings, or corrections), say so in one line and stop.

## File layout

All artifacts live under `~/projects/second-brain/session-contexts/`:

```
~/projects/second-brain/session-contexts/
  {project}/                    # basename of git root, else basename of the cwd pi ran in
    {lesson-theme}/             # slug of the session's dominant theme, e.g. pi-skill-authoring
      README.md                 # index: what this dir covers, doc map, smaller notes, session log
      reasoning-and-intent.md   # between-the-lines record: goals, decisions, corrections, open threads
      insight--{slug}.md        # 1–5 files, each ONE cohesive insight written up in full
```

These are living reference docs, not dated snapshots: a later session on the same theme updates them in place. Provenance lives in each file's frontmatter and the README's session log.

Doc templates (read them before writing):

- `~/.pi/agent/prompts/assets/session-contexts/index.md` → `README.md`
- `~/.pi/agent/prompts/assets/session-contexts/insight.md` → each `insight--{slug}.md`
- `~/.pi/agent/prompts/assets/session-contexts/reasoning-and-intent.md` → `reasoning-and-intent.md`

## What qualifies as an insight

Mine the session for durable, non-obvious knowledge that was produced or uncovered:

- Root causes found while debugging, and the evidence trail that exposed them.
- How a system, API, or tool *actually* behaves — verified in-session, especially where it defied expectation or documentation.
- Working procedures: command sequences or approaches that succeeded, plus the gotcha that made naive attempts fail.
- Environment specifics: this machine, this repo, this toolchain.
- Design rationale that generalizes beyond the one change it justified.

Every candidate must pass all three tests, or be discarded:

1. **Durable** — still true and relevant in a month.
2. **Time-saving** — a fresh session or human would demonstrably benefit from knowing it up front.
3. **Session-grounded** — traceable to something that actually happened in this session.

Exclude: routine edits, generic knowledge any model already has, anything the diff or existing docs already state plainly, ephemeral state (open PRs, current failures mid-fix).

## What to read between the lines

The `reasoning-and-intent.md` doc captures what is invisible in the code and the insight docs. Extract:

1. **Intent** — what the user was actually after, behind the literal requests. What prompted the session; what "done" looked like to them.
2. **Decisions** — each consequential choice: what was picked, why, which alternatives were considered or rejected, and the signal in the session that settled it.
3. **Course corrections** — every place the user redirected the work. Each one reveals a preference, a constraint, or a misunderstanding worth not repeating.
4. **Unstated constraints** — limits that bound the solution but were never spoken as requirements (compatibility, environment, style, risk tolerance).
5. **Open threads** — what was deferred or left unfinished, and what a future session should pick up first.

This doc explicitly deals in inference. Label every inferred item `(inferred)`; treat user-stated items as facts. Never present a guess as a quote.

## Steps

1. Resolve the project and date:
   ```bash
   project=$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")
   today=$(date +%Y-%m-%d)
   ```
2. Mine the session in two passes: first insights (section above), then between-the-lines (section above). List candidates, apply the three tests, discard failures.
3. Pick a lesson-theme slug from the dominant subject of what survived (e.g. `pi-skill-discovery`, never `misc-fixes` or `session-work`). Honor the theme hint above if one was given. If the session genuinely contains two unrelated lessons, make two theme directories, each complete with its own README and reasoning doc — but prefer one; split only when a single slug would be a junk drawer.
4. Check for an existing theme directory:
   ```bash
   ls ~/projects/second-brain/session-contexts/"$project"/"$theme"/ 2>/dev/null
   ```
   - **Missing** → create it and write fresh docs from the templates.
   - **Exists** → read every doc in it first, then merge: update existing docs where this session adds or corrects (rewrite the affected section — do not append contradictions), add new `insight--*.md` files only for genuinely new insights, and append to the README session log. When the session disproves an existing claim, the newer finding wins; keep one line noting the correction ("Previously recorded X; session {date} showed Y").
5. Write the docs from the templates listed above, following the writing rules below.
6. Self-check each doc before finishing:
   - Reads standalone: no "as discussed above", no reference to the session's conversation flow.
   - Every claim is session-grounded; every inference is labeled.
   - No secrets: API keys, tokens, credentials, and private URLs from the session are replaced with `{REDACTED}`.
7. Report to the user: each written or updated file path with a one-liner, and note that a future session can be pointed at the theme's `README.md` to load the context.

## Writing rules

- **One insight per file.** If a write-up covers two unrelated claims, split it. If an insight has under ~15 lines of substance, demote it to a bullet in the README's Smaller notes instead of a file.
- **Titles are claims, not topics.** "pi discovers skills from four locations, but root .md files from only two" — not "Skill discovery".
- **Organize by theme, never chronology.** The only chronological text allowed is the README session log.
- **Prose first.** Each insight doc is a cohesive write-up that makes its case in paragraphs; bullets only for genuinely list-shaped data.
- **Evidence verbatim.** Include the actual commands, error messages, file paths, and code snippets from the session that ground each claim — enough for a skeptical future reader to re-verify.
- **State the boundaries.** Each insight records what it does *not* cover and what was not verified.
- **No fabrication.** Nothing goes in a doc that did not come from the session. Never invent citations or URLs.
- **Target 40–120 lines per insight doc.** Compression is the job: a doc nobody will read is a failure.
