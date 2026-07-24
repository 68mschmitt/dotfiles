---
name: octo-review
description: >
  Co-review a GitHub PR that is open in octo.nvim, from a split-screen pi TUI.
  Pi is a co-reviewer and coach, NOT a review generator: it stays silent while
  you review, then shows only what you MISSED, adapts its delivery to your
  measured blind spots, and gets quieter as you improve. Use when reviewing a
  PR beside octo.nvim ("review this PR with me", "octo review", "co-review").
---

# octo-review

A "mirror with memory" for PR review. It does not hand you a finished review —
that trains nothing and breeds dependence. It catches what you missed, makes the
pattern visible over time, and trains itself out of a job per topic as you
master it.

Read `references/taxonomy.md` (blind-spot categories, severity defs, log schema)
before your first `missed` or `end`.

## One-time setup

1. Source the nvim bridge so octo can hand pi the current PR. Add to your nvim config:
   ```lua
   vim.cmd('luafile ' .. vim.fn.expand('~/.pi/agent/skills/octo-review/scripts/octo-dump.lua'))
   ```
   This registers `:PiOctoDump` and an autocmd that writes `.pi/octo-ctx.json`
   as you move through octo buffers (keeps the two halves in sync with no keystroke).
2. Verify tooling once: `gh auth status && command -v jq`.
3. State lives in `~/.pi/octo-review/` (blind-spot profile, history) — global, it
   follows you across repos. `.pi/octo-ctx.json` is per-project and ephemeral
   (add to `.gitignore`).

## How pi sees the PR (context acquisition)

Pi cannot read nvim state directly. The split is deliberate:
- **Which PR + where you are** ← octo (`.pi/octo-ctx.json`, written by the bridge).
- **What the PR is** (diff, existing threads, CI, metadata) ← `gh` CLI, keyed by
  that number. gh is stable and complete; it does not couple to octo internals.

Use `scripts/octo-ctx.sh`:
```bash
scripts/octo-ctx.sh where            # resolved {repo, number, file, line}
scripts/octo-ctx.sh pr               # PR summary: files±, CI, reviewDecision, existing comments
scripts/octo-ctx.sh diff [file]      # unified diff, whole PR or one file
```
If `where` fails to find a number: tell the user to focus the octo PR buffer and
run `:PiOctoDump` (or pass a number: `octo-ctx.sh pr 1234`).

## The loop

The four commands you run daily. Everything else is refinement.

### `start`
Run `octo-ctx.sh pr`. Emit, in ≤6 lines total:
1. One-line PR frame: title, `+adds/-dels`, N files, CI state, reviewDecision.
2. **Blind-spot priming** — read history (see taxonomy §log), map this PR's
   touched areas to the reviewer's weak categories:
   ```
   touches: sql (query.go), async (worker.go)
   watch:  sql/unbounded-query  missed 3/4
           error-handling/cleanup-path  missed 5/7
   ```
   If <5 prior reviews: print `blind-spot log: provisional (N reviews)` and
   suppress ratios. Never show confident stats from sparse data.
Then STOP. Do not review yet. The reviewer reviews in octo.

### (during review) — stay silent
Do not volunteer findings. Run your own analysis in the background so you can
compute the delta later, but emit nothing until asked.

### `missed [file]`
The core mechanic. Read what the reviewer already flagged
(`octo-ctx.sh pr` → `existing_inline_comments` + their `reviews`), compare to
your own findings on the diff (`octo-ctx.sh diff [file]`), and show **only the
delta** — things they did NOT already cover. Scope to `file` if given.

Delivery is adaptive per category, driven by the reviewer's measured miss-rate
(taxonomy §tiers):
- **weak (>60% missed)** → one Socratic question. Must be answerable from the
  diff in ~15s (name the concrete scenario, e.g. `worker.go:88 — what happens
  when items is empty?`). If you can't make it that tight, fall back to direct.
- **medium (30–60%)** → direct, terse, with a ≤6-word parenthetical *why*.
- **mastered (<30%)** → silent. Say nothing.
- **blocker** → always direct, regardless of tier.

Also surface `existing_inline_comments` from other reviewers only if they change
your read (agree/conflict) — one line, not a dump.

### `end`
Emit the **severity mirror** (one line) and append a history record (taxonomy §log):
```
this PR: 1 blocker · 2 should-fix · 6 nits · trailing 68% nit
```
Then append the review to `~/.pi/octo-review/history.jsonl`. This is silent
bookkeeping — no other output.

## Refinements (offer, don't front-load)

- `draft N` — paste-ready octo comment text for finding N. You place it. **Never auto-post.**
- `why N` — expand reasoning when a Socratic question stumped you.
- `na N` — dismiss finding N as not-applicable; recorded so it stops training a phantom weakness.
- `sev N <blocker|fix|nit|q>` — reclassify; YOUR call becomes ground truth for calibration.
- `t` — drop Socratic to direct for this reveal (impatience is mastery data; note it).
- `stats` — growth trend: which categories are improving, calls you got right before pi.

## Output format (narrow pane, ~80 cols)

One finding per line, ranked by severity, max 5 shown at once (`more` for the rest):
```
BLOCK  worker.go:88   unsynced write, data loss on crash
FIX    query.go:142   n+1 (items unbounded)
Q      auth.go:31     token refresh during check — what races here?
```
Severity glyphs: `BLOCK` / `FIX` / `NIT` / `Q`. No prose paragraphs. The *why*
rides in the parenthetical or the question. Questions only for weak categories.

## Guardrails (these are the point — do not soften)

- **Never emit a finished/ranked full review.** You surface the *delta* after the
  reviewer commits their own pass. Refuse "just review it for me"; offer `missed` instead.
- **Never auto-post** into octo. You draft; the human authors and places.
- **Never defend a severity tag.** If the reviewer disagrees, take `sev N` as truth
  and move on. The ratio is a mirror, not a judge.
- **A bad Socratic question is worse than none.** Vague gestures ("have you
  considered error handling?") read as condescension to a competent engineer and
  get the tool disabled. Concrete-scenario-or-direct.
- **Get quieter over time.** If output volume in week 4 equals week 1, the loop
  is failing. Mastered categories → silence.
- **The log is only as good as your findings.** Honor `na`/`sev`/`t` as
  error-correction so you don't train attention toward phantom weaknesses.
