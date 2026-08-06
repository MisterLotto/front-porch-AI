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
| **Passage of Time** | clock fully frozen (E2E-pinned) | the scene-time EVAL is realism machinery | see below — the one real decision |
| **Story Weather / °F** | vanishes (explicit `_realismEnabled` read + frozen clock) | the CLOCK, not realism — engine is pure/deterministic | 1-line un-gate once time is independent |
| **Dreams** | inert (no story nights pass) | Journal + a night source | rides the time decision, or redefine to wall-clock nights |
| **Needs** | frozen (not zeroed) | none for a NEW call (its eval is its own) — but medium code change incl. group per-speaker orchestration | maintainer leaning: keep PAIRED with realism ("would it feel right without it — no") |
| **NSFW Cooldown** | inert, values preserved | arousal deltas ride the emotional-state eval; climax rides needs-impact | "rebuilding a slice of the realism engine" — stays realism-bound |
| **Fixation / spatial stance** | fossilized | narrative + posture evals (posture is FUSED with the time eval) | confirmed inseparable — stays realism-bound |

## The Passage-of-Time decision (the only hard one)

The 2026-08-02 ruling ("cannot be decoupled — do not re-propose") was
re-audited reason by reason: **all four hold at current line numbers.**
Accuracy IS an LLM eval (`minutes ?? failureDriftMinutes`); the eval is fused
with posture; one-shot fuses time into the realism JSON; the clock persists
through `realism_state`. The maintainer reopening this changes what we OFFER,
not what is true. The proposal (mockup's "Clock accuracy" control):

- **Steady mode** (new): realism-free deterministic clock — fixed drift per
  turn + the OOC skip regex un-gated + calendar/nudge UI re-enabled. Honest
  copy: "time moves at a gentle fixed pace unless you tell it otherwise."
  Costs: a per-turn hook outside the eval path, un-gating the time prompt
  fragment for this mode only (the current gate exists to prevent injecting a
  frozen timestamp — Steady's clock MOVES, so the lie-prevention reason
  vanishes), a persistence story for realism-off chats, web parity, and
  amending `realism_off_test.dart` §3 (protected — needs the maintainer's
  explicit approved-test-change sign-off, rationale: the asserted behavior is
  being deliberately changed).
- **Model-judged mode** = today's fused eval when Realism is ON (free). With
  realism OFF it would cost one extra LLM call per turn — offered only as an
  explicit opt-in labeled with its cost, or not at all (maintainer choice).
- CLAUDE.md's settled block gets AMENDED (not deleted) when this ships:
  the four constraints stay documented; the ruling becomes "the eval cannot be
  decoupled; the CLOCK now has a deterministic standalone mode."

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
- **Phase 3 — Steady time + weather un-gate + Dreams night source.** The
  decision block above; ships only after the maintainer picks the mode set.
- **Phase 4 — deliberately NOT doing:** Needs unbundling (kept paired by
  maintainer instinct — revisit only on user demand), NSFW cooldown and
  fixation/stance independence (would rebuild realism piecewise).

Every phase: provability nets first, 1:1/group parity audit where state is
touched, one-shot/multi-call parity for any eval prompt change, desktop+web
parity in the same body of work, Rawhide.md bullets.
