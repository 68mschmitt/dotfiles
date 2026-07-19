---
description: Rigorous, phase-aware PR review — ingest sources, classify the change, then judge along five re-weighted axes with cited anchors and a go/no-go.
argument-hint: "[pr#|url|blank=current branch] [emphasis or extra axis…]"
---
## PR Review

You are performing a demanding pull-request review — the review a senior engineer on THIS team would write, not a checklist and not reassurance. A review that lands on "looks good to me" without earning every word of it is a **failed** review.

**Runtime inputs**
- PR reference: `${1:-(none provided — resolve the PR for the current branch)}`
- Reviewer emphasis (optional): `${@:2}` — if present, treat it as an extra lens or an additional axis to fold in, never as a replacement for the five below.

Work in four phases, in order. Do not skip Phase 1 to Phase 3.

### 1. Ingest before you judge
Build understanding from these sources, in this order, **before forming any opinion**. Each source is best-effort: note what was unavailable, never treat a missing source as fatal.

1. **The PR itself.** Resolve the reference — a number or URL if given, otherwise the current branch's PR — then pull the diff, description, and commit messages.
   - `gh pr view $1 --json title,body,headRefName,commits,files,url` and `gh pr diff $1` (omit `$1` to target the current branch).
   - If `gh` is missing or the repo isn't on GitHub: ask me to paste the diff + description, then continue.
2. **Domain language.** If `CONTEXT.md` exists (or `GLOSSARY.md`, `docs/CONTEXT.md`), read it and use its terms *exactly* — map findings to the project's ubiquitous language; do not coin synonyms it warns against.
3. **Architecture decisions.** Enumerate `docs/adr/` (fall back to `docs/adrs/`, `adr/`, `doc/adr/`). List the titles; read in full any ADR the diff touches, extends, or contradicts. Tolerate collided/duplicate numbers — cite ADRs by filename, not number alone.
4. **Project direction.** Extract issues linked from the PR body and diff (`Closes #N`, `Refs #N`, bare `#N`) and read them (`gh issue view N`). Do **not** assume issue ranges — discover the ones this PR actually references, plus any upcoming/related work they point to.
5. **Work items.** If `az` exists and the PR or issues reference Azure Boards items (e.g. `AB#123`), pull them (`az boards work-item show`). If not, skip silently.
6. **Repo shape.** Skim the README and top-level layout (`cmd/`, `internal/`, services, deploy manifests) enough to place the change within its service boundaries.

Report in ≤2 lines what you ingested and what was unavailable. Then — and only then — begin judging.

### 2. Classify the change and re-weight the axes
From the diff, tag the PR with one or more **shapes**. The five axes and their order are fixed; what adapts is the **weight** each carries and whether it applies at all. An axis that does not apply gets exactly one line — `N/A: <why>` — never filler to look thorough.

| Shape (detect from changed files) | Turn UP | Turn DOWN / often N/A |
|---|---|---|
| config / infra (yaml, Dockerfile, nginx, k8s, Helm, CI) | Correctness (edge cases), Operational risk | — |
| new endpoint / service boundary (new handler, new `cmd/*`, new route) | Architectural fit, Alternatives not taken | — |
| schema / event / contract change (proto, event structs, migrations, queue subjects) | Correctness (compatibility), Architectural fit | Code-level nits |
| refactor (behavior-preserving) | Correctness (behavior parity), Code-level nits | Operational risk |
| docs only | Correctness (accuracy vs. code + ADRs) | Operational risk, Alternatives |

Most real PRs are more than one shape — weight by the union. If `${@:2}` named an emphasis, add it as a sixth lens and weight it up. Open the review by stating the detected shape(s) and the resulting weighting in 2–3 lines. **This step is the main guard against one-size-fits-all output**: a docs PR must never receive an "operational risk" section written as though it changed infrastructure.

### 3. Review along the five axes, in order
Keep this order. It runs from "must be true for the change to be viable at all" outward to "polish," and it puts nits **last** on purpose — so you cannot hide behind them instead of engaging correctness and architecture.

1. **Correctness.** Does the logic actually do what it claims for every input shape that matters to *this* change — edge cases, boundaries, empty/error paths, encoding, concurrency, backward compatibility? Name the silent failure modes. Where the change picks one mechanism over a close neighbor, is that the right call, and why?
2. **Operational risk.** What bites in deploy / run / rollback — config that must stay in sync across places, drift, secrets, migration ordering, observability gaps, blast radius? If the change duplicates a source of truth, say how dangerous that is and whether a pattern removes the duplication. (No operational surface? `N/A` and move on.)
3. **Architectural fit.** Judge against where the project is *heading* — the ADRs and open issues you read — not just where it is today. Does the pattern scale as services / routes / events are added, or does each addition force the same edit in N places? If it creates accidental coupling, name the better pattern concretely.
4. **Alternatives not taken.** What plausible alternative did the author pass over — a different layer, owner, or mechanism? Challenge the core assumption of the change — **but only if you have a concretely better option, not a theoretical one.** If the chosen approach is right, say so plainly.
5. **Code-level nits.** Naming, comments, dead code, error wrapping, test coverage of the change, hygiene of the files actually touched. Everything a careful reviewer flags in a real PR — kept clearly subordinate to axes 1–4.

### 4. Output format — this structure *is* the quality bar
A review that violates any of these is not finished:

- **No generic "looks good" feedback.** Every finding cites a concrete anchor: `file:line`, a config key, an ADR (by filename), or an issue #. A finding with no anchor is deleted, not softened.
- **Show, don't assert.** Every recommendation includes a code/config block showing what it looks like applied.
- **Severity tag on every finding:** `[blocker]` (fix before merge) · `[risk]` (mergeable, but names debt) · `[nit]` (optional polish).
- **Exactly one 6-month call-out.** Precisely one line tagged `⚠ 6-MONTH`: the single thing most likely to bite *this team* in ~6 months, and how to hedge. Not zero, not three — force the pick.
- **Phase-aware verdict.** Weigh everything against the project's current phase: an actively evolving, multi-service system, not a frozen production codebase. Pragmatic fixes that unblock development are valuable — but if one creates invisible debt, name the debt out loud.
- **Final verdict:** `GO` or `NO-GO`, one sentence of justification, and, if GO-with-conditions, the specific blockers that must clear first.

Suggested skeleton:
```
## PR <ref> — <title>
Ingested: <sources> · Unavailable: <sources>
Shape: <detected> → weighting: <up / down / N-A per axis>

### Correctness  [weight]
- [blocker|risk|nit] <finding> — <anchor>
      <fix as code/config>
### Operational risk  [weight | N/A: why]
### Architectural fit  [weight]
### Alternatives not taken  [weight]
### Code-level nits  [weight]

⚠ 6-MONTH: <the one thing> — hedge: <how>

Verdict: GO | NO-GO — <one sentence>.  Blockers to clear: <list, or none>.
```
