# Task for worker

Read the authoritative spec at /tmp/voice-archive-spec.md IN FULL first. Then implement the **UI** portions in the single file you own:

  /Users/michael.schmitt/projects/dotfiles/pi/.pi/agent/extensions/voice-archive/ui.html

You own ONLY that file. index.ts and server.mjs are ALREADY IMPLEMENTED and verified — do NOT edit them, or anything in node_modules. If you believe the server is wrong, report it; do not change it.

## What to build (spec sections 1-4)

1. **Live processing status.** Poll `GET /api/status` every 1000ms. Show per-session animated indicators in the sidebar (pulsing dot + phase label; distinct colour per phase: summarizing / speaking / archiving; a steady non-pulsing dot for `idle` so the user can still see which sessions are open; greyed + `⚠` with an explanatory `title` when `stalled` is true). The open session's header shows the same status larger, with `detail` and `queueDepth` when > 0.
   **CRITICAL: a status poll must never re-render the timeline.** It would destroy the user's scroll position and every open/closed disclosure. Update only the status elements in place.

2. **Group each voice note with the response it summarizes**, source **collapsed by default** behind a disclosure control. The paired assistant message must NOT also render standalone (no duplicated text in the timeline). Unpaired notes render as they do today. Disclosure state must survive status polls.

3. **Sidebar grouping + categories + renaming.** A grouping switch: by directory (DEFAULT) or by category, with collapsible groups whose collapse state persists in localStorage. Inline session rename (Enter commits, Escape cancels, empty clears the override). Category assignment via a small control including a `New category…` option that creates one. After a PATCH, update in place — do not lose scroll position or group state.

4. **Per-session autoQueue toggle** in the session header.
   IMPORTANT NUANCE, verify it yourself via `GET /api/health` → `voiceCoverage`:
   - `"every"` (the user's CURRENT setting): pi-voice already voices every response, so auto-queue is a deliberate no-op. The toggle must still be settable, but show an honest inline note like "every response is already voiced by your global voice config — this adds nothing right now". Do not present it as if it will do work.
   - `"final"`: auto-queue fills in the earlier responses of each run. Normal active toggle.
   - `"none"`: auto-queue does all the work.

## Ground truth — use these, do not guess field names

A server is NOT running; start your own on **port 8193**:
  cd /Users/michael.schmitt/.pi/agent/extensions/voice-archive && VOICE_ARCHIVE_PORT=8193 node server.mjs &
If you restart it, KILL THE OLD ONE FIRST: `lsof -nP -iTCP:8193 -sTCP:LISTEN -t | xargs -r kill -9`. An EADDRINUSE failure silently leaves the OLD code serving and will convince you a broken change works. This trap already cost real time on this project.

Then `curl` these and match your rendering to the ACTUAL shapes:
  /api/health   → { ok, archiveDir, tts:{status,activeDtype,modelLoaded,loading}|null, voiceCoverage:"none"|"final"|"every" }
  /api/status   → { sessions: { "<id>": { phase, detail, queueDepth, pid, cwd, updatedAt, stalled } } }
  /api/meta     → { v, categories:[{id,name,color}], sessions:{ "<id>":{name?,categoryId?,autoQueue?} } }
  /api/sessions → [ { id, cwd, startedAt, updatedAt, mtimeMs, file, title, messages, voiceNotes, name, displayName, categoryId, autoQueue } ]  (newest first, ~240 real entries)
  /api/session/:id → { meta:{...same fields...}, items:[ ... ] }

Timeline `items` are a FLAT chronological array. Kinds:
  user      : { kind, id, ts, text, tools:[], hasThinking, model }
  assistant : { kind, id, ts, text, tools:[{name,args}], hasThinking, model, voiceNoteIds:string[] }
  voice     : { kind, id, noteId, ts, text, voice, speed, source:"auto"|"tool"|"queue", sourceEntryId, sourceText, audio, durationMs, bytes, error, orphan? }
Pairing rule: a voice item pairs with the assistant item whose `id === voice.sourceEntryId`; that assistant also lists the note in `voiceNoteIds`.
Audio URL: `/api/audio/<voice.audio>` (already includes the session-id prefix). `audio` is null when nothing was archived.

Mutation routes: `PATCH /api/session/:id/meta` {name?,categoryId?,autoQueue?} ; `POST /api/categories` {name,color?} ; `PATCH /api/categories/:id` ; `DELETE /api/categories/:id`.

**A purpose-built fixture exists for verifying the pairing UI** (live sessions have `sourceEntryId: null` because the pi process currently running loaded an older build, so you cannot verify pairing from them):
  session id: `fixture0-aaaa-bbbb-cccc-000000000001`
  It has assistant `a1` ↔ voice note `n1` (source "auto") and assistant `a2` ↔ voice note `n2` (source "queue"), both with real playable Opus audio, plus a fake live status in phase `summarizing` with `queueDepth: 2` and a `detail` string. Use it as your primary test case for sections 1, 2 and 4.
Also useful: `019fd2c6-595f-7b7b-bd25-3cf55d4e36fa` is a real 91-message session with 22 real unpaired voice notes — good for checking you did not regress normal rendering, and that ~240 sessions across many directories group sensibly.

## Constraints

Spec section 5 is binding. Especially:
- Vanilla HTML/CSS/JS only. No build step, no dependencies, no CDN tags. The file is currently 371 lines with a dark theme — match its existing style and structure, keep the diff additive.
- Session names and category names are NEW user-controlled injection surfaces: every interpolation into HTML must go through the existing `esc()` helper.
- Do not regress what already works: session list, chronological timeline, `<audio>` playback of archived notes, the `♪ read aloud` on-demand synthesis button, `j`/`k` voice-note jumping, `/` to focus filter, play-all, the only-voice-sessions checkbox.

## Verification (mandatory — you cannot see a browser)

- Extract the inline `<script>` to /tmp and `node --check` it. A syntax error yields a blank page with zero server-side clue, so this is non-negotiable. Do the same for any large refactor step.
- Verify your DOM/render logic headlessly. Best approach: keep the pure logic (grouping sessions by directory, pairing notes to source messages, status/label formatting, name resolution) as small pure functions, then extract and unit-test them from node against the REAL curl payloads above. Show the actual output for the fixture session proving: (a) n1 pairs to a1 and a2 is not rendered standalone, (b) directory grouping buckets the ~240 sessions, (c) the summarizing status maps to the right label/colour.
- Prove escaping: feed a category or session name like `<img src=x onerror=alert(1)>` through your rendering path and show it comes out escaped.
- Kill your test server and clean up /tmp artifacts when done.

Report: exact commands run with their real output, which behaviours you verified headlessly vs. which genuinely need human eyes in a browser, and any spec ambiguity or deviation.