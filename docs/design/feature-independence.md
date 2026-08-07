# Feature Independence & the "Porch Life" Settings Tab

Maintainer intent (2026-08-07): *"break out all FPAI toggles into separate
leaves since they will be able to function independently… give users options
for what features to enable and disable."* This doc is the evidence-based
answer: what each feature ACTUALLY depends on today (grep-verified with
file:line by a three-agent audit, 2026-08-07), what independence costs, and
the phased plan. Companion features doc: `pockets-and-preferences.md`.
Mockup (approved layout pending): the "Porch Life" tab sketch artifact.

## The verified dependency matrix

| Feature | Today with Realism OFF | True dependency | Independence cost |
|---|---|---|---|
| **Chaos / Chance Time** | fully functional | none — only *listed* under realism | **zero** (docs/UI relabel) |
| **Welcome-back recap** | fully functional | none (wall-clock) | **zero** — but its toggle is INVISIBLE (nested in the realism settings block) |
| **Promises** | fully functional | Journal | zero; optional 1-line gate so kept/broken doesn't write frozen bond/trust scalars |
| **Growth Rings** | fully functional | none | zero (loses felt-window annotations only) |
| **The Journal** | pass runs; cards plant | none | zero to run; emotion stamps/salience/mood-boost need realism (or a future classifier/extra call for parity) |
| **Objectives** | manual quests fully work | none for manual | zero; AUTONOMOUS proposals piggyback the narrative eval → standalone = +1 periodic call |
| **Ambitions** | injection works (copy is honest) | none | two cheap fixes: the 1:1 sidebar row hides inside the realism-on block; the accrual eval ignores ambitionsEnabled |
| **Notices your absence** | silently dead (note rides the realism-gated time fragment) | its own flag + last-message timestamp | small: lift `getAbsenceNote` into its own injection fragment, own gate |
| **Passage of Time** | frozen by default; runs on its own eval with the opt-in on | a MODEL CALL, not the engine — **DECOUPLED 2026-08-06** | +1 short call per turn, only for engine-off users who opt in |
| **Story Weather / °F** | follows the clock — works whenever the clock moves | the CLOCK (either driver) | zero: deterministic math, no eval of its own |
| **Dreams** | follows the clock | Journal + a moving clock (either driver) | zero |
| **Needs** | frozen (not zeroed) | the engine — RULED a hard dependency 2026-08-07 ("leave the gate, fix the wording") | none: gate stays; NEW global `needsSimDefault` added so the tab can show it |
| **NSFW Cooldown** | inert, values preserved | arousal deltas ride the emotional-state eval; climax rides needs-impact | "rebuilding a slice of the realism engine" — stays realism-bound |
| **Fixation / spatial stance** | fossilized | narrative + posture evals (posture is FUSED with the time eval) | confirmed inseparable — stays realism-bound |

## The Passage-of-Time decision — DECOUPLED (2026-08-06), and why

**The 2026-08-07 entry that stood here recorded a misreading, and the
maintainer corrected it on 2026-08-06.** The quote it rested on was:

> "passage of time requires the model usage, the fallback is just that a
> fallback… fallback deterministic passage of time is not usable as is but an
> emergency 'oh shit'."

That says time requires **model usage**. It was written up as requiring **the
engine**, and Phase 3 was cancelled on that basis. Those are different claims:
the clock needs an eval, not bond/trust/emotion/arousal. Read correctly, the
quote is an argument *for* giving time its own call — because the
deterministic drift is explicitly unusable as a standalone mode.

**Shipped:** the scene-time eval stands on its own. With the engine off and
the opt-in on, one short call per turn asks only `minutes_elapsed` /
`new_day`, and everything after the call is the *same code* the engine path
uses — same clamp, same failure floor, same `new_day` corroboration guard,
same OOC-skip ownership. Parity is by construction, and
`test/services/chat/standalone_clock_test.dart` asserts both drivers land on
the identical moment for an identical verdict.

### The four "cannot decouple" reasons, re-audited

1. **Accuracy IS an LLM eval** — true, and it is the *motive*, not a blocker.
   The deterministic drift stays exactly what it was: the cushion for one
   failed call. Never a mode, never surfaced, never offered.
2. **Fused with posture** — a cost, not a barrier. `time_service.dart` had
   *already* shipped a posture-only branch (the `!passageOfTimeEnabled` path);
   time-only is that shape mirrored. Engine-on behaviour is byte-identical —
   the fused call stays fused and costs what it always did.
3. **One-shot has no time call to extract** — true and irrelevant. One-shot is
   a *realism* optimization; with the engine off there is no fused JSON. The
   paths never intersect, so one-shot parity is untouched.
4. **"The wire format is `realism_state`, so this needs a migration"** —
   **wrong.** The clock's store of record is the session row
   (`sessions.story_clock` / `story_start_date` / `passage_of_time_enabled`),
   written at `chat_service_session_state.dart:346-348` and read at
   `chat_service_session_load.dart:385-395`, both unconditional.
   `realism_state` is the per-message swipe/regen rewind snapshot. No
   migration existed to perform.

### The decisions that shaped the implementation

- **Opt-in, default OFF** (`standaloneClockEnabled`). Passage of Time already
  defaults ON, but with the engine off that flag was inert — nobody chose it
  in a world where it cost a call. Treating it as consent would have handed a
  per-turn call to every existing engine-off user. Hence a separate,
  deliberate yes, with the cost stated in the switch's own copy.
- **`realism_off_test.dart` needed NO amendment.** Because the opt-in defaults
  off, §2 (zero eval calls) and §3 (frozen clock) stay true exactly as
  written. The protected file is untouched and no `approved-test-change`
  label is required — the earlier plan to amend §3 is moot.
- **No swipe/regen rewind, deliberately.** The engine path rewinds because it
  re-runs its eval and would double-advance; the standalone eval fires once
  per user turn from `sendMessage` and never re-fires on regenerate, so the
  clock already sits at exactly one advance. Adding a rewind would be a bug.
- **Weather and Dreams follow the CLOCK**, not the engine — their realism term
  was only ever standing in for "the clock is frozen". Weather is
  deterministic math and costs no eval.
- **Porch Life gates weather/dreams on the Passage of Time FLAG, not on
  whether the clock is moving.** Gating on the latter looks more honest and
  is not: with the engine off it greys Story Weather out again, which is the
  dead-switch bug this tab exists to end. The tab sets defaults; the "left
  off, the clock holds still" fact lives on the row that owns it.
- **Group:** the standalone eval fires once per turn, chat-scoped — a group of
  four costs one call, not four. Its prompt names nobody, so it needs no
  speaker.
- Also fixed in passing: the OOC time-skip regex was gated on
  `_realismActiveThisMode`, so "(OOC: skip to morning)" was dead with the
  engine off — contradicting this doc's own claim that it survived.

## The plan

- **Phase 1 — the tab, zero behavior change.** New "Porch Life" settings tab
  (name TBD by maintainer; candidates: Porch Life ★ / Living World /
  Immersion). Every feature toggle moves out of General's nested realism
  block into grouped cards with honest chips (works alone / needs X / pairs
  with X) + one-tap enable-the-dependency. Fixes the real bug this nesting
  causes today: recap's and weather's toggles are invisible to realism-off
  users. Desktop + web same PR. The old Realism Mode section in General
  becomes a pointer (deprecation rule: no dead surface left).
- **Phase 2 — cheap truths.** Chaos relabeled independent; Ambitions' two
  fixes; absence-note fragment lift; Promises' optional purity gate
  (maintainer call); Objectives cadence copy.
- **Phase 3 — SHIPPED 2026-08-06** (it had been cancelled on the misreading
  corrected above). Passage of Time runs on its own eval behind an opt-in;
  weather and dreams follow the clock rather than the engine. Needs keeps its
  engine dependency (Phase 4). No protected test was amended — the opt-in
  default made that unnecessary. The 2026-08-02 CLAUDE.md ruling is amended,
  not deleted: the four constraints stay on record with the audit of each.
- **Phase 4 — deliberately NOT doing:** Needs unbundling (kept paired by
  maintainer instinct — revisit only on user demand), NSFW cooldown and
  fixation/stance independence (would rebuild realism piecewise).

Every phase: provability nets first, 1:1/group parity audit where state is
touched, one-shot/multi-call parity for any eval prompt change, desktop+web
parity in the same body of work, Rawhide.md bullets.
