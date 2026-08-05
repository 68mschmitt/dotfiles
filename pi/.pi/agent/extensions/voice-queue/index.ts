/**
 * pi-voice-queue guard.
 *
 * The cross-session playback queue lives in ~/.pi/voice-queue/ but has to be
 * hooked into pi-voice's playWav(), which sits in node_modules and is therefore
 * reverted by every `pi update --extensions` / package reinstall. This
 * extension makes that self-healing: on session start it checks the marker and
 * re-applies the patch if it is gone.
 *
 * It deliberately does nothing else. All queue behaviour is in
 * ~/.pi/voice-queue/playback-lock.mjs, which no package manager can clobber.
 *
 * Two properties matter here:
 *   - Silence: in the common case (already patched) it does one small file read
 *     and never notifies, so it is invisible.
 *   - Honesty about timing: pi-voice's modules are already loaded by the time
 *     this runs, so a freshly re-applied patch only takes effect in the *next*
 *     session. That is exactly what the notification says, rather than
 *     pretending the current session is queued when it is not.
 */

import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const PATCHER = join(homedir(), ".pi", "voice-queue", "apply-patch.mjs");

export default function (pi: ExtensionAPI) {
  let checked = false;

  pi.on("session_start", async (_event, ctx) => {
    if (checked) return; // one check per process is enough
    checked = true;

    try {
      if (!existsSync(PATCHER)) return;
      const { findTarget, isPatched, applyPatch } = await import(PATCHER);

      const target = findTarget(process.cwd());
      if (!target) return; // pi-voice not installed here — nothing to guard

      if (isPatched(readFileSync(target, "utf8"))) return;

      const result = applyPatch(target);
      if (result === "applied") {
        ctx.ui.notify(
          "pi-voice was updated: cross-session voice queue re-applied (active next session)",
          "info",
        );
      } else if (result === "upstream-changed") {
        ctx.ui.notify(
          "pi-voice's playWav() changed upstream — voice queue NOT applied. Run: node ~/.pi/voice-queue/apply-patch.mjs",
          "warning",
        );
      }
    } catch (err) {
      console.warn("[pi-voice-queue] guard failed:", err);
    }
  });
}
