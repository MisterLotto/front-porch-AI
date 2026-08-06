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
  (`inventory_ops: [{op: wear|remove|pickup|drop|give, item, to?}]`) — same
  transport, same forgiving parse, ZERO extra calls. Ops apply to the record
  through ONE applier with dedup (token-overlap, the promise-dedup precedent).
  When Needs is disabled, the ops ride whatever post-turn pass the
  independence work keeps alive (open decision — see that doc).
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

## Sequencing
1. Independence/toggle-tab work lands first (settles where post-turn passes
   live and which gates exist).
2. Likes & Dislikes (smaller, pure-additive, no new store) ships second.
3. Pockets & Wardrobe v1 third; wardrobe→portrait as its own follow-up.

Every stage: provability nets first (applier/dedup/injection budgets),
desktop+web same PR, 1:1/group parity audit, one-shot/multi-call parity for
any eval prompt change, docs/Rawhide.md bullets.
