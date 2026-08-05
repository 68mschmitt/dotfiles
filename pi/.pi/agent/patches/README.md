# Local patches for pi packages

Packages installed with `pi install` live in `~/.pi/agent/npm/node_modules`, which
is overwritten wholesale on every install or update. Anything fixed in place there
is temporary, so the fix is kept here as a patch plus a re-apply script.

```bash
./apply-pi-voice-patch.sh --check   # is the running install patched?
./apply-pi-voice-patch.sh           # apply + restart the TTS server
```

## `pi-voice-3.0.0-chunked-tts.patch`

Fixes **silently truncated voice notes** in `@s1m0n38/pi-voice@3.0.0`, plus a
broken `pi-voice server start` in hoisted installs.

### The bug

Kokoro's transformer accepts at most 512 phoneme tokens per forward pass
(`tokenizer_config.json`: `model_max_length: 512`). `kokoro-js` tokenizes with
`{ truncation: true }` and clamps the style index at 509:

```js
const {input_ids: l} = this.tokenizer(n, {truncation: !0});          // drops the rest
const l = 256 * Math.min(Math.max(e.dims.at(-1) - 2, 0), 509);       // hard clamp
```

`pi-voice`'s server called `tts.generate(spokenText)` **once**, with no chunking, so
any longer text was cut off mid-sentence. The request still returned HTTP 200 and a
valid WAV — nothing warned, nothing logged, nothing failed.

Observed: a 3307-character note (568 words) produced **22.8 s** of audio and stopped
at the end of its first paragraph. 88 % of it was never spoken. Requests of 700 and
3307 characters returned byte-identical WAVs.

### The fix

`extensions/text.ts` gains `splitForSynthesis()`, which splits cleaned text at
paragraph and sentence boundaries into chunks that fit the model, and
`extensions/server.ts` synthesizes each chunk and concatenates the samples
(60 ms of silence at each seam).

The budget is **not** a character count. The truncation cliff was measured against
the real model at five corpora, and raw character count moves by 2× between prose
and digit-dense text:

| corpus              | cliff (chars) | weighted cost at cliff |
|---------------------|---------------|------------------------|
| plain prose         | 450           | 450                    |
| numeric dense       | 236           | 448                    |
| acronym heavy       | 242           | 467                    |
| mixed report        | 427           | 476 *(held out)*       |
| clipped punctuation | 484           | 484 *(held out)*       |

So `synthesisCost()` weights digits (`0.0037` → "zero point zero zero three seven"),
symbols, and acronym letters. That holds within 1.08× across all five corpora,
including the two held out of calibration, and the per-chunk budget is set 15 %
under the lowest observed cliff (`MAX_SYNTHESIS_COST = 380`).

A budget of "300 characters" — the obvious guess — would still have truncated
digit-dense text, whose cliff is at 236.

Verified after patching: that same note went **22.8 s → 184.7 s**, and the full
request's duration equals the sum of its 15 chunks plus seams to within 0.000 s, so
nothing is dropped or duplicated. Notes that already fit (≤ ~55 words) return as a
single chunk and one model call, exactly as before.

### Also fixed: `pi-voice server start`

`src/cli.ts` hardcoded `PACKAGE_ROOT/node_modules/jiti/lib/jiti-register.mjs`. npm
hoists `jiti` to the top of pi's shared `~/.pi/agent/npm` tree, so that path does not
exist, the spawned server died instantly with `ERR_MODULE_NOT_FOUND`, and the CLI
reported only "Server failed to start within 15 seconds". It now resolves `jiti`
through its `package.json` (the one subpath its `exports` map always exposes —
`jiti/register` is mapped for `import` only, so `require.resolve` rejects it).

This is also why `npm test`'s `server.test.ts` cancels all 38 subtests in this
install; the patch does not change that test's own hardcoded path.

### Upstream

Both fixes are environment-independent and belong upstream:
<https://github.com/S1M0N38/pi-voice>. If a release lands with either fix, drop the
corresponding hunk from this patch.
