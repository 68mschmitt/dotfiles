/**
 * OpenAI Codex Usage Extension for Prime Agent
 *
 * Publishes your ChatGPT/Codex subscription quota as a Prime Agent status item,
 * e.g.
 *
 *     73% 2h15m
 *
 * Data source: GET https://chatgpt.com/backend-api/wham/usage
 *   - Uses the existing Prime Agent OAuth token from auth.json (`openai-codex`).
 *   - Sends the same `chatgpt-account-id` identity header Prime Agent uses for Codex.
 *   - Shows the most constrained rate-limit window as percentage remaining
 *     plus time until that window resets.
 *
 * The status is only published while the active model provider is
 * `openai-codex` and an OpenAI Codex OAuth credential is configured.
 */

import { arch, platform, release } from "node:os";
import { join } from "node:path";
import { readFile, writeFile } from "node:fs/promises";
import { getAgentDir, type ExtensionAPI, type ExtensionContext } from "@earendil-works/pi-coding-agent";
import { truncateToWidth } from "@earendil-works/pi-tui";

// ── Tunables ────────────────────────────────────────────────────────────────
const STATUS_KEY = "openai-usage";
const PROVIDER = "openai-codex";
const USAGE_URL = "https://chatgpt.com/backend-api/wham/usage";
const JWT_CLAIM_PATH = "https://api.openai.com/auth";

const MIN_INTERVAL_MS = 60_000; // never hit the network more than once/min
const STALE_MS = 5 * 60_000; // refetch on triggers only if older than this
const COOLDOWN_429_MS = 15 * 60_000; // back off this long after a 429
const FETCH_TIMEOUT_MS = 8_000;

// Low-remaining coloring (truecolor; matches the original Pi extension palette).
const WARN_REMAINING_PCT = 25;
const CRIT_REMAINING_PCT = 10;
const C_WARN = "\x1b[38;2;254;188;56m"; // #febc38 amber
const C_CRIT = "\x1b[38;2;215;95;95m"; // #d75f5f red
const C_RESET = "\x1b[0m";
// ──────────────────────────────────────────────────────────────────────────

const AGENT_DIR = getAgentDir();
const AUTH_PATH = join(AGENT_DIR, "auth.json");
const CACHE_PATH = join(AGENT_DIR, ".openai-usage-cache.json");

interface Credential {
	token: string;
	accountId: string;
}

interface Meter {
	remainingPercent: number; // 0..100, already clamped for display
	resetAtMs?: number;
	windowSeconds?: number;
}

function clampPercent(n: number): number {
	return Math.max(0, Math.min(100, n));
}

function numberValue(value: unknown): number | undefined {
	const n = typeof value === "number" ? value : typeof value === "string" && value.trim() !== "" ? Number(value) : NaN;
	return Number.isFinite(n) ? n : undefined;
}

function epochToMs(value: unknown): number | undefined {
	const n = numberValue(value);
	if (n === undefined) return undefined;
	// /wham/usage currently returns epoch seconds, but tolerate ms too.
	return n > 10_000_000_000 ? n : n * 1000;
}

function decodeJwtPayload(token: string): any | null {
	try {
		const part = token.split(".")[1];
		if (!part) return null;
		const padded = part.replace(/-/g, "+").replace(/_/g, "/") + "=".repeat((4 - (part.length % 4)) % 4);
		return JSON.parse(Buffer.from(padded, "base64").toString("utf8"));
	} catch {
		return null;
	}
}

function accountIdFromToken(token: string): string | null {
	const payload = decodeJwtPayload(token);
	const accountId = payload?.[JWT_CLAIM_PATH]?.chatgpt_account_id;
	return typeof accountId === "string" && accountId.length > 0 ? accountId : null;
}

async function readStoredCredential(): Promise<Partial<Credential> | null> {
	try {
		const raw = await readFile(AUTH_PATH, "utf8");
		const auth = JSON.parse(raw);
		const a = auth?.[PROVIDER];
		if (a?.type !== "oauth" || typeof a.access !== "string") return null;
		return {
			token: a.access,
			...(typeof a.accountId === "string" && a.accountId.length > 0 ? { accountId: a.accountId } : {}),
		};
	} catch {
		return null;
	}
}

async function readCredential(ctx?: ExtensionContext): Promise<Credential | null> {
	// Prefer Prime Agent's live model registry so OAuth refreshes performed by Prime Agent are honored.
	let token: string | undefined;
	if (ctx?.model?.provider === PROVIDER) {
		const resolved = await ctx.modelRegistry.getApiKeyAndHeaders(ctx.model);
		if (resolved.ok && typeof resolved.apiKey === "string" && resolved.apiKey.length > 0) token = resolved.apiKey;
	}

	const stored = await readStoredCredential();
	token ??= stored?.token;
	const accountId = stored?.accountId ?? (token ? accountIdFromToken(token) ?? undefined : undefined);
	return token && accountId ? { token, accountId } : null;
}

function parseWindow(raw: any): Meter | null {
	if (!raw || typeof raw !== "object") return null;

	let remaining = numberValue(raw.remaining_percent ?? raw.percent_left);
	const used = numberValue(raw.used_percent);
	if (remaining === undefined && used !== undefined) remaining = 100 - used;
	if (remaining === undefined) return null;

	const resetAfterSeconds = numberValue(raw.reset_after_seconds);
	const resetAtMs = epochToMs(raw.reset_at ?? raw.reset_time_ms) ?? (resetAfterSeconds !== undefined ? Date.now() + resetAfterSeconds * 1000 : undefined);
	const windowSeconds = numberValue(raw.limit_window_seconds ?? raw.window_seconds);

	return {
		remainingPercent: clampPercent(remaining),
		...(resetAtMs !== undefined ? { resetAtMs } : {}),
		...(windowSeconds !== undefined ? { windowSeconds } : {}),
	};
}

/** Extract the effective provider quota: the most constrained rate-limit window. */
function parseMeter(data: any): Meter | null {
	const rateLimit = data?.rate_limit ?? data?.rate_limits ?? data;
	const candidates = [
		rateLimit?.primary_window,
		rateLimit?.secondary_window,
		rateLimit?.primary,
		rateLimit?.secondary,
		rateLimit?.five_hour,
		rateLimit?.five_hour_limit,
		rateLimit?.five_hour_rate_limit,
		rateLimit?.weekly,
		rateLimit?.weekly_limit,
		rateLimit?.weekly_rate_limit,
	];

	const windows = candidates.map(parseWindow).filter((m): m is Meter => m !== null);
	if (windows.length === 0) return null;

	return windows.reduce((best, candidate) => {
		if (candidate.remainingPercent < best.remainingPercent) return candidate;
		if (candidate.remainingPercent > best.remainingPercent) return best;
		const bestReset = best.resetAtMs ?? Number.POSITIVE_INFINITY;
		const candidateReset = candidate.resetAtMs ?? Number.POSITIVE_INFINITY;
		return candidateReset < bestReset ? candidate : best;
	});
}

function secondsUntil(resetAtMs: number | undefined): number | undefined {
	if (resetAtMs === undefined) return undefined;
	return Math.max(0, Math.ceil((resetAtMs - Date.now()) / 1000));
}

function formatDuration(seconds: number | undefined): string | undefined {
	if (seconds === undefined) return undefined;
	if (seconds < 60) return "<1m";
	const minutes = Math.ceil(seconds / 60);
	if (minutes < 60) return `${minutes}m`;
	const hours = Math.floor(minutes / 60);
	const mins = minutes % 60;
	if (hours < 24) return `${hours}h${mins.toString().padStart(2, "0")}m`;
	const days = Math.floor(hours / 24);
	const hrs = hours % 24;
	return hrs > 0 ? `${days}d${hrs}h` : `${days}d`;
}

/** Render only the remaining percentage and the reset time next to it. */
function formatStatus(m: Meter): string {
	const pct = Math.round(clampPercent(m.remainingPercent));
	const reset = formatDuration(secondsUntil(m.resetAtMs));
	const text = reset ? `${pct}% ${reset}` : `${pct}%`;
	if (pct <= CRIT_REMAINING_PCT) return `${C_CRIT}${text}${C_RESET}`;
	if (pct <= WARN_REMAINING_PCT) return `${C_WARN}${text}${C_RESET}`;
	return text; // normal: let the footer color it
}

function stripAnsi(s: string): string {
	return s.replace(/\x1b\[[0-9;]*m/g, "");
}

function userAgent(): string {
	return `pi (${platform()} ${release()}; ${arch()})`;
}

export default function (pi: ExtensionAPI) {
	let lastFetchTs = 0;
	let cooldownUntil = 0;
	let inFlight = false;
	let lastMeter: Meter | undefined;
	let credentialPresent = false;
	let controller: AbortController | undefined;

	const installFooter = (ctx: ExtensionContext) => {
		if (!ctx.hasUI) return;
		ctx.ui.setFooter((_tui, theme, footerData) => ({
			invalidate() {},
			render(width: number): string[] {
				const statuses = footerData.getExtensionStatuses();
				const parts: string[] = [];
				const claudeStatus = statuses.get("claude-usage");
				if (claudeStatus) parts.push(`${theme.fg("dim", "Claude ")}${claudeStatus}`);
				const openaiStatus = statuses.get("openai-usage");
				if (openaiStatus) parts.push(`${theme.fg("dim", "OpenAI ")}${openaiStatus}`);
				if (parts.length === 0) return [];
				return [truncateToWidth(parts.join(theme.fg("dim", "  ")), width)];
			},
		}));
	};

	const isActiveProvider = (ctx: ExtensionContext) => ctx.model?.provider === PROVIDER;
	const clear = (ctx: ExtensionContext) => ctx.ui.setStatus(STATUS_KEY, undefined);
	const publish = (ctx: ExtensionContext) => {
		if (!ctx.hasUI) return;
		if (!isActiveProvider(ctx) || !credentialPresent || lastMeter === undefined) {
			clear(ctx);
			return;
		}
		ctx.ui.setStatus(STATUS_KEY, formatStatus(lastMeter));
	};
	const refreshCredentialPresence = async (ctx?: ExtensionContext) => {
		credentialPresent = (await readCredential(ctx)) !== null;
		return credentialPresent;
	};

	async function loadCache(): Promise<void> {
		try {
			const c = JSON.parse(await readFile(CACHE_PATH, "utf8"));
			if (typeof c?.ts === "number") lastFetchTs = c.ts;
			if (typeof c?.cooldownUntil === "number") cooldownUntil = c.cooldownUntil;
			const meter = c?.meter;
			if (meter && typeof meter.remainingPercent === "number") {
				lastMeter = {
					remainingPercent: clampPercent(meter.remainingPercent),
					...(typeof meter.resetAtMs === "number" ? { resetAtMs: meter.resetAtMs } : {}),
					...(typeof meter.windowSeconds === "number" ? { windowSeconds: meter.windowSeconds } : {}),
				};
			}
		} catch {
			// no cache yet
		}
	}

	async function saveCache(): Promise<void> {
		try {
			await writeFile(CACHE_PATH, JSON.stringify({ ts: lastFetchTs, cooldownUntil, meter: lastMeter }), "utf8");
		} catch {
			// best effort
		}
	}

	/**
	 * Fetch usage and update the status.
	 * Returns a short human summary (used by the /openai-usage command).
	 */
	async function fetchUsage(ctx?: ExtensionContext, opts: { force?: boolean } = {}): Promise<string> {
		const now = Date.now();
		if (!opts.force) {
			if (inFlight) return "already refreshing…";
			if (now < cooldownUntil) return `rate-limited; retry in ${Math.ceil((cooldownUntil - now) / 60_000)}m`;
			if (now - lastFetchTs < MIN_INTERVAL_MS) return "refreshed recently";
		}

		const credential = await readCredential(ctx);
		credentialPresent = credential !== null;
		if (!credential) return "no OpenAI Codex OAuth token in auth.json";

		inFlight = true;
		lastFetchTs = now;
		controller = new AbortController();
		const timer = setTimeout(() => controller?.abort(), FETCH_TIMEOUT_MS);
		try {
			const res = await fetch(USAGE_URL, {
				headers: {
					Authorization: `Bearer ${credential.token}`,
					"chatgpt-account-id": credential.accountId,
					originator: "pi",
					"User-Agent": userAgent(),
					Accept: "application/json",
					"Content-Type": "application/json",
				},
				signal: controller.signal,
			});

			if (res.status === 401 || res.status === 403) {
				credentialPresent = false;
				return `HTTP ${res.status} (OpenAI token rejected)`;
			}
			if (res.status === 429) {
				cooldownUntil = Date.now() + COOLDOWN_429_MS;
				await saveCache();
				return "HTTP 429 (rate limited); backing off 15m";
			}
			if (!res.ok) return `HTTP ${res.status}`;

			const data = await res.json();
			const meter = parseMeter(data);
			if (!meter) return "no rate-limit usage data in response";

			lastMeter = meter;
			await saveCache();
			return stripAnsi(formatStatus(meter));
		} catch (err: any) {
			if (err?.name === "AbortError") return "timed out";
			return `error: ${err?.message ?? String(err)}`;
		} finally {
			clearTimeout(timer);
			inFlight = false;
			controller = undefined;
		}
	}

	// Refresh + publish, respecting throttle. Fire-and-forget from events.
	const maybeRefresh = (ctx: ExtensionContext, opts: { force?: boolean } = {}) => {
		if (!ctx.hasUI) return;
		if (!isActiveProvider(ctx)) {
			clear(ctx);
			return;
		}
		void (async () => {
			if (!(await refreshCredentialPresence(ctx))) {
				clear(ctx);
				return;
			}
			const now = Date.now();
			const resetPassed = lastMeter?.resetAtMs !== undefined && now >= lastMeter.resetAtMs;
			if (!opts.force && lastMeter !== undefined && !resetPassed && now - lastFetchTs < STALE_MS) {
				publish(ctx);
				return;
			}
			await fetchUsage(ctx, opts);
			publish(ctx);
		})();
	};

	pi.on("session_start", async (_event, ctx) => {
		if (!ctx.hasUI) return;
		installFooter(ctx);
		await loadCache();
		await refreshCredentialPresence(ctx);
		publish(ctx); // show cached value immediately, but only for active OpenAI Codex OAuth sessions
		maybeRefresh(ctx); // then refresh if stale
	});

	// Hide/show immediately when switching away from or back to OpenAI Codex.
	pi.on("model_select", async (_event, ctx) => maybeRefresh(ctx));

	// Refresh after each agent run; quota changes as Codex requests are made.
	pi.on("agent_end", async (_event, ctx) => maybeRefresh(ctx));

	pi.on("session_shutdown", async () => {
		controller?.abort();
	});

	pi.registerCommand("openai-usage", {
		description: "Refresh and show OpenAI Codex usage remaining",
		handler: async (_args, ctx) => {
			const summary = await fetchUsage(ctx, { force: true });
			publish(ctx);
			ctx.ui.notify(`OpenAI usage: ${summary}`, "info");
		},
	});
}
