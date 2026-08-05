#!/usr/bin/env node
/**
 * Voice Archive web UI server.
 *
 * Serves a browsable, chronological view of pi sessions: the transcript plus
 * the voice notes that were spoken during it, each replayable inline.
 *
 * Standalone by design — zero dependencies, no pi imports. Run it directly:
 *     node ~/.pi/agent/extensions/voice-archive/server.mjs
 * or let the extension start it for you with `/voice-notes`.
 *
 * Data sources (read-only with respect to pi; this server never mutates your
 * sessions — ui-meta.json below is the one thing it owns and writes):
 *   ~/.pi/agent/sessions/<cwd-slug>/<iso>_<uuid>.jsonl   transcripts + voice-note entries
 *   ~/.pi/voice-archive/<session-id>/*.opus|.wav|.json   archived audio + sidecars
 *   ~/.pi/voice-archive/status/<session-id>.json         live per-session phase (written by the extension)
 *   ~/.pi/voice-archive/ui-meta.json                     UI-only names/categories/autoQueue (owned here)
 *
 * Routes:
 *   GET    /                      UI
 *   GET    /api/health            server + TTS status
 *   GET    /api/status            live per-session processing phase
 *   GET    /api/sessions          session list (newest first)
 *   GET    /api/session/:id       chronological timeline for one session
 *   PATCH  /api/session/:id/meta  set UI-only name / category / autoQueue
 *   GET    /api/meta              whole UI-only metadata store
 *   POST   /api/categories        create a category
 *   PATCH  /api/categories/:id    rename/recolor a category
 *   DELETE /api/categories/:id    delete a category (and unassign it everywhere)
 *   GET    /api/audio/<path>      archived audio blob
 *   POST   /api/tts               synthesize arbitrary text via the live Kokoro server
 *
 * SECURITY POSTURE
 * There is deliberately no auth, no session token and no CSRF token: this binds
 * 127.0.0.1 for a single local user, and a password would only be theatre.
 *
 * But localhost is NOT an authorization boundary. Any web page the user visits
 * can issue a plain cross-origin GET at this port with no CORS preflight (an
 * <img src> is enough) and, while it cannot *read* the response, the request
 * still executes here. So every GET must be safe to trigger from a hostile page:
 * inputs that reach the filesystem are validated (see isValidSessionId and
 * serveAudio), and no GET may mutate state or be able to kill the process. That
 * last part matters especially because the extension starts us detached with
 * stdio ignored, so a crash is completely invisible to the user.
 *
 * Mutations are confined to PATCH/POST/DELETE, which a cross-origin page cannot
 * send to us without a preflight it will not get.
 */

import { createServer } from "node:http";
import { createReadStream, readFileSync, statSync } from "node:fs";
import { randomBytes } from "node:crypto";
import { readdir, readFile, rename, stat, unlink, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join, normalize, resolve, sep } from "node:path";

const PORT = Number(process.env.VOICE_ARCHIVE_PORT ?? 8182);
const HOST = "127.0.0.1";
const SESSIONS_DIR = join(homedir(), ".pi", "agent", "sessions");
const ARCHIVE_DIR = join(homedir(), ".pi", "voice-archive");
const STATUS_DIR = join(ARCHIVE_DIR, "status");
const UI_META_FILE = join(ARCHIVE_DIR, "ui-meta.json");
const VOICE_CONFIG = join(homedir(), ".pi", "voice", "config.json");
const UI_FILE = join(import.meta.dirname, "ui.html");

// A crashed pi leaves its status file behind. Ignore anything older than this
// (or whose pid is gone); flag long-running non-idle phases as stalled so a
// wedged summarizer stays visible instead of silently disappearing.
const STATUS_DEAD_MS = 15 * 60 * 1000;
const STATUS_STALLED_MS = 3 * 60 * 1000;

/**
 * Is this a session id we are willing to turn into a filesystem path or an
 * object key?
 *
 * Session ids arrive from the URL and flow into join(ARCHIVE_DIR, id) and into
 * meta.sessions[id], so an unvalidated id is both a directory-traversal and a
 * prototype-pollution primitive. `new URL` normalises a literal `..` segment,
 * but a percent-encoded `..%2F` survives parsing and reappears once decoded, so
 * validation has to happen after decoding and before any use.
 *
 * An allowlist rather than a denylist: real ids are uuids or short fixture-style
 * slugs, so anything outside [A-Za-z0-9._-] is simply not a session id. That
 * also excludes `/`, `\`, NUL and the dangerous keys `__proto__`,
 * `constructor` and `prototype`, which cannot match because of the leading
 * alphanumeric requirement... except they can (`constructor` is alphanumeric),
 * so they are rejected explicitly below.
 */
const SESSION_ID_RE = /^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$/;
const FORBIDDEN_KEYS = new Set(["__proto__", "constructor", "prototype"]);
// Server-owned names that live alongside the per-session directories in the
// archive but are not sessions. "status" is a valid-looking id, so without this
// it reads as a session whose status files become empty phantom voice notes.
const RESERVED_IDS = new Set(["status"]);

function isValidSessionId(id) {
  if (typeof id !== "string" || !SESSION_ID_RE.test(id)) return false;
  if (id.includes("..")) return false; // ".." alone fails the regex, but "a..b" would not
  if (RESERVED_IDS.has(id)) return false;
  return !FORBIDDEN_KEYS.has(id);
}

// ── TTS endpoint (for on-demand "speak this message") ───────────────

/**
 * How much of the conversation pi-voice already narrates by itself, derived from
 * the user's ~/.pi/voice/config.json. The UI needs this to explain the
 * per-session auto-queue toggle honestly: when a prompt-driven `turn_end` is
 * configured, every response is already voiced and auto-queue deliberately does
 * nothing, so presenting it as an active switch would be a lie.
 *
 *   "every" — prompt-driven turn_end/message_end: all responses already voiced
 *   "final" — only agent_end: just the last response of each run
 *   "none"  — TTS disabled, or only fixed `text:` phrases (which summarize nothing)
 */
/**
 * A category colour is interpolated straight into a `style="color:…"` attribute
 * in the UI, and HTML-escaping does not stop CSS injection there (a value like
 * `red;background:url(http://evil/x)` would be honoured). So only literal
 * 3/6-digit hex is accepted; anything else is dropped and the UI falls back to
 * its default accent. Returns "" when there is no usable colour.
 */
function normalizeColor(value) {
  if (typeof value !== "string") return "";
  const color = value.trim();
  return /^#[0-9a-fA-F]{3}([0-9a-fA-F]{3})?$/.test(color) ? color : "";
}

function voiceCoverage() {
  try {
    const cfg = JSON.parse(readFileSync(VOICE_CONFIG, "utf8"));
    if (cfg.enabled === false) return "none";
    const events = cfg.events ?? {};
    if (events.turn_end?.prompt || events.message_end?.prompt) return "every";
    if (events.agent_end?.prompt) return "final";
    return "none";
  } catch {
    return "none";
  }
}

function ttsEndpoint() {
  let host = "127.0.0.1";
  let port = 8181;
  try {
    const cfg = JSON.parse(readFileSync(VOICE_CONFIG, "utf8"));
    if (typeof cfg.host === "string") host = cfg.host;
    if (typeof cfg.port === "number") port = cfg.port;
  } catch {
    /* defaults */
  }
  return `http://${host}:${port}`;
}

// ── Live status (written by the extension, one file per session) ────

/**
 * Read every status file and drop the ones nobody is behind any more.
 *
 * Two independent liveness checks, because either can fail alone: a pi that
 * was SIGKILLed leaves a fresh-looking file with a dead pid, and a pid can be
 * recycled by an unrelated process while the file goes stale.
 */
/**
 * Delete a status file we have just proven belongs to a process that is gone.
 *
 * pi normally removes its own file on session_shutdown, but that never runs when
 * a session is killed (SIGKILL, a closed terminal, a crash), so without this the
 * directory grows forever. Safe because ESRCH means no process holds that pid at
 * all: a *recycled* pid makes a dead session look alive, never the reverse, so
 * we can only ever be too conservative here. Best-effort and never fatal — the
 * status read must not fail because a file vanished underneath it.
 */
function reapStatus(file) {
  unlink(join(STATUS_DIR, file)).catch(() => {});
}

async function readStatuses() {
  const sessions = {};
  let files;
  try {
    files = await readdir(STATUS_DIR);
  } catch {
    return sessions; // no status dir yet — nothing has run since install
  }

  const now = Date.now();
  for (const f of files) {
    if (!f.endsWith(".json")) continue; // skip *.tmp mid-rename
    let s;
    try {
      s = JSON.parse(await readFile(join(STATUS_DIR, f), "utf8"));
    } catch {
      continue; // torn write — the next phase change rewrites it
    }

    const sessionId = s.sessionId ?? f.replace(/\.json$/, "");
    const age = now - new Date(s.updatedAt ?? 0).getTime();
    if (!Number.isFinite(age) || age > STATUS_DEAD_MS) {
      reapStatus(f);
      continue;
    }

    // process.kill(pid, 0) only probes; it delivers no signal. EPERM means the
    // pid exists but is owned by someone else, which still counts as alive.
    if (typeof s.pid === "number") {
      try {
        process.kill(s.pid, 0);
      } catch (err) {
        if (err.code === "ESRCH") {
          reapStatus(f);
          continue;
        }
      }
    }

    const phase = s.phase ?? "idle";
    sessions[sessionId] = {
      phase,
      detail: s.detail ?? "",
      queueDepth: s.queueDepth ?? 0,
      pid: s.pid ?? null,
      cwd: s.cwd ?? "",
      updatedAt: s.updatedAt ?? null,
      stalled: phase !== "idle" && age > STATUS_STALLED_MS,
    };
  }
  return sessions;
}

// ── UI-only metadata (names, categories, autoQueue) ────────────────
//
// The only mutable state this server owns. Deliberately a separate file from
// pi's session logs: renaming a session here must never touch the transcript,
// and pi must be free to prune or rewrite its own sessions without consulting
// us. Session ids are the join key.

const EMPTY_META = { v: 1, categories: [], sessions: {} };

let warnedBadMeta = false;

/**
 * Load the store, keeping only entries that match the shape we promise callers.
 *
 * This file is hand-editable and survives across versions, so the routes must
 * not assume it is well formed: a stray `categories:[null]` used to 500 every
 * category route on `c.id`. Malformed entries are dropped rather than repaired,
 * and the sessions map gets a null prototype so a key like `__proto__` that is
 * already on disk cannot poison lookups.
 */
function sanitizeMeta(parsed) {
  const categories = [];
  if (Array.isArray(parsed?.categories)) {
    for (const c of parsed.categories) {
      if (!c || typeof c !== "object") continue;
      if (typeof c.id !== "string" || !c.id) continue;
      const cat = { id: c.id, name: typeof c.name === "string" ? c.name : c.id };
      const color = normalizeColor(c.color);
      if (color) cat.color = color;
      categories.push(cat);
    }
  }

  const sessions = Object.create(null);
  const raw = parsed?.sessions;
  // Arrays are objects too, but a session map is never an array.
  if (raw && typeof raw === "object" && !Array.isArray(raw)) {
    for (const [id, entry] of Object.entries(raw)) {
      if (!isValidSessionId(id) || !entry || typeof entry !== "object") continue;
      const clean = {};
      if (typeof entry.name === "string" && entry.name) clean.name = entry.name.slice(0, 200);
      if (typeof entry.categoryId === "string" && entry.categoryId) {
        clean.categoryId = entry.categoryId;
      }
      if (entry.autoQueue === true) clean.autoQueue = true;
      if (Object.keys(clean).length > 0) sessions[id] = clean;
    }
  }

  return { v: 1, categories, sessions };
}

async function readMeta() {
  try {
    return sanitizeMeta(JSON.parse(await readFile(UI_META_FILE, "utf8")));
  } catch (err) {
    // ENOENT is the normal first-run case and not worth mentioning. Anything
    // else (corrupt JSON, bad permissions) is worth saying once, then we carry
    // on with an empty store rather than taking the whole UI down.
    if (err.code !== "ENOENT" && !warnedBadMeta) {
      warnedBadMeta = true;
      console.warn(`[voice-archive] Ignoring unreadable ${UI_META_FILE}:`, err.message);
    }
    return sanitizeMeta(EMPTY_META);
  }
}

async function writeMeta(meta) {
  // tmp + rename so a reader never observes a half-written store.
  const tmp = `${UI_META_FILE}.tmp`;
  await writeFile(tmp, `${JSON.stringify(meta, null, 2)}\n`, "utf8");
  await rename(tmp, UI_META_FILE);
}

// Every mutation is read-modify-write, so two browser tabs racing would lose an
// update. Serialize them through one promise chain — this process is the only
// writer, so that is sufficient.
let metaChain = Promise.resolve();

function updateMeta(mutator) {
  const next = metaChain.then(async () => {
    const meta = await readMeta();
    const result = await mutator(meta);
    if (result?.skipWrite !== true) await writeMeta(meta);
    return result;
  });
  // Keep the chain alive even when this mutation rejects, or one bad request
  // would wedge every later write.
  metaChain = next.then(
    () => {},
    () => {},
  );
  return next;
}

/** Thrown by mutators to turn a validation failure into an HTTP status. */
class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

function sessionMetaFor(meta, id) {
  // Own-property only: never let an inherited key masquerade as saved metadata.
  const m = meta.sessions && Object.hasOwn(meta.sessions, id) ? meta.sessions[id] : {};
  return {
    name: typeof m.name === "string" && m.name ? m.name : null,
    categoryId: typeof m.categoryId === "string" ? m.categoryId : null,
    autoQueue: m.autoQueue === true,
  };
}

/** Merge UI-only fields onto a session summary without touching derived ones. */
function withSessionMeta(summary, meta) {
  const m = sessionMetaFor(meta, summary.id);
  return {
    ...summary,
    name: m.name,
    displayName: m.name ?? summary.title,
    categoryId: m.categoryId,
    autoQueue: m.autoQueue,
  };
}

// ── Session parsing ────────────────────────────────────────────────

/** Flatten a message's content blocks into display text + tool names. */
function renderContent(content) {
  if (typeof content === "string") return { text: content, tools: [], thinking: "" };
  if (!Array.isArray(content)) return { text: "", tools: [], thinking: "" };
  let text = "";
  let thinking = "";
  const tools = [];
  for (const part of content) {
    if (!part || typeof part !== "object") continue;
    if (part.type === "text" && part.text) text += part.text;
    else if (part.type === "thinking" && part.thinking) thinking += part.thinking;
    else if (part.type === "toolCall") {
      tools.push({ name: part.name, args: summarizeArgs(part.arguments) });
    } else if (part.type === "image") {
      text += "\n[image]\n";
    }
  }
  return { text, tools, thinking };
}

/** One-line hint of what a tool call did, without dumping whole file contents. */
function summarizeArgs(args) {
  if (!args || typeof args !== "object") return "";
  for (const key of ["command", "path", "query", "text", "pattern", "task", "agent"]) {
    const v = args[key];
    if (typeof v === "string" && v.trim()) {
      const flat = v.replace(/\s+/g, " ").trim();
      return flat.length > 120 ? `${flat.slice(0, 120)}…` : flat;
    }
  }
  return "";
}

function parseJsonl(raw) {
  const entries = [];
  for (const line of raw.split("\n")) {
    if (!line.trim()) continue;
    try {
      entries.push(JSON.parse(line));
    } catch {
      /* tolerate a torn final line from a live session */
    }
  }
  return entries;
}

/** Cheap metadata pass: header + counters + title, without building a timeline. */
function summarize(entries, file, mtimeMs) {
  const header = entries.find((e) => e.type === "session");
  if (!header) return null;
  let messages = 0;
  let voiceNotes = 0;
  let title = "";
  let lastTs = header.timestamp;

  for (const e of entries) {
    if (e.timestamp) lastTs = e.timestamp;
    if (e.type === "message") {
      const role = e.message?.role;
      if (role === "user" || role === "assistant") messages++;
      if (!title && role === "user") {
        const { text } = renderContent(e.message.content);
        const flat = text.replace(/\s+/g, " ").trim();
        if (flat && !flat.startsWith("<")) title = flat.slice(0, 100);
      }
    } else if (e.type === "custom" && e.customType === "voice-note") {
      voiceNotes++;
    }
  }

  return {
    id: header.id,
    cwd: header.cwd ?? "",
    startedAt: header.timestamp,
    updatedAt: lastTs,
    mtimeMs,
    file,
    title: title || "(no prompt)",
    messages,
    voiceNotes,
  };
}

async function listSessionFiles() {
  const out = [];
  let slugs;
  try {
    slugs = await readdir(SESSIONS_DIR, { withFileTypes: true });
  } catch {
    return out;
  }
  for (const slug of slugs) {
    if (!slug.isDirectory()) continue;
    const dir = join(SESSIONS_DIR, slug.name);
    let files;
    try {
      files = await readdir(dir);
    } catch {
      continue;
    }
    for (const f of files) {
      if (f.endsWith(".jsonl")) out.push(join(dir, f));
    }
  }
  return out;
}

// Sessions change only when their file changes, so cache on mtime.
const summaryCache = new Map();

async function listSessions() {
  const files = await listSessionFiles();
  // Forget sessions that have gone away, or a long-lived server slowly retains
  // the parsed summary of every session pi ever pruned. Bounded by what is
  // actually on disk, which is the only set we ever serve from.
  if (summaryCache.size > files.length) {
    const live = new Set(files);
    for (const key of summaryCache.keys()) {
      if (!live.has(key)) summaryCache.delete(key);
    }
  }
  const results = await Promise.all(
    files.map(async (file) => {
      let st;
      try {
        st = await stat(file);
      } catch {
        return null;
      }
      const cached = summaryCache.get(file);
      if (cached && cached.mtimeMs === st.mtimeMs) return cached.summary;
      let raw;
      try {
        raw = await readFile(file, "utf8");
      } catch {
        return null;
      }
      const summary = summarize(parseJsonl(raw), file, st.mtimeMs);
      summaryCache.set(file, { mtimeMs: st.mtimeMs, summary });
      return summary;
    }),
  );
  return results
    .filter(Boolean)
    .sort((a, b) => new Date(b.updatedAt) - new Date(a.updatedAt));
}

/** Full chronological timeline: prompts, replies, tool calls, voice notes. */
function buildTimeline(entries) {
  const items = [];
  for (const e of entries) {
    if (e.type === "custom" && e.customType === "voice-note") {
      const d = e.data ?? {};
      items.push({
        kind: "voice",
        id: e.id,
        noteId: d.noteId ?? null,
        ts: d.ts ?? e.timestamp,
        text: d.text ?? "",
        voice: d.voice ?? null,
        speed: d.speed ?? null,
        source: d.source,
        // Which assistant message this note summarizes, so the UI can group
        // them. Older notes predate these fields; enrichArchive() backfills
        // from the sidecar when the session entry lacks them.
        sourceEntryId: d.sourceEntryId ?? null,
        sourceText: d.sourceText ?? null,
        // Audio metadata lives in the archive sidecar, not the session log;
        // enrichArchive() fills these in.
        audio: null,
        durationMs: null,
        bytes: null,
        error: null,
      });
      continue;
    }
    if (e.type !== "message") continue;
    const msg = e.message;
    const role = msg?.role;
    if (role !== "user" && role !== "assistant") continue;
    const { text, tools, thinking } = renderContent(msg.content);
    if (!text.trim() && tools.length === 0) continue;
    items.push({
      kind: role,
      id: e.id,
      ts: e.timestamp,
      text,
      tools,
      hasThinking: Boolean(thinking),
      model: msg.model,
      // Filled in by linkVoiceSources() once every note is known.
      ...(role === "assistant" ? { voiceNoteIds: [] } : {}),
    });
  }
  items.sort((a, b) => new Date(a.ts) - new Date(b.ts));
  return items;
}

/**
 * Point each assistant message at the notes that summarize it.
 *
 * The API stays a flat chronological list — nothing is nested or removed — so
 * the UI is free to render the pairing (or not) however it likes. Run this only
 * after orphans are folded in, or archive-only notes would not be linked.
 */
function linkVoiceSources(items) {
  const assistants = new Map();
  for (const it of items) {
    if (it.kind === "assistant") assistants.set(it.id, it);
  }
  for (const it of items) {
    if (it.kind !== "voice" || !it.sourceEntryId || !it.noteId) continue;
    const target = assistants.get(it.sourceEntryId);
    if (!target) continue; // source was compacted away or lives on another branch
    if (!target.voiceNoteIds.includes(it.noteId)) target.voiceNoteIds.push(it.noteId);
  }
  return items;
}

/**
 * Read a session's archive directory: sidecar records keyed by noteId, plus
 * the set of files actually on disk (so we never hand the UI a dead <audio>).
 */
async function readArchive(sessionId) {
  const dir = join(ARCHIVE_DIR, sessionId);
  const sidecars = new Map();
  const present = new Set();
  let files;
  try {
    files = await readdir(dir);
  } catch {
    return { sidecars, present };
  }
  for (const f of files) {
    if (f.endsWith(".json")) {
      try {
        const d = JSON.parse(await readFile(join(dir, f), "utf8"));
        sidecars.set(d.noteId ?? f.replace(/\.json$/, ""), d);
      } catch {
        /* skip unreadable sidecar */
      }
    } else {
      present.add(f);
    }
  }
  return { sidecars, present };
}

/**
 * Join session-log notes to their archived audio via noteId, and fold in any
 * sidecar-only notes — a note whose appendEntry failed, or whose session file
 * was pruned, is still in the archive and must stay visible.
 */
function enrichArchive(items, sessionId, archive) {
  const { sidecars, present } = archive;
  const seen = new Set();

  for (const it of items) {
    if (it.kind !== "voice") continue;
    const rec = it.noteId ? sidecars.get(it.noteId) : null;
    if (!rec) {
      // Archival synthesis has not finished (or never will).
      it.error = "audio not archived";
      continue;
    }
    seen.add(it.noteId);
    it.durationMs = rec.durationMs ?? null;
    it.bytes = rec.bytes ?? null;
    it.error = rec.error ?? null;
    it.voice = it.voice ?? rec.voice ?? null;
    it.speed = it.speed ?? rec.speed ?? null;
    // Session entry wins; the sidecar is the fallback for notes written before
    // these fields existed, or whose appendEntry lost the race.
    it.sourceEntryId = it.sourceEntryId ?? rec.sourceEntryId ?? null;
    it.sourceText = it.sourceText ?? rec.sourceText ?? null;
    it.audio = rec.audio && present.has(rec.audio) ? `${sessionId}/${rec.audio}` : null;
  }

  const orphans = [];
  for (const [noteId, rec] of sidecars) {
    if (seen.has(noteId)) continue;
    orphans.push({
      kind: "voice",
      id: `sidecar:${noteId}`,
      noteId,
      ts: rec.ts,
      text: rec.text ?? "",
      voice: rec.voice ?? null,
      speed: rec.speed ?? null,
      source: rec.source,
      sourceEntryId: rec.sourceEntryId ?? null,
      sourceText: rec.sourceText ?? null,
      audio: rec.audio && present.has(rec.audio) ? `${sessionId}/${rec.audio}` : null,
      durationMs: rec.durationMs ?? null,
      bytes: rec.bytes ?? null,
      error: rec.error ?? null,
      orphan: true,
    });
  }
  return orphans;
}

async function getSession(id) {
  const sessions = await listSessions();
  const summary = sessions.find((s) => s.id === id);

  let items = [];
  if (summary) {
    const raw = await readFile(summary.file, "utf8");
    items = buildTimeline(parseJsonl(raw));
  }

  const orphans = enrichArchive(items, id, await readArchive(id));
  if (orphans.length) {
    items = [...items, ...orphans].sort((a, b) => new Date(a.ts) - new Date(b.ts));
  }
  linkVoiceSources(items);

  if (!summary && items.length === 0) return null;
  const uiMeta = await readMeta();
  const base =
    summary ?? { id, cwd: "", startedAt: items[0]?.ts, title: "(session file removed)" };
  return { meta: withSessionMeta(base, uiMeta), items };
}

// ── HTTP plumbing ──────────────────────────────────────────────────

function json(res, code, body) {
  const payload = JSON.stringify(body);
  res.writeHead(code, {
    "content-type": "application/json; charset=utf-8",
    "content-length": Buffer.byteLength(payload),
    "cache-control": "no-store",
  });
  res.end(payload);
}

function serveAudio(res, relPath) {
  // Contain the path inside ARCHIVE_DIR — no traversal out of the archive.
  const target = resolve(ARCHIVE_DIR, normalize(relPath));
  if (!target.startsWith(ARCHIVE_DIR + sep)) {
    json(res, 403, { error: "forbidden" });
    return;
  }

  // One stat, and it must be a regular file. Every session-id directory under
  // the archive is a valid path here, and streaming a directory throws an
  // asynchronous EISDIR that used to take the whole server down — fatal, since
  // any page the user visits can request this path cross-origin.
  let st;
  try {
    st = statSync(target);
  } catch {
    json(res, 404, { error: "audio not found" });
    return;
  }
  if (!st.isFile()) {
    json(res, 404, { error: "audio not found" });
    return;
  }

  const type = target.endsWith(".wav") ? "audio/wav" : "audio/ogg";
  res.writeHead(200, {
    "content-type": type,
    "content-length": st.size,
    "accept-ranges": "none",
    "cache-control": "public, max-age=31536000, immutable",
  });

  // The file can still vanish between the stat and the open (pi prunes the
  // archive, the user deletes a session). Without this listener that late error
  // is an unhandled 'error' event, which is a process-level crash.
  const stream = createReadStream(target);
  stream.on("error", (err) => {
    console.warn(`[voice-archive] Audio read failed for ${relPath}:`, err.message);
    res.destroy(); // headers are already sent, so a clean status is impossible
  });
  stream.pipe(res);
  // Stop reading if the browser goes away mid-download (seek, tab close).
  res.on("close", () => stream.destroy());
}

async function readBody(req, limit = 64 * 1024) {
  const chunks = [];
  let total = 0;
  for await (const c of req) {
    total += c.length;
    // 413, not 500: an oversized body is the client's mistake, not ours.
    if (total > limit) throw new HttpError(413, "body too large");
    chunks.push(c);
  }
  return Buffer.concat(chunks).toString("utf8");
}

/**
 * Parse a request body, blaming the client for malformed JSON.
 *
 * A bare JSON.parse throws a plain SyntaxError, which the catch-all reports as a
 * 500 — misleading, since the server is fine and the request was not.
 *
 * Also rejects arrays and non-objects: every caller then reads named fields, and
 * `Object.hasOwn(body, "name")` on a string or null would throw.
 */
function parseJsonBody(raw) {
  let parsed;
  try {
    parsed = JSON.parse(raw);
  } catch {
    throw new HttpError(400, "invalid JSON body");
  }
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new HttpError(400, "body must be a JSON object");
  }
  return parsed;
}

const server = createServer(async (req, res) => {
  let url;
  try {
    url = new URL(req.url, `http://${HOST}:${PORT}`);
  } catch {
    json(res, 400, { error: "bad request" });
    return;
  }
  const path = url.pathname;

  // A malformed percent-escape (`%E0%A4%A`) makes every decodeURIComponent below
  // throw "URI malformed". That is a bad request, not a server fault, so decode
  // once up front and answer 400 rather than letting it surface as a 500.
  try {
    decodeURIComponent(path);
  } catch {
    json(res, 400, { error: "malformed URL escape" });
    return;
  }

  try {
    if (req.method === "GET" && (path === "/" || path === "/index.html")) {
      const html = await readFile(UI_FILE);
      res.writeHead(200, {
        "content-type": "text/html; charset=utf-8",
        "content-length": html.length,
        "cache-control": "no-store",
      });
      res.end(html);
      return;
    }

    if (req.method === "GET" && path === "/api/health") {
      const tts = await fetch(`${ttsEndpoint()}/health`, {
        signal: AbortSignal.timeout(800),
      })
        .then((r) => (r.ok ? r.json() : null))
        .catch(() => null);
      json(res, 200, { ok: true, archiveDir: ARCHIVE_DIR, tts, voiceCoverage: voiceCoverage() });
      return;
    }

    // Polled every second by the UI, so it must stay cheap and uncached.
    if (req.method === "GET" && path === "/api/status") {
      json(res, 200, { sessions: await readStatuses() });
      return;
    }

    if (req.method === "GET" && path === "/api/sessions") {
      const all = await listSessions();
      const onlyVoice = url.searchParams.get("voice") === "1";
      const uiMeta = await readMeta();
      const shown = onlyVoice ? all.filter((s) => s.voiceNotes > 0) : all;
      json(res, 200, shown.map((s) => withSessionMeta(s, uiMeta)));
      return;
    }

    if (req.method === "GET" && path === "/api/meta") {
      json(res, 200, await readMeta());
      return;
    }

    if (req.method === "POST" && path === "/api/categories") {
      const body = parseJsonBody(await readBody(req));
      const created = await updateMeta((meta) => {
        // Capped like session names are, so one paste cannot wedge the sidebar.
        const name = String(body.name ?? "").trim().slice(0, 200);
        if (!name) throw new HttpError(400, "category name required");
        // Ids are generated here, never accepted from the client, so they can
        // always be trusted as object keys / filenames.
        const cat = { id: `c-${randomBytes(3).toString("hex")}`, name };
        const color = normalizeColor(body.color);
        if (color) cat.color = color;
        meta.categories.push(cat);
        return cat;
      });
      json(res, 201, created);
      return;
    }

    if (req.method === "PATCH" && path.startsWith("/api/categories/")) {
      const id = decodeURIComponent(path.slice("/api/categories/".length));
      const body = parseJsonBody(await readBody(req));
      const updated = await updateMeta((meta) => {
        const cat = meta.categories.find((c) => c.id === id);
        if (!cat) throw new HttpError(404, "category not found");
        if (Object.hasOwn(body, "name")) {
          const name = String(body.name ?? "").trim().slice(0, 200);
          if (!name) throw new HttpError(400, "category name required");
          cat.name = name;
        }
        if (Object.hasOwn(body, "color")) {
          const color = normalizeColor(body.color);
          if (color) cat.color = color;
          else delete cat.color;
        }
        return cat;
      });
      json(res, 200, updated);
      return;
    }

    if (req.method === "DELETE" && path.startsWith("/api/categories/")) {
      const id = decodeURIComponent(path.slice("/api/categories/".length));
      await updateMeta((meta) => {
        const idx = meta.categories.findIndex((c) => c.id === id);
        if (idx === -1) throw new HttpError(404, "category not found");
        meta.categories.splice(idx, 1);
        // Unassign everywhere, or sessions would keep pointing at a category
        // that no longer exists and silently render as uncategorized-but-set.
        for (const s of Object.values(meta.sessions)) {
          if (s.categoryId === id) delete s.categoryId;
        }
        return { ok: true };
      });
      json(res, 200, { ok: true });
      return;
    }

    // Must be tested before the GET timeline route below, which prefix-matches
    // /api/session/ and would otherwise swallow "<id>/meta" as a session id.
    if (req.method === "PATCH" && path.startsWith("/api/session/") && path.endsWith("/meta")) {
      const id = decodeURIComponent(
        path.slice("/api/session/".length, -"/meta".length),
      );
      // Rejects `__proto__` and friends before they can be used as a key: with
      // a bare `meta.sessions[id] ?? {}` the entry below WAS Object.prototype,
      // and assigning to it corrupted every object in the process — including
      // later requests, which then inherited `name`/`autoQueue` and persisted
      // them to unrelated sessions.
      if (!isValidSessionId(id)) {
        json(res, 404, { error: "session not found" });
        return;
      }
      const body = parseJsonBody(await readBody(req));
      const updated = await updateMeta((meta) => {
        // Unknown session ids are allowed on purpose: the user may categorize a
        // session whose transcript pi has since pruned. Own-property lookup, so
        // a key inherited from the prototype chain can never be picked up.
        const entry = Object.hasOwn(meta.sessions, id) ? meta.sessions[id] : {};
        // Object.hasOwn rather than `!== undefined`: an absent field must mean
        // "leave this alone", and `undefined` can be inherited.
        if (Object.hasOwn(body, "name")) {
          const name = body.name === null ? "" : String(body.name).trim();
          if (name) entry.name = name.slice(0, 200);
          else delete entry.name; // empty clears the override
        }
        if (Object.hasOwn(body, "categoryId")) {
          if (body.categoryId === null || body.categoryId === "") {
            delete entry.categoryId;
          } else {
            const cid = String(body.categoryId);
            if (!meta.categories.some((c) => c.id === cid)) {
              throw new HttpError(400, "unknown category");
            }
            entry.categoryId = cid;
          }
        }
        if (Object.hasOwn(body, "autoQueue")) {
          if (body.autoQueue) entry.autoQueue = true;
          else delete entry.autoQueue;
        }
        // Drop the record entirely once nothing is set, so the store does not
        // accumulate empty objects for every session ever viewed.
        if (Object.keys(entry).length === 0) delete meta.sessions[id];
        else meta.sessions[id] = entry;
        return { id, ...sessionMetaFor(meta, id) };
      });
      json(res, 200, updated);
      return;
    }

    if (req.method === "GET" && path.startsWith("/api/session/")) {
      const id = decodeURIComponent(path.slice("/api/session/".length));
      // The id becomes a directory name in readArchive(), so validate it before
      // any path join: `..%2Fagent` survives URL parsing and used to enumerate
      // ~/.pi/agent, returning any JSON file whose keys collide with the sidecar
      // schema as a fake voice note.
      if (!isValidSessionId(id)) {
        json(res, 404, { error: "session not found" });
        return;
      }
      const data = await getSession(id);
      if (!data) {
        json(res, 404, { error: "session not found" });
        return;
      }
      json(res, 200, data);
      return;
    }

    if (req.method === "GET" && path.startsWith("/api/audio/")) {
      serveAudio(res, decodeURIComponent(path.slice("/api/audio/".length)));
      return;
    }

    // On-demand synthesis: hear any transcript line, even one never voiced.
    if (req.method === "POST" && path === "/api/tts") {
      const body = parseJsonBody(await readBody(req));
      const text = String(body.text ?? "").slice(0, 4000);
      if (!text.trim()) {
        json(res, 400, { error: "text required" });
        return;
      }
      const payload = { text };
      if (body.voice) payload.voice = body.voice;
      if (body.speed) payload.speed = Number(body.speed);

      const upstream = await fetch(`${ttsEndpoint()}/tts`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(payload),
        signal: AbortSignal.timeout(60_000),
      });
      if (!upstream.ok) {
        json(res, 502, { error: `TTS server returned ${upstream.status}` });
        return;
      }
      const wav = Buffer.from(await upstream.arrayBuffer());
      res.writeHead(200, {
        "content-type": "audio/wav",
        "content-length": wav.length,
        "cache-control": "no-store",
      });
      res.end(wav);
      return;
    }

    json(res, 404, { error: "not found" });
  } catch (err) {
    // Validation failures raised by the meta mutators carry their own status;
    // anything else really is a server fault.
    const status = err instanceof HttpError ? err.status : 500;
    json(res, status, { error: err instanceof Error ? err.message : String(err) });
  }
});

// The extension starts us only after a health check says nothing is listening,
// so two `/voice-notes` invocations can race and both spawn a server. The loser
// used to die on an unhandled EADDRINUSE, dumping a stack trace into the
// /dev/null it was spawned with. Losing that race is the expected outcome and
// means the UI is already up, so say so in one line and exit successfully.
server.on("error", (err) => {
  if (err.code === "EADDRINUSE") {
    console.log(`voice-archive UI already running at http://${HOST}:${PORT}/`);
    process.exit(0);
  }
  console.error(`[voice-archive] Server error: ${err.message}`);
  process.exit(1);
});

server.listen(PORT, HOST, () => {
  console.log(`voice-archive UI  http://${HOST}:${PORT}/`);
  console.log(`  sessions: ${SESSIONS_DIR}`);
  console.log(`  archive:  ${ARCHIVE_DIR}`);
});
