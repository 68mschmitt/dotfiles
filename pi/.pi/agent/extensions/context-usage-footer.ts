/**
 * Context Usage Footer Extension
 *
 * Overrides the default footer to display context usage as:
 *   100K/1M (10%)
 * instead of the default percent%/window format.
 */

import type { AssistantMessage } from "@earendil-works/pi-ai";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

function formatTokens(count: number): string {
	if (count < 1000) return count.toString();
	if (count < 10_000) return `${(count / 1000).toFixed(1)}K`;
	if (count < 1_000_000) return `${Math.round(count / 1000)}K`;
	if (count < 10_000_000) return `${(count / 1_000_000).toFixed(1)}M`;
	return `${Math.round(count / 1_000_000)}M`;
}

// Theme color key for each thinking/effort level (see docs/tui.md theme colors).
const THINKING_COLORS = {
	off: "thinkingOff",
	minimal: "thinkingMinimal",
	low: "thinkingLow",
	medium: "thinkingMedium",
	high: "thinkingHigh",
	xhigh: "thinkingXhigh",
	max: "thinkingMax",
} as const;

type ThinkingLevel = keyof typeof THINKING_COLORS;

export default function (pi: ExtensionAPI) {
	// Let thinking-level and model changes refresh the footer so the
	// effort indicator stays in sync with the current setting.
	let requestRender: (() => void) | undefined;
	pi.on("thinking_level_select", () => requestRender?.());
	pi.on("model_select", () => requestRender?.());

	pi.on("session_start", (_event, ctx) => {
		ctx.ui.setFooter((tui, theme, footerData) => {
			const unsub = footerData.onBranchChange(() => tui.requestRender());
			const refresh = () => tui.requestRender();
			requestRender = refresh;

			return {
				dispose: () => {
					unsub();
					if (requestRender === refresh) requestRender = undefined;
				},
				invalidate() {},
				render(width: number): string[] {
					// Cumulative usage from all session entries
					let totalInput = 0;
					let totalOutput = 0;
					let totalCacheRead = 0;
					let totalCacheWrite = 0;
					let totalCost = 0;
					let latestCacheHitRate: number | undefined;

					for (const entry of ctx.sessionManager.getEntries()) {
						if (entry.type === "message" && entry.message.role === "assistant") {
							const m = entry.message as AssistantMessage;
							totalInput += m.usage.input;
							totalOutput += m.usage.output;
							totalCacheRead += m.usage.cacheRead;
							totalCacheWrite += m.usage.cacheWrite;
							totalCost += m.usage.cost.total;
							const latestPrompt = m.usage.input + m.usage.cacheRead + m.usage.cacheWrite;
							latestCacheHitRate = latestPrompt > 0 ? (m.usage.cacheRead / latestPrompt) * 100 : undefined;
						}
					}

					// Context usage: tokens/window (percent%)
					const contextUsage = ctx.getContextUsage();
					const contextWindow = contextUsage?.contextWindow ?? ctx.model?.contextWindow ?? 0;
					const contextTokens = contextUsage?.tokens ?? null;
					const contextPercent = contextUsage?.percent ?? null;

					let contextStr: string;
					if (contextTokens !== null && contextPercent !== null) {
						const display = `${formatTokens(contextTokens)}/${formatTokens(contextWindow)} (${contextPercent.toFixed(0)}%)`;
						if (contextPercent > 90) {
							contextStr = theme.fg("error", display);
						} else if (contextPercent > 70) {
							contextStr = theme.fg("warning", display);
						} else {
							contextStr = display;
						}
					} else {
						contextStr = `?/${formatTokens(contextWindow)}`;
					}

					// Build pwd line
					let pwd = ctx.cwd;
					const home = process.env.HOME || process.env.USERPROFILE;
					if (home && pwd.startsWith(home)) {
						pwd = "~" + pwd.slice(home.length);
					}
					const branch = footerData.getGitBranch();
					if (branch) pwd = `${pwd} (${branch})`;
					const sessionName = ctx.sessionManager.getSessionName();
					if (sessionName) pwd = `${pwd} • ${sessionName}`;

					// Build stats parts
					const statsParts: string[] = [];
					if (totalInput) statsParts.push(`↑${formatTokens(totalInput)}`);
					if (totalOutput) statsParts.push(`↓${formatTokens(totalOutput)}`);
					if (totalCacheRead) statsParts.push(`R${formatTokens(totalCacheRead)}`);
					if (totalCacheWrite) statsParts.push(`W${formatTokens(totalCacheWrite)}`);
					if ((totalCacheRead > 0 || totalCacheWrite > 0) && latestCacheHitRate !== undefined) {
						statsParts.push(`CH${latestCacheHitRate.toFixed(1)}%`);
					}
					if (totalCost) statsParts.push(`$${totalCost.toFixed(3)}`);
					statsParts.push(contextStr);

					let statsLeft = statsParts.join(" ");

					// Model + thinking/effort level on the right
					const modelName = ctx.model?.id || "no-model";
					const thinkingLevel = pi.getThinkingLevel();
					// Only surface the effort level when the model actually supports it.
					const showThinking = Boolean(ctx.model?.reasoning) && Boolean(thinkingLevel);

					// Plain text drives width/layout math; colored version is for display.
					const rightPlain = showThinking ? `${modelName} ${thinkingLevel}` : modelName;
					const thinkingColor = THINKING_COLORS[thinkingLevel as ThinkingLevel] ?? "dim";
					const rightColored = showThinking
						? theme.fg("dim", `${modelName} `) + theme.fg(thinkingColor, thinkingLevel)
						: theme.fg("dim", modelName);

					let statsLeftWidth = visibleWidth(statsLeft);
					if (statsLeftWidth > width) {
						statsLeft = truncateToWidth(statsLeft, width, "...");
						statsLeftWidth = visibleWidth(statsLeft);
					}
					const dimStatsLeft = theme.fg("dim", statsLeft);

					const rightWidth = visibleWidth(rightPlain);
					const minPadding = 2;
					const totalNeeded = statsLeftWidth + minPadding + rightWidth;

					const pwdLine = truncateToWidth(theme.fg("dim", pwd), width, theme.fg("dim", "..."));

					let statsLine: string;
					if (totalNeeded <= width) {
						const padding = " ".repeat(width - statsLeftWidth - rightWidth);
						statsLine = dimStatsLeft + padding + rightColored;
					} else {
						const availableForRight = width - statsLeftWidth - minPadding;
						if (availableForRight > 0) {
							// Too narrow for the colored layout; fall back to dim + truncated.
							const truncatedRight = truncateToWidth(rightPlain, availableForRight, "");
							const truncatedRightWidth = visibleWidth(truncatedRight);
							const padding = " ".repeat(Math.max(0, width - statsLeftWidth - truncatedRightWidth));
							statsLine = dimStatsLeft + theme.fg("dim", padding + truncatedRight);
						} else {
							statsLine = dimStatsLeft;
						}
					}

					const lines = [pwdLine, statsLine];

					// Extension statuses
					const extensionStatuses = footerData.getExtensionStatuses();
					if (extensionStatuses.size > 0) {
						const statusLine = Array.from(extensionStatuses.entries())
							.sort(([a], [b]) => a.localeCompare(b))
							.map(([, text]) => text.replace(/[\r\n\t]/g, " ").replace(/ +/g, " ").trim())
							.join(" ");
						lines.push(truncateToWidth(statusLine, width, theme.fg("dim", "...")));
					}

					return lines;
				},
			};
		});
	});
}
