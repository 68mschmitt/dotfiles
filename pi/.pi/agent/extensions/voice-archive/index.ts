/**
 * Voice Archive Extension
 *
 * Keeps a permanent, per-session, chronological record of every voice note
 * pi-voice speaks — the spoken sentence *and* its audio — so you can browse
 * and replay them later in a local web UI (`/voice-notes`).
 *
 * WHY THIS EXISTS
 *   pi-voice is fire-and-forget: it synthesizes a WAV into $TMPDIR/pi-voice,
 *   plays it with afplay, then `unlinkSync`s it. The audio is gone, and the
 *   spoken sentence (an LLM rewrite of the agent's reply, not the reply itself)
 *   is never persisted anywhere. This extension captures both.
 *
 * HOW IT CAPTURES  (deliberately: only via pi-voice's *documented* contract)
 *   pi-voice publishes two events on the shared bus:
 *     voice:speak_start { text, voice, speed, source }
 *     voice:speak_end   { text, source, error? }
 *   We pair them, then re-request the identical {text, voice, speed} from the
 *   same local Kokoro server and store the resulting audio ourselves.
 *
 *   We deliberately do NOT:
 *     - watch $TMPDIR/pi-voice to steal the file before unlink (undocumented
 *       path + filename scheme, racy, fails silently when it loses the race), or
 *     - patch pi-voice to keep the file (node_modules is overwritten on every
 *       `pi install` / package update).
 *   Both couple us to internals that change without warning. The event bus and
 *   POST /tts are the only interfaces pi-voice actually commits to.
 *
 *   The session-log entry is written at speak_start (see ORDERING below).
 *   Archival synthesis is deferred to speak_end and runs through a serial
 *   queue, so it never competes with the interactive synthesis you are waiting
 *   to hear. It costs ~1s of local ONNX inference per note, after the note has
 *   already been spoken.
 *
 * WHY STORE AUDIO AT ALL (rather than re-synthesizing at replay time)
 *   Replay-time synthesis would need the TTS server running, the 759 MB model
 *   still installed, and the voice preset still named the same, months from
 *   now. None of that is guaranteed — `pi-voice model remove` alone breaks it.
 *   An archive that can't play its own contents isn't an archive. Audio is
 *   transcoded to Opus (~6-10 KB/note vs ~100 KB of 24 kHz WAV), so a year of
 *   heavy use stays well under 100 MB.
 *
 * WHERE IT IS STORED  (two writes, each immutable, so there is nothing to sync)
 *   1. pi.appendEntry("voice-note", {...facts}) — one line in the session's own
 *      JSONL, written at speak_start. It inherits the session's identity, tree
 *      position and chronology for free, costs zero LLM context tokens, and
 *      lands *interleaved with the transcript* — exactly the timeline the web
 *      UI renders. It records only what is known for certain at speak time
 *      (text, voice, speed, source, noteId) — never derived audio metadata.
 *   2. ~/.pi/voice-archive/<session-id>/<note-id>.opus + <note-id>.json
 *      The audio (JSONL can't hold binary) plus a self-describing sidecar with
 *      the derived facts (bytes, duration, failure reason). The `noteId` joins
 *      the two. If the session log is ever pruned or its format changes, the
 *      archive still stands alone and the UI folds those notes back in.
 *
 * ORDERING MATTERS: the session entry is appended synchronously during
 * speak_start, while the session is guaranteed live. Archival synthesis takes
 * ~1s, by which time pi may have torn the session down (it always has in
 * headless `pi -p` runs) — appendEntry would throw a stale-ctx error there.
 * So the slow, failure-prone work only ever touches the archive directory.
 *
 * Sample previews from the /voice settings UI (source: "sample") are ignored.
 *
 * ── Three further jobs, all layered on the same event contract ──
 *
 * LIVE STATUS (§1) — the web UI runs in a *separate process*, and two pi
 *   sessions can be active at once, so progress is published through files:
 *   ~/.pi/voice-archive/status/<session-id>.json, rewritten atomically on every
 *   phase change (idle → summarizing → speaking → archiving → idle) and deleted
 *   on session_shutdown. The server decides liveness from `pid` + `updatedAt`;
 *   we only report what we are doing right now.
 *
 * SOURCE PAIRING (§2) — a voice note summarizes an assistant response, but
 *   pi-voice never says *which* message it summarized. We infer it: whenever it
 *   is about to summarize (turn_end and/or agent_end, depending on which of the
 *   user's voice events are prompt-driven) we remember that response, then
 *   attach it to the next auto note, oldest first. Fixed-text notes (a voice
 *   config event with `text:` instead of `prompt:`, e.g. a constant "Still on
 *   it.") summarize nothing, so they get a null source and leave the remembered
 *   message for the real note that follows. This is what lets the UI collapse a
 *   note together with the reply it describes.
 *
 *   pi-voice also drops notes silently on several paths (TTS switched off for
 *   the session, empty context, empty LLM output, a swallowed ollama error), so
 *   remembered responses are capped and time-expired: without that, one drop
 *   would shift the pairing by one forever and mislabel every later note.
 *
 * AUTO-QUEUE (§4) — per session, opt-in from the web UI via ui-meta.json. When
 *   on, *every* LLM response in that session is summarized and archived, not
 *   just the run's final one. These notes are written with source "queue" and
 *   are deliberately NEVER played: they exist to be browsed later, and speaking
 *   a backlog would be intolerable. The final response is dropped from the batch
 *   when pi-voice is already going to voice it, which is the whole dedup story.
 */

import { spawn } from "node:child_process";
import {
  existsSync,
  mkdirSync,
  readFileSync,
  renameSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { homedir } from "node:os";
import { join, resolve } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import {
  createAgentSession,
  DefaultResourceLoader,
  ModelRuntime,
  SessionManager,
} from "@earendil-works/pi-coding-agent";

// ── Layout & constants ─────────────────────────────────────────────

const ARCHIVE_DIR = join(homedir(), ".pi", "voice-archive");
const STATUS_DIR = join(ARCHIVE_DIR, "status");
/** UI-only metadata owned by the web server; we only ever read it. */
const UI_META = join(ARCHIVE_DIR, "ui-meta.json");
const VOICE_CONFIG = join(homedir(), ".pi", "voice", "config.json");
const AGENT_DIR = resolve(homedir(), ".pi", "agent");
const SERVER_SCRIPT = join(import.meta.dirname, "server.mjs");

const DEFAULT_TTS_HOST = "127.0.0.1";
const DEFAULT_TTS_PORT = 8181;
const UI_PORT = 8182;

// Opus at 24 kbps is transparent for a single mono voice and ~15x smaller
// than the 24 kHz/16-bit WAV Kokoro returns.
const OPUS_BITRATE = "24k";
const TTS_TIMEOUT_MS = 60_000;
/** Transcode of a ~3s clip takes milliseconds; this is purely anti-wedge. */
const FFMPEG_TIMEOUT_MS = 30_000;
/** A local summarizer should answer in seconds; bound it so it cannot wedge. */
const SUMMARIZE_TIMEOUT_MS = 120_000;
/**
 * How long to believe a `summarizing` phase that produced no note. Under the
 * server's 3-minute `stalled` threshold, so an expectation that quietly came to
 * nothing resolves to idle instead of raising a false wedge warning.
 */
const SUMMARIZE_WATCHDOG_MS = 150_000;

/** Source responses can be long; keep the stored copy bounded. */
const SOURCE_TEXT_LIMIT = 4000;
/** `detail` is a status-line hint, not a transcript. */
const STATUS_DETAIL_LIMIT = 80;

// ── Records ────────────────────────────────────────────────────────

/** Written to the session JSONL at speak_start. Facts only. */
interface VoiceNoteEntry {
  v: 1;
  noteId: string;
  sessionId: string;
  /** ISO timestamp of speak_start — when you actually heard it. */
  ts: string;
  text: string;
  voice: string | null;
  speed: number | null;
  source: string;
  /** Session entry id of the assistant message this note summarizes. */
  sourceEntryId: string | null;
  /** That message's text, truncated — so the pairing survives log pruning. */
  sourceText: string | null;
}

/** Written to the archive sidecar once synthesis resolves. Derived facts. */
interface VoiceNoteSidecar extends VoiceNoteEntry {
  cwd: string;
  /** Filename inside the session's archive dir, or null if unavailable. */
  audio: string | null;
  bytes: number | null;
  durationMs: number | null;
  /** Why audio is missing (playback error, server down, ffmpeg failure). */
  error?: string;
}

interface SpeakStart {
  text: string;
  voice: string | null;
  speed: number | null;
  source: string;
}

/** The assistant message a voice note is about, as far as we can tell. */
interface SourceRef {
  entryId: string | null;
  text: string;
}

/** A SourceRef waiting to be claimed, stamped so it can be expired. */
interface PendingSource extends SourceRef {
  at: number;
}

/** One phase of work worth showing in the UI. */
type Phase = "idle" | "summarizing" | "speaking" | "archiving";

/** The subset of ~/.pi/voice/config.json we care about. */
interface VoiceEventConfig {
  prompt?: string;
  text?: string;
  model?: { provider: string; id: string };
}
interface VoiceConfig {
  enabled?: boolean;
  host?: string;
  port?: number;
  events?: Record<string, VoiceEventConfig>;
}

interface SpeakEnd {
  text: string;
  source: string;
  error?: string;
}

/** A speak_start we have logged and are waiting to archive audio for. */
interface Pending extends SpeakStart {
  noteId: string;
  sessionId: string;
  ts: string;
  sourceEntryId: string | null;
  sourceText: string | null;
}

// ── Helpers ────────────────────────────────────────────────────────

/**
 * Read ~/.pi/voice/config.json fresh. Always fresh, never cached: the user
 * retunes voice/speed/events from the /voice TUI mid-session, and auto-queue
 * borrows their tuned prompt and model from it.
 */
function loadVoiceConfig(): VoiceConfig {
  try {
    return JSON.parse(readFileSync(VOICE_CONFIG, "utf8")) as VoiceConfig;
  } catch {
    return {};
  }
}

function ttsEndpoint(): string {
  const cfg = loadVoiceConfig();
  const host = typeof cfg.host === "string" ? cfg.host : DEFAULT_TTS_HOST;
  const port = typeof cfg.port === "number" ? cfg.port : DEFAULT_TTS_PORT;
  return `http://${host}:${port}`;
}

/**
 * The voice config as it actually applies to *this* session.
 *
 * `alt+v` (and the /voice TUI) toggle TTS for the current session only, which
 * pi-voice persists as a `voice-session` custom entry rather than writing to
 * ~/.pi/voice/config.json. Reading only the global file therefore misses the
 * common case of "TTS is off right now": we would keep queueing source
 * responses that no note will ever claim. pi-voice resolves session-over-global
 * the same way (last matching entry wins), so mirror that.
 */
function effectiveVoiceConfig(ctx: ExtensionContext | undefined): VoiceConfig {
  const cfg = loadVoiceConfig();
  if (!ctx) return cfg;
  let override: { enabled?: boolean } | undefined;
  try {
    for (const raw of ctx.sessionManager.getBranch()) {
      const entry = raw as { type?: string; customType?: string; data?: unknown };
      if (entry?.type === "custom" && entry.customType === "voice-session") {
        override = (entry.data as { enabled?: boolean } | undefined) ?? override;
      }
    }
  } catch {
    return cfg; // stale ctx — the global config is the best we can do
  }
  return typeof override?.enabled === "boolean"
    ? { ...cfg, enabled: override.enabled }
    : cfg;
}

/**
 * Every fixed phrase pi-voice can speak (a voice config event with `text:`
 * instead of `prompt:`). These summarize nothing, so a note whose text matches
 * one must not be paired with an assistant response.
 */
function fixedPhrases(cfg: VoiceConfig): Set<string> {
  const out = new Set<string>();
  for (const ev of Object.values(cfg.events ?? {})) {
    if (typeof ev?.text === "string" && ev.text.trim()) out.add(ev.text.trim());
  }
  return out;
}

/**
 * True when pi-voice will itself voice the end of an agent run. Drives the
 * `summarizing` phase hint.
 */
function piVoiceHandlesAgentEnd(cfg: VoiceConfig): boolean {
  return cfg.enabled !== false && Boolean(cfg.events?.agent_end);
}

/**
 * How much of the conversation pi-voice already narrates on its own.
 *
 * This decides how much auto-queue (§4) has left to do, and it is read from the
 * live voice config rather than assumed, because the answer changes completely
 * depending on how the user has tuned their events:
 *
 *   "every" — a prompt-driven turn_end (or message_end) summarizes *every*
 *             response, so auto-queue has nothing to add and must stay out of
 *             the way or every response gets two near-identical notes.
 *   "final" — only agent_end is prompt-driven, so the last response of each run
 *             is covered and the earlier ones are not.
 *   "none"  — TTS is off, or every configured event speaks a fixed `text:`
 *             phrase, which summarizes nothing.
 */
type Coverage = "none" | "final" | "every";

function piVoiceCoverage(cfg: VoiceConfig): Coverage {
  if (cfg.enabled === false) return "none";
  const events = cfg.events ?? {};
  if (events.turn_end?.prompt || events.message_end?.prompt) return "every";
  if (events.agent_end?.prompt) return "final";
  return "none";
}

/** Events whose notes summarize a response, so their source is worth pairing. */
function summarizingEvents(cfg: VoiceConfig): { turnEnd: boolean; agentEnd: boolean } {
  if (cfg.enabled === false) return { turnEnd: false, agentEnd: false };
  return {
    turnEnd: Boolean(cfg.events?.turn_end?.prompt),
    agentEnd: Boolean(cfg.events?.agent_end?.prompt),
  };
}

/** Concatenated text content of an assistant message, or "" if it has none. */
function assistantText(message: unknown): string {
  const content = (message as { content?: unknown })?.content;
  if (typeof content === "string") return content;
  if (!Array.isArray(content)) return "";
  let text = "";
  for (const part of content) {
    if (part && typeof part === "object" && (part as { type?: string }).type === "text") {
      const t = (part as { text?: string }).text;
      if (t) text += t;
    }
  }
  return text;
}

/** Duration straight from the WAV header — no extra ffprobe process. */
function wavDurationMs(buf: Buffer): number | null {
  try {
    if (buf.length < 45 || buf.toString("ascii", 0, 4) !== "RIFF") return null;
    const channels = buf.readUInt16LE(22);
    const sampleRate = buf.readUInt32LE(24);
    const bits = buf.readUInt16LE(34);
    const bytesPerSample = (bits / 8) * channels;
    if (!sampleRate || !bytesPerSample) return null;
    return Math.round(((buf.length - 44) / (sampleRate * bytesPerSample)) * 1000);
  } catch {
    return null;
  }
}

/**
 * WAV -> Opus in an Ogg container. Resolves null if ffmpeg is unavailable.
 *
 * Bounded by a timeout because this sits in the single serial archive chain: a
 * wedged ffmpeg would otherwise block archiving of every later note for the
 * rest of the session. SIGKILL rather than SIGTERM — there is nothing to clean
 * up, and we want the pipe to close now.
 */
function toOpus(wav: Buffer): Promise<Buffer | null> {
  return new Promise((resolve) => {
    let child: ReturnType<typeof spawn>;
    try {
      child = spawn(
        "ffmpeg",
        [
          "-hide_banner",
          "-loglevel", "error",
          "-f", "wav",
          "-i", "pipe:0",
          "-c:a", "libopus",
          "-b:a", OPUS_BITRATE,
          "-ac", "1",
          "-f", "ogg",
          "pipe:1",
        ],
        { stdio: ["pipe", "pipe", "pipe"] },
      );
    } catch {
      resolve(null);
      return;
    }

    const chunks: Buffer[] = [];
    let settled = false;
    const timer = setTimeout(() => {
      try {
        child.kill("SIGKILL");
      } catch {
        /* already gone */
      }
      finish(null);
    }, FFMPEG_TIMEOUT_MS);
    const finish = (out: Buffer | null) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      resolve(out);
    };

    child.stdout?.on("data", (c: Buffer) => chunks.push(c));
    child.stderr?.resume();
    child.on("error", () => finish(null));
    child.on("close", (code) => {
      const out = Buffer.concat(chunks);
      finish(code === 0 && out.length > 0 ? out : null);
    });
    child.stdin?.on("error", () => finish(null));
    child.stdin?.end(wav);
  });
}

/**
 * Run a promise with a deadline, resolving `fallback` if it overruns.
 *
 * The losing promise is left to settle on its own (we cannot cancel a side
 * session mid-flight); this only stops it holding up the serial chain forever.
 */
function withTimeout<T>(work: Promise<T>, ms: number, fallback: T): Promise<T> {
  return new Promise<T>((resolveOuter) => {
    let done = false;
    const timer = setTimeout(() => {
      if (done) return;
      done = true;
      resolveOuter(fallback);
    }, ms);
    work.then(
      (value) => {
        if (done) return;
        done = true;
        clearTimeout(timer);
        resolveOuter(value);
      },
      () => {
        if (done) return;
        done = true;
        clearTimeout(timer);
        resolveOuter(fallback);
      },
    );
  });
}

/**
 * Is auto-queue on for this session right now?
 *
 * Read fresh on every use and never cached: the toggle lives in the browser, so
 * the user flips it *during* the session. A missing/corrupt file just means off
 * — this file is owned by the web server, and we must never fail because of it.
 */
function autoQueueEnabled(sessionId: string): boolean {
  try {
    const meta = JSON.parse(readFileSync(UI_META, "utf8")) as {
      sessions?: Record<string, { autoQueue?: boolean }>;
    };
    return meta.sessions?.[sessionId]?.autoQueue === true;
  } catch {
    return false;
  }
}

/**
 * Summarize one response into a spoken sentence, reusing the user's own tuned
 * agent_end prompt and model so queued notes sound exactly like spoken ones.
 *
 * Runs as an isolated side session that loads no extensions and no skills —
 * without `noExtensions` this extension would load into the side session and
 * recurse into its own voice handling. Same approach pi-voice uses itself.
 */
async function generateSpeechText(
  prompt: string,
  context: string,
  ctx: ExtensionContext,
  modelConfig?: { provider: string; id: string },
): Promise<string | null> {
  const model = modelConfig
    ? ctx.modelRegistry.find(modelConfig.provider, modelConfig.id)
    : ctx.model;
  if (!model) {
    console.warn("[voice-archive] No model available for auto-queue summarization.");
    return null;
  }

  const loader = new DefaultResourceLoader({
    cwd: process.cwd(),
    agentDir: AGENT_DIR,
    systemPromptOverride: () => prompt,
    noExtensions: true,
    noSkills: true,
    noPromptTemplates: true,
    noThemes: true,
    noContextFiles: true,
  });
  await loader.reload();

  const { session } = await createAgentSession({
    model,
    tools: [],
    sessionManager: SessionManager.inMemory(),
    modelRuntime: await getModelRuntime(),
    resourceLoader: loader,
  });

  try {
    let responseText = "";
    const unsub = session.subscribe((event) => {
      if (event.type === "message_end" && event.message.role === "assistant") {
        for (const part of event.message.content) {
          if (part.type === "text" && part.text) responseText += part.text;
        }
      }
    });
    await session.prompt(
      `The following is a message from a conversation that you need to summarize:\n\n""""\n${context}\n""""`,
    );
    unsub();
    return responseText.trim() || null;
  } finally {
    session.dispose();
  }
}

// Shared across auto-queue calls; reads auth.json + models.json once.
// On failure the cached promise is dropped, or one transient error (a
// half-written auth.json, a locked file) would disable auto-queue for the
// entire process lifetime.
let runtimePromise: Promise<ModelRuntime> | undefined;
function getModelRuntime(): Promise<ModelRuntime> {
  const existing = runtimePromise;
  if (existing) return existing;
  const created = ModelRuntime.create().catch((err) => {
    if (runtimePromise === created) runtimePromise = undefined;
    throw err;
  });
  runtimePromise = created;
  return created;
}

// ── Extension ──────────────────────────────────────────────────────

export default function (pi: ExtensionAPI) {
  // Capture the id as a *string* at session start. Holding the ctx and calling
  // getSessionId() later throws once pi replaces the session (reload/fork/exit).
  let sessionId = "unknown-session";
  let seq = 0;

  // speak_start fires before pi-voice's fetch; speak_end after playback.
  // Fetches can overlap even though playback is serialized, so keep a FIFO
  // of unmatched starts rather than a single slot.
  const pending: Pending[] = [];
  const PENDING_MAX = 32;

  // Serial archive queue: one archival synthesis at a time, so we never add
  // concurrent load to the TTS server the agent is also using.
  let chain: Promise<void> = Promise.resolve();

  /**
   * Append work to the serial chain, isolated from its neighbours.
   *
   * Two hazards this exists to prevent, both of which are fatal rather than
   * cosmetic:
   *   - An unhandled rejection **terminates the user's pi process**. pi installs
   *     an `uncaughtException` hook but no `unhandledRejection` one, and Node 22
   *     exits non-zero on an unhandled rejection. Note `.finally()` re-throws,
   *     so a `.catch()` must come *before* it, not after.
   *   - A rejected `chain` poisons every later `.then()`, so one failed job
   *     would silently stop archiving for the rest of the session. Re-anchoring
   *     on a resolved promise keeps each job independent.
   */
  function enqueue(work: () => Promise<void>, label: string): void {
    chain = chain
      .catch(() => {}) // never inherit a predecessor's failure
      .then(work)
      .catch((err) => console.warn(`[voice-archive] ${label} error:`, err));
  }

  // How much work the chain is doing, so the status falls back to idle only
  // once everything has really drained. Counters, not booleans: with two jobs
  // in flight a boolean would be cleared by the first to finish and report
  // `idle` while the second was still running.
  let archiveBusy = 0;
  let queueBusy = 0;

  // In headless (`pi -p`) runs the session is torn down before pi-voice even
  // finishes summarizing, so appendEntry always fails there. Say so once,
  // quietly, instead of printing a stack trace per note.
  let warnedStaleSession = false;

  // The assistant message we expect the next auto note to be summarizing.
  // Responses pi-voice has been handed to summarize but has not spoken yet,
  // oldest first; each is consumed by the next matching speak_start (§2).
  //
  // This is a queue rather than a single slot because a prompt-driven turn_end
  // means a summarization is in flight for *every* turn, and pi-voice runs them
  // concurrently (it never awaits handleAutoTTS). So several can be outstanding
  // at once, and a later turn must not overwrite an earlier turn's source.
  // Pairing is therefore oldest-first, which holds as long as the summaries
  // come back in roughly the order they were requested — true for one local
  // model on same-sized inputs, and a mis-pairing only mislabels which response
  // a note belongs to, never loses the note.
  const pendingSources: PendingSource[] = [];

  // Bounds for that queue. pi-voice drops notes without ever emitting
  // speak_start on several paths (TTS disabled for the session via alt+v, an
  // empty summarization context, empty LLM output, a swallowed ollama error),
  // and every such drop leaves an entry here forever. Unbounded, that is both a
  // slow leak and — worse — a permanent off-by-N that labels every later note
  // with a stale, much older response. So: cap the depth, and treat an entry
  // older than the expiry as never-going-to-be-claimed.
  const PENDING_SOURCE_MAX = 8;
  const PENDING_SOURCE_TTL_MS = 2 * 60 * 1000;

  /** Drop sources too old to plausibly belong to the note being spoken now. */
  function expirePendingSources(): void {
    const cutoff = Date.now() - PENDING_SOURCE_TTL_MS;
    while (pendingSources.length > 0 && pendingSources[0].at < cutoff) {
      pendingSources.shift();
    }
  }

  /** Remember a response pi-voice is summarizing, oldest-first and bounded. */
  function pushPendingSource(src: SourceRef): void {
    expirePendingSources();
    pendingSources.push({ ...src, at: Date.now() });
    while (pendingSources.length > PENDING_SOURCE_MAX) pendingSources.shift();
  }

  // Assistant responses seen this run, for auto-queue. Collected at turn_end
  // because that is exactly "one LLM response"; drained at agent_end.
  let turnBatch: SourceRef[] = [];

  function noteIdFor(ts: string): string {
    return `${ts.replace(/[:.]/g, "-")}-${String(seq++).padStart(3, "0")}`;
  }

  // ── Live status (§1) ─────────────────────────────────────────

  function statusFile(): string {
    return join(STATUS_DIR, `${sessionId}.json`);
  }

  /**
   * Publish the current phase for the web UI.
   *
   * Written tmp-then-rename so a poller never reads a half-written file, and
   * best-effort throughout: failing to *describe* our work must never break the
   * work itself. `queueDepth` counts notes still waiting to be archived.
   */
  function publishStatus(next: Phase, detail = ""): void {
    if (sessionId === "unknown-session") return;
    const trimmed = detail.replace(/\s+/g, " ").trim().slice(0, STATUS_DETAIL_LIMIT);
    try {
      mkdirSync(STATUS_DIR, { recursive: true });
      const file = statusFile();
      const tmp = `${file}.tmp`;
      writeFileSync(
        tmp,
        JSON.stringify(
          {
            v: 1,
            sessionId,
            pid: process.pid,
            cwd: process.cwd(),
            phase: next,
            detail: trimmed,
            // Notes still waiting to be archived (spec §1), not unmatched
            // speak_starts — those are waiting on playback, not on us.
            queueDepth: archiveBusy + queueBusy,
            updatedAt: new Date().toISOString(),
          },
          null,
          2,
        ),
      );
      renameSync(tmp, file);
    } catch {
      /* status is a nicety; never let it break archiving */
    }
  }

  /** Drop back to idle, but only once every kind of work has really drained. */
  function settleStatus(): void {
    if (archiveBusy === 0 && queueBusy === 0) {
      clearSummarizeWatchdog();
      publishStatus("idle");
    }
  }

  /**
   * Fail-safe for a `summarizing` phase that no note ever arrives for.
   *
   * We enter `summarizing` on the *expectation* that pi-voice is about to speak,
   * but it silently produces nothing on several paths (empty summarization
   * context, empty LLM output, a swallowed ollama error). Nothing would then
   * settle the phase, so the file would sit at `summarizing` and the server
   * would flag it ⚠ stalled after 3 minutes — training the user to ignore the
   * one signal that means a genuine wedge. Time out slightly under that
   * threshold so an unclaimed expectation resolves quietly to idle instead.
   */
  let summarizeWatchdog: NodeJS.Timeout | undefined;

  function clearSummarizeWatchdog(): void {
    if (summarizeWatchdog) {
      clearTimeout(summarizeWatchdog);
      summarizeWatchdog = undefined;
    }
  }

  function armSummarizeWatchdog(): void {
    clearSummarizeWatchdog();
    summarizeWatchdog = setTimeout(() => {
      summarizeWatchdog = undefined;
      expirePendingSources();
      settleStatus();
    }, SUMMARIZE_WATCHDOG_MS);
    // Never hold the process open just to reset a status file.
    summarizeWatchdog.unref?.();
  }

  function clearStatus(id: string = sessionId): void {
    if (id === "unknown-session") return;
    const file = join(STATUS_DIR, `${id}.json`);
    try {
      rmSync(file, { force: true });
      rmSync(`${file}.tmp`, { force: true });
    } catch {
      /* nothing to clean up */
    }
  }

  /** True if a closed-session warning was already printed this run. */
  function alreadyWarnedStale(): boolean {
    const already = warnedStaleSession;
    warnedStaleSession = true;
    return already;
  }

  /**
   * Write the note's audio and its sidecar.
   *
   * The two writes are independent on purpose. Sharing one `try` meant a failed
   * audio write (disk full, bad permissions) also skipped the sidecar, losing
   * the note's record entirely — the text is the part worth keeping most. So the
   * sidecar is written last, always, and records the audio failure instead.
   *
   * The audio goes out tmp-then-rename so a SIGKILL mid-write cannot leave a
   * truncated .opus that the web server would happily serve as valid audio.
   */
  function writeSidecar(rec: VoiceNoteSidecar, audio: Buffer | null): void {
    const dir = join(ARCHIVE_DIR, rec.sessionId);

    if (audio && rec.audio) {
      try {
        mkdirSync(dir, { recursive: true });
        const target = join(dir, rec.audio);
        const tmp = `${target}.tmp`;
        writeFileSync(tmp, audio);
        renameSync(tmp, target);
      } catch (err) {
        console.warn("[voice-archive] Could not write archive audio:", err);
        // Describe what is actually on disk: no audio, and why.
        rec.error = `audio write: ${err instanceof Error ? err.message : String(err)}`;
        rec.audio = null;
        rec.bytes = null;
      }
    }

    try {
      mkdirSync(dir, { recursive: true });
      writeFileSync(join(dir, `${rec.noteId}.json`), JSON.stringify(rec, null, 2));
    } catch (err) {
      console.warn("[voice-archive] Could not write archive sidecar:", err);
    }
  }

  /** Re-synthesize the note and store it. Never touches the session log. */
  async function archive(p: Pending, end: SpeakEnd): Promise<void> {
    const rec: VoiceNoteSidecar = {
      v: 1,
      noteId: p.noteId,
      sessionId: p.sessionId,
      ts: p.ts,
      cwd: process.cwd(),
      text: p.text,
      voice: p.voice,
      speed: p.speed,
      source: p.source,
      sourceEntryId: p.sourceEntryId,
      sourceText: p.sourceText,
      audio: null,
      bytes: null,
      durationMs: null,
    };

    publishStatus("archiving", p.text);

    // Playback failed upstream — keep the sentence, skip the audio.
    if (end.error) {
      rec.error = `playback: ${end.error}`;
      writeSidecar(rec, null);
      return;
    }

    let wav: Buffer;
    try {
      const res = await fetch(`${ttsEndpoint()}/tts`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          text: p.text,
          ...(p.voice ? { voice: p.voice } : {}),
          ...(p.speed ? { speed: p.speed } : {}),
        }),
        signal: AbortSignal.timeout(TTS_TIMEOUT_MS),
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      wav = Buffer.from(await res.arrayBuffer());
    } catch (err) {
      // Server stopped / model unloaded. The transcript is still worth keeping.
      rec.error = `tts: ${err instanceof Error ? err.message : String(err)}`;
      writeSidecar(rec, null);
      return;
    }

    rec.durationMs = wavDurationMs(wav);

    const opus = await toOpus(wav);
    const payload = opus ?? wav;
    if (!opus) rec.error = "ffmpeg unavailable — stored uncompressed WAV";

    rec.audio = `${p.noteId}.${opus ? "opus" : "wav"}`;
    rec.bytes = payload.length;
    writeSidecar(rec, payload);
  }

  // ── Capture ──────────────────────────────────────────────────────

  pi.events.on("voice:speak_start", (data: unknown) => {
    const ev = data as SpeakStart;
    if (!ev?.text || ev.source === "sample") return;

    // Pair the note with the response it summarizes (§2). Only "auto" notes
    // summarize anything: `tool` notes are text the agent chose to speak, and a
    // fixed phrase from the voice config (e.g. a constant "Still on it.") is
    // spoken every turn and describes nothing — so it must not steal the
    // remembered response from the real note that follows it.
    let source: SourceRef | null = null;
    if (ev.source === "auto") {
      expirePendingSources();
      if (pendingSources.length > 0 && !fixedPhrases(loadVoiceConfig()).has(ev.text.trim())) {
        source = pendingSources.shift() ?? null;
      }
    }

    const ts = new Date().toISOString();
    const entry: Pending = {
      noteId: noteIdFor(ts),
      sessionId,
      ts,
      text: ev.text,
      voice: ev.voice ?? null,
      speed: ev.speed ?? null,
      source: ev.source,
      sourceEntryId: source?.entryId ?? null,
      sourceText: source ? source.text.slice(0, SOURCE_TEXT_LIMIT) : null,
    };
    // Guard against unbounded growth if speak_end were ever dropped. Evict
    // *before* inserting, and drop the oldest only when it is too old to still
    // be waiting on playback: evicting a live entry would leave its speak_end to
    // fall through to the same-source fallback match below and stamp an
    // unrelated note with a bogus `playback:` error.
    while (pending.length >= PENDING_MAX) {
      const evicted = pending.shift();
      if (evicted) {
        console.warn(
          `[voice-archive] Dropping un-archived note (queue full): ${evicted.text.slice(0, 60)}`,
        );
      }
    }
    pending.push(entry);

    // Kokoro is synthesizing and afplay is about to play it.
    clearSummarizeWatchdog();
    publishStatus("speaking", ev.text);

    // Log the fact NOW, synchronously, while the session is certainly alive.
    try {
      const {
        noteId, sessionId: sid, ts: t, text, voice, speed,
        source: src, sourceEntryId, sourceText,
      } = entry;
      pi.appendEntry<VoiceNoteEntry>("voice-note", {
        v: 1, noteId, sessionId: sid, ts: t, text, voice, speed,
        source: src, sourceEntryId, sourceText,
      });
    } catch {
      // Non-fatal: the archive sidecar is still written, and the web UI folds
      // sidecar-only notes back into the timeline by timestamp.
      if (!alreadyWarnedStale()) {
        console.warn(
          "[voice-archive] Session already closed; note archived to disk only (not added to the session log).",
        );
      }
    }
  });

  pi.events.on("voice:speak_end", (data: unknown) => {
    const end = data as SpeakEnd;
    if (!end?.text || end.source === "sample") return;

    // Prefer an exact text+source match; fall back to the oldest start from
    // the same source (text is identical in practice; belt and braces).
    let idx = pending.findIndex((p) => p.text === end.text && p.source === end.source);
    if (idx === -1) idx = pending.findIndex((p) => p.source === end.source);
    if (idx === -1) return;
    const p = pending.splice(idx, 1)[0];

    // Queue behind any in-flight archive job; never block the caller.
    archiveBusy++;
    enqueue(async () => {
      try {
        await archive(p, end);
      } finally {
        archiveBusy--;
        settleStatus();
      }
    }, "Archive");
  });

  // ── Source pairing + auto-queue (§2, §4) ─────────────────────────

  /**
   * Walk the current branch backwards over assistant messages that carry text,
   * newest first. Both callers need the *entry id*, which the raw event message
   * does not have — only the persisted entry does.
   */
  function* assistantEntries(
    ctx: ExtensionContext,
  ): Generator<{ entryId: string | null; text: string }> {
    let branch: unknown[];
    try {
      branch = ctx.sessionManager.getBranch();
    } catch {
      return; // stale ctx — pairing is best-effort
    }
    for (let i = branch.length - 1; i >= 0; i--) {
      const entry = branch[i] as {
        type?: string;
        id?: string;
        message?: { role?: string };
      };
      if (entry?.type !== "message" || entry.message?.role !== "assistant") continue;
      const text = assistantText(entry.message);
      if (text.trim()) yield { entryId: entry.id ?? null, text };
    }
  }

  /**
   * Last assistant message carrying text.
   *
   * pi-voice summarizes "the last message" of the run but never tells us which
   * entry that was, so we look it up ourselves — and the entry id is what lets
   * the UI pair a note with the exact response in the transcript.
   */
  function lastAssistantSource(ctx: ExtensionContext): SourceRef | null {
    for (const found of assistantEntries(ctx)) return found;
    return null;
  }

  /**
   * Entry id for a specific response text.
   *
   * turn_end hands us the message but not its entry id, and by the time a later
   * turn fires, the newest assistant entry is no longer the one we want — so
   * match on the text across the whole branch rather than assuming the tail.
   */
  function entryIdForText(ctx: ExtensionContext, text: string): string | null {
    const needle = text.trim();
    for (const found of assistantEntries(ctx)) {
      if (found.text.trim() === needle) return found.entryId;
    }
    return null;
  }

  /**
   * Archive one auto-queue note: summarize, synthesize, store.
   *
   * Deliberately NEVER played — these exist to be browsed later, and speaking a
   * whole backlog would be intolerable. So this goes nowhere near pi-voice's
   * audio queue or afplay; it only writes files.
   */
  async function archiveQueued(
    src: SourceRef,
    cfg: VoiceConfig,
    ctx: ExtensionContext,
    label: string,
    sid: string,
  ): Promise<void> {
    const eventCfg = cfg.events?.agent_end;
    if (!eventCfg?.prompt) return;

    publishStatus("summarizing", `auto-queue ${label}`);
    // Bounded: this sits in the serial chain, so a wedged summarizer would block
    // archiving of every later note.
    const spoken = await withTimeout(
      generateSpeechText(eventCfg.prompt, src.text, ctx, eventCfg.model),
      SUMMARIZE_TIMEOUT_MS,
      null,
    );
    if (!spoken) return;

    const ts = new Date().toISOString();
    const entry: Pending = {
      noteId: noteIdFor(ts),
      // The session id captured when this batch was queued, NOT the current
      // one: a batch can run minutes later, and a /reload, fork or session
      // switch in between would otherwise file the note under whichever session
      // is live now.
      sessionId: sid,
      ts,
      text: spoken,
      // Let the TTS server apply the user's configured defaults, exactly as it
      // does for a spoken note, so replay sounds the same.
      voice: null,
      speed: null,
      source: "queue",
      sourceEntryId: src.entryId,
      sourceText: src.text.slice(0, SOURCE_TEXT_LIMIT),
    };

    // Same session-log write as the spoken path, with the same tolerance for a
    // session that has already been torn down.
    try {
      const {
        noteId, sessionId: sid, ts: t, text, voice, speed,
        source: srcKind, sourceEntryId, sourceText,
      } = entry;
      pi.appendEntry<VoiceNoteEntry>("voice-note", {
        v: 1, noteId, sessionId: sid, ts: t, text, voice, speed,
        source: srcKind, sourceEntryId, sourceText,
      });
    } catch {
      if (!alreadyWarnedStale()) {
        console.warn(
          "[voice-archive] Session already closed; note archived to disk only (not added to the session log).",
        );
      }
    }

    // No SpeakEnd exists for a note that was never spoken, so report no error.
    await archive(entry, { text: spoken, source: "queue" });
  }

  // turn_end is exactly "one LLM response plus its tool calls" — both the
  // granularity auto-queue works at (§4) and, when the user's turn_end is
  // prompt-driven, the moment pi-voice starts summarizing that response (§2).
  pi.on("turn_end", async (event, ctx) => {
    // Effective, not global: with TTS toggled off for this session (alt+v) no
    // note is coming, so queueing a source would leak and mis-pair later notes.
    const cfg = effectiveVoiceConfig(ctx);
    const message = (event as { message?: unknown }).message;
    if ((message as { role?: string })?.role !== "assistant") return;
    const text = assistantText(message);
    // Pure tool-call turns have nothing to say.
    if (!text.trim()) return;

    // Match this turn's message to its persisted entry by text. The note is
    // still worth recording without an id; it just cannot be grouped in the UI.
    const src: SourceRef = { entryId: entryIdForText(ctx, text), text };

    // §2: a prompt-driven turn_end means pi-voice is now summarizing THIS
    // response, so queue it as the source for the note that will follow.
    if (summarizingEvents(cfg).turnEnd) {
      pushPendingSource(src);
      publishStatus("summarizing", text);
      armSummarizeWatchdog();
    }

    if (autoQueueEnabled(sessionId)) turnBatch.push(src);
  });

  pi.on("agent_end", async (_event, ctx) => {
    const cfg = effectiveVoiceConfig(ctx);

    // §2: remember the response pi-voice is about to summarize. Only claim the
    // `summarizing` phase when a note is actually coming, or a run with
    // auto-TTS switched off would look busy forever.
    const src = lastAssistantSource(ctx);
    if (piVoiceHandlesAgentEnd(cfg)) {
      if (summarizingEvents(cfg).agentEnd && src) pushPendingSource(src);
      publishStatus("summarizing", src?.text ?? "");
      armSummarizeWatchdog();
    }

    // §4: drain the batch collected at turn_end.
    const batch = turnBatch;
    turnBatch = [];
    if (batch.length === 0) return;
    if (!autoQueueEnabled(sessionId)) return;
    if (!cfg.events?.agent_end?.prompt) return;

    // Dedup against what pi-voice already narrates, or we archive two
    // near-identical notes for the same response. With a prompt-driven
    // turn_end every response is already covered and auto-queue is a deliberate
    // no-op — the user's global voice config is doing this job already.
    const coverage = piVoiceCoverage(cfg);
    if (coverage === "every") return;
    const queued = coverage === "final" ? batch.slice(0, -1) : batch;
    if (queued.length === 0) return;

    // Pin the session now: the batch runs behind the chain, possibly minutes
    // later, by which time `sessionId` may describe a different session.
    const sid = sessionId;

    // Behind the same serial chain as archiving, so we never run two ollama
    // calls or two Kokoro requests at once. Fire-and-forget: the agent must
    // never wait on us.
    queueBusy++;
    enqueue(async () => {
      try {
        for (let i = 0; i < queued.length; i++) {
          try {
            await archiveQueued(queued[i], cfg, ctx, `${i + 1}/${queued.length}`, sid);
          } catch (err) {
            console.warn("[voice-archive] Auto-queue error:", err);
          }
        }
      } finally {
        queueBusy--;
        settleStatus();
      }
    }, "Auto-queue");
  });

  // ── Session lifecycle ────────────────────────────────────────────

  function adoptSession(ctx: { sessionManager: { getSessionId(): string } }) {
    let next = "unknown-session";
    try {
      next = ctx.sessionManager.getSessionId() ?? "unknown-session";
    } catch {
      next = "unknown-session";
    }
    // Retire the outgoing session's status file first. A reload/fork/switch
    // reuses this same process, so its pid stays alive and the server would keep
    // reporting the old id as a live session — frozen in whatever phase it was
    // last in — until the 15-minute staleness cutoff.
    if (next !== sessionId) {
      clearSummarizeWatchdog();
      pendingSources.length = 0;
      turnBatch = [];
      clearStatus();
    }
    sessionId = next;
  }

  pi.on("session_start", async (_event, ctx) => {
    adoptSession(ctx);
    // Announce the session as live and idle, so the UI can show which sessions
    // are open even before any voice work happens.
    publishStatus("idle");
  });

  pi.on("session_tree", async (_event, ctx) => {
    adoptSession(ctx);
    publishStatus("idle");
  });

  // A status file outlives its process otherwise, and the server would be left
  // guessing from the pid whether we are still here.
  pi.on("session_shutdown", async () => {
    clearSummarizeWatchdog();
    pendingSources.length = 0;
    turnBatch = [];
    clearStatus();
  });

  // ── /voice-notes command: open the web UI ────────────────────────

  pi.registerCommand("voice-notes", {
    description: "Open the voice note archive in a browser",
    handler: async (_args, ctx) => {
      const url = `http://127.0.0.1:${UI_PORT}/`;

      const up = await fetch(`${url}api/health`, { signal: AbortSignal.timeout(700) })
        .then((r) => r.ok)
        .catch(() => false);

      if (!up) {
        if (!existsSync(SERVER_SCRIPT)) {
          ctx.ui.notify(`voice-archive server missing: ${SERVER_SCRIPT}`, "error");
          return;
        }
        // Detached so the UI outlives this pi session. An 'error' listener is
        // mandatory: an un-listened spawn failure (ENOENT, EAGAIN) is an
        // uncaught exception, which would take pi down with it.
        try {
          const child = spawn(process.execPath, [SERVER_SCRIPT], {
            detached: true,
            stdio: "ignore",
            env: { ...process.env, VOICE_ARCHIVE_PORT: String(UI_PORT) },
          });
          child.on("error", (err) =>
            console.warn("[voice-archive] Could not start the UI server:", err),
          );
          child.unref();
        } catch (err) {
          ctx.ui.notify(`Could not start voice-archive server: ${String(err)}`, "error");
          return;
        }
        await new Promise((r) => setTimeout(r, 400));
      }

      // Best-effort browser launch: `open` is macOS-only, so on any other
      // platform (or if it is missing) just report the URL rather than throwing.
      try {
        const opener = spawn("open", [url], { detached: true, stdio: "ignore" });
        opener.on("error", () =>
          ctx.ui.notify(`Voice notes ready — open ${url}`, "info"),
        );
        opener.unref();
      } catch {
        /* reported via the notify below */
      }
      ctx.ui.notify(`Voice notes: ${url}`, "info");
    },
  });
}
