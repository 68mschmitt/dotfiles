/**
 * consultant-temp — child-only extension for expert-panel consultants.
 *
 * Injected into consultant processes via `-e` (while `--no-extensions` blocks
 * everything else). Sets the sampling temperature from PI_EXPERT_TEMPERATURE
 * on every provider request.
 *
 * NOT auto-discovered: pi only discovers top-level extension files and
 * `index.ts` inside extension subdirectories, so this file never loads in
 * the parent agent. The parent never sets PI_EXPERT_TEMPERATURE, so even if
 * it were loaded it would be a no-op there.
 *
 * Provider constraint: Anthropic only accepts temperature=1 when thinking is
 * enabled OR adaptive — and pi serializes a thinking field (adaptive) for
 * some models even at `--thinking off`. Precedence here:
 *   - expertPanel.thinking != "off"  -> thinking wins, temperature is skipped
 *   - expertPanel.thinking == "off"  -> parent sets PI_EXPERT_STRIP_THINKING=1
 *     and this hook removes the thinking field so temperature can apply
 *
 * Note: some newer models (e.g. claude-fable-5) deprecate temperature
 * entirely and 400 on any value; use a model like claude-sonnet-4-5 if you
 * want temperature-driven variance.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
	pi.on("before_provider_request", (event) => {
		const raw = process.env.PI_EXPERT_TEMPERATURE;
		if (raw === undefined || raw === "") return undefined;

		const temperature = Number(raw);
		if (!Number.isFinite(temperature)) return undefined;

		const payload = event.payload as Record<string, unknown>;

		// Reasoning-effort style payloads (OpenAI o-series etc.) reject
		// custom temperatures outright; leave them untouched.
		if (payload.reasoning !== undefined || payload.reasoning_effort !== undefined) return undefined;

		const thinking = payload.thinking as { type?: string } | undefined;
		const thinkingActive = thinking !== undefined && thinking.type !== "disabled";

		if (thinkingActive) {
			// Only override thinking when the user explicitly configured it off.
			if (process.env.PI_EXPERT_STRIP_THINKING !== "1") return undefined;
			const { thinking: _dropped, ...rest } = payload;
			return { ...rest, temperature };
		}

		return { ...payload, temperature };
	});
}
