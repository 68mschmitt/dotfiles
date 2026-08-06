/**
 * ADHD Mode Extension
 *
 * Activates the `i-have-adhd` output style by default in every session by
 * appending the skill body to the system prompt on each turn.
 *
 * The skill file stays the single source of truth; this extension only decides
 * when it is active.
 *
 * Toggle at runtime with `/adhd` (or `/adhd on` | `/adhd off`). Saying
 * "stop adhd mode" / "normal mode" in a prompt also turns it off, and
 * "adhd mode" turns it back on.
 */

import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const SKILL_PATH = join(
	homedir(),
	".pi",
	"agent",
	"skills",
	"i-have-adhd",
	"SKILL.md",
);

/** Strip YAML frontmatter so only the instruction body is injected. */
function stripFrontmatter(text: string): string {
	if (!text.startsWith("---")) return text;
	const end = text.indexOf("\n---", 3);
	if (end === -1) return text;
	return text.slice(text.indexOf("\n", end + 1) + 1).trimStart();
}

let cached: string | null | undefined;

function loadSkill(): string | null {
	if (cached !== undefined) return cached;
	try {
		cached = stripFrontmatter(readFileSync(SKILL_PATH, "utf8")).trim();
	} catch {
		cached = null;
	}
	return cached;
}

const OFF_PATTERN = /\b(stop adhd mode|normal mode|adhd mode off)\b/i;
const ON_PATTERN = /\b(adhd mode on|start adhd mode)\b/i;

export default function (pi: ExtensionAPI) {
	let enabled = true;

	pi.registerCommand("adhd", {
		description: "Toggle ADHD output style (on by default)",
		getArgumentCompletions: (prefix: string) => {
			const items = [
				{ value: "on", label: "on" },
				{ value: "off", label: "off" },
			].filter((i) => i.value.startsWith(prefix));
			return items.length > 0 ? items : null;
		},
		handler: async (args, ctx) => {
			const arg = args.trim().toLowerCase();
			if (arg === "on") enabled = true;
			else if (arg === "off") enabled = false;
			else enabled = !enabled;

			if (enabled && !loadSkill()) {
				ctx.ui.notify(`ADHD skill not found at ${SKILL_PATH}`, "warning");
				return;
			}
			ctx.ui.notify(`ADHD mode ${enabled ? "on" : "off"}`, "info");
		},
	});

	pi.on("before_agent_start", async (event) => {
		const prompt = event.prompt ?? "";
		if (OFF_PATTERN.test(prompt)) enabled = false;
		else if (ON_PATTERN.test(prompt)) enabled = true;

		if (!enabled) return;

		const skill = loadSkill();
		if (!skill) return;

		// Skip if the skill is already in context (e.g. loaded via /skill:i-have-adhd).
		if (event.systemPrompt.includes("## Pre-send check")) return;

		return {
			systemPrompt: `${event.systemPrompt}\n\n# Output style: ADHD mode (active)\n\n${skill}`,
		};
	});
}
