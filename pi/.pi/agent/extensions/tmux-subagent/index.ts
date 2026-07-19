/**
 * tmux Subagent Tool — delegate tasks to specialized agents.
 *
 * Each subagent runs as a separate `pi --mode json` process with an isolated
 * context window. The default child transport is configured by
 * `tmuxSubagent.defaultTransport` in settings.json. With the "auto"/"tmux"
 * transport inside tmux, the child is launched in a NEW, dedicated tmux window
 * (a "tab") — never a split of the active pi pane — so you can watch it work
 * live. With the "hidden" transport, or when tmux is unavailable, it runs
 * headless.
 *
 * Modes:
 *   - single:   { agent, task }
 *   - parallel: { tasks: [{ agent, task }, ...] }
 *
 * Agents are markdown files with frontmatter in ~/.pi/agent/agents/*.md
 * (see agents.ts). Sample agents: scout, planner, reviewer, mission-control.
 *
 * This is adapted from pi's official examples/extensions/subagent. The child
 * transport is settings-controlled via tmuxSubagent.defaultTransport in
 * settings.json: "auto" preserves the observable tmux-pane behavior, while
 * "hidden" uses a headless pipe even inside tmux.
 */

import { spawn, spawnSync } from "node:child_process";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import type { Message } from "@earendil-works/pi-ai";
import { StringEnum } from "@earendil-works/pi-ai";
import {
	CONFIG_DIR_NAME,
	type ExtensionAPI,
	getAgentDir,
	getMarkdownTheme,
	withFileMutationQueue,
} from "@earendil-works/pi-coding-agent";
import { Container, Markdown, Spacer, Text } from "@earendil-works/pi-tui";
import { Type } from "typebox";
import { type AgentConfig, type AgentScope, discoverAgents } from "./agents.ts";

const MAX_PARALLEL_PANES = 4;
const COLLAPSED_ITEM_COUNT = 10;
const PER_TASK_OUTPUT_CAP = 50 * 1024;
const POLL_MS = 200;
const DEFAULT_TIMEOUT_S = 1800;
// Keep tmux window (tab) labels short enough to sit comfortably in the status bar.
const TAB_NAME_MAX = 18;
const SETTINGS_KEY = "tmuxSubagent";
const DEFAULT_TRANSPORT: TransportPreference = "auto";

type TransportPreference = "auto" | "tmux" | "hidden";
type ResolvedTransport = "tmux" | "hidden";

interface ExtensionSettings {
	/** Default transport preference for subagent calls. */
	defaultTransport?: TransportPreference;
	/** Optional defaults for existing tool parameters. Tool-call parameters still win. */
	layout?: "h" | "v";
	focus?: boolean;
	keepPaneOpen?: boolean;
	timeoutSeconds?: number;
}

// ---------------------------------------------------------------------------
// Formatting helpers (shared with the parent-side TUI renderers)
// ---------------------------------------------------------------------------

function formatTokens(count: number): string {
	if (count < 1000) return count.toString();
	if (count < 10000) return `${(count / 1000).toFixed(1)}k`;
	if (count < 1000000) return `${Math.round(count / 1000)}k`;
	return `${(count / 1000000).toFixed(1)}M`;
}

interface UsageStats {
	input: number;
	output: number;
	cacheRead: number;
	cacheWrite: number;
	cost: number;
	contextTokens: number;
	turns: number;
}

function emptyUsage(): UsageStats {
	return { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, cost: 0, contextTokens: 0, turns: 0 };
}

function formatUsageStats(usage: UsageStats, model?: string): string {
	const parts: string[] = [];
	if (usage.turns) parts.push(`${usage.turns} turn${usage.turns > 1 ? "s" : ""}`);
	if (usage.input) parts.push(`↑${formatTokens(usage.input)}`);
	if (usage.output) parts.push(`↓${formatTokens(usage.output)}`);
	if (usage.cacheRead) parts.push(`R${formatTokens(usage.cacheRead)}`);
	if (usage.cacheWrite) parts.push(`W${formatTokens(usage.cacheWrite)}`);
	if (usage.cost) parts.push(`$${usage.cost.toFixed(4)}`);
	if (usage.contextTokens && usage.contextTokens > 0) parts.push(`ctx:${formatTokens(usage.contextTokens)}`);
	if (model) parts.push(model);
	return parts.join(" ");
}

function formatToolCall(
	toolName: string,
	args: Record<string, unknown>,
	themeFg: (color: any, text: string) => string,
): string {
	const shortenPath = (p: string) => {
		const home = os.homedir();
		return p.startsWith(home) ? `~${p.slice(home.length)}` : p;
	};
	switch (toolName) {
		case "bash": {
			const command = (args.command as string) || "...";
			const preview = command.length > 60 ? `${command.slice(0, 60)}...` : command;
			return themeFg("muted", "$ ") + themeFg("toolOutput", preview);
		}
		case "read": {
			const filePath = shortenPath((args.file_path || args.path || "...") as string);
			return themeFg("muted", "read ") + themeFg("accent", filePath);
		}
		case "write": {
			const filePath = shortenPath((args.file_path || args.path || "...") as string);
			return themeFg("muted", "write ") + themeFg("accent", filePath);
		}
		case "edit": {
			const filePath = shortenPath((args.file_path || args.path || "...") as string);
			return themeFg("muted", "edit ") + themeFg("accent", filePath);
		}
		case "ls":
			return themeFg("muted", "ls ") + themeFg("accent", shortenPath((args.path || ".") as string));
		case "find":
			return (
				themeFg("muted", "find ") +
				themeFg("accent", (args.pattern || "*") as string) +
				themeFg("dim", ` in ${shortenPath((args.path || ".") as string)}`)
			);
		case "grep":
			return (
				themeFg("muted", "grep ") +
				themeFg("accent", `/${(args.pattern || "") as string}/`) +
				themeFg("dim", ` in ${shortenPath((args.path || ".") as string)}`)
			);
		default: {
			const argsStr = JSON.stringify(args);
			const preview = argsStr.length > 50 ? `${argsStr.slice(0, 50)}...` : argsStr;
			return themeFg("accent", toolName) + themeFg("dim", ` ${preview}`);
		}
	}
}

// ---------------------------------------------------------------------------
// Result model
// ---------------------------------------------------------------------------

interface SingleResult {
	agent: string;
	agentSource: "user" | "project" | "unknown";
	task: string;
	exitCode: number; // -1 = still running
	messages: Message[];
	stderr: string;
	usage: UsageStats;
	model?: string;
	stopReason?: string;
	errorMessage?: string;
	transport: ResolvedTransport;
	paneId?: string;
}

interface SubagentDetails {
	mode: "single" | "parallel";
	agentScope: AgentScope;
	projectAgentsDir: string | null;
	results: SingleResult[];
}

function getFinalOutput(messages: Message[]): string {
	for (let i = messages.length - 1; i >= 0; i--) {
		const msg = messages[i];
		if (msg.role === "assistant") {
			for (const part of msg.content) {
				if (part.type === "text") return part.text;
			}
		}
	}
	return "";
}

function isFailedResult(r: SingleResult): boolean {
	return r.exitCode > 0 || r.stopReason === "error" || r.stopReason === "aborted";
}

function getResultOutput(r: SingleResult): string {
	if (isFailedResult(r)) return r.errorMessage || r.stderr || getFinalOutput(r.messages) || "(no output)";
	return getFinalOutput(r.messages) || "(no output)";
}

function truncateForModel(output: string): string {
	const byteLength = Buffer.byteLength(output, "utf8");
	if (byteLength <= PER_TASK_OUTPUT_CAP) return output;
	let truncated = output.slice(0, PER_TASK_OUTPUT_CAP);
	while (Buffer.byteLength(truncated, "utf8") > PER_TASK_OUTPUT_CAP) truncated = truncated.slice(0, -1);
	return `${truncated}\n\n[Output truncated. Full output preserved in tool details.]`;
}

type DisplayItem = { type: "text"; text: string } | { type: "toolCall"; name: string; args: Record<string, any> };

function getDisplayItems(messages: Message[]): DisplayItem[] {
	const items: DisplayItem[] = [];
	for (const msg of messages) {
		if (msg.role === "assistant") {
			for (const part of msg.content) {
				if (part.type === "text") items.push({ type: "text", text: part.text });
				else if (part.type === "toolCall") items.push({ type: "toolCall", name: part.name, args: part.arguments });
			}
		}
	}
	return items;
}

// ---------------------------------------------------------------------------
// Incremental JSON-line parser (used by both tmux-pane and hidden transports)
// ---------------------------------------------------------------------------

class StreamParser {
	private buffer = "";
	sawAgentEnd = false;

	constructor(
		private readonly result: SingleResult,
		private readonly onProgress: () => void,
	) {}

	push(text: string): void {
		this.buffer += text;
		const lines = this.buffer.split("\n");
		this.buffer = lines.pop() || "";
		for (const line of lines) this.handle(line);
	}

	flush(): void {
		if (this.buffer.trim()) this.handle(this.buffer);
		this.buffer = "";
	}

	private handle(line: string): void {
		if (!line.trim()) return;
		let event: any;
		try {
			event = JSON.parse(line);
		} catch {
			return;
		}
		if (event.type === "message_end" && event.message) {
			const msg = event.message as Message;
			this.result.messages.push(msg);
			if (msg.role === "assistant") {
				this.result.usage.turns++;
				const u = (msg as any).usage;
				if (u) {
					this.result.usage.input += u.input || 0;
					this.result.usage.output += u.output || 0;
					this.result.usage.cacheRead += u.cacheRead || 0;
					this.result.usage.cacheWrite += u.cacheWrite || 0;
					this.result.usage.cost += u.cost?.total || 0;
					this.result.usage.contextTokens = u.totalTokens || this.result.usage.contextTokens;
				}
				if (!this.result.model && (msg as any).model) this.result.model = (msg as any).model;
				if ((msg as any).stopReason) this.result.stopReason = (msg as any).stopReason;
				if ((msg as any).errorMessage) this.result.errorMessage = (msg as any).errorMessage;
			}
			this.onProgress();
		} else if (event.type === "agent_end") {
			this.sawAgentEnd = true;
		}
	}
}

// ---------------------------------------------------------------------------
// Child process invocation + shell quoting
// ---------------------------------------------------------------------------

/**
 * Resolve how to invoke pi for the child. Mirrors the official example: prefer
 * re-running the current script with the current runtime; fall back to `pi`.
 */
function getPiInvocation(args: string[]): { command: string; args: string[] } {
	const currentScript = process.argv[1];
	const isBunVirtualScript = currentScript?.startsWith("/$bunfs/root/");
	if (currentScript && !isBunVirtualScript && fs.existsSync(currentScript)) {
		return { command: process.execPath, args: [currentScript, ...args] };
	}
	const execName = path.basename(process.execPath).toLowerCase();
	const isGenericRuntime = /^(node|bun)(\.exe)?$/.test(execName);
	if (!isGenericRuntime) return { command: process.execPath, args };
	return { command: "pi", args };
}

/** POSIX single-quote a string for embedding in a shell command. */
function shellQuote(s: string): string {
	return `'${s.replace(/'/g, `'\\''`)}'`;
}

/**
 * The live stream renderer, written to each child's temp dir and run as
 * `node stream-render.mjs <rawFile> <agentName> <taskPreview>`. It reads pi's
 * --mode json stream on stdin, appends every raw line to <rawFile> (for the
 * parent to parse), and renders a styled, navigable session into the pane's
 * tty:
 *   - a header banner (agent + task) framed by a horizontal rule,
 *   - a dimmed, italic THINKING block with a colored left gutter — visibly the
 *     model's scratch reasoning, not the answer,
 *   - a bright RESPONSE block (the ultimate answer),
 *   - compact tool-call lines (\u2192 verb args) with \u2713/\u2717 result previews.
 * Blocks are separated by blank lines and consistent colors so the scrollback
 * reads like a document rather than a wall of white text.
 *
 * IMPORTANT: keep this source free of backticks and ${...} so it can live
 * inside the template literal below without escaping. ESC is built via
 * String.fromCharCode(27) for the same reason; runtime newlines/unicode are
 * written as \\n / \\uXXXX so they survive the enclosing template literal.
 */
const RENDERER_SOURCE = `
import fs from "node:fs";

const ESC = String.fromCharCode(27);
const rawPath = process.argv[2];
const agentName = process.argv[3] || "subagent";
const taskText = process.argv[4] || "";
const out = process.stdout;
const color = (code, s) => ESC + "[" + code + "m" + s + ESC + "[0m";

// Palette (256-color SGR; tuned for dark terminal backgrounds).
const C_TITLE = "1;36";          // banner title
const C_AGENT = "1;38;5;80";     // agent name
const C_TASK = "38;5;250";       // task line
const C_DIM = "38;5;245";        // secondary text / result previews
const C_RULE = "38;5;238";       // horizontal rules
const C_THINK_H = "1;38;5;146";  // thinking header
const C_THINK = "3;38;5;146";    // thinking body (italic)
const C_BAR = "38;5;103";        // thinking left gutter
const C_RESP_H = "1;38;5;114";   // response header
const C_TOOL = "36";             // tool keyword
const C_ARG = "38;5;250";        // tool argument
const C_OK = "1;32";
const C_ERR = "1;31";

let buffer = "";
let mode = null;            // null | "thinking" | "response"
let atLineStart = true;
let printedAnything = false;
let lastBlock = null;       // "banner" | "thinking" | "response" | "tool"

function width() {
  const c = out.columns || 80;
  return Math.max(20, Math.min(c, 100));
}
function rule() {
  let s = "";
  const w = width();
  for (let i = 0; i < w; i++) s += "\\u2500";
  return color(C_RULE, s);
}
function shortenPath(p) {
  const home = process.env.HOME || "";
  return home && p.indexOf(home) === 0 ? "~" + p.slice(home.length) : p;
}

function banner() {
  out.write("\\n" + color(C_TITLE, "\\u25b6 subagent") + color(C_DIM, " \\u00b7 ") + color(C_AGENT, agentName) + "\\n");
  if (taskText) out.write(color(C_TASK, "  " + taskText) + "\\n");
  out.write(rule() + "\\n");
  printedAnything = true;
  lastBlock = "banner";
}

// Vertical spacing before a new logical block; consecutive tool lines stay tight.
function block(type) {
  if (!atLineStart) { out.write("\\n"); atLineStart = true; }
  if (printedAnything && !(lastBlock === "tool" && type === "tool")) out.write("\\n");
  printedAnything = true;
  lastBlock = type;
}

function enterMode(m) {
  if (mode === m) return;
  block(m);
  out.write((m === "thinking" ? color(C_THINK_H, "\\u273b thinking") : color(C_RESP_H, "\\u25cf response")) + "\\n");
  atLineStart = true;
  mode = m;
}

function endBlock() {
  if (mode && !atLineStart) out.write("\\n");
  atLineStart = true;
  mode = null;
}

// Thinking: italic + dim with a colored left gutter, so it reads as the model's
// scratch reasoning and never gets confused with the final answer.
function writeThinking(text) {
  if (!text) return;
  const gutter = color(C_BAR, "\\u2502 ");
  const parts = text.split("\\n");
  for (let k = 0; k < parts.length; k++) {
    if (k > 0) { out.write("\\n"); atLineStart = true; }
    const seg = parts[k];
    if (seg) {
      if (atLineStart) { out.write(gutter); atLineStart = false; }
      out.write(color(C_THINK, seg));
    }
  }
}

// Response: bright, unadorned text — the ultimate answer.
function writeResponse(text) {
  if (!text) return;
  out.write(text);
  atLineStart = text.charAt(text.length - 1) === "\\n";
}

function fmtTool(name, args) {
  args = args || {};
  const k = (s) => color(C_TOOL, s);
  const a = (s) => color(C_ARG, s);
  if (name === "bash") {
    let cmd = String(args.command || "...");
    if (cmd.length > 72) cmd = cmd.slice(0, 72) + "\\u2026";
    return k("$ ") + a(cmd);
  }
  if (name === "read") return k("read ") + a(shortenPath(String(args.file_path || args.path || "...")));
  if (name === "write") return k("write ") + a(shortenPath(String(args.file_path || args.path || "...")));
  if (name === "edit") return k("edit ") + a(shortenPath(String(args.file_path || args.path || "...")));
  if (name === "ls") return k("ls ") + a(shortenPath(String(args.path || ".")));
  if (name === "find") return k("find ") + a(String(args.pattern || "*")) + color(C_DIM, " in " + shortenPath(String(args.path || ".")));
  if (name === "grep") return k("grep ") + a("/" + String(args.pattern || "") + "/") + color(C_DIM, " in " + shortenPath(String(args.path || ".")));
  let j = "";
  try { j = JSON.stringify(args); } catch { j = ""; }
  if (j && j.length > 60) j = j.slice(0, 60) + "\\u2026";
  return k(name) + (j ? " " + a(j) : "");
}

function collectText(arr) {
  const parts = [];
  try { for (const p of arr) if (p && typeof p.text === "string") parts.push(p.text); } catch {}
  return parts.join(" ");
}
function previewResult(r) {
  try {
    if (r == null) return "";
    let s = "";
    if (typeof r === "string") s = r;
    else if (Array.isArray(r)) s = collectText(r);
    else if (r.content) s = typeof r.content === "string" ? r.content : collectText(r.content);
    else if (typeof r.output === "string") s = r.output;
    else if (typeof r.text === "string") s = r.text;
    s = String(s).replace(/\\s+/g, " ").trim();
    if (!s) return "";
    if (s.length > 96) s = s.slice(0, 96) + "\\u2026";
    return s;
  } catch { return ""; }
}

function handle(line) {
  if (!line.trim()) return;
  let e;
  try { e = JSON.parse(line); } catch { return; }
  const t = e.type;
  if (t === "message_update" && e.assistantMessageEvent) {
    const ev = e.assistantMessageEvent;
    const et = ev.type;
    if (et === "thinking_start") enterMode("thinking");
    else if (et === "thinking_delta") { enterMode("thinking"); writeThinking(ev.delta || ""); }
    else if (et === "thinking_end") endBlock();
    else if (et === "text_start") enterMode("response");
    else if (et === "text_delta") { enterMode("response"); writeResponse(ev.delta || ""); }
    else if (et === "text_end") endBlock();
  } else if (t === "tool_execution_start") {
    endBlock();
    block("tool");
    out.write(color(C_TOOL, "\\u2192 ") + fmtTool(e.toolName, e.args) + "\\n");
    atLineStart = true;
  } else if (t === "tool_execution_end") {
    let line = "  " + (e.isError ? color(C_ERR, "\\u2717") : color(C_OK, "\\u2713"));
    const pv = previewResult(e.result);
    if (pv) line += " " + color(C_DIM, pv);
    out.write(line + "\\n");
    atLineStart = true;
  } else if (t === "agent_end") {
    endBlock();
  }
}

banner();
process.stdin.setEncoding("utf8");
process.stdin.on("data", (d) => {
  try { fs.appendFileSync(rawPath, d); } catch {}
  buffer += d;
  const lines = buffer.split("\\n");
  buffer = lines.pop() || "";
  for (const line of lines) handle(line);
});
process.stdin.on("end", () => {
  if (buffer) handle(buffer);
  endBlock();
  out.write("\\n" + rule() + "\\n");
});
`;

// ---------------------------------------------------------------------------
// tmux helpers
// ---------------------------------------------------------------------------

function insideTmux(): boolean {
	return Boolean(process.env.TMUX);
}

function resolveTransportPreference(preference: TransportPreference): ResolvedTransport {
	if (preference === "hidden") return "hidden";
	// "auto" and "tmux" both use tmux only when it is actually available. Outside
	// tmux, child pi processes continue to run headless instead of failing.
	return insideTmux() ? "tmux" : "hidden";
}

function readJsonObject(filePath: string): Record<string, unknown> | undefined {
	try {
		const raw = fs.readFileSync(filePath, "utf-8");
		const parsed = JSON.parse(raw);
		if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) return parsed as Record<string, unknown>;
	} catch {
		/* ignore missing or invalid extension settings */
	}
	return undefined;
}

function normalizeTransportPreference(value: unknown): TransportPreference | undefined {
	if (value === "auto" || value === "tmux" || value === "hidden") return value;
	return undefined;
}

function normalizeSettings(value: unknown): ExtensionSettings {
	if (!value || typeof value !== "object" || Array.isArray(value)) return {};
	const raw = value as Record<string, unknown>;
	const settings: ExtensionSettings = {};

	// Preferred setting: { "tmuxSubagent": { "defaultTransport": "hidden" } }.
	// Also accept { transport } and { openInTmux } as easy-to-guess aliases.
	settings.defaultTransport =
		normalizeTransportPreference(raw.defaultTransport) ??
		normalizeTransportPreference(raw.transport) ??
		(typeof raw.openInTmux === "boolean" ? (raw.openInTmux ? "auto" : "hidden") : undefined);

	if (raw.layout === "h" || raw.layout === "v") settings.layout = raw.layout;
	if (typeof raw.focus === "boolean") settings.focus = raw.focus;
	if (typeof raw.keepPaneOpen === "boolean") settings.keepPaneOpen = raw.keepPaneOpen;
	if (typeof raw.timeoutSeconds === "number" && Number.isFinite(raw.timeoutSeconds) && raw.timeoutSeconds > 0) {
		settings.timeoutSeconds = Math.floor(raw.timeoutSeconds);
	}

	return settings;
}

function loadExtensionSettings(cwd: string, projectTrusted: boolean): ExtensionSettings {
	const globalSettings = normalizeSettings(readJsonObject(path.join(getAgentDir(), "settings.json"))?.[SETTINGS_KEY]);
	if (!projectTrusted) return globalSettings;

	const projectSettings = normalizeSettings(readJsonObject(path.join(cwd, CONFIG_DIR_NAME, "settings.json"))?.[SETTINGS_KEY]);
	return { ...globalSettings, ...projectSettings };
}

function tmux(args: string[]): { ok: boolean; stdout: string; stderr: string } {
	const res = spawnSync("tmux", args, { encoding: "utf8" });
	return { ok: res.status === 0, stdout: (res.stdout || "").trim(), stderr: (res.stderr || "").trim() };
}

function tmuxPaneState(paneId: string): { exists: boolean; dead: boolean } {
	const res = tmux(["list-panes", "-a", "-F", "#{pane_id} #{pane_dead}"]);
	if (!res.ok) return { exists: false, dead: false };
	for (const line of res.stdout.split("\n")) {
		const [id, dead] = line.split(" ");
		if (id === paneId) return { exists: true, dead: dead === "1" };
	}
	return { exists: false, dead: false };
}

// ---------------------------------------------------------------------------
// tmux tab (window) naming
// ---------------------------------------------------------------------------

/**
 * Make a string safe and compact for a tmux window name shown in the status
 * bar: collapse any run of characters outside [A-Za-z0-9._-] to a single dash
 * (this also neutralizes tmux status-format-special chars such as '#', '{',
 * '}', '[') and trim stray separators. Spaces become dashes so the bar stays
 * tidy.
 */
function sanitizeTabPart(s: string): string {
	return s
		.replace(/[^\w.-]+/g, "-")
		.replace(/-{2,}/g, "-")
		.replace(/^[-.]+|[-.]+$/g, "");
}

/**
 * A short label identifying the calling pi session: the user-set session name
 * if there is one, otherwise the working directory's basename (the project).
 */
function callerLabel(sessionName: string | undefined, cwd: string): string {
	const raw = (sessionName && sessionName.trim()) || path.basename(cwd) || "pi";
	return sanitizeTabPart(raw) || "pi";
}

/**
 * Build the tmux window (tab) label for a subagent run as "<caller>/<suffix>",
 * e.g. "dotfiles/scout" or "my-app/3x". The suffix (what's running) is given
 * priority; the caller label fills whatever budget is left so the whole label
 * stays within TAB_NAME_MAX and fits the status bar.
 */
function buildTabName(sessionName: string | undefined, cwd: string, suffix: string): string {
	const suf = sanitizeTabPart(suffix);
	const slugBudget = Math.max(4, TAB_NAME_MAX - (suf ? suf.length + 1 : 0));
	const slug = callerLabel(sessionName, cwd).slice(0, slugBudget);
	return suf ? `${slug}/${suf}` : slug;
}

interface PaneGroupOptions {
	/** tmux window name shown in the status bar (the "tab" label). */
	windowName: string;
	/** Switch to the new window (true) or leave it in the background (false). */
	focus: boolean;
	/** Pane arrangement: "h" = equal-width columns (default), "v" = equal-height rows. */
	layout: "h" | "v";
}

/**
 * Places subagent panes into a single dedicated tmux window (a "tab") instead of
 * splitting the active pi pane. The first pane opens a NEW window; each
 * subsequent pane splits that same window; panes are re-evened into equal-width
 * side-by-side columns (even-horizontal) as each arrives. addPane() is
 * fully synchronous (every tmux call is spawnSync), so concurrent callers in
 * parallel mode can never interleave — exactly one window is ever created.
 */
class PaneGroup {
	private windowTarget: string | null = null;

	constructor(private readonly opts: PaneGroupOptions) {}

	addPane(runPath: string, cwd: string): { ok: boolean; paneId?: string; stderr?: string } {
		if (this.windowTarget === null) {
			const args = ["new-window", "-c", cwd, "-P", "-F", "#{pane_id}"];
			if (this.opts.windowName) args.push("-n", this.opts.windowName);
			if (!this.opts.focus) args.push("-d");
			args.push(`bash ${shellQuote(runPath)}`);
			const res = tmux(args);
			if (!res.ok || !res.stdout) return { ok: false, stderr: res.stderr || "tmux new-window failed" };
			this.windowTarget = res.stdout;
			// Keep our label; don't let tmux auto-rename the tab from the running command.
			tmux(["set-option", "-w", "-t", this.windowTarget, "automatic-rename", "off"]);
			return { ok: true, paneId: res.stdout };
		}
		const args = [
			"split-window",
			this.opts.layout === "v" ? "-v" : "-h",
			"-t",
			this.windowTarget,
			"-c",
			cwd,
			"-d",
			"-P",
			"-F",
			"#{pane_id}",
			`bash ${shellQuote(runPath)}`,
		];
		const res = tmux(args);
		if (!res.ok || !res.stdout) return { ok: false, stderr: res.stderr || "tmux split-window failed" };
		// Keep panes as equal-size, side-by-side columns ("v" stacks them into rows).
		const evenLayout = this.opts.layout === "v" ? "even-vertical" : "even-horizontal";
		tmux(["select-layout", "-t", this.windowTarget, evenLayout]);
		return { ok: true, paneId: res.stdout };
	}
}

// ---------------------------------------------------------------------------
// Building the per-child temp workspace + run script
// ---------------------------------------------------------------------------

interface ChildWorkspace {
	dir: string;
	rawPath: string;
	errPath: string;
	exitPath: string;
	runPath: string;
	rendererPath: string;
}

async function buildChildWorkspace(agent: AgentConfig, task: string): Promise<ChildWorkspace> {
	const dir = await fs.promises.mkdtemp(path.join(os.tmpdir(), "pi-tmux-subagent-"));
	const rawPath = path.join(dir, "raw.jsonl");
	const errPath = path.join(dir, "stderr.log");
	const exitPath = path.join(dir, "exit.code");
	const runPath = path.join(dir, "run.sh");
	const rendererPath = path.join(dir, "stream-render.mjs");
	const promptPath = path.join(dir, "system-prompt.md");

	await fs.promises.writeFile(rendererPath, RENDERER_SOURCE, { encoding: "utf-8", mode: 0o600 });

	const piArgs = ["--mode", "json", "--no-session"];
	if (agent.model) piArgs.push("--model", agent.model);
	if (agent.tools && agent.tools.length > 0) piArgs.push("--tools", agent.tools.join(","));
	if (agent.systemPrompt.trim()) {
		await withFileMutationQueue(promptPath, async () => {
			await fs.promises.writeFile(promptPath, agent.systemPrompt, { encoding: "utf-8", mode: 0o600 });
		});
		piArgs.push("--append-system-prompt", promptPath);
	}
	piArgs.push(`Task: ${task}`);

	const invocation = getPiInvocation(piArgs);
	const piCmd = [invocation.command, ...invocation.args].map(shellQuote).join(" ");
	const nodeQ = shellQuote(process.execPath);
	const taskPreview = task.replace(/\s+/g, " ").slice(0, 200);

	// The banner + closing rule are drawn by the renderer (it knows the pane
	// width); the run script only appends a colored exit-status footer. NOTE:
	// /usr/bin/env bash may be bash 3.2 (macOS), which does NOT expand \u in
	// printf — so the footer uses literal glyphs (✓ ✗ ·) and octal \033 for ESC.
	const script = [
		"#!/usr/bin/env bash",
		"set -o pipefail",
		`${piCmd} 2> ${shellQuote(errPath)} | ${nodeQ} ${shellQuote(rendererPath)} ${shellQuote(rawPath)} ${shellQuote(agent.name)} ${shellQuote(taskPreview)}`,
		"ec=${PIPESTATUS[0]}",
		`printf '%s' "$ec" > ${shellQuote(exitPath)}`,
		`if [ "$ec" = 0 ]; then printf '\\033[1;32m✓ finished\\033[0m\\033[38;5;245m · exit %s\\033[0m\\n' "$ec"; else printf '\\033[1;31m✗ failed\\033[0m\\033[38;5;245m · exit %s\\033[0m\\n' "$ec"; fi`,
		"",
	].join("\n");
	await fs.promises.writeFile(runPath, script, { encoding: "utf-8", mode: 0o755 });

	return { dir, rawPath, errPath, exitPath, runPath, rendererPath };
}

function cleanupWorkspace(ws: ChildWorkspace): void {
	try {
		fs.rmSync(ws.dir, { recursive: true, force: true });
	} catch {
		/* ignore */
	}
}

// ---------------------------------------------------------------------------
// Transports
// ---------------------------------------------------------------------------

type OnResultUpdate = (result: SingleResult) => void;

interface PaneOptions {
	layout: "h" | "v";
	size: string;
	focus: boolean;
	keepPaneOpen: boolean;
	timeoutSeconds: number;
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

/** Run a subagent in a visible tmux pane and tail its output. */
async function runInPane(
	result: SingleResult,
	agent: AgentConfig,
	task: string,
	cwd: string,
	opts: PaneOptions,
	group: PaneGroup,
	signal: AbortSignal | undefined,
	onUpdate: OnResultUpdate | undefined,
): Promise<void> {
	const ws = await buildChildWorkspace(agent, task);
	const parser = new StreamParser(result, () => onUpdate?.(result));

	try {
		const placement = group.addPane(ws.runPath, cwd);
		if (!placement.ok || !placement.paneId) {
			result.exitCode = 1;
			result.stderr = `tmux pane placement failed: ${placement.stderr || "unknown error"}`;
			return;
		}
		result.paneId = placement.paneId;
		tmux(["select-pane", "-t", result.paneId, "-T", `subagent: ${agent.name}`]);
		if (opts.keepPaneOpen) tmux(["set-option", "-p", "-t", result.paneId, "remain-on-exit", "on"]);
		onUpdate?.(result);

		const started = Date.now();
		let lastLen = 0;
		let aborted = false;

		const readNew = () => {
			let content = "";
			try {
				content = fs.readFileSync(ws.rawPath, "utf-8");
			} catch {
				return;
			}
			if (content.length > lastLen) {
				parser.push(content.slice(lastLen));
				lastLen = content.length;
			}
		};

		while (true) {
			if (signal?.aborted) {
				aborted = true;
				break;
			}
			readNew();

			if (fs.existsSync(ws.exitPath)) {
				readNew();
				parser.flush();
				const raw = fs.readFileSync(ws.exitPath, "utf-8").trim();
				result.exitCode = Number.parseInt(raw, 10);
				if (!Number.isFinite(result.exitCode)) result.exitCode = 0;
				break;
			}

			const paneState = tmuxPaneState(result.paneId);
			if (!paneState.exists && !fs.existsSync(ws.exitPath)) {
				// Pane vanished without writing a sentinel (killed/crashed). Give it a
				// brief grace period for the file to flush, then finalize.
				await sleep(POLL_MS);
				readNew();
				parser.flush();
				result.exitCode = fs.existsSync(ws.exitPath) ? 0 : parser.sawAgentEnd ? 0 : 1;
				break;
			}

			if ((Date.now() - started) / 1000 > opts.timeoutSeconds) {
				tmux(["kill-pane", "-t", result.paneId]);
				result.exitCode = 124;
				result.errorMessage = `Timed out after ${opts.timeoutSeconds}s`;
				break;
			}

			await sleep(POLL_MS);
		}

		try {
			result.stderr = fs.readFileSync(ws.errPath, "utf-8").slice(-4000);
		} catch {
			/* ignore */
		}

		if (aborted) {
			tmux(["kill-pane", "-t", result.paneId]);
			result.stopReason = "aborted";
			result.exitCode = 130;
			throw new Error("Subagent aborted");
		}
	} finally {
		cleanupWorkspace(ws);
	}
}

/** Fallback: run headless (hidden) when not inside tmux. */
async function runHidden(
	result: SingleResult,
	agent: AgentConfig,
	task: string,
	cwd: string,
	signal: AbortSignal | undefined,
	onUpdate: OnResultUpdate | undefined,
): Promise<void> {
	const parser = new StreamParser(result, () => onUpdate?.(result));

	const piArgs = ["--mode", "json", "--no-session"];
	if (agent.model) piArgs.push("--model", agent.model);
	if (agent.tools && agent.tools.length > 0) piArgs.push("--tools", agent.tools.join(","));

	let promptPath: string | null = null;
	let promptDir: string | null = null;
	if (agent.systemPrompt.trim()) {
		promptDir = await fs.promises.mkdtemp(path.join(os.tmpdir(), "pi-subagent-"));
		promptPath = path.join(promptDir, "system-prompt.md");
		await fs.promises.writeFile(promptPath, agent.systemPrompt, { encoding: "utf-8", mode: 0o600 });
		piArgs.push("--append-system-prompt", promptPath);
	}
	piArgs.push(`Task: ${task}`);

	try {
		let aborted = false;
		const exitCode = await new Promise<number>((resolve) => {
			const invocation = getPiInvocation(piArgs);
			const proc = spawn(invocation.command, invocation.args, {
				cwd,
				shell: false,
				stdio: ["ignore", "pipe", "pipe"],
			});
			proc.stdout.on("data", (d) => parser.push(d.toString()));
			proc.stderr.on("data", (d) => {
				result.stderr = (result.stderr + d.toString()).slice(-4000);
			});
			proc.on("close", (code) => {
				parser.flush();
				resolve(code ?? 0);
			});
			proc.on("error", () => resolve(1));
			if (signal) {
				const kill = () => {
					aborted = true;
					proc.kill("SIGTERM");
					setTimeout(() => !proc.killed && proc.kill("SIGKILL"), 5000);
				};
				if (signal.aborted) kill();
				else signal.addEventListener("abort", kill, { once: true });
			}
		});
		result.exitCode = exitCode;
		if (aborted) {
			result.stopReason = "aborted";
			throw new Error("Subagent aborted");
		}
	} finally {
		if (promptDir)
			try {
				fs.rmSync(promptDir, { recursive: true, force: true });
			} catch {
				/* ignore */
			}
	}
}

/** Dispatch to the right transport and produce a finalized SingleResult. */
async function runOne(
	agents: AgentConfig[],
	agentName: string,
	task: string,
	cwd: string,
	opts: PaneOptions,
	transport: ResolvedTransport,
	group: PaneGroup,
	signal: AbortSignal | undefined,
	onUpdate: OnResultUpdate | undefined,
): Promise<SingleResult> {
	const agent = agents.find((a) => a.name === agentName);
	const result: SingleResult = {
		agent: agentName,
		agentSource: agent?.source ?? "unknown",
		task,
		exitCode: -1,
		messages: [],
		stderr: "",
		usage: emptyUsage(),
		model: agent?.model,
		transport,
	};

	if (!agent) {
		const available = agents.map((a) => `"${a.name}"`).join(", ") || "none";
		result.exitCode = 1;
		result.stderr = `Unknown agent: "${agentName}". Available: ${available}.`;
		return result;
	}

	if (transport === "tmux") await runInPane(result, agent, task, cwd, opts, group, signal, onUpdate);
	else await runHidden(result, agent, task, cwd, signal, onUpdate);

	if (result.exitCode === -1) result.exitCode = 0;
	return result;
}

// ---------------------------------------------------------------------------
// Tool schema
// ---------------------------------------------------------------------------

const TaskItem = Type.Object({
	agent: Type.String({ description: "Name of the agent to invoke" }),
	task: Type.String({ description: "Task to delegate to the agent" }),
	cwd: Type.Optional(Type.String({ description: "Working directory for the agent process" })),
});

const AgentScopeSchema = StringEnum(["user", "project", "both"] as const, {
	description: 'Which agent directories to use. Default: "user". Use "both" to include project-local agents.',
	default: "user",
});

const LayoutSchema = StringEnum(["h", "v"] as const, {
	description:
		'Pane arrangement in the shared window: "h" = equal-width columns (default), "v" = equal-height rows.',
	default: "h",
});

const TransportSchema = StringEnum(["auto", "tmux", "hidden"] as const, {
	description:
		'Override tmuxSubagent.defaultTransport for this call: "auto" = tmux when available, "tmux" = tmux when available, "hidden" = headless/no tmux window.',
	default: DEFAULT_TRANSPORT,
});

const SubagentParams = Type.Object({
	agent: Type.Optional(Type.String({ description: "Agent name (single mode)" })),
	task: Type.Optional(Type.String({ description: "Task to delegate (single mode)" })),
	tasks: Type.Optional(Type.Array(TaskItem, { description: "Array of {agent, task} to run in parallel panes" })),
	cwd: Type.Optional(Type.String({ description: "Working directory for the agent process (single mode)" })),
	agentScope: Type.Optional(AgentScopeSchema),
	confirmProjectAgents: Type.Optional(
		Type.Boolean({ description: "Prompt before running project-local agents. Default: true.", default: true }),
	),
	layout: Type.Optional(LayoutSchema),
	transport: Type.Optional(TransportSchema),
	size: Type.Optional(
		Type.String({
			description:
				'Deprecated: subagent panes now open side-by-side in a dedicated tmux window (tab), so this value is ignored.',
			default: "40%",
		}),
	),
	focus: Type.Optional(
		Type.Boolean({ description: "Focus the new pane instead of staying in pi. Default: false.", default: false }),
	),
	keepPaneOpen: Type.Optional(
		Type.Boolean({
			description: "Keep the (dead) pane open after finishing so you can review it. Default: true.",
			default: true,
		}),
	),
	timeoutSeconds: Type.Optional(
		Type.Integer({ description: `Max seconds before killing the subagent. Default: ${DEFAULT_TIMEOUT_S}.` }),
	),
});

// ---------------------------------------------------------------------------
// Extension
// ---------------------------------------------------------------------------

export default function (pi: ExtensionAPI) {
	pi.registerTool({
		name: "subagent",
		label: "Subagent",
		description: [
			"Delegate a task to a specialized subagent that runs in its own pi process with an isolated context window.",
			`Default transport comes from settings.json ${SETTINGS_KEY}.defaultTransport ("auto", "tmux", or "hidden") and can be overridden per call with transport.`,
			"When transport resolves to tmux inside tmux, subagents open in a NEW dedicated tmux window (a 'tab'), never a split of the active pane; when transport is hidden they run headless.",
			"Modes: single (agent + task) or parallel (tasks array).",
			`Default agent scope is "user" (from ${path.join(getAgentDir(), "agents")}).`,
			`Set agentScope "both" to also load project agents from ${CONFIG_DIR_NAME}/agents.`,
		].join(" "),
		promptSnippet: "Delegate a task to a specialized subagent, using settings-controlled tmux/headless transport",
		promptGuidelines: [
			"Use subagent to delegate a self-contained task (recon, planning, review, or implementation) to an isolated context window; prefer it for large explorations so the main context stays lean.",
			"Use subagent parallel mode (tasks array) when several independent investigations can run at once.",
			"Pick the cheapest capable agent (e.g. scout for read-only recon) and give each subagent a precise, self-contained task; it does not see the parent conversation.",
		],
		parameters: SubagentParams,

		async execute(_toolCallId, params, signal, onUpdate, ctx) {
			const agentScope: AgentScope = params.agentScope ?? "user";
			const discovery = discoverAgents(ctx.cwd, agentScope);
			const agents = discovery.agents;
			const confirmProjectAgents = params.confirmProjectAgents ?? true;

			const hasTasks = (params.tasks?.length ?? 0) > 0;
			const hasSingle = Boolean(params.agent && params.task);
			const settings = loadExtensionSettings(ctx.cwd, ctx.isProjectTrusted());
			const transportPreference: TransportPreference = params.transport ?? settings.defaultTransport ?? DEFAULT_TRANSPORT;
			const transport = resolveTransportPreference(transportPreference);

			const opts: PaneOptions = {
				layout: params.layout ?? settings.layout ?? "h",
				size: params.size ?? "40%",
				focus: params.focus ?? settings.focus ?? false,
				keepPaneOpen: params.keepPaneOpen ?? settings.keepPaneOpen ?? true,
				timeoutSeconds: params.timeoutSeconds ?? settings.timeoutSeconds ?? DEFAULT_TIMEOUT_S,
			};

			const makeDetails =
				(mode: "single" | "parallel") =>
				(results: SingleResult[]): SubagentDetails => ({
					mode,
					agentScope,
					projectAgentsDir: discovery.projectAgentsDir,
					results,
				});

			if (Number(hasTasks) + Number(hasSingle) !== 1) {
				const available = agents.map((a) => `${a.name} (${a.source})`).join(", ") || "none";
				return {
					content: [
						{
							type: "text",
							text: `Invalid parameters. Provide exactly one of: {agent, task} or {tasks:[...]}.\nAvailable agents: ${available}`,
						},
					],
					details: makeDetails("single")([]),
					isError: true,
				};
			}

			// Confirm before running repo-controlled project agents.
			if ((agentScope === "project" || agentScope === "both") && confirmProjectAgents && ctx.hasUI) {
				const requested = new Set<string>();
				if (params.tasks) for (const t of params.tasks) requested.add(t.agent);
				if (params.agent) requested.add(params.agent);
				const projectAgents = Array.from(requested)
					.map((n) => agents.find((a) => a.name === n))
					.filter((a): a is AgentConfig => a?.source === "project");
				if (projectAgents.length > 0) {
					const names = projectAgents.map((a) => a.name).join(", ");
					const ok = await ctx.ui.confirm(
						"Run project-local agents?",
						`Agents: ${names}\nSource: ${discovery.projectAgentsDir ?? "(unknown)"}\n\nProject agents are repo-controlled. Only continue for trusted repositories.`,
					);
					if (!ok)
						return {
							content: [{ type: "text", text: "Canceled: project-local agents not approved." }],
							details: makeDetails(hasTasks ? "parallel" : "single")([]),
							isError: true,
						};
				}
			}

			// ---- Parallel mode -------------------------------------------------
			if (params.tasks && params.tasks.length > 0) {
				if (params.tasks.length > MAX_PARALLEL_PANES) {
					return {
						content: [
							{
								type: "text",
								text: `Too many parallel tasks (${params.tasks.length}). Max is ${MAX_PARALLEL_PANES}.`,
							},
						],
						details: makeDetails("parallel")([]),
						isError: true,
					};
				}

				const results: SingleResult[] = params.tasks.map((t) => ({
					agent: t.agent,
					agentSource: "unknown",
					task: t.task,
					exitCode: -1,
					messages: [],
					stderr: "",
					usage: emptyUsage(),
					transport,
				}));

				const emit = () => {
					const running = results.filter((r) => r.exitCode === -1).length;
					const done = results.length - running;
					onUpdate?.({
						content: [{ type: "text", text: `Parallel: ${done}/${results.length} done, ${running} running...` }],
						details: makeDetails("parallel")(results.map((r) => ({ ...r }))),
					});
				};

				// All parallel subagents share ONE new window (tab), labeled after the
				// calling session (+ task count) so you can tell whose subagents these are.
				const windowName = buildTabName(
					ctx.sessionManager.getSessionName?.(),
					ctx.cwd,
					`${params.tasks.length}x`,
				);
				const group = new PaneGroup({ windowName, focus: opts.focus, layout: opts.layout });
				const settled = await Promise.all(
					params.tasks.map(async (t, i) => {
						const r = await runOne(agents, t.agent, t.task, t.cwd ?? ctx.cwd, opts, transport, group, signal, (updated) => {
							results[i] = updated;
							emit();
						});
						results[i] = r;
						emit();
						return r;
					}),
				);

				const successCount = settled.filter((r) => !isFailedResult(r)).length;
				const summaries = settled.map((r) => {
					const status = isFailedResult(r)
						? `failed${r.stopReason && r.stopReason !== "stop" ? ` (${r.stopReason})` : ""}`
						: "completed";
					return `### [${r.agent}] ${status}\n\n${truncateForModel(getResultOutput(r))}`;
				});
				return {
					content: [
						{
							type: "text",
							text: `Parallel: ${successCount}/${settled.length} succeeded\n\n${summaries.join("\n\n---\n\n")}`,
						},
					],
					details: makeDetails("parallel")(settled),
				};
			}

			// ---- Single mode ---------------------------------------------------
			// A lone subagent gets its own dedicated new window (tab), labeled after the
			// calling session and the agent it runs (e.g. "dotfiles/scout").
			const windowName = buildTabName(
				ctx.sessionManager.getSessionName?.(),
				ctx.cwd,
				params.agent as string,
			);
			const singleGroup = new PaneGroup({ windowName, focus: opts.focus, layout: opts.layout });
			const result = await runOne(
				agents,
				params.agent as string,
				params.task as string,
				params.cwd ?? ctx.cwd,
				opts,
				transport,
				singleGroup,
				signal,
				(updated) =>
					onUpdate?.({
						content: [{ type: "text", text: getFinalOutput(updated.messages) || "(running...)" }],
						details: makeDetails("single")([updated]),
					}),
			);

			if (isFailedResult(result)) {
				return {
					content: [{ type: "text", text: `Agent ${result.stopReason || "failed"}: ${getResultOutput(result)}` }],
					details: makeDetails("single")([result]),
					isError: true,
				};
			}
			return {
				content: [{ type: "text", text: getFinalOutput(result.messages) || "(no output)" }],
				details: makeDetails("single")([result]),
			};
		},

		renderCall(args, theme) {
			const scope: AgentScope = args.agentScope ?? "user";
			if (args.tasks && args.tasks.length > 0) {
				let text =
					theme.fg("toolTitle", theme.bold("subagent ")) +
					theme.fg("accent", `parallel (${args.tasks.length} panes)`) +
					theme.fg("muted", ` [${scope}]`);
				for (const t of args.tasks.slice(0, 4)) {
					const preview = t.task.length > 40 ? `${t.task.slice(0, 40)}...` : t.task;
					text += `\n  ${theme.fg("accent", t.agent)}${theme.fg("dim", ` ${preview}`)}`;
				}
				return new Text(text, 0, 0);
			}
			const preview = args.task ? (args.task.length > 60 ? `${args.task.slice(0, 60)}...` : args.task) : "...";
			return new Text(
				theme.fg("toolTitle", theme.bold("subagent ")) +
					theme.fg("accent", args.agent || "...") +
					theme.fg("muted", ` [${scope}]`) +
					`\n  ${theme.fg("dim", preview)}`,
				0,
				0,
			);
		},

		renderResult(result, { expanded }, theme) {
			const details = result.details as SubagentDetails | undefined;
			if (!details || details.results.length === 0) {
				const text = result.content[0];
				return new Text(text?.type === "text" ? text.text : "(no output)", 0, 0);
			}
			const mdTheme = getMarkdownTheme();
			const fg = theme.fg.bind(theme);

			const paneLabel = (r: SingleResult) =>
				r.transport === "tmux" && r.paneId ? theme.fg("dim", ` (tmux ${r.paneId})`) : "";

			const renderItems = (items: DisplayItem[], limit?: number) => {
				const toShow = limit ? items.slice(-limit) : items;
				const skipped = limit && items.length > limit ? items.length - limit : 0;
				let text = "";
				if (skipped > 0) text += theme.fg("muted", `... ${skipped} earlier items\n`);
				for (const item of toShow) {
					if (item.type === "text") {
						const preview = expanded ? item.text : item.text.split("\n").slice(0, 3).join("\n");
						text += `${theme.fg("toolOutput", preview)}\n`;
					} else {
						text += `${theme.fg("muted", "→ ") + formatToolCall(item.name, item.args, fg)}\n`;
					}
				}
				return text.trimEnd();
			};

			// Single
			if (details.mode === "single" && details.results.length === 1) {
				const r = details.results[0];
				const isError = isFailedResult(r);
				const running = r.exitCode === -1;
				const icon = running ? theme.fg("warning", "⏳") : isError ? theme.fg("error", "✗") : theme.fg("success", "✓");
				const items = getDisplayItems(r.messages);
				const finalOutput = getFinalOutput(r.messages);

				if (expanded) {
					const c = new Container();
					let header = `${icon} ${theme.fg("toolTitle", theme.bold(r.agent))}${theme.fg("muted", ` (${r.agentSource})`)}${paneLabel(r)}`;
					if (isError && r.stopReason) header += ` ${theme.fg("error", `[${r.stopReason}]`)}`;
					c.addChild(new Text(header, 0, 0));
					if (isError && (r.errorMessage || r.stderr))
						c.addChild(new Text(theme.fg("error", `Error: ${r.errorMessage || r.stderr}`), 0, 0));
					c.addChild(new Spacer(1));
					c.addChild(new Text(theme.fg("muted", "─── Task ───"), 0, 0));
					c.addChild(new Text(theme.fg("dim", r.task), 0, 0));
					c.addChild(new Spacer(1));
					c.addChild(new Text(theme.fg("muted", "─── Output ───"), 0, 0));
					for (const item of items)
						if (item.type === "toolCall")
							c.addChild(new Text(theme.fg("muted", "→ ") + formatToolCall(item.name, item.args, fg), 0, 0));
					if (finalOutput) {
						c.addChild(new Spacer(1));
						c.addChild(new Markdown(finalOutput.trim(), 0, 0, mdTheme));
					}
					const usage = formatUsageStats(r.usage, r.model);
					if (usage) {
						c.addChild(new Spacer(1));
						c.addChild(new Text(theme.fg("dim", usage), 0, 0));
					}
					return c;
				}

				let text = `${icon} ${theme.fg("toolTitle", theme.bold(r.agent))}${theme.fg("muted", ` (${r.agentSource})`)}${paneLabel(r)}`;
				if (isError && r.stopReason) text += ` ${theme.fg("error", `[${r.stopReason}]`)}`;
				if (isError && (r.errorMessage || r.stderr)) text += `\n${theme.fg("error", `Error: ${r.errorMessage || r.stderr}`)}`;
				else if (items.length === 0) text += `\n${theme.fg("muted", running ? "(running...)" : "(no output)")}`;
				else {
					text += `\n${renderItems(items, COLLAPSED_ITEM_COUNT)}`;
					if (items.length > COLLAPSED_ITEM_COUNT) text += `\n${theme.fg("muted", "(Ctrl+O to expand)")}`;
				}
				const usage = formatUsageStats(r.usage, r.model);
				if (usage) text += `\n${theme.fg("dim", usage)}`;
				return new Text(text, 0, 0);
			}

			// Parallel
			const running = details.results.filter((r) => r.exitCode === -1).length;
			const successCount = details.results.filter((r) => r.exitCode !== -1 && !isFailedResult(r)).length;
			const failCount = details.results.filter((r) => r.exitCode !== -1 && isFailedResult(r)).length;
			const isRunning = running > 0;
			const icon = isRunning
				? theme.fg("warning", "⏳")
				: failCount > 0
					? theme.fg("warning", "◐")
					: theme.fg("success", "✓");
			const status = isRunning
				? `${successCount + failCount}/${details.results.length} done, ${running} running`
				: `${successCount}/${details.results.length} tasks`;

			let text = `${icon} ${theme.fg("toolTitle", theme.bold("parallel "))}${theme.fg("accent", status)}`;
			for (const r of details.results) {
				const rIcon =
					r.exitCode === -1
						? theme.fg("warning", "⏳")
						: isFailedResult(r)
							? theme.fg("error", "✗")
							: theme.fg("success", "✓");
				const items = getDisplayItems(r.messages);
				text += `\n\n${theme.fg("muted", "─── ")}${theme.fg("accent", r.agent)} ${rIcon}${paneLabel(r)}`;
				if (items.length === 0) text += `\n${theme.fg("muted", r.exitCode === -1 ? "(running...)" : "(no output)")}`;
				else text += `\n${renderItems(items, expanded ? undefined : 5)}`;
			}
			if (!expanded) text += `\n${theme.fg("muted", "(Ctrl+O to expand)")}`;
			return new Text(text, 0, 0);
		},
	});
}
