# octo-review reference: severity, blind-spot taxonomy, log schema

## Severity (4 levels)

| Tag     | Meaning                                                            |
|---------|-------------------------------------------------------------------|
| `BLOCK` | Correctness/safety: data loss, crash, security hole, broken build. Ship = regret. Always stated directly. |
| `FIX`   | Should-fix before merge: real bug on a plausible path, missing test for new behavior, contract violation. |
| `NIT`   | Style/taste/micro. Optional. This is the category the ratio watches. |
| `Q`     | Genuine question (Socratic or clarifying) — no assertion of a defect. |

The reviewer's `sev N <level>` overrides your tag and becomes ground truth for
future calibration. Never argue a tag.

## Blind-spot categories

Track misses at the granularity a senior engineer uses to name a *class* of bug
to a colleague — specific enough to direct the eye, general enough to show a
pattern in ~10 reviews. Not "security" (wallpaper), not "off-by-one in
kmalloc_array loops" (never accumulates). Start with these ~18; extend only when
a real miss genuinely doesn't fit, and split/retire a label once it goes stale.

- correctness/nil-deref-after-early-return
- correctness/off-by-one-boundary
- correctness/wrong-error-wrapping
- error-handling/cleanup-path        (leak/partial-state when a later step fails)
- error-handling/swallowed-error
- resource/unclosed-handle           (file, conn, ctx, rows)
- resource/unbounded-growth          (slice/map/goroutine)
- concurrency/lock-ordering
- concurrency/check-then-act-race
- concurrency/context-not-propagated
- sql/unbounded-query                (no LIMIT / N+1 / full scan)
- sql/missing-tx-boundary
- security/authz-check-absent
- security/input-validation-missing
- data/migration-backward-compat
- api/breaking-change-unflagged
- tests/new-behavior-untested
- clarity/misleading-name            (only when it can actually mislead)

## Tiers: automation ↔ Socratic (per category, per reviewer)

Compute miss-rate = missed / seen over the trailing 15 reviews for the category.
The line SHIFTS with the data — it is never fixed per domain.

| Miss-rate         | Delivery in `missed`                              |
|-------------------|---------------------------------------------------|
| > 60%             | one Socratic question (concrete scenario, ≤1 line, answerable from diff in ~15s — else fall back to direct) |
| 30–60%            | direct, terse, ≤6-word parenthetical *why*        |
| < 30% (mastered)  | silent unless it's a `BLOCK`                       |
| < 5 total reviews | everything direct; log marked provisional          |

`BLOCK` is always direct regardless of tier. Bias direct early: the tool earns
the right to ask questions only after it has data on the reviewer.

## Log: `~/.pi/octo-review/history.jsonl`

Source of truth. One JSON object per review, appended at `end`. Aggregate on
read (trailing window) — do not keep a separate rollup that can drift.

```json
{"date":"2026-06-01","repo":"org/app","pr":1234,
 "touched":["sql/unbounded-query","error-handling/cleanup-path"],
 "caught":["error-handling/cleanup-path"],
 "missed":["sql/unbounded-query"],
 "dismissed":[],
 "severity":{"block":1,"fix":2,"nit":6,"q":1},
 "socratic_impatience":["security/authz-check-absent"]}
```

Field meaning:
- `touched` — categories this PR's diff plausibly exercised (denominator for "seen").
- `caught` — reviewer flagged it themselves before `missed` (a win — surface in `stats`).
- `missed` — pi found it, reviewer had not commented (the training signal).
- `dismissed` — reviewer said `na N`; do NOT count as missed, and downweight the
  category for false-positive proneness.
- `socratic_impatience` — categories where reviewer hit `t`; evidence of mastery,
  nudge the category toward direct.

## `stats` output

Show trend, not a data dump. Improvement is the dopamine — make it visible:
```
authz-check-absent   missed 5/5 -> 1/4   improving
unbounded-query      missed 3/4 -> 3/4   flat (still weak)
caught-before-pi:    cleanup-path x4, nil-deref x2
```
