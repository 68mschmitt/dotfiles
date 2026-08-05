---
description: Map a repo's domain model as a navigable web page of typed diagrams
argument-hint: "[scope, focus area, or 'whole repo']"
---
## Domain Mapping

Map the domain model of this repository as a set of navigable diagrams, delivered
as a self-contained web page. Scope: **${@:-the entire repository}**.

You are not writing documentation. You are producing a **map someone will read
before they change something**, so that they change the right thing. Its value is
proportional to how many surprises it contains.

---

### The governing rule: DERIVE, DON'T ASSUME

Everything below describes *classes of thing* to look for. Some will not exist in
this repo. **When a category is absent, say so explicitly and show what you
checked — never invent an instance to fill a section.** "This system has no
temporal relationships; every join is unconditional" is a valuable finding. A
fabricated temporal diagram is worse than no diagram.

Equally: **when you find a category the checklist below does not name, add a
section for it.** The checklist is a floor, not a ceiling.

---

## Phase 1 — Establish the source of truth (before drawing anything)

Do not draw a single box until you know which artifact is authoritative, because
domain models hide in different places in different stacks.

**Enumerate the candidate authorities.** Look for all of these that exist:

- Schema/DDL, migrations, `schema.rb`, `.sql`, IaC table definitions
- ORM models, entity classes, repositories, DAOs, active-record classes
- Type definitions: TypeScript interfaces, dataclasses, structs, Pydantic models
- Interface contracts: OpenAPI/Swagger, GraphQL SDL, protobuf, Avro, JSON Schema
- Serializers, DTOs, presenters, view models, API resource classes
- Config schemas, env var contracts, feature flag definitions
- Event/message payload shapes, queue contracts, webhook bodies
- Fixtures, factories, seed data, test builders — often the *only* honest record
  of a shape nothing else declares
- Grammars, DSLs, template languages, query builders, rule engines
- Prose docs and READMEs — treat as **claims to verify, not evidence**

**Then rank them and justify the ranking.** State which artifact wins and why.
Common answer: the runtime-enforced artifact beats the declarative one; the thing
that would break production if wrong beats the thing that would only break a
build.

**Produce a reconciliation table:**

| Declared entity | Where declared | Where enforced at runtime | Storage / transport | Drift found |
|---|---|---|---|---|

Both directions of absence are findings and must appear as rows:
- **Declared but never enforced** (a type nothing validates, a table no code reads)
- **Enforced but never declared** (a shape only fixtures reveal, a column only raw SQL touches)

**Verify prose against code.** If a README or doc comment describes behaviour,
check it. Documentation that is confidently wrong is a trap for the next reader
and is one of the highest-value findings you can report. Quote the wrong claim and
show the code that contradicts it.

---

## Phase 2 — Find the disjoint domains and refuse to merge them

**Most repos hold two or more domains with incompatible semantics, and a single
diagram silently merges them into something that is true of neither.** Your job is
to find the seams and diagram each side in a notation that fits.

Look for splits along these axes — several usually apply at once:

| Axis | One side | Other side |
|---|---|---|
| **Lifetime** | persisted, has identity, survives restarts | ephemeral, no identity, exists only within one request/job/frame |
| **Authorship** | configured by humans at design time | produced by machines at run time |
| **Identity** | keyed, addressable, referenceable | positional, anonymous, structural |
| **Substrate** | relational, one datastore | documents, cache, queue, blob, third-party API, another datastore |
| **Trust** | internal, validated | external, hostile, unvalidated |
| **Layer** | core domain | infrastructure, transport, presentation |

**The domain most likely to be missing from any existing docs is the one with no
class file.** Payload shapes, message contracts, config trees, template variable
namespaces, CLI argument structures, DSL binding scopes, event bodies. These are
frequently *more* consequential than the entities that do have classes, because
nothing type-checks them. Reconstruct them from grammars, serializers, iteration
code, fixtures, and tests. **Diagram them. Their absence from `models/` is not a
reason to omit them; it is the reason to include them.**

Then, for each domain, **pick a notation that fits its actual structure and
justify the choice in one sentence:**

- `erDiagram` — keyed entities with cardinal relationships
- `flowchart` — containment trees, binding scopes, pipelines, dependency graphs
- `stateDiagram-v2` — lifecycles, status machines, workflow states
- `sequenceDiagram` — cross-boundary protocols, ordering-sensitive interactions
- `flowchart` with `subgraph` — deployment/process/trust/tenancy boundaries
- `classDiagram` — behavioural hierarchies where inheritance is load-bearing

Forcing an ER diagram onto a containment tree is the single most common way these
maps go wrong. If a domain isn't relational, don't draw it relationally — say why.

---

## Phase 3 — Find the seam and make it the centerpiece

Somewhere in this repo, **two of the domains from Phase 2 must agree, and nothing
verifies that they do.** Find it. It is where the next bug will come from.

Seams look like:
- a stored/cached artifact whose assumptions about a live shape are frozen at write time
- a name in a string resolved against a registry populated elsewhere
- a serialized structure deserialized by code that evolved independently
- a schema version implied but never checked
- a contract that two services each believe the other validates
- a generated artifact checked into the repo, regenerated by a manual step

For the seam you pick, produce a **lifecycle flowchart** tracing the full path:
authoring → transformation → persistence → retrieval → binding → effect. Mark the
exact node where verification is absent.

**Then characterize the failure mode, and this is the part that matters most:**

- Does it fail **loud** (throws, alerts, 500s) or **silent** (returns a plausible
  wrong answer)?
- Which direction does it fail — **closed** (blocks work) or **open** (permits
  what should be blocked)?
- Is the silent-failure value **distinguishable from a legitimate result?** If
  not, this is the top finding in the entire document and should be stated in the
  opening paragraph.

Systems frequently fail closed on crashes and open on drift. Check for that
asymmetry specifically.

---

## Phase 4 — Type every edge

**No undifferentiated lines.** Every relationship gets classified, and the class
must be visible on the diagram itself, not only in prose. Build a legend and use
it consistently.

Adapt this taxonomy to what the repo actually has:

| Class | Meaning |
|---|---|
| **Constraint-enforced** | The datastore/type system rejects violations (FK, unique, NOT NULL, non-nullable type, exhaustive match) |
| **Application-enforced** | Code validates it before writing; bypassable via another writer |
| **Unenforced** | Nothing checks it anywhere. Violations are possible and usually silently absorbed on read. |
| **Temporal** | Valid only within a time window, version range, or feature-flag state |
| **Conditional** | Exists only for certain subtypes, roles, tenants, or config states |
| **Cyclic-by-design** | Self-referencing; cycles reachable |
| **Cross-substrate** | Endpoints in different stores/services. **Unjoinable by any single query.** |
| **Implicit-via-identifier** | Reference is a string/name/path resolved at runtime |
| **Eventually-consistent** | Correct only after an async process completes |
| **Derived** | Not stored; recomputed on read, so it can silently disagree with its source |

**State the count of real, datastore-enforced constraints explicitly.** If it is
zero or near-zero:
1. Say so in the **first paragraph** of the document.
2. Explain **what upholds integrity instead** (read-side filtering, application
   validation, single-writer discipline, convention, luck).
3. **Argue the case that the absence is load-bearing before calling it a
   defect.** Legitimate reasons include: cross-store composition that cannot be
   constrained; blob-first/document-first persistence where relational tables are
   a rebuilt projection; soft-delete semantics that constraints would break;
   non-transactional multi-step writes where a constraint converts "stale, self-heals"
   into "fails, cannot heal"; deliberate write-availability trade-offs; multi-writer
   architectures. Weigh each against this repo's evidence and say which apply.
   Only then recommend — and prefer *detection* over *constraints* where adding
   constraints would make currently-succeeding writes newly fallible.

If any edge is **date-, version-, or flag-scoped**, standard notation cannot
express it. **Invent notation, define it in the legend, and show how the code
resolves the guard** (which query, which branch, what happens when the guard input
is null/absent — that null case is usually a bug).

If any structure is **self-referencing**, determine whether it is a tree, a DAG,
or a cyclic graph **in storage** versus **as traversed**. Find every cycle guard,
compare their semantics, and **trace a diamond (A→B, A→C, B→D, C→D) through each.**
Multiple guards with different scoping (global vs per-branch visited sets) is
common and means different parts of the system disagree about the shape of the
same data. Say whether the divergence is intended.

If any dependency is **encoded in strings** (function names, plugin ids, template
keys, event types, permission strings, dynamic imports): that graph is real. **Try
to extract it.** If it's machine-extractable, extract it and show the script. If
not, say precisely why. Then answer: **can anything in this codebase detect a
reference to something that no longer exists?** Trace what actually happens on a
missing target — the error path is often broken in a way that misattributes the
failure.

---

## Phase 5 — Dual representations, boundaries, and vocabulary

**Dual representations.** Wherever the same information is stored twice —
normalized column plus JSON blob, cache plus source, denormalized counter plus
count, index plus table, local copy plus remote — enumerate for each entity:
which fields are duplicated, which exist in only one representation (and are
therefore unqueryable/invisible from the other), and which can diverge.
**Then answer precisely: which representation wins on read — and is the answer the
same on every read path?** Different paths preferring different copies is a live
bug. Name the specific write that would split them, including writers outside
this repo.

**Boundaries, not edges.** Where isolation is *physical* rather than relational —
separate database per tenant, per-region deployment, process/service boundary,
trust boundary, sandbox, security context — **draw it as a boundary that encloses,
not an arrow that connects.** There is often no column to relate to. Then answer:
**where could a scoping bug cross it?** Look specifically at: caches keyed on
partial identity, connection/client pools reused across scopes, module-level
singletons and memoization, shared registries consulted from inside a scoped
operation, values that let a request override its own scope, and defaults that
collapse a missing identifier to a shared empty key.

**Ubiquitous language audit.** Find every concept with more than one name, and
every name meaning more than one concept (homonyms are worse than synonyms).
Check across: code identifiers, datastore names, API field names, UI strings,
config keys, log/metric labels, test names, and docs. Recommend **one term per
concept**, then split the renames:

- **Cheap** — internal identifiers, unused exports, dead constants, private
  helpers. Note anything with zero references; deleting beats renaming.
- **Frozen** — shipped schema, public API contracts, persisted enum values,
  external consumers, log/metric names with dashboards attached, anything already
  written into stored data.

State the cost honestly. A rename that requires migrating stored data is not cheap.

---

## Phase 6 — Verify by execution

**Do not ship claims you have not tested when testing is possible.** Prove at
least three non-obvious assertions by running code, and show the actual output:

- Run a real traversal/resolver against a constructed input to prove graph behaviour
- Execute a parser/compiler/serializer on a crafted case to prove what it produces
- Load a constants module and print the resolved values to check for shadowing,
  gaps, duplicate keys, or off-by-one enum drift
- Feed a deliberately broken input through a validator to prove what it *doesn't* catch
- Query real data if a dev/test datastore is available

Use throwaway scripts in a temp dir; never modify the repo to test it. When
execution is impossible (no runnable env, requires prod credentials, needs live
data), say so and record it in Phase 8 with the artifact that would settle it.

Also run the repo's own test suite or linter if cheap — a failing test is a finding.

---

## Phase 7 — Rank by blast radius

Close the analysis with **the three relationships most likely to break silently
under change, ranked by blast radius.** For each:

1. **What breaks** and the file:line of the mechanism
2. **The specific change that triggers it** — a concrete edit, migration, rename,
   deploy, or upstream change, not "if someone is careless"
3. **Why it is silent** — what the system reports instead of an error
4. **Blast radius** — one record, one tenant, one endpoint, or everything

Rank by *silence × reach*, not by how easy each is to fix. A total-reach silent
failure outranks a loud one every time.

---

## Phase 8 — State what you could not determine

A table of open questions, each with **the specific artifact, query, or command
that would settle it.** Vagueness here undermines everything above; "would need
more investigation" is not an entry. "The output of `<exact query>` against a
production replica" is.

Include anything that depends on: runtime/production state, data volume or
distribution, deployment topology, values in secret stores, external service
behaviour, or human intent recorded only in tickets and PRs.

---

## Deliverables

Write both, to `docs/domain-map/` (create it; adjust if the repo has an
established docs convention):

1. **`domain-map.md`** — the document. Single source of truth, reviewable in a PR diff.
2. **`index.html`** — the navigable viewer, which **embeds the Markdown inline**
   so it works by double-clicking the file with no server and no CORS problems.

### Building the viewer

A tested viewer scaffold is at
`~/.pi/agent/prompts/assets/domain-map-viewer.html`. **Copy it, then make exactly
these edits — do not rewrite its JavaScript:**

1. Replace `__TITLE__` (twice), `__DATE__`, and `__COMMIT__` (use `git rev-parse --short HEAD`).
2. Replace everything between the `<script id="doc" type="text/markdown">` tags
   with the full contents of `domain-map.md`.

It provides: sidebar TOC auto-built from `##`/`###` with scroll-spy, section
filter, per-figure source/copy/expand, zoom-and-pan fullscreen, dark mode, print
stylesheet, per-diagram error isolation, and a no-network fallback.

**Hard constraints on the embedded Markdown:**

- It must not contain the literal string `</script>`. If content requires it,
  write `<\/script>`.
- Diagram fences must be exactly ```` ```mermaid ```` at line start — the splitter
  is a line-anchored regex.
- Heading text becomes both nav label and anchor slug. Keep `##` headings short
  and unique.

**Offline/air-gapped repos:** download `mermaid.esm.min.mjs` and `marked.esm.js`
into `docs/domain-map/vendor/` and set `<html data-vendored="true">`. The loader
then prefers local copies and falls back to CDN.

### Validate before declaring done

Mermaid syntax errors are easy to introduce and render as an error box rather
than a crash, so they survive casual review. **Extract every diagram and validate
each one:**

```bash
mkdir -p /tmp/dmv && cd /tmp/dmv && rm -f *.mmd *.svg
python3 - <<'PY'
import re, pathlib
src = pathlib.Path("docs/domain-map/domain-map.md").read_text()
blocks = re.findall(r"^```mermaid[ \t]*\r?\n(.*?)^```[ \t]*$", src, re.S | re.M)
for i, b in enumerate(blocks, 1):
    pathlib.Path(f"/tmp/dmv/d{i:02d}.mmd").write_text(b)
print("blocks:", len(blocks), "| fences balanced:", src.count("```") % 2 == 0)
PY
for f in /tmp/dmv/*.mmd; do
  npx --yes @mermaid-js/mermaid-cli@11 -i "$f" -o "${f%.mmd}.svg" >/dev/null 2>/tmp/dmv/err.txt \
    && echo "OK   $(basename $f)" \
    || { echo "FAIL $(basename $f)"; grep -i -A2 "error" /tmp/dmv/err.txt | head -4; }
done
```

**Fix every FAIL before finishing.** Known Mermaid traps:
- Backslash-escaped quotes inside an edge label (`-. "a \"b\"" .->`) is a parse
  error — use single quotes or `#quot;`.
- `#`, `(`, `)`, `{`, `}`, `<`, `>` inside node text need `"…"` quoting.
- `<br/>` for line breaks, never a literal newline.
- Reserved words (`end`, `graph`, `class`, `style`) as bare node ids break parsing.
- Naive brace-counting reports false imbalance in `erDiagram` — crow's-foot `o{`
  contributes a `{`. Trust `mmdc`, not the count.

Then confirm the page works. If Chrome is available, load it headlessly and assert
the SVG count matches the block count and no `.diag-error` boxes remain.
Otherwise open it and check visually. Report: number of diagrams, number of
sections, and validation status.

---

## Quality bar — self-check before you finish

Reject your own draft if:

- [ ] It draws any relationship the code does not actually enforce without labeling it unenforced.
- [ ] It presents a gateway/repository/serializer layer **as** the domain model rather than as an accessor over it.
- [ ] It omits entities that have no class file (payloads, messages, config trees, DSL scopes).
- [ ] It merges two domains with different lifetimes into one diagram.
- [ ] Every arrow looks the same.
- [ ] It treats a missing safeguard as an oversight without first arguing the case that the absence is deliberate.
- [ ] It contains a section invented to satisfy this template rather than derived from the repo.
- [ ] Any Mermaid diagram fails to render.
- [ ] Any claim about behaviour could have been tested by running code and wasn't.
- [ ] A file:line citation is wrong. **Spot-check them; line numbers drift as you edit.**
- [ ] "Open questions" contains an entry with no named settling artifact.

Correct the framing you were given — including the framing in this template — if
the repo contradicts it. **Put the correction in the output rather than quietly
complying.** A disagreement between two artifacts is a finding, never a detail to
smooth over.
