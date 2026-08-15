# Local reasoning capability: what shipped, and what LM Studio / oMLX still need

**Status:** KoboldCpp half shipped 2026-08-15. LM Studio + oMLX halves are
**open** and need a machine with those servers running — this doc is the
hand-off for that work.

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

## 4. OPEN: LM Studio and oMLX

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

### Step 1 — settle it with curl (5 minutes)

With the server running and a reasoning model loaded:

```bash
curl -s http://localhost:1234/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"YOUR_MODEL","max_tokens":1,
       "messages":[{"role":"user","content":"ok"}],
       "reasoning_effort":"fpai_probe"}'
```

(LM Studio defaults to :1234, oMLX usually :8080. Repeat per server.)

Three possible outcomes, and each implies different work:

**(a) It returns a 400 naming the valid values.** Best case. The existing
parser already handles it. The change is small: pass `allowLocal: true` from
the pick-time kick for these two backends, and narrow `isLocalRemoteUrl`'s use
so it still protects genuinely unrelated LAN hosts. Add a truth-table test for
the new gate and one parser test using the server's **real** error string —
capture it verbatim in the commit message.

**(b) It returns a normal completion** (the bogus value is ignored). The poke
is worthless there. Fall back to the same trick as Kobold: ask the server for
the chat template. llama.cpp-family servers expose `GET /props` with
`chat_template`; LM Studio also has `GET /api/v0/models` (already used by
`vision_support_resolver` for its `type == "vlm"` check — copy that shape).
Feed whatever template text comes back into the SAME
`detectThinkingFromChatTemplate()` — it is pure and backend-agnostic, so this
is a fetch plus a cache, not new policy.

**(c) It errors without a listing** (generic 500 / unknown-parameter). Treat as
(b), and make sure the failure caches as *unknown* rather than as a verdict —
`vision_support_resolver` has the precedent: cache only definitive answers, or
a model gets branded wrongly for the whole session.

### Step 2 — wire it the same way

Whatever the source, register through
`rememberReasoningEffortsForModel(model, set, persist: ...)` so the shared chip
and caption machinery applies. Do **not** add a parallel local-only path; that
is the whole point of the current shape.

Persistence differs from Kobold here: LM Studio/oMLX model ids are stable
strings (not file paths), so persisting them is reasonable — match what the
remote probe does.

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
| `lib/services/capability/reasoning_support.dart` | the detector + resolver |
| `lib/services/reasoning_effort.dart` | shared vocabulary, chips, captions |
| `lib/services/reasoning_effort_probe.dart` | the remote poke, incl. `allowLocal` |
| `lib/services/capability/vision_support_resolver.dart` | the per-backend resolution precedent (LM Studio + oMLX endpoints already used here) |
| `lib/services/open_router_service.dart` (~line 380) | the verified oMLX `enable_thinking` finding |
| `test/services/capability/reasoning_support_test.dart` | the truth table to extend |
