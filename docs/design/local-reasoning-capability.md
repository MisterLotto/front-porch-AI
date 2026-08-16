# Local reasoning capability: what shipped, and what LM Studio / oMLX still need

**Status:** All three halves shipped 2026-08-15. KoboldCpp reads the GGUF
header. oMLX reads `chat_template.jinja` via `/v1/models/status`. LM Studio
reads the GGUF under `~/.lmstudio/models` after `/api/v0/models` (no poke).

---

## 1. The thing to understand first

There are two completely different questions hiding under "which thinking
strengths does this model support", and the answer differs per backend.

**Remote hosted providers (OpenRouter, Nano-GPT)** enforce an effort menu
server-side. So we can *ask* by sending a deliberately invalid value and
reading the rejection:

```
POST /v1/chat/completions  { "reasoning_effort": "fpai_probe", ... }
→ 400  "... Supported values are: none, high, max"
```

`lib/services/reasoning_effort_probe.dart` does exactly that, once per model,
with a 30s backoff and an on-disk memory of the answer.
`supportedReasoningEffortsFromError()` parses the listing.

**KoboldCpp does not enforce anything.** It takes its own
`chat_template_kwargs.enable_thinking` and `reasoning_effort` fields and hands
them to the model's chat template. An invalid value is ignored, not rejected.
So the poke would spend a request to learn nothing — and worse, it would mark
the model "probed" and stop us ever asking again.

For Kobold the capability is not a server policy at all. It is a property of
the GGUF's own chat template, which the backend executes because we launch
with `--jinja`. That template is on disk, so we read it.

**LM Studio and oMLX are the open question** — they may behave like either.
See §4.

---

## 2. What shipped (KoboldCpp)

### The detector — `lib/services/capability/reasoning_support.dart`

Pure function over the template text, four outcomes:

| Verdict   | Trigger in the template            | Meaning                                   |
|-----------|------------------------------------|-------------------------------------------|
| `graded`  | mentions `reasoning_effort`        | strength levels are real (gpt-oss/harmony) |
| `toggle`  | mentions `enable_thinking`         | on/off real, strength decorative (Qwen3)   |
| `always`  | think markers, no switch           | thinking cannot be turned off (R1 distill) |
| `none`    | none of the above                  | the model cannot think at all              |

**Order is load-bearing.** Harmony templates carry `reasoning_effort` *and*
channel markers; Qwen3 carries `enable_thinking` *and* `<think>`. Checking the
markers first misreads both as `always`. There is a red-proven test for this.

Think markers include `<|channel|>analysis`, not just `<think>` — gpt-oss
reasoners never emit `<think>`, and omitting the channel marker reports a
thinking model as having none.

### Reading the template

`readChatTemplate(path)` pulls `tokenizer.chat_template` out of the GGUF header
via the existing `GGUFFileReader.parseMetadataBytes`, which already skips the
huge token array by length arithmetic rather than decoding it. One bounded 4 MB
header read, no generation, no backend required.

### Caching and wiring

`ReasoningSupportResolver` caches one verdict per model path — **including
misses**, so an unreadable file is not re-read every rebuild. `peek()` is the
build-safe read and never touches disk; `resolveLocalGguf()` is kicked from
lifecycle hooks only.

Verdicts register into the **shared** `kLearnedReasoningEffortsByModel` /
`kMandatoryReasoningModels` under the model's file path, with `persist: false`
(the on-disk menu store is for remote models; a local path is not portable and
the GGUF is free to re-read next launch). That is why there is no local-only
chip logic anywhere: `reasoningEffortChipsFor()` and friends just work once the
model is keyed.

Desktop UI is `thinking_settings_block.dart`; web is the `reasoningEfforts` /
`reasoningMandatory` / `reasoningLocalSupport` fields from `settings_facade`.

### The user-visible payoff

Before, every local model showed Low/Medium/High. Most GGUFs cannot think at
all, so those chips did nothing. Now: a `none` model says so and disables the
switch, a `toggle` model shows no strength chips and says why, `always` locks
Off, and only `graded` shows real levels.

---

## 3. Deliberately NOT done

- **No poke against KoboldCpp.** It cannot enumerate; see §1.
- **Preset (.kcpps) mode claims nothing.** The preset owns the model and we
  have no path to read, so the key stays empty and the generic chips stand.
- **Nothing persisted for local.** Re-read per launch, deliberately.

---

## 4. oMLX (shipped) and LM Studio (still open)

### Why they are a separate question

Both are OpenAI-compatible and both already ride the **remote** code path
(`LLMProvider.isLocal` is true only for managed KoboldCpp), so they already get
remote-style chips and the `reasoning:{}` object. The probe is skipped for them
only because `isLocalRemoteUrl()` refuses to poke loopback/LAN/Tailscale/.local
addresses. `probeReasoningEfforts()` already accepts an `allowLocal` flag that
nothing currently sets.

There is also a known wrinkle, verified against oMLX v0.5.2 and documented in
`open_router_service.dart`: these servers **ignore** the OpenRouter `reasoning`
object and honour only `enable_thinking` in the chat template. So we already
send `chat_template_kwargs` for local URLs.

### oMLX — settled live 2026-08-14 (no poke)

Against oMLX at `http://localhost:8000` with 18 models listed and
**none loaded**:

- Completions poke is **outcome (b) and dangerous**. No model is resident;
  a `/v1/chat/completions` call would load 30–90 GB. Do not poke.
- `GET /props` and `GET /v1/props` are **404**. No llama.cpp template
  endpoint.
- `GET /v1/models/status` (already used for vision) carries `model_path`
  and `thinking_default`. `thinking_default` is a classification
  (`true` / `false` / `null`), **not** a capability: gpt-oss is `null`
  and still graded; Gemma is `false` and still toggle.
- `/admin/api/models` `settings.enable_thinking` is a **user pref**, not
  a capability. Ignore it.
- Every MLX dir ships `chat_template.jinja`. Feeding that into the SAME
  `detectThinkingFromChatTemplate()` is the honest signal. Ran live on
  all 18: gpt-oss → `graded`, Qwen3.6 / GLM / Gemma / Laguna / MiniMax →
  `toggle`, Devstral / Qwen3-Coder-Next / Qwen3-VL-Instruct → `none`,
  two distill/harmony-history templates → `always`.

Shipped path: `ReasoningSupportResolver.resolveOmlx` fetches status,
reads `chat_template.jinja` (or `tokenizer_config.json`'s
`chat_template`), runs `detectThinkingFromOmlxEntry` (template wins;
`thinking_default is bool` promotes a silent template to `toggle`;
missing template + null default stays unknown). Registers into the
shared chip store with `persist: false` (toggle vs none would collapse
on disk). Never generates. Failures are not cached.

### LM Studio — settled live 2026-08-15 (no poke)

Against LM Studio **0.4.21+2** at `http://127.0.0.1:1234` (the GUI can be
up while `lms status` still says Server: OFF — start it with
`lms server start`). Only model on disk: `qwen2.5-0.5b-instruct` (531 MB).

- Completions poke is **outcome (a) and the wrong signal.** Verbatim 400:
  `Invalid 'reasoning_effort' value: 'fpai_probe'. Supported values: none, minimal, low, medium, high, xhigh.`
  That is the *server's* parameter enum, not this model's capability. Using
  it would put six chips on every LM Studio model, including the 0.5B
  instruct that cannot think — the original bug. The parser was also
  extended: the live string says `reasoning_effort` (underscore), which
  the old `reasoning.effort` / `reasoning effort` trigger missed.
- The poke **JIT-loaded** the 0.5B (`justInTimeModelLoading: true`). A
  31B selected in Settings would have been pulled in. Do not poke.
- `GET /props` is not a template endpoint (`Unexpected endpoint`).
- `GET /api/v0/models` has **no path** (id / publisher / quantization /
  state / compatibility_type only). GGUFs still live under
  `~/.lmstudio/models`; `findLmStudioGguf` matches the compact id onto
  a filename and skips `mmproj`.

Shipped path: `ReasoningSupportResolver.resolveLmStudio` confirms the
listing is LM Studio-shaped, finds the GGUF, runs
`detectThinkingFromChatTemplate`, registers into the shared store
(`persist: false`). Failures are not cached. Kicked for any
`isLocalRemoteUrl` that is not the oMLX backend — a generic llama.cpp
on LAN 404s `/api/v0/models` and stays on generic chips.

### Step 2 — wire it the same way

Whatever the source, register through
`rememberReasoningEffortsForModel(model, set, persist: ...)` so the shared chip
and caption machinery applies. Do **not** add a parallel local-only path; that
is the whole point of the current shape.

oMLX and LM Studio both ship with `persist: false`: toggle and none both
store `{none}`, so a disk menu cannot tell them apart, and the re-read
is cheap. Do not persist the LM Studio poke listing — it is the server
enum, not a per-model capability.

### Step 3 — verify honestly

- Real server, real model, both a reasoning model and a plain one.
- Confirm the chips change, and that a plain model now says it cannot think.
- Confirm we do **not** fire the poke on every settings rebuild (the probe has
  in-flight dedup + backoff — check it still holds on a local URL).
- Web parity: `settings_facade` already emits `reasoningLocalSupport`; extend
  it if these backends produce a verdict, and rebuild the web bundle
  (`cd web_ui && npm run build`) or the change ships nothing.

### Gotcha worth knowing before you start

`_reasoningModelKey` in `settings_facade.dart` and the `effectiveModelId` in
`thinking_settings_block.dart` deliberately stay **empty** until a verdict
exists, so an unresolved model falls back to generic chips instead of claiming
knowledge. Keep that property — it is what stops a slow/absent server from
showing a confidently wrong menu.

---

## 5. Files to read first

| File | Why |
|---|---|
| `lib/services/capability/reasoning_support.dart` | the detector + Kobold / oMLX / LMS resolver |
| `lib/services/capability/lmstudio_gguf.dart` | LMS downloads-folder GGUF matcher |
| `lib/services/reasoning_effort.dart` | shared vocabulary, chips, captions, 400 parser |
| `lib/services/reasoning_effort_probe.dart` | the remote poke (not used for LMS / oMLX) |
| `lib/services/capability/vision_support_resolver.dart` | the per-backend listing precedent |
| `test/services/capability/reasoning_support_test.dart` | the truth table |
