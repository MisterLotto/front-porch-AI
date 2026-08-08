# Pockets & Wardrobe + Likes & Dislikes

Two character-depth features that share one design principle: **a deterministic
record the model is re-told every turn, updated by deltas.**

Status: PROPOSED (maintainer conversation 2026-08-07). No longer blocked behind
the feature-independence work — see the ruling immediately below, which settles
the one question that was waiting on it.

---

## SETTLED — Pockets runs its own eval. Do not re-open this.

**Maintainer ruling, 2026-08-07:** *"Pockets needs its own separate eval, not to
get mixed with needs."* Earlier drafts of this document had Pockets ride the
post-generation needs-impact eval as an extra JSON field, advertised as "zero
new LLM calls". **That is retracted.** Both the reason of principle and the
technical fact are recorded here so the next agent to pick this up implements
it rather than re-deriving it.

**Reason of principle (the maintainer's, and it governs):** interleaving one
feature's data into another feature's pass is what produced the mess that took
a full day to untangle in `docs/design/feature-independence.md`. Pockets stands
alone or it repeats that.

**The technical fact that makes the old plan unworkable anyway.** The carrier
does not run on a default install. `NeedsImpactEvaluator.evaluateAndApply`
opens with:

```dart
if (!getNeedsSimEnabled() || !getRealismEnabled() || responseText.trim().isEmpty) {
  return;
}
```

Two switches, both required, and `realismEnabled` defaults **false**. So riding
that eval would have meant Pockets silently does nothing until the user turns on
the Realism Engine AND Needs — coupling an inventory feature to a
bond/trust/emotion engine it has no relationship with, which is precisely the
dependency class the independence audit exists to remove. "Zero new LLM calls"
was only ever true for the subset of users who had already opted into both.

### What this means concretely — implement exactly this

- **Its own eval.** One small post-generation call that asks only for
  `inventory_ops`. Own prompt builder, own parse, own leaf under
  `lib/services/chat/`. It does NOT read or write needs state, and no needs
  code path learns the word "inventory".
- **Its own switch** in Settings → Porch Life, **defaulting OFF**. This is a
  real per-turn token cost, and the standing rule from the standalone story
  clock applies: a feature that spends a call every turn is opt-in, because
  that is the user's money to spend, not ours. The toggle copy must say plainly
  that it costs one short extra AI request per turn.
- **Dependency chip: none.** Not the Realism Engine, not Needs, not the
  Journal, not Objectives. Pockets is a record plus an injection plus an
  applier; none of that needs another engine. If a reviewer proposes a
  dependency, that is a design regression, not a simplification.
- **It reuses the shared plumbing, not another feature's pass.** Fire through
  `LlmEvalEngine` (retry/cancel/think-strip) and negotiate tools via the shared
  `fireStructuredEval` / `ToolTransportProbe` in `pass_support.dart`, exactly as
  the realism evals, the journal pass and growth do. Reusing *infrastructure* is
  correct; riding another feature's *call* is what was wrong.
- **Off means off.** With the switch off: no eval fires, no injection block is
  built, and the sidebar panel is absent — not greyed, absent. The Porch Life
  gating shape already established for the other rows applies.

### Explicitly rejected alternatives — do not propose these again

| Proposal | Why it is rejected |
|---|---|
| Add `inventory_ops` to the needs-impact eval JSON | The maintainer's ruling; and the carrier is gated behind Realism + Needs, so it never runs by default. |
| Gate Pockets on `needsSimEnabled` | Couples two unrelated features; a user wanting inventory would have to run a needs simulation they did not ask for. |
| Ride the Journal maintenance pass instead | Same interleaving mistake with a different host. The Journal pass is periodic, not per-turn, so item state would lag the scene badly. |
| Make it free by inferring items from the reply text with regex/heuristics | Discussed and dropped: this is exactly the "prose scrolling out of context" problem the feature exists to fix. A judged eval is the point. |
| Default the switch ON because "it's cheap" | Per-turn cost is never ours to assume. See the standalone clock precedent. |

---

## Part 1 — Pockets & Wardrobe (inventory + outfit state)

### Problem
No AI chat app keeps clothing/carried-item state consistent, because nothing
*stores* it — it's prose scrolling out of context. FPAI already solves this
class of problem three times (Needs, Journal, story clock): keep a real
record, inject it every turn, apply deltas.

### v1 scope
- **Per-character, per-chat record**: `worn: []` and `carrying: []`, short
  free-text entries ("sundress", "car keys", "$40"). Strictly session-scoped
  like Journal cards; deleted with the chat.
- **Seeding**: from the card — new optional `frontPorchExtensions.inventory`
  (`{worn: [...], carrying: [...]}`). Additive/optional → old apps ignore it;
  Stoop-portable by construction. Absent field → seeded empty + a gentle
  first-turn inference (see Detection) so imported cards still work.
  - **Authoring (shipped 2026-08-08).** The field shipped ahead of any UI to
    fill it, so for a while the only way to give a character starting items was
    to hand-edit the card JSON. All three surfaces now author it — the desktop
    edit page, the manual creator and the AI creator — through the shared
    `IdentityChipLists` "Pockets & Wardrobe" section, mirrored in the web
    editor's `RealismFormSection.tsx`.
  - **Condition rides the chip text.** Items carry a free-text condition but a
    chip editor holds plain strings, so the chip IS the item as it reads:
    `sundress (rain-soaked)`. `PocketItem.parseDisplay` is the inverse of
    `PocketItem.display`, and `Pockets.cardJsonFrom` is the ONE normalization
    all three surfaces (and the web mirror) route through — same tidy, same
    60-char caps, same 8-per-list trim as the runtime. The split is not
    information-preserving in the naive sense ("pepper spray (small)" re-splits)
    and does not need to be: what round-trips exactly is the DISPLAY string,
    and display is what gets injected and shown.
  - **Seeded BEFORE turn 1, not after it (fixed 2026-08-08).** The card seed
    originally lived only inside `_runPocketsPass`, which runs *after* a reply
    is generated. Counting the greeting as turn 0, that left turn 1 — the
    character's first real reply — built from a prompt with no inventory
    fragment at all: dressed from turn 2 onward, bare for the turn that sets
    the scene, and a blank sidebar for exactly as long. `seedPocketsFromCards()`
    now runs at the top of `sendMessage` (before any prompt is built) and on
    session load (so the sidebar is populated at turn 0). Idempotent, gated on
    the Pockets switch, identical for 1:1 and group by construction — one loop
    over one speaker list through the same `setPocketsFor` the pass uses.
    Deliberately NOT a fallback inside `pocketsFor`: that getter is read from
    the sidebar's `build`, which rebuilds once per streamed token, so parsing
    the card there would be the per-frame-work pattern the `coverImageFileFor`
    regression exists to warn about. The pass keeps its own `??` seed for
    characters who ARRIVE mid-turn (Scene Guest, cast change).
  - **An empty wardrobe stays absent from the card.** `cardJsonFrom` returns an
    empty map when nothing survives, so `CharacterCard.toJson`'s conditional
    emit keeps a card without a wardrobe byte-identical to one written before
    any of this existed. Two protected goldens depend on that.
- **Injection**: one compact block in the character prompt
  (`[<char> is wearing: …. Carrying: ….]`), capped (8 worn / 8 carried),
  built by a new `prompt_injection/inventory_injection.dart` leaf.
- **Detection**: **its own** post-generation eval (see the SETTLED section
  above — this used to say the needs-impact eval, and that is retracted). One
  small call, asking for one field:
  `inventory_ops: [{op: wear|remove|pickup|drop|give|update|transform, item,
  to?, state?}]`. Tools transport first via the shared
  `fireStructuredEval`/`ToolTransportProbe` negotiation, with the same forgiving
  flat-JSON regex floor every other eval keeps for tool-less backends. Fires
  only when the Pockets switch is on, and only when the reply is non-empty.
  Ops apply to the record through ONE applier with dedup (token-overlap, the
  promise-dedup precedent).
- **Item state & transformations (maintainer-requested 2026-08-07)**: every
  item carries an optional FREE-TEXT condition (`state`, capped ~60 chars) —
  "half-eaten", "rain-soaked, muddy hem", "notched, needs sharpening".
  `update` changes an item's state in place; `transform` replaces the item
  with what it became (candy bar → wrapper). Deliberately narrative, NOT
  numeric: no durability bars, no damage math, no per-category schemas —
  the model narrates transformations anyway, and a phrase is exactly as
  expressive as the story needs. Injection renders state as a suffix
  ("Carrying: iron sword (notched)"); chips show it quietly; the panel edits
  name + state together. This is the fantasy-RP equipment sheet by
  narrative means — an RPG stat system is an explicit NON-GOAL.
- **Chips + receipts**: item changes attach to the message like needs chips
  ("+ picked up: car keys"); tap shows the before/after.
- **Sidebar panel**: "Pockets" accordion under the character state section —
  worn list, carried list, add/edit/remove by hand (Journal-editor precedent:
  the UI mutates the store; injection re-reads per turn, no extra plumbing).
- **Group parity**: per-member records in the group state JSON (`_groupRealism`
  neighborhood), loaded/saved through the established per-speaker dance.
  1:1 and group observable behavior identical.
- **Regen/rewind**: the record snapshots into message `realism_state` metadata
  like every other per-turn scalar; regen restores it (the rewind contract).
- **Web parity (same work, not deferred)**: panel in the chat tools drawer +
  facade endpoints (`inventory`, `inventory-edit`), same visual language.

### v2+ (explicitly out of v1)
- Wardrobe→portrait: outfit selects the avatar gallery "look" (completes the
  avatar-gallery wardrobe stages).
- Item location memory ("the keys are at the diner") — items can be IN a
  place, not just on a person; ties into Worlds/places.
- Needs interplay (wet clothes → comfort decay modifier).
- Author-defined item significance (a locket that matters).

### Risks / guards
- Silly-item accumulation → caps + a prune suggestion in the periodic journal
  pass. Net: unit tests on the applier (dedup, cap, op grammar) written
  BEFORE the wiring, negative-checked.
- Prompt bloat → hard char budget on the injection block; PromptPlan section
  so the Context Budget viewer shows its true cost.
- **Per-turn call cost — the honest one.** Its own eval means Pockets bills a
  short request every turn it is on. Mitigations: the switch defaults OFF and
  says so in its copy; the eval is one field with a tight max-token cap; it is
  chat-scoped, so a group costs one call and not one per member (the same
  decision the standalone story clock made). Measure the real cost on the
  Context Budget viewer before/after and record it here.

---

## Part 2 — Likes & Dislikes (structured preferences)

### Problem
Turn-ons/turn-offs/comfort buttons currently live buried in personality prose
where neither the engine nor the UI can see them. Precedent already in-tree:
`enjoysLowHygiene` is ONE hardcoded preference that flips needs behavior —
this feature makes that pattern author-editable data.

### v1 scope
- **Card fields**: `frontPorchExtensions.likes: []` and `.dislikes: []`
  (short phrases, cap ~8 each, editor hint "phrases, not paragraphs").
  Additive/optional/portable, same as inventory.
- **NSFW split (wording rule applies)**: the everyday lists are always
  available and labeled "Likes / Dislikes". An additional
  `.intimatePreferences: {into: [], notInto: []}` section appears in editors
  ONLY when NSFW is enabled, feeds lust/arousal, and uses "suggestive/18+"
  copy — never "explicit".
- **Behavior side**: lists join the behavioral injection so the character
  ACTS on them (seeks the liked, bristles at the disliked).
- **Scoring side**: the realism eval prompts (all: relationship, emotional,
  one-shot — BOTH paths, parity duty) get a compact preferences block so
  bond/trust/emotion/arousal deltas become character-specific. Temp-0.1
  regen determinism unaffected (same prompt in → same deltas out).
- **Receipts**: the eval's existing pending-chip metadata gains an optional
  `because` string so chip tooltips can say "+4 bond — she loved that".
- **Fixation synergy**: repeated like-hits become fixation candidates through
  the existing fixation proposal path (no new machinery).
- **Editors**: desktop character editor + creator (guided/automated modes can
  propose them; one-tap "extract from personality" via LlmEvalEngine) + web
  editor + Stoop card detail display. All in the same body of work.
- **Realism-off behavior**: the behavioral injection still works (acting on
  likes needs no engine); only the scoring side goes quiet. Document in the
  toggle copy.

### Risks / guards
- Overfit behavior (constant cuddle-seeking) → injection phrasing frames them
  as tendencies, not scripts; cap counts.
- Eval prompt growth → token-budgeted block, measured before/after on the
  Context Budget viewer.

---

## Part 3 — Ambitions authoring & the Current Task swap

Maintainer decision (2026-08-07). Verified wiring first: ambitions do NOT
guide the objective system — the arrow points the other way
(`ObjectiveProposal.onObjectiveCompleted` → `AmbitionService` progress check;
ambitions reach scenes only via injection). `card.currentTask` does exactly
one thing: seeds one primary objective at new-chat entry
(`chat_service_chat_entry.dart:299-304`). An ambitions editor already EXISTS
(one-per-line TextField in edit_character_page, `_ambitionsController`) but
is buried while "Current Task / Quest" holds a whole prominent section — the
maintainer didn't know the editor existed, which is the design verdict.

### Scope

> **Status 2026-08-07 — the first three bullets have SHIPPED.** Ambitions is a
> chip editor in the character editor, the creator's realism step and the web
> form; the "Current Task / Quest" section is gone from all of them; the FIELD
> is untouched and now imports on fresh chat entry through one shared
> `_importAuthoredTask` — **including group entry, which never seeded it at
> all** (a member card's task was silently dropped; harmless while the box
> existed, permanent data loss once it went). Two findings from the wiring
> audit: the group wizard's copy of the box wrote `currentTask` into the member
> seed map, which **no code has ever read**, so it was decorative in every
> build; and both create flows held `realismCurrentTask` state that could only
> ever be `''` once the editor was gone — deleted.
>
> **PART 3 IS NOW COMPLETE (2026-08-07).** The last two bullets shipped with
> the UI half below: the "starting quest" affordance lives in the extracted
> `story_tools/objective_add_goal.dart` (shown when a chat has no primary and
> no side quests — there is no fresh-chat flag, and scanning `chat.messages`
> in a build would copy the list on every notify), and the Stoop card detail
> shows ambitions on desktop and web with **no backend change**: the card blob
> already travels verbatim through the `/api/stoop/*` relay, so both clients
> were already receiving `extensions.front_porch.realism_engine.ambitions`.

- **Promote Ambitions** in the character editor: chip-style list editor
  (same component as Likes/Dislikes), prominent placement, copy explaining
  identity-not-quests + that objective completions tick progress.
- **Remove the "Current Task / Quest" section from the character editor.**
  Per-chat quest control belongs in the sidebar Objectives panel. Same swap
  in the creator's realism step and the group wizard's member card (no
  parallel surfaces left — deprecation rule).
- **The `currentTask` FIELD stays fully honored** (never removed): imported/
  existing cards still seed their first objective exactly as today. It just
  loses its authoring surface. (V2.5/Stoop compat — additive-only contract.)
- The sidebar Objectives panel gains a small "starting objective" affordance
  for brand-new chats so the removed control has an obvious new home.

### Ambition-driven objectives (maintainer ruling 2026-08-07 — CORE, not optional)

> **Status 2026-08-07 — the forward direction has SHIPPED (schema v46).** The
> proposal eval is shown the character's open ambitions with stage words and
> asked for the next step up the least-advanced one; situational quests stay
> legal. It returns `serves_ambition`, resolved against the same roster the
> prompt numbered and stored in `objectives.served_ambition` (TEXT, nullable,
> no default — NULL is a real answer and the only honest one for pre-v46
> rows). Both transports and both paths (multi-call + one-shot, JSON + tools)
> carry it, and the Director's preserve-shape hint names it. A character with
> no unachieved ambitions gets none of it, at no token cost.
>
> The feedback direction also improved: with a tag present, the completion
> judge is shown only that ambition and rules on the SIZE of the step instead
> of re-deriving which mountain the finished quest was on. Stale tags
> (ambition achieved or deleted since) fall back to the original question.
>
> **THE UI HALF SHIPPED 2026-08-07.** `AmbitionService.activeStepsFrom` is the
> one merge behind every display — the sidebar Ambitions row, the group member
> card and the web facade all call it over `getObjectivesForGroupCharacter`,
> which returns the 1:1 list unchanged when there is no group, so 1:1 and group
> cannot disagree by construction. `AmbitionServedChip` renders the "🧭 open
> her own bakery" tag on all three objective surfaces (1:1 panel, side-quest
> row, group dialog); `ChatTools.tsx` mirrors both, fed by two additive
> nullable facade keys (`servedAmbition` on an objective, `step` on an
> ambition).
>
> Note for whoever extends this: the merge is a separate static rather than a
> widened `ambitionsFor` record ON PURPOSE. `test/golden/support/fakes.dart`
> pins that record's exact type, and `test-integrity.yml` fails any PR that
> edits a test file without the maintainer's `approved-test-change` label — so
> widening the service signature would have forced a test edit just to compile.
> Do not "simplify" it back.

"Ambitions need to guide the objectives, not the other way around. Ambitions
are the final overarching goal of the character and that is what they work
toward bit by bit." The hierarchy is now explicit:
**Ambition (the mountain) → Objectives (the switchbacks) → Tasks (the steps).**
- **Forward direction (new, primary):** the autonomous objective-proposal
  eval is shown the character's ambitions + current progress bands and
  instructed to propose the next believable SMALL step toward them —
  favoring the least-advanced/most-relevant ambition, while situational
  objectives unrelated to any ambition remain allowed (life happens; not
  every quest serves the arc).
- **Proposals TAG the ambition they serve** (eval returns it; stored with
  the objective — additive nullable column or existing metadata, whichever
  the objectives store offers). The sidebar Objectives panel shows the link
  as a small chip ("→ open her own bakery"), and the Ambitions row shows
  the active step under each goal.
- **Feedback direction (exists today, unchanged):** completing an objective
  runs the strict progress judge and ticks the served ambition.
- Task generation needs no change — tasks serve the objective, the objective
  serves the ambition, transitively.
- Parity duties as ever: 1:1/group, one-shot/multi-call prompt parity for
  the proposal block, desktop + web objectives panel, same body of work.
- Parity: desktop + web editors, creator, group wizard, Stoop card detail
  (ambitions display), same body of work.

## Sequencing
1. ~~Independence/toggle-tab work lands first~~ — **DONE 2026-08-07.** The
   Porch Life tab shipped, Objectives got a switch, and the story clock was
   decoupled from the Realism Engine. Pockets no longer waits on it: the
   question it was waiting to answer ("where do post-turn passes live?") is
   answered by the ruling at the top of this document — Pockets brings its own.
2. Likes & Dislikes (smaller, pure-additive, no new store) ships second. Note
   this one genuinely IS zero-new-calls: it adds a block to eval prompts that
   already fire and to the behavioural injection. That is not the same shape as
   Pockets and the two should not be reasoned about together.
3. Pockets & Wardrobe v1 third; wardrobe→portrait as its own follow-up.

**Do not bundle 2 and 3 into one body of work.** They are in this document
together because they were proposed in the same conversation, not because they
share an implementation. Likes & Dislikes touches card fields, injections and
eval prompts; Pockets adds a store, a switch, an eval and a UI panel. Shipping
them together is how the interleaving starts.

Every stage: provability nets first (applier/dedup/injection budgets),
desktop+web same PR, 1:1/group parity audit, one-shot/multi-call parity for
any eval prompt change, docs/Rawhide.md bullets.
