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
| **Passage of Time** | clock fully frozen (E2E-pinned) | the engine — RULED a hard dependency 2026-08-07 | none: not decoupling; deterministic drift stays an emergency fallback |
| **Story Weather / °F** | vanishes | the CLOCK (which needs the engine) — RULED to keep this gate | none: not decoupling |
| **Dreams** | inert (no story nights pass) | Journal + a moving clock | none: follows the time ruling |
| **Needs** | frozen (not zeroed) | the engine — RULED a hard dependency 2026-08-07 ("leave the gate, fix the wording") | none: gate stays; NEW global `needsSimDefault` added so the tab can show it |
| **NSFW Cooldown** | inert, values preserved | arousal deltas ride the emotional-state eval; climax rides needs-impact | "rebuilding a slice of the realism engine" — stays realism-bound |
| **Fixation / spatial stance** | fossilized | narrative + posture evals (posture is FUSED with the time eval) | confirmed inseparable — stays realism-bound |

## The Passage-of-Time decision (the only hard one)

The 2026-08-02 ruling ("cannot be decoupled — do not re-propose") was
re-audited reason by reason: **all four hold at current line numbers.**
Accuracy IS an LLM eval (`minutes ?? failureDriftMinutes`); the eval is fused
with posture; one-shot fuses time into the realism JSON; the clock persists
through `realism_state`. The maintainer reopening this changes what we OFFER,
not what is true.

**DECIDED (maintainer, 2026-08-07, refined the same day): Passage of Time
REQUIRES the engine, full stop.** "Passage of time requires the model usage,
the fallback is just that a fallback… fallback deterministic passage of time
is not usable as is but an emergency 'oh shit'." So the deterministic drift
stays exactly what it is today — a failure cushion when an eval doesn't come
back — and is never surfaced, never a mode, never a reason to claim the clock
works without the engine. **Weather keeps its Passage of Time requirement**
(it is a function of story days; a frozen clock means frozen weather).
Consequences: Phase 3 below is CANCELLED except its documentation half;
the Porch Life tab chips Passage of Time as "requires the Realism Engine";
Dreams keeps needing the Journal + a moving clock.

Superseded proposal, kept for the record: There is no "clock accuracy"
control and no "Steady" branding anywhere in the UI. Users see exactly one
toggle — Passage of Time — and it simply works:

- Realism Engine ON → clock accuracy comes from the fused scene-time eval,
  exactly as today (free).
- Realism Engine OFF → the clock silently falls back to the deterministic
  machinery (fixed per-turn drift + the un-gated OOC skip regex + the
  calendar/nudge UI). Toggle copy states it plainly in one sentence ("time
  still moves on its own and always honors 'let's skip to morning'") without
  presenting it as a feature or a choice.
- A dedicated realism-off time eval is NOT offered (rejected with the mode
  picker — it was the other half of the same removed choice).

Engineering costs are unchanged by hiding the seam: a per-turn fallback hook
outside the eval path, un-gating the time prompt fragment when the fallback
is driving (the current gate prevents injecting a FROZEN timestamp — the
fallback clock moves, so the lie-prevention reason vanishes), a persistence
story for realism-off chats, web parity, and amending
`realism_off_test.dart` §3 (protected — needs the maintainer's explicit
approved-test-change sign-off at implementation time, rationale: the
asserted frozen-clock behavior is being deliberately changed).
CLAUDE.md's settled block gets AMENDED (not deleted) when this ships: the
four constraints stay documented; the ruling becomes "the eval cannot be
decoupled; the clock falls back to internal deterministic drift when the
engine is off."

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
- **Phase 3 — CANCELLED (maintainer, 2026-08-07).** Time, weather, dreams and
  needs keep their engine dependency; the honest UI (chips + copy) is the
  whole deliverable, and it ships in Phase 1. No protected-test amendment is
  needed, and the 2026-08-02 CLAUDE.md ruling stands UNCHANGED.
- **Phase 4 — deliberately NOT doing:** Needs unbundling (kept paired by
  maintainer instinct — revisit only on user demand), NSFW cooldown and
  fixation/stance independence (would rebuild realism piecewise).

Every phase: provability nets first, 1:1/group parity audit where state is
touched, one-shot/multi-call parity for any eval prompt change, desktop+web
parity in the same body of work, Rawhide.md bullets.
