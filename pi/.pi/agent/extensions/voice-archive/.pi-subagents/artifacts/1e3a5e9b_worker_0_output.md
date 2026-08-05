Done. Everything cleaned up (the three remaining `/tmp/va-*` files are the other implementers', not mine).

Implemented spec §1–§4 in `ui.html` (371 → 845 lines, additive; dark theme, naming and comment register preserved; zero dependencies).

**Changed files:** `pi/.pi/agent/extensions/voice-archive/ui.html` only. `index.ts` and `server.mjs` untouched (`git status` shows the dir untracked as a whole; I only wrote `ui.html`).

## What was built

**§1 status** — `pollStatus()` every 1000 ms → `applyStatus()`, which writes *only* into reserved `[data-stat]` spans. Colours: summarizing `#bb9af7`, speaking `--voice`, archiving `--accent`, idle `--dim`; `@keyframes statpulse` applied via `.stat:not(.p-idle):not(.stalled) .sdot` so idle is a steady dot. `stalled` → `.stalled` grey + `⚠` + wedge-explaining `title`. Header gets `.stat.big` plus `detail` and `queue N` when > 0.

**§2 pairing** — `pairTimeline(items)` folds the flat list into `{type:"item"}` / `{type:"group"}` nodes; grouped assistants are skipped standalone, notes stack when they share a source, group sits at the first note's timestamp. Disclosure is native `<details class="src">` (custom ▸/▾, marker hidden), collapsed by default, state mirrored into `openGroups` so it survives the 15 s timeline refresh too.

**§3 sidebar** — `groupSessions(list, mode, categories)`; `#groupMode` select persisted in `va.groupMode`, collapse set in `va.collapsedGroups`. Inline rename (Enter commits, Escape/blur cancels, empty clears). `catOptionsHTML` with `Uncategorized` + `New category…`. `patchSessionMeta()` reconciles local state then re-renders the sidebar with `scrollTop` saved/restored; header updated via `refreshHeaderMeta()` — never `renderSession()`.

**§4 autoQueue** — header checkbox + `autoQueueNote(voiceCoverage)`. Verified `GET /api/health → voiceCoverage: "every"`, so the live note reads *"every response is already voiced by your global voice config — this adds nothing right now"* in amber; `final`/`none` render as normal active notes.

## Validation (exact commands + real output above)

- `node --check` on the extracted `<script>` — **OK** (re-run on the final file after every edit).
- Static markup tag-balance check outside `<script>`/`<style>` — **balanced**. `$("id")` audit — no `MISSING`.
- `/tmp/va-ui-test.mjs` (pure logic vs. real curl payloads): **41/41 PASS**. Actual output included: fixture folds to `user u1 → group a1[n1] → user u2 → group a2[n2]`, a1/a2 never standalone; 231 sessions → 32 directory buckets (`~/.pi` 29, `/private/tmp` 32, `~/projects/dotfiles` 17 …), all bucketed exactly once, recency-ordered; real 91-msg session `019fd2c6…` → 116 items → 116 nodes, all 23 notes still rendered; `summarizing` → `cls="stat p-summarizing" label="summarizing" q=2`; `idle` → `stat p-idle` (no pulse rule); `stalled` → `stat p-summarizing stalled`; unknown phase degrades to idle.
- `/tmp/va-render-test.mjs` (real `renderGroup`/`voiceBody`/`assistantBody`/`statusHTML`): **33/33 PASS**, full rendered HTML printed for `openGroups=[]` and `["a1"]` — 2 `<details>`, 2 `data-voice="1"` anchors (so `j`/`k` and play-all still see each note), each body text once, both `<audio>` with session-prefixed URLs, `♪ read aloud` present 4×, `<div class="item assistant">` count 0.
- **Escaping proof:** `<img src=x onerror=alert(1)>` pushed through the *real* `sessHTML`/`groupHTML`/`catOptionsHTML` as session name, derived title, cwd and category name — printed output shows only `&lt;img src=x onerror=alert(1)&gt;`; payload never appears verbatim.
- **Live route checks** on port 8193 (started clean after `lsof … | xargs -r kill -9`, log confirmed): `GET /` serves the new file byte-identical; health/status/meta/sessions/session all 200; `n1.opus` 200, 8816 bytes, `OggS` magic; traversal blocked. `PATCH` round-trips verified: name set → `displayName` override, `{"name":""}` → `name:null` and `displayName` back to derived title, `autoQueue` true/false. Fixture status temporarily given a live pid → `/api/status` returned `phase:"summarizing", queueDepth:2, stalled:false`; backdated 4 min → `stalled:true`. Original fixture status file restored byte-for-byte; `ui-meta.json` restored to `{v:1,categories:[],sessions:{}}`; server killed, port free.
- **Poll-never-renders-timeline** proved structurally: `renderSession()` has exactly two call sites (`openSession`, and the 15 s refresh when item count changes); `pollStatus` → `applyStatus` only.

## Deviations / ambiguities to flag

1. **`idle` gets the word "open"**, not a bare dot. A dot with no label in a row of text reads as noise; the dot is still steady and dim.
2. **Category-group ordering is unspecified** in §3. I used most-recently-active first (matching directory mode) with `Uncategorized` pinned last.
3. **Added `safeColor()`, not in the spec.** The server stores `color` verbatim — I confirmed `"red;background:url(http://evil/x)"` round-trips through `POST /api/categories` and `GET /api/meta`. `esc()` prevents attribute-breaking but not CSS injection into a `style=` value, so I gate colours to literal `#hex` and drop anything else. Server-side validation would be the better fix; I did not touch `server.mjs`.
4. **Traversal status code:** `/api/audio/..%2F..%2F..%2Fetc%2Fpasswd` → 403 (as §0 documents), but the un-encoded `../` form → 404 (normalised before the guard). Blocked either way; reporting, not changing.
5. Live sessions still emit `sourceEntryId: null`, so §2 is verified from the fixture only, as the brief anticipated. Also: the fixture's status file pid `94368` is dead, so `/api/status` correctly culls it — to see the fixture indicator in a browser, refresh that file's `pid`/`updatedAt` first.

## Needs human eyes (not verifiable headlessly)

Pulse animation look and phase-colour distinctness; `<details>` interaction feel; that scroll position, open disclosures and a *playing* `<audio>` genuinely survive live 1 s polls; play-all chaining; `localStorage` persistence across reloads; `prompt()` for `New category…`; hover-reveal of row controls; inline-rename focus/blur in a real browser.

**Recommended next step:** run the server on its normal port, open `#fixture0-aaaa-bbbb-cccc-000000000001` (after bumping its status-file pid/updatedAt), expand one source disclosure, start an `<audio>`, and watch for ~10 s to confirm the 1 s poll leaves scroll, disclosure and playback untouched.