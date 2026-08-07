# Pockets & Wardrobe + Likes & Dislikes

Two character-depth features that share one design principle: **a deterministic
record the model is re-told every turn, updated by deltas from a pass that
already runs.** Zero new LLM calls in either v1.

Status: PROPOSED (maintainer conversation 2026-08-07). Blocked behind the
feature-independence work (`docs/design/feature-independence.md`) only insofar
as the post-turn evaluator hook should land on whatever gating shape that work
settles on.

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
- **Injection**: one compact block in the character prompt
  (`[<char> is wearing: …. Carrying: ….]`), capped (8 worn / 8 carried),
  built by a new `prompt_injection/inventory_injection.dart` leaf.
- **Detection**: the post-generation needs-impact eval gains one JSON field
  (`inventory_ops: [{op: wear|remove|pickup|drop|give|update|transform, item,
  to?, state?}]`) — same transport, same forgiving parse, ZERO extra calls.
  Ops apply to the record through ONE applier with dedup (token-overlap, the
  promise-dedup precedent). When Needs is disabled, the ops ride whatever
  post-turn pass the independence work keeps alive (open decision — see that
  doc).
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
> ever be `''` once the editor was gone — deleted. The remaining bullets (the
> sidebar "starting objective" affordance, and the Stoop card detail showing
> ambitions) are still open.

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
> STILL OPEN: the UI half — the sidebar chip ("→ open her own bakery") and the
> active step under each goal in the Ambitions row, desktop AND web.

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
1. Independence/toggle-tab work lands first (settles where post-turn passes
   live and which gates exist).
2. Likes & Dislikes (smaller, pure-additive, no new store) ships second.
3. Pockets & Wardrobe v1 third; wardrobe→portrait as its own follow-up.

Every stage: provability nets first (applier/dedup/injection budgets),
desktop+web same PR, 1:1/group parity audit, one-shot/multi-call parity for
any eval prompt change, docs/Rawhide.md bullets.
