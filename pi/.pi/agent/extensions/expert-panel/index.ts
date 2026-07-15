/**
 * Expert Panel — consult isolated expert personas and return their opinions.
 *
 * Registers a `consult_panel` tool. Each requested persona is spawned as a
 * maximally locked-down `pi` child process:
 *
 *   PI_EXPERT_TEMPERATURE=<t> pi --mode json --no-session
 *     --no-extensions -e <this-dir>/consultant-temp.ts   # ONLY hook that loads
 *     --no-skills --no-prompt-templates --no-context-files
 *     --no-tools                                         # zero tools
 *     --provider <p> --model <m> --thinking <th>
 *     --system-prompt "<persona body>"                   # persona = whole prompt
 *     "Task: <question>\n\nContext:\n<context>\n\nDecision criteria:\n<criteria>"
 *
 * The consultant reasons only from persona + question + the curated context
 * and decision criteria — the single intentional information channel. Only its
 * FINAL assistant message is returned to the caller.
 *
 * Personas live in ./personas/*.md (frontmatter: id, name, domain,
 * consult_when, bias; body = the consultant's entire system prompt). They are
 * never skill-discovered and their bodies never enter the parent's context —
 * the parent model only ever handles persona ids. The discoverable surface is
 * the `expert-panel` skill (~/.pi/agent/skills/expert-panel/SKILL.md), which
 * carries the roster + selection protocol.
 *
 * Global config (no per-persona settings) in ~/.pi/agent/settings.json:
 *   { "expertPanel": { "provider": "...", "model": "...",
 *                      "temperature": 0.7, "thinking": "high" } }
 * Falls back to defaultProvider / defaultModel / defaultThinkingLevel.
 *
 * When running inside tmux, the whole panel opens in a single NEW, dedicated
 * tmux window (a "tab") — never a split of the active pi pane — with each
 * consultant rendering live in its own equal-width column (adapted from tmux-subagent);
 * otherwise consultants run headless.
 */

import { spawn, spawnSync } from "node:child_process";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import { fileURLToPath } from "node:url";
import type { Message } from "@earendil-works/pi-ai";
import { type ExtensionAPI, getAgentDir, getMarkdownTheme, parseFrontmatter } from "@earendil-works/pi-coding-agent";
import { Container, Markdown, Spacer, Text } from "@earendil-works/pi-tui";
import { Type } from "typebox";

const MAX_PANEL_SIZE = 4;
const POLL_MS = 200;
const DEFAULT_TIMEOUT_S = 600;
const PER_OPINION_CAP = 50 * 1024;

const EXT_DIR = path.dirname(fileURLToPath(import.meta.url));
const PERSONAS_DIR = path.join(EXT_DIR, "personas");
const CONSULTANT_TEMP_PATH = path.join(EXT_DIR, "consultant-temp.ts");

// ---------------------------------------------------------------------------
// Personas
// ---------------------------------------------------------------------------

interface Persona {
	id: string;
	name: string;
	body: string;
	filePath: string;
}

function loadPersonas(): Map<string, Persona> {
	const personas = new Map<string, Persona>();
	let entries: fs.Dirent[];
	try {
		entries = fs.readdirSync(PERSONAS_DIR, { withFileTypes: true });
	} catch {
		return personas;
	}
	for (const entry of entries) {
		if (!entry.name.endsWith(".md")) continue;
		if (!entry.isFile() && !entry.isSymbolicLink()) continue;
		const filePath = path.join(PERSONAS_DIR, entry.name);
		try {
			const content = fs.readFileSync(filePath, "utf-8");
			const { frontmatter, body } = parseFrontmatter<Record<string, string>>(content);
			const id = frontmatter.id || entry.name.replace(/\.md$/, "");
			if (!body.trim()) continue;
			personas.set(id, { id, name: frontmatter.name || id, body: body.trim(), filePath });
		} catch {
			/* skip unreadable persona */
		}
	}
	return personas;
}

// ---------------------------------------------------------------------------
// Global config
// ---------------------------------------------------------------------------

interface PanelConfig {
	provider?: string;
	model?: string;
	temperature?: number;
	thinking: string;
	timeoutSeconds: number;
}

function loadConfig(): PanelConfig {
	let settings: Record<string, any> = {};
	try {
		settings = JSON.parse(fs.readFileSync(path.join(getAgentDir(), "settings.json"), "utf-8"));
	} catch {
		/* use defaults */
	}
	const ep = (settings.expertPanel ?? {}) as Record<string, any>;
	return {
		provider: ep.provider ?? settings.defaultProvider,
		model: ep.model ?? settings.defaultModel,
		temperature: typeof ep.temperature === "number" ? ep.temperature : 0.7,
		thinking: ep.thinking ?? settings.defaultThinkingLevel ?? "high",
		timeoutSeconds: typeof ep.timeoutSeconds === "number" ? ep.timeoutSeconds : DEFAULT_TIMEOUT_S,
	};
}

// ---------------------------------------------------------------------------
// Child invocation
// ---------------------------------------------------------------------------

/** Prefer re-running the current pi script with the current runtime. */
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

function shellQuote(s: string): string {
	return `'${s.replace(/'/g, `'\\''`)}'`;
}

function buildConsultantArgs(cfg: PanelConfig, personaBody: string, prompt: string): string[] {
	const args = [
		"--mode",
		"json",
		"--no-session",
		// Lockdown: nothing ambient reaches the consultant.
		"--no-extensions",
		"-e",
		CONSULTANT_TEMP_PATH, // the ONLY hook that loads (temperature)
		"--no-skills",
		"--no-prompt-templates",
		"--no-context-files",
		"--no-tools",
	];
	if (cfg.provider) args.push("--provider", cfg.provider);
	if (cfg.model) args.push("--model", cfg.model);
	args.push("--thinking", cfg.thinking);
	args.push("--system-prompt", personaBody);
	args.push(prompt);
	return args;
}

/**
 * Env for the consultant's temperature hook. PI_EXPERT_STRIP_THINKING tells
 * the hook it may remove the provider thinking field (only when the user
 * explicitly configured thinking "off") so temperature can apply — Anthropic
 * rejects custom temperatures whenever thinking is enabled or adaptive.
 */
function consultantEnv(cfg: PanelConfig): Record<string, string> {
	const env: Record<string, string> = {};
	if (cfg.temperature !== undefined) {
		env.PI_EXPERT_TEMPERATURE = String(cfg.temperature);
		if (cfg.thinking === "off") env.PI_EXPERT_STRIP_THINKING = "1";
	}
	return env;
}

function buildPrompt(
	question: string,
	context: string | undefined,
	decisionCriteria: string | undefined,
): string {
	let prompt = `Task: ${question}`;
	if (context?.trim()) {
		prompt += `\n\nContext — this is your entire world; you cannot see any files, tools, or prior conversation:\n${context.trim()}`;
	}
	if (decisionCriteria?.trim()) {
		prompt += `\n\nDecision criteria — what a useful answer must weigh here:\n${decisionCriteria.trim()}`;
	}
	return prompt;
}

// ---------------------------------------------------------------------------
// Result model
// ---------------------------------------------------------------------------

interface UsageStats {
	input: number;
	output: number;
	cost: number;
	turns: number;
}

interface ConsultResult {
	personaId: string;
	personaName: string;
	exitCode: number; // -1 = still running
	messages: Message[];
	stderr: string;
	usage: UsageStats;
	model?: string;
	stopReason?: string;
	errorMessage?: string;
	transport: "tmux" | "hidden";
	paneId?: string;
}

interface PanelDetails {
	question: string;
	context?: string;
	decisionCriteria?: string;
	temperature?: number;
	thinking: string;
	results: ConsultResult[];
}

function getOpinion(messages: Message[]): string {
	// Final assistant message only — thinking stays with the consultant.
	for (let i = messages.length - 1; i >= 0; i--) {
		const msg = messages[i];
		if (msg.role === "assistant") {
			const texts = msg.content.filter((p) => p.type === "text").map((p: any) => p.text);
			if (texts.length > 0) return texts.join("\n\n");
		}
	}
	return "";
}

function isFailed(r: ConsultResult): boolean {
	return r.exitCode > 0 || r.stopReason === "error" || r.stopReason === "aborted";
}

function truncateOpinion(text: string): string {
	if (Buffer.byteLength(text, "utf8") <= PER_OPINION_CAP) return text;
	let truncated = text.slice(0, PER_OPINION_CAP);
	while (Buffer.byteLength(truncated, "utf8") > PER_OPINION_CAP) truncated = truncated.slice(0, -1);
	return `${truncated}\n\n[Opinion truncated.]`;
}

// ---------------------------------------------------------------------------
// JSON-line stream parser (captures messages from `pi --mode json`)
// ---------------------------------------------------------------------------

class StreamParser {
	private buffer = "";
	sawAgentEnd = false;

	constructor(
		private readonly result: ConsultResult,
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
					this.result.usage.cost += u.cost?.total || 0;
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
// tmux helpers
// ---------------------------------------------------------------------------

function insideTmux(): boolean {
	return Boolean(process.env.TMUX);
}

function tmux(args: string[]): { ok: boolean; stdout: string; stderr: string } {
	const res = spawnSync("tmux", args, { encoding: "utf8" });
	return { ok: res.status === 0, stdout: (res.stdout || "").trim(), stderr: (res.stderr || "").trim() };
}

function tmuxPaneExists(paneId: string): boolean {
	const res = tmux(["list-panes", "-a", "-F", "#{pane_id}"]);
	return res.ok && res.stdout.split("\n").includes(paneId);
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
 * Places consultant panes into a single dedicated tmux window (a "tab") instead
 * of splitting the active pi pane. The first pane opens a NEW window; each
 * subsequent pane splits that same window; panes are re-evened into equal-width
 * side-by-side columns (even-horizontal) as each arrives. addPane() is
 * fully synchronous (every tmux call is spawnSync), so concurrent callers can
 * never interleave — exactly one window is ever created for the whole panel.
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
		// Keep consultant panes as equal-width, side-by-side columns.
		tmux(["select-layout", "-t", this.windowTarget, "even-horizontal"]);
		return { ok: true, paneId: res.stdout };
	}
}

/**
 * Minimal live stream renderer for the consultant pane: tees the raw JSONL
 * stream to <rawFile> for the parent to parse, and pretty-prints streamed
 * text to the pane tty. Consultants have no tools, so text is all there is.
 * Kept free of backticks and ${...} so it can live in this template literal.
 */
const RENDERER_SOURCE = `
import fs from "node:fs";

const ESC = String.fromCharCode(27);
const rawPath = process.argv[2];
const out = process.stdout;
const color = (code, s) => ESC + "[" + code + "m" + s + ESC + "[0m";

let buffer = "";
let inText = false;
let inThinking = false;

function endBlock() {
  if (inText || inThinking) { out.write("\\n"); inText = false; inThinking = false; }
}

function handle(line) {
  if (!line.trim()) return;
  let e;
  try { e = JSON.parse(line); } catch { return; }
  if (e.type === "message_update" && e.assistantMessageEvent) {
    const ev = e.assistantMessageEvent;
    if (ev.type === "thinking_delta") { inThinking = true; out.write(color("2", ev.delta || "")); }
    else if (ev.type === "thinking_end") endBlock();
    else if (ev.type === "text_delta") { inText = true; out.write(ev.delta || ""); }
    else if (ev.type === "text_end") endBlock();
  } else if (e.type === "agent_end") {
    endBlock();
  }
}

process.stdin.setEncoding("utf8");
process.stdin.on("data", (d) => {
  try { fs.appendFileSync(rawPath, d); } catch {}
  buffer += d;
  const lines = buffer.split("\\n");
  buffer = lines.pop() || "";
  for (const line of lines) handle(line);
});
process.stdin.on("end", () => { if (buffer) handle(buffer); endBlock(); });
`;

// ---------------------------------------------------------------------------
// Per-consultant temp workspace + run script (pane transport)
// ---------------------------------------------------------------------------

interface ChildWorkspace {
	dir: string;
	rawPath: string;
	errPath: string;
	exitPath: string;
	runPath: string;
}

/**
 * Renders the consultant's full brief — persona name plus the three context
 * channels it was actually given (question, context, decision criteria) — as a
 * color-coded banner shown at the very TOP of the pane, so a viewer can see
 * exactly what this expert is working from. Every channel is showcased and each
 * section is easily identifiable by type: its own uppercase label and color
 * (question=magenta, context=blue, decision criteria=green). Real ESC bytes are
 * emitted straight into a file that the run script `cat`s, so there is no
 * bash-level escaping to get wrong regardless of what the brief contains.
 */
const ANSI_ESC = "\x1b";
const sgr = (code: string, s: string): string => `${ANSI_ESC}[${code}m${s}${ANSI_ESC}[0m`;

function buildBriefing(
	persona: Persona,
	question: string,
	context: string | undefined,
	decisionCriteria: string | undefined,
): string {
	const header = (code: string, label: string): string => {
		const prefix = `── ${label} `;
		return sgr(`1;${code}`, prefix + "─".repeat(Math.max(3, 46 - prefix.length)));
	};
	const section = (code: string, label: string, body: string | undefined): string =>
		`${header(code, label)}\n${body?.trim() || sgr("2", "(none provided)")}`;
	const blocks = [
		sgr("1;36", `▶ consultant: ${persona.name}`),
		section("35", "QUESTION", question),
		section("34", "CONTEXT", context),
		section("32", "DECISION CRITERIA", decisionCriteria),
		sgr("2", `── briefing ends · live answer below ${"─".repeat(9)}`),
	];
	return `${blocks.join("\n\n")}\n\n`;
}

async function buildChildWorkspace(
	persona: Persona,
	cfg: PanelConfig,
	prompt: string,
	briefing: string,
): Promise<ChildWorkspace> {
	const dir = await fs.promises.mkdtemp(path.join(os.tmpdir(), "pi-expert-panel-"));
	const rawPath = path.join(dir, "raw.jsonl");
	const errPath = path.join(dir, "stderr.log");
	const exitPath = path.join(dir, "exit.code");
	const runPath = path.join(dir, "run.sh");
	const rendererPath = path.join(dir, "stream-render.mjs");
	const briefingPath = path.join(dir, "briefing.txt");

	await fs.promises.writeFile(rendererPath, RENDERER_SOURCE, { encoding: "utf-8", mode: 0o600 });
	await fs.promises.writeFile(briefingPath, briefing, { encoding: "utf-8", mode: 0o600 });

	const invocation = getPiInvocation(buildConsultantArgs(cfg, persona.body, prompt));
	const piCmd = [invocation.command, ...invocation.args].map(shellQuote).join(" ");
	const nodeQ = shellQuote(process.execPath);

	const envExports = Object.entries(consultantEnv(cfg)).map(
		([key, value]) => `export ${key}=${shellQuote(value)}`,
	);
	const script = [
		"#!/usr/bin/env bash",
		"set -o pipefail",
		...envExports,
		`cat ${shellQuote(briefingPath)}`,
		`${piCmd} 2> ${shellQuote(errPath)} | ${nodeQ} ${shellQuote(rendererPath)} ${shellQuote(rawPath)}`,
		"ec=${PIPESTATUS[0]}",
		`printf '%s' "$ec" > ${shellQuote(exitPath)}`,
		`printf '\\n\\033[2m── consultant finished (exit %s) ──\\033[0m\\n' "$ec"`,
		"",
	].join("\n");
	await fs.promises.writeFile(runPath, script, { encoding: "utf-8", mode: 0o755 });

	return { dir, rawPath, errPath, exitPath, runPath };
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

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

async function runInPane(
	result: ConsultResult,
	persona: Persona,
	cfg: PanelConfig,
	prompt: string,
	briefing: string,
	cwd: string,
	group: PaneGroup,
	signal: AbortSignal | undefined,
	onProgress: () => void,
): Promise<void> {
	const ws = await buildChildWorkspace(persona, cfg, prompt, briefing);
	const parser = new StreamParser(result, onProgress);

	try {
		const placement = group.addPane(ws.runPath, cwd);
		if (!placement.ok || !placement.paneId) {
			result.exitCode = 1;
			result.stderr = `tmux pane placement failed: ${placement.stderr || "unknown error"}`;
			return;
		}
		result.paneId = placement.paneId;
		tmux(["select-pane", "-t", result.paneId, "-T", `expert: ${persona.name}`]);
		tmux(["set-option", "-p", "-t", result.paneId, "remain-on-exit", "on"]);
		onProgress();

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

			if (!tmuxPaneExists(result.paneId)) {
				await sleep(POLL_MS);
				readNew();
				parser.flush();
				result.exitCode = fs.existsSync(ws.exitPath) ? 0 : parser.sawAgentEnd ? 0 : 1;
				break;
			}

			if ((Date.now() - started) / 1000 > cfg.timeoutSeconds) {
				tmux(["kill-pane", "-t", result.paneId]);
				result.exitCode = 124;
				result.errorMessage = `Timed out after ${cfg.timeoutSeconds}s`;
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
		}
	} finally {
		cleanupWorkspace(ws);
	}
}

async function runHidden(
	result: ConsultResult,
	persona: Persona,
	cfg: PanelConfig,
	prompt: string,
	cwd: string,
	signal: AbortSignal | undefined,
	onProgress: () => void,
): Promise<void> {
	const parser = new StreamParser(result, onProgress);
	const timer = { id: undefined as NodeJS.Timeout | undefined };

	const exitCode = await new Promise<number>((resolve) => {
		const invocation = getPiInvocation(buildConsultantArgs(cfg, persona.body, prompt));
		const env = { ...process.env, ...consultantEnv(cfg) };
		if (cfg.temperature === undefined) delete env.PI_EXPERT_TEMPERATURE;
		if (cfg.thinking !== "off") delete env.PI_EXPERT_STRIP_THINKING;

		const proc = spawn(invocation.command, invocation.args, {
			cwd,
			env,
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

		const kill = (why: "abort" | "timeout") => {
			if (why === "timeout") {
				result.errorMessage = `Timed out after ${cfg.timeoutSeconds}s`;
				result.exitCode = 124;
			} else {
				result.stopReason = "aborted";
			}
			proc.kill("SIGTERM");
			setTimeout(() => !proc.killed && proc.kill("SIGKILL"), 5000);
		};
		timer.id = setTimeout(() => kill("timeout"), cfg.timeoutSeconds * 1000);
		if (signal) {
			if (signal.aborted) kill("abort");
			else signal.addEventListener("abort", () => kill("abort"), { once: true });
		}
	});
	if (timer.id) clearTimeout(timer.id);
	if (result.exitCode !== 124) result.exitCode = exitCode;
	if (result.stopReason === "aborted") result.exitCode = 130;
}

async function consultOne(
	persona: Persona,
	cfg: PanelConfig,
	question: string,
	context: string | undefined,
	decisionCriteria: string | undefined,
	cwd: string,
	group: PaneGroup,
	signal: AbortSignal | undefined,
	onProgress: () => void,
): Promise<ConsultResult> {
	const result: ConsultResult = {
		personaId: persona.id,
		personaName: persona.name,
		exitCode: -1,
		messages: [],
		stderr: "",
		usage: { input: 0, output: 0, cost: 0, turns: 0 },
		transport: insideTmux() ? "tmux" : "hidden",
	};
	const prompt = buildPrompt(question, context, decisionCriteria);
	const briefing = buildBriefing(persona, question, context, decisionCriteria);

	if (insideTmux()) await runInPane(result, persona, cfg, prompt, briefing, cwd, group, signal, onProgress);
	else await runHidden(result, persona, cfg, prompt, cwd, signal, onProgress);

	if (result.exitCode === -1) result.exitCode = 0;
	if (!isFailed(result) && !getOpinion(result.messages)) {
		result.exitCode = result.exitCode || 1;
		result.errorMessage = result.errorMessage || "Consultant produced no final answer";
	}
	return result;
}

// ---------------------------------------------------------------------------
// Extension
// ---------------------------------------------------------------------------

const ConsultPanelParams = Type.Object({
	question: Type.String({
		description:
			'The single sharp question every expert answers. Prefer a concrete decision ("X or Y, given ...?") over "any thoughts?".',
	}),
	context: Type.String({
		description:
			"REQUIRED. The expert's entire world — it has NO access to your files, tools, or conversation, so anything not written here does not exist for it. Write a self-contained brief: what the artifact/decision is and why, the surrounding system, the hard constraints (scale, team, deadline, budget, compatibility), and the alternatives you have already weighed. Paste the actual code/design/spec VERBATIM — do not summarize it. Not every item applies to every consult; include whatever an expert would otherwise have to ask for.",
	}),
	decision_criteria: Type.String({
		description:
			'REQUIRED. What separates a useful answer from a generic one here: the specific trade-off(s) in tension and how you will judge them (e.g. "correctness under contention over write latency"; "maintainable by a 3-person team over raw speed"). This is what turns "it depends" into a decision — state it even for quick consults. If you are not choosing between fixed alternatives, name what a good answer must optimize for.',
	}),
	personas: Type.Array(Type.String({ description: "Persona id from the expert-panel roster" }), {
		description: "2-4 persona ids from the expert-panel skill roster (prefer experts likely to disagree)",
		minItems: 1,
		maxItems: MAX_PANEL_SIZE,
	}),
});

export default function (pi: ExtensionAPI) {
	pi.registerTool({
		name: "consult_panel",
		label: "Consult Expert Panel",
		description: [
			"Consult a panel of isolated expert personas. Each expert runs as a locked-down process",
			"(no tools, no files, no skills, no conversation history): its ENTIRE world is its persona plus the",
			'question, context, and decision_criteria you pass. Thin context yields generic "it depends" answers,',
			"so assemble a self-contained brief. It then returns one opinionated answer.",
			"Persona ids, the roster, the context checklist, and the selection protocol live in the expert-panel skill — load it first.",
		].join(" "),
		promptSnippet: "Consult a panel of isolated expert personas for independent opinions (roster: expert-panel skill)",
		promptGuidelines: [
			'Before calling consult_panel, load the expert-panel skill. Experts are isolated — they see only your question, context, and decision_criteria (no files, tools, or history), so assemble a self-contained brief: what/why, hard constraints, alternatives already weighed, and any code/design pasted verbatim; then state the decision_criteria (the real trade-off to weigh). Self-test: if you can imagine an expert answering "it depends", add the deciding detail. Pick 2-4 personas likely to disagree.',
		],
		parameters: ConsultPanelParams,

		async execute(_toolCallId, params, signal, onUpdate, ctx) {
			const personas = loadPersonas();
			const cfg = loadConfig();

			const makeDetails = (results: ConsultResult[]): PanelDetails => ({
				question: params.question,
				context: params.context,
				decisionCriteria: params.decision_criteria,
				temperature: cfg.temperature,
				thinking: cfg.thinking,
				results,
			});

			const requested = params.personas ?? [];
			if (requested.length < 1 || requested.length > MAX_PANEL_SIZE) {
				return {
					content: [{ type: "text", text: `Provide 1-${MAX_PANEL_SIZE} persona ids.` }],
					details: makeDetails([]),
					isError: true,
				};
			}
			const unknown = requested.filter((id) => !personas.has(id));
			if (unknown.length > 0) {
				const available = Array.from(personas.keys()).sort().join(", ");
				return {
					content: [
						{
							type: "text",
							text: `Unknown persona id(s): ${unknown.join(", ")}.\nAvailable: ${available}`,
						},
					],
					details: makeDetails([]),
					isError: true,
				};
			}
			const duplicates = requested.filter((id, i) => requested.indexOf(id) !== i);
			if (duplicates.length > 0) {
				return {
					content: [{ type: "text", text: `Duplicate persona id(s): ${duplicates.join(", ")}` }],
					details: makeDetails([]),
					isError: true,
				};
			}

			const selected = requested.map((id) => personas.get(id) as Persona);
			const results: ConsultResult[] = selected.map((p) => ({
				personaId: p.id,
				personaName: p.name,
				exitCode: -1,
				messages: [],
				stderr: "",
				usage: { input: 0, output: 0, cost: 0, turns: 0 },
				transport: insideTmux() ? "tmux" : "hidden",
			}));

			const emit = () => {
				const running = results.filter((r) => r.exitCode === -1).length;
				onUpdate?.({
					content: [
						{
							type: "text",
							text: `Panel: ${results.length - running}/${results.length} done, ${running} consulting...`,
						},
					],
					details: makeDetails(results.map((r) => ({ ...r }))),
				});
			};
			emit();

			// Single wave (panel is capped at MAX_PANEL_SIZE consultants). The whole
			// panel shares ONE new window (tab); consultant panes tile live.
			const group = new PaneGroup({ windowName: "expert-panel", focus: false, layout: "h" });
			const settled = await Promise.all(
				selected.map(async (persona, i) => {
					const r = await consultOne(persona, cfg, params.question, params.context, params.decision_criteria, ctx.cwd, group, signal, () => emit());
					results[i] = r;
					emit();
					return r;
				}),
			);

			if (signal?.aborted) throw new Error("Panel aborted");

			const sections = settled.map((r) => {
				if (isFailed(r)) {
					const why = r.errorMessage || r.stderr.split("\n").filter(Boolean).pop() || "unknown error";
					return `### ${r.personaName} (${r.personaId}) — FAILED\n\n${why}`;
				}
				return `### ${r.personaName} (${r.personaId})\n\n${truncateOpinion(getOpinion(r.messages))}`;
			});
			const okCount = settled.filter((r) => !isFailed(r)).length;

			return {
				content: [
					{
						type: "text",
						text: `Expert panel — ${okCount}/${settled.length} opinions returned.\n\n${sections.join("\n\n---\n\n")}`,
					},
				],
				details: makeDetails(settled),
				isError: okCount === 0,
			};
		},

		renderCall(args, theme) {
			const ids = (args.personas ?? []).join(", ") || "...";
			const q = args.question
				? args.question.length > 70
					? `${args.question.slice(0, 70)}...`
					: args.question
				: "...";
			let text =
				theme.fg("toolTitle", theme.bold("consult_panel ")) +
				theme.fg("accent", ids) +
				`\n  ${theme.fg("dim", q)}`;
			const meta: string[] = [];
			if (args.context) meta.push(`+${args.context.length} ctx`);
			if (args.decision_criteria) meta.push(`+${args.decision_criteria.length} criteria`);
			if (meta.length) text += theme.fg("muted", ` (${meta.join(", ")})`);
			return new Text(text, 0, 0);
		},

		renderResult(result, { expanded }, theme) {
			const details = result.details as PanelDetails | undefined;
			if (!details || details.results.length === 0) {
				const text = result.content[0];
				return new Text(text?.type === "text" ? text.text : "(no output)", 0, 0);
			}
			const mdTheme = getMarkdownTheme();
			const running = details.results.filter((r) => r.exitCode === -1).length;
			const failed = details.results.filter((r) => r.exitCode !== -1 && isFailed(r)).length;
			const icon =
				running > 0
					? theme.fg("warning", "⏳")
					: failed > 0
						? theme.fg("warning", "◐")
						: theme.fg("success", "✓");
			const status =
				running > 0
					? `${details.results.length - running}/${details.results.length} done, ${running} consulting`
					: `${details.results.length - failed}/${details.results.length} opinions`;

			if (expanded) {
				const c = new Container();
				c.addChild(new Text(`${icon} ${theme.fg("toolTitle", theme.bold("expert panel"))} ${theme.fg("accent", status)}`, 0, 0));
				c.addChild(new Text(theme.fg("dim", details.question), 0, 0));
				if (details.decisionCriteria) {
					c.addChild(new Text(theme.fg("muted", `criteria: ${details.decisionCriteria}`), 0, 0));
				}
				for (const r of details.results) {
					c.addChild(new Spacer(1));
					const rIcon =
						r.exitCode === -1
							? theme.fg("warning", "⏳")
							: isFailed(r)
								? theme.fg("error", "✗")
								: theme.fg("success", "✓");
					const pane = r.paneId ? theme.fg("dim", ` (tmux ${r.paneId})`) : "";
					c.addChild(new Text(`${theme.fg("muted", "─── ")}${theme.fg("accent", r.personaName)} ${rIcon}${pane}`, 0, 0));
					if (isFailed(r)) {
						c.addChild(new Text(theme.fg("error", r.errorMessage || r.stderr || "failed"), 0, 0));
					} else {
						const opinion = getOpinion(r.messages);
						if (opinion) c.addChild(new Markdown(opinion.trim(), 0, 0, mdTheme));
						else c.addChild(new Text(theme.fg("muted", r.exitCode === -1 ? "(consulting...)" : "(no output)"), 0, 0));
					}
					const u = r.usage;
					const parts: string[] = [];
					if (u.output) parts.push(`↓${u.output}`);
					if (u.cost) parts.push(`$${u.cost.toFixed(4)}`);
					if (r.model) parts.push(r.model);
					if (parts.length) c.addChild(new Text(theme.fg("dim", parts.join(" ")), 0, 0));
				}
				return c;
			}

			let text = `${icon} ${theme.fg("toolTitle", theme.bold("expert panel"))} ${theme.fg("accent", status)}`;
			for (const r of details.results) {
				const rIcon =
					r.exitCode === -1
						? theme.fg("warning", "⏳")
						: isFailed(r)
							? theme.fg("error", "✗")
							: theme.fg("success", "✓");
				text += `\n${rIcon} ${theme.fg("accent", r.personaName)}`;
				if (isFailed(r)) text += ` ${theme.fg("error", r.errorMessage || "failed")}`;
				else {
					const opinion = getOpinion(r.messages);
					if (opinion) {
						const preview = opinion.replace(/\s+/g, " ").slice(0, 100);
						text += ` ${theme.fg("dim", preview)}${opinion.length > 100 ? theme.fg("muted", "…") : ""}`;
					} else if (r.exitCode === -1) text += ` ${theme.fg("muted", "(consulting...)")}`;
				}
			}
			text += `\n${theme.fg("muted", "(Ctrl+O to expand)")}`;
			return new Text(text, 0, 0);
		},
	});
}
