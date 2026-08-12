/**
 * Claude Usage Extension for Prime Agent
 *
 * Publishes your Claude subscription "usage credits" spend (the pay-as-you-go
 * meter that covers you past plan limits) as a Prime Agent status item, e.g.
 *
 *     credits $68.68/$500 (14%)
 *
 * Data source: GET https://api.anthropic.com/api/oauth/usage
 *   - Uses your existing Prime Agent OAuth token (read fresh from auth.json each fetch,
 *     so it tracks Prime Agent's own token refresh — no separate OAuth flow needed).
 *   - Requires the `anthropic-beta: oauth-2025-04-20` header (which is what
 *     surfaces the usage payload). We read the `spend` block (falling back to
 *     `extra_usage`), both of which describe the same dollar-denominated cap.
 *
 * The status is published via ctx.ui.setStatus("claude-usage", ...), and this
 * extension installs a compact Prime Agent footer segment to show it. It is
 * only published while the active model provider is `anthropic` and an
 * Anthropic OAuth credential is configured.
 *
 * NOTE: /api/oauth/usage is an undocumented endpoint that rate-limits hard if
 * polled. This extension only fetches on session start and after each agent run
 * (throttled), caches to disk, and backs off aggressively on HTTP 429.
 */

import { join } from "node:path";
import { readFile, writeFile } from "node:fs/promises";
import { getAgentDir, type ExtensionAPI, type ExtensionContext } from "@earendil-works/pi-coding-agent";
import { truncateToWidth } from "@earendil-works/pi-tui";

// ── Tunables ────────────────────────────────────────────────────────────────
const STATUS_KEY = "claude-usage";
const PROVIDER = "anthropic";
const LABEL = "credits";
const USAGE_URL = "https://api.anthropic.com/api/oauth/usage";
const OAUTH_BETA = "oauth-2025-04-20";

const MIN_INTERVAL_MS = 60_000; // never hit the network more than once/min
const STALE_MS = 5 * 60_000; // refetch on triggers only if older than this
const COOLDOWN_429_MS = 15 * 60_000; // back off this long after a 429
const FETCH_TIMEOUT_MS = 8_000;

// Elevated-usage coloring (truecolor; matches the original Pi extension palette).
const WARN_PCT = 50;
const CRIT_PCT = 80;
const C_WARN = "\x1b[38;2;254;188;56m"; // #febc38 amber
const C_CRIT = "\x1b[38;2;215;95;95m"; // #d75f5f red
const C_RESET = "\x1b[0m";
// ──────────────────────────────────────────────────────────────────────────

const AGENT_DIR = getAgentDir();
const AUTH_PATH = join(AGENT_DIR, "auth.json");
const CACHE_PATH = join(AGENT_DIR, ".claude-usage-cache.json");

interface Meter {
	used: number; // dollars
	limit: number; // dollars
	percent: number; // 0..100
	enabled: boolean;
}

function money(n: number): string {
	return Number.isInteger(n) ? `$${n}` : `$${n.toFixed(2)}`;
}

/** Extract the "usage credits" meter from a /api/oauth/usage payload. */
function parseMeter(data: any): Meter | null {
	// Preferred: normalized `spend` block (amount_minor + exponent + percent).
	const s = data?.spend;
	if (s?.used && s?.limit) {
		const usedExp = s.used.exponent ?? 2;
		const limitExp = s.limit.exponent ?? 2;
		const used = Number(s.used.amount_minor ?? 0) / 10 ** usedExp;
		const limit = Number(s.limit.amount_minor ?? 0) / 10 ** limitExp;
		const percent = typeof s.percent === "number" ? s.percent : limit > 0 ? (used / limit) * 100 : 0;
		return { used, limit, percent, enabled: s.enabled !== false };
	}

	// Fallback: `extra_usage` (used_credits / monthly_limit in minor units).
	const e = data?.extra_usage;
	if (e && (e.monthly_limit != null || e.used_credits != null)) {
		const dp = e.decimal_places ?? 2;
		const used = Number(e.used_credits ?? 0) / 10 ** dp;
		const limit = Number(e.monthly_limit ?? 0) / 10 ** dp;
		const percent = typeof e.utilization === "number" ? e.utilization : limit > 0 ? (used / limit) * 100 : 0;
		return { used, limit, percent, enabled: e.is_enabled !== false };
	}

	return null;
}

/** Render the status string (colored only when usage is elevated). */
function formatStatus(m: Meter): string {
	if (!m.enabled) return `${LABEL} off`;
	const pct = Math.round(m.percent);
	const text = `${LABEL} ${money(m.used)}/${money(m.limit)} (${pct}%)`;
	if (pct >= CRIT_PCT) return `${C_CRIT}${text}${C_RESET}`;
	if (pct >= WARN_PCT) return `${C_WARN}${text}${C_RESET}`;
	return text; // normal: let the footer color it
}

async function readToken(): Promise<string | null> {
	try {
		const raw = await readFile(AUTH_PATH, "utf8");
		const auth = JSON.parse(raw);
		const a = auth?.[PROVIDER];
		if (a?.type === "oauth" && typeof a.access === "string") return a.access;
	} catch {
		// no auth file / not oauth
	}
	return null;
}

export default function (pi: ExtensionAPI) {
	let lastFetchTs = 0;
	let cooldownUntil = 0;
	let inFlight = false;
	let lastText: string | undefined;
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
		if (!isActiveProvider(ctx) || !credentialPresent || lastText === undefined) {
			clear(ctx);
			return;
		}
		ctx.ui.setStatus(STATUS_KEY, lastText);
	};
	const refreshCredentialPresence = async () => {
		credentialPresent = (await readToken()) !== null;
		return credentialPresent;
	};

	async function loadCache(): Promise<void> {
		try {
			const c = JSON.parse(await readFile(CACHE_PATH, "utf8"));
			if (typeof c?.text === "string") lastText = c.text;
			if (typeof c?.ts === "number") lastFetchTs = c.ts;
			if (typeof c?.cooldownUntil === "number") cooldownUntil = c.cooldownUntil;
		} catch {
			// no cache yet
		}
	}

	async function saveCache(): Promise<void> {
		try {
			await writeFile(CACHE_PATH, JSON.stringify({ ts: lastFetchTs, cooldownUntil, text: lastText }), "utf8");
		} catch {
			// best effort
		}
	}

	/**
	 * Fetch usage and update the status.
	 * Returns a short human summary (used by the /claude-usage command).
	 */
	async function fetchUsage(opts: { force?: boolean } = {}): Promise<string> {
		const now = Date.now();
		if (!opts.force) {
			if (inFlight) return "already refreshing…";
			if (now < cooldownUntil) return `rate-limited; retry in ${Math.ceil((cooldownUntil - now) / 60_000)}m`;
			if (now - lastFetchTs < MIN_INTERVAL_MS) return "refreshed recently";
		}

		const token = await readToken();
		credentialPresent = token !== null;
		if (!token) return "no Claude OAuth token in auth.json";

		inFlight = true;
		lastFetchTs = now;
		controller = new AbortController();
		const timer = setTimeout(() => controller?.abort(), FETCH_TIMEOUT_MS);
		try {
			const res = await fetch(USAGE_URL, {
				headers: {
					Authorization: `Bearer ${token}`,
					"anthropic-beta": OAUTH_BETA,
					"Content-Type": "application/json",
					Accept: "application/json",
				},
				signal: controller.signal,
			});

			if (res.status === 429) {
				cooldownUntil = Date.now() + COOLDOWN_429_MS;
				await saveCache();
				return "HTTP 429 (rate limited); backing off 15m";
			}
			if (!res.ok) return `HTTP ${res.status}`;

			const data = await res.json();
			const meter = parseMeter(data);
			if (!meter) return "no usage-credits data in response";

			lastText = formatStatus(meter);
			await saveCache();
			return lastText.replace(/\x1b\[[0-9;]*m/g, ""); // plain summary
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
			if (!(await refreshCredentialPresence())) {
				clear(ctx);
				return;
			}
			const now = Date.now();
			if (!opts.force && lastText !== undefined && now - lastFetchTs < STALE_MS) {
				publish(ctx);
				return;
			}
			await fetchUsage(opts);
			publish(ctx);
		})();
	};

	pi.on("session_start", async (_event, ctx) => {
		if (!ctx.hasUI) return;
		installFooter(ctx);
		await loadCache();
		await refreshCredentialPresence();
		publish(ctx); // show cached value immediately, but only for active Anthropic OAuth sessions
		maybeRefresh(ctx); // then refresh if stale
	});

	// Hide/show immediately when switching away from or back to Anthropic.
	pi.on("model_select", async (_event, ctx) => maybeRefresh(ctx));

	// Usage credits move when you exceed plan limits; refresh after each agent run.
	pi.on("agent_end", async (_event, ctx) => maybeRefresh(ctx));

	pi.on("session_shutdown", async () => {
		controller?.abort();
	});

	pi.registerCommand("claude-usage", {
		description: "Refresh and show Claude subscription usage-credits spend",
		handler: async (_args, ctx) => {
			const summary = await fetchUsage({ force: true });
			publish(ctx);
			ctx.ui.notify(`Claude usage: ${summary}`, "info");
		},
	});
}
