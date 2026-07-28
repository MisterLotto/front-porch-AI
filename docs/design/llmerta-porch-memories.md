# LLMerta → Front Porch AI — Porch Memories Import

**Status:** Implemented on `Rawhide` (consumer). Producer shipped in LLMerta  
(`docs/PORCH_MEMORIES.md` + `packages/llm/lib/src/porch_memories.dart`).  
**Branch:** `Rawhide`  
**Direction:** LLMerta → FPA only. No reverse path. No network.  
**Handoff brief:** `FPA_LLMerta_Porch_Memories_Import.md` (Desktop).  
**Related:** `docs/design/journal-memory.md` (per-chat Journal isolation).

---

## 1. One-line pitch

When the user opens a chat whose **character `stableGroupId`** and **session
`user_persona_id`** match a pending LLMerta game bundle on disk, plant each
emotion-stamped card into **The Journal** for that session, dedupe by card id,
delete fully consumed bundle files — **and force the character’s next reply to
open on that Mafia night** (Chance Time–style scene injection) so the night
cannot be silently swallowed by the diary.

---

## 2. Why

LLMerta already writes multi-card “constellation of feelings” bundles after
Mafia nights played with FPA personas + FPA cards. Without a consumer, those
files sit forever under `KoboldManager/llmerta_porch_memories/`. Characters
should remember the night the next time you talk to them — fond of playing
*and* bitter about being bussed — as normal Journal cards that inject, cool,
and show in the diary UI with zero new memory subsystem.

**Planting alone is not enough.** Hot Journal cards sit in the middle of the
prompt with many peers; local models routinely ignore mid-prompt diary lines.
Chance Time and Needs catastrophe already solved this with a short post-suffix
**SCENE EVENT — CANON** block that *requires* the reply to open on the event.
Mafia nights use the same mechanism once per imported night (per diary owner).

---

## 3. Locked decisions

| Decision | Choice | Rationale |
|---|---|---|
| Scope | Per **(sessionId, characterId)** Journal only | Journal design forbids cross-chat leak |
| When to plant | On **session open / focus** (not boot-time plant) | Avoid guessing which of N Alma chats should own the night |
| Identity | **UUID persona id + stableGroupId only** | Names are prose only; no fuzzy match |
| Card `kind` | `llmerta_game` in metadata | Distinct from milestone/promise/dream; readers already parse kind forgivingly |
| Cap / cool | **Normal hot cards** (not ledger) | Ledger skips hot-set injection — Mafia nights *should* inject into the prompt. Strong intensities from LLMerta already slow cooling. No `sourceMessageIds` → safe from transcript invalidation |
| Dedup | Metadata `porchCardId` (bundle `cards[].id`) on planted cards | No new Drift table; re-scan existing diary for owner |
| Bundle delete | Only when every character block is planted **or** skipped (missing library char) | Partial multi-character nights keep the file |
| **First-reply force-ack** | **One-shot SCENE EVENT injection** (Chance Time / catastrophe register) on the **next generation** for that diary owner after plant | Diary alone gets swallowed; user requirement: first character message must address the game |
| **Ack durability** | Metadata `porchAckPending: true` on planted cards; clear after injection delivered | Survives app restart; no new table; regen window can re-read pending until cleared |
| Setting | Opt-in toggle default **on** (`importLlmertaPorchMemories`) | Parity with LLMerta lobby toggle |
| Schema | Require `schemaVersion == 1`; unknown → skip + log, never delete | Forward-safe |
| Beta path | Prefer live `StorageService.rootPath`; also scan LLMerta’s hard-coded stable paths | Producer currently only writes stable `FrontPorchAI` tree; importer must still find those files when FPA root is custom/beta |
| Web parity | v1 desktop plant is enough if Journal already surfaces on web | Cards are session data; web reads same Journal. Optional “N nights waiting” badge can defer with maintainer OK |
| Schema / DB | **Zero new tables** | Prefs for the toggle only; dedup + ack flag live in card metadata |

---

## 4. Mailbox (discovery)

LLMerta writes one `{gameId}.json` per finished game under:

```text
{home}/Documents/FrontPorchAI/KoboldManager/llmerta_porch_memories/
{home}/FrontPorchAI/KoboldManager/llmerta_porch_memories/
```

FPA additionally must check the **live install root**:

```text
{StorageService.rootPath}/KoboldManager/llmerta_porch_memories/
```

(`rootPath` is already `…/FrontPorchAI` or `…/FrontPorchAI-Beta` or a custom
path — same tree LLMerta targets when it finds KoboldManager.)

Rules:

- Folder missing → empty list (normal).
- Multiple files accumulate; sort by `finishedAt` ascending (oldest first).
- Corrupt JSON → skip, **do not delete** (optional rename to `*.bad` later).
- Import setting off → leave files untouched.

---

## 5. Bundle schema (v1) — consumer view

```json
{
  "schemaVersion": 1,
  "gameId": "game-…",
  "finishedAt": "ISO-8601",
  "townName": "Brasshollow",
  "difficulty": "standard",
  "userPersonaId": "<personas.id UUID>",
  "userPersonaName": "Joseph",
  "characters": [
    {
      "characterId": "<stableGroupId>",
      "characterName": "Alma",
      "cards": [
        {
          "id": "game-…:1:playedTogether",
          "kind": "playedTogether",
          "category": "about_us",
          "content": "…",
          "emotionLabel": "fond",
          "emotionIntensity": "moderate",
          "salience": 0.35,
          "dayHint": 1,
          "source": { "kind": "playedTogether" }
        }
      ]
    }
  ]
}
```

### Field → FPA plant

| Bundle | Journal |
|---|---|
| `userPersonaId` | Must equal `sessions.user_persona_id` (and active persona for this chat) |
| `characterId` | Must equal diary owner id = `CharacterCard.stableGroupId` / `ChatParticipant.id` |
| `cards[].content` | `addCard.content` |
| `cards[].category` | `about_user` / `about_us` / `moment` (normalize snake/camel if needed) |
| `cards[].emotionLabel` / `emotionIntensity` | As-is (`mild` \| `moderate` \| `strong`) |
| `cards[].id` | Metadata `porchCardId` (dedupe key) |
| `cards[].kind` | Metadata `porchKind` (provenance enum string) |
| `gameId` / `finishedAt` / `townName` | Metadata `gameId`, `finishedAt`, `townName` |
| top-level plant marker | Metadata `kind: "llmerta_game"` |

Unknown future `cards[].kind` values: still plant if content + category valid.

---

## 6. Code map (where it lives)

### New pure leaves (under `lib/services/chat/` — keep each &lt; 500 LOC)

| File | Role |
|---|---|
| `porch_memory_models.dart` | `PorchMemoryBundle` / `PorchCharacterBlock` / `PorchMemoryCard` + forgiving `fromJson` |
| `porch_memory_mailbox.dart` | `detectMailboxDirs()`, `listPendingBundles()`, parse + sort; pure `dart:io` + models |
| `porch_memory_import.dart` | `PorchMemoryImportService` — resolve match, plant, dedupe, delete when fully consumed |
| `prompt_injection/porch_night_injection.dart` | Build + consume the one-shot SCENE EVENT block from `porchAckPending` cards (same calm-but-firm register as Chance Time / needs catastrophe) |

No new private methods on `ChatService` beyond thin hooks:
1. **Post-load:** fire-and-forget `import.tryImportForSession(...)` from
   `chat_service_session_load.dart` / group focus path.
2. **Prompt plan:** call `PorchNightInjection.build(...)` next to Chance Time /
   needs catastrophe in `chat_service_generation.dart` (one line + place the
   returned block in the plan — do not grow chaos_mode_service for this).

### Existing surfaces to touch lightly

| Area | Change |
|---|---|
| `JournalStore.addCard` | Accept optional `Map<String, dynamic>? extraMetadata` merged into the metadata pouch (or plant then `updateCardMetadata` — prefer one write). **Do not** invent a second plant API. |
| `JournalPhysics` | No change for v1 (not ledger). Optional later: UI chip helper `isLlmertaGame(card)` via `cardKind == 'llmerta_game'`. |
| `MemorySettings` (or small prefs on `StorageService`) | `importLlmertaPorchMemories` bool, default `true` |
| `chat_service_session_load.dart` `loadSession` | After `_currentSessionId` is set + persona hydrated: `unawaited(import.tryImportForSession(...))` — never throw into open path |
| `chat_service_generation.dart` | Wire porch-night injection beside Chance Time / catastrophe (post-suffix / high-recency slot) |
| Group focus | When focused participant changes, same plant for that member’s `ChatParticipant.id` against the **group session** id |
| Journal UI (optional, same PR if cheap) | Chip “Mafia night” when `kind == llmerta_game` — reuse existing kind chip pattern if any |
| Settings | One toggle under Memory / Journal section |
| `docs/Rawhide.md` | User-facing What’s New bullet when feature ships |
| Web | No new facade required for plant; cards appear via existing Journal read. Force-ack rides the same generation path on web. Waiting-nights badge = optional deferral |

### Explicit non-touches

- No `database/migrations/`
- No LLMerta code in this repo
- No writing into LLMerta dirs except **delete** after successful full consume / user discard
- Do not grow `chat_service.dart` — hooks stay in session-load + generation part files
- Do **not** reuse `ChaosModeService.pendingChaosInjection` — porch nights are not Chance Time (separate leave, same *register*)

---

## 7. Import algorithm

```
tryImportForSession(sessionId, userPersonaId, diaryCharacterIds[]):
  if !setting: return
  for bundle in listPendingBundles() sorted finishedAt ASC:
    if bundle.userPersonaId != userPersonaId: continue
    for block in bundle.characters:
      if block.characterId not in diaryCharacterIds: continue  // wrong chat owner
      if library has no card with stableGroupId == block.characterId:
        mark block skipped-missing
        continue
      existing = journal.cardsFor(sessionId, block.characterId)
      already = set of porchCardId from existing metadata
      plantedAny = false
      for card in block.cards sorted by salience DESC (optional):
        if card.id in already: continue
        addCard(
          sessionId, characterId: block.characterId,
          content, category, emotionLabel, emotionIntensity,
          kind: 'llmerta_game',
          extraMetadata: {
            porchCardId, porchKind, gameId, finishedAt, townName,
            porchAckPending: true,   // ← one-shot force-ack
          },
          maxCards: journalMaxCards,
        )
        plantedAny = true
      mark block imported
    if every block imported or skipped-missing:
      delete bundle file
```

**1:1:** `diaryCharacterIds = [activeCharacter.stableGroupId]`.  
**Group:** `diaryCharacterIds = [focusedMember.id]` on focus, or all members if
we plant only the focused diary (recommended: focused member only so opening
the group doesn’t dump every seat’s night into every member at once — each
member’s diary fills when that member is focused / panel opens).

**Persona mismatch:** opening Alma as a different persona → no plant (file stays
for the correct persona later).

**Missing persona entirely (deleted):** skip whole bundle for plant; leave file
(or Settings discard).

---

## 7b. First-reply force-ack (Chance Time parity) — **required**

### Why this exists

Journal hot-set injection is budgeted mid-prompt. Local models often skip it.
Chance Time solved “this *must* land in the next reply” with a short
`[SCENE EVENT — CANON, …]` block in a high-recency prompt slot
(`ChaosInjection.buildChanceTimeInjection` / needs catastrophe in
`chat_service_generation.dart`). Mafia nights use the **same register**, not
the Chaos machinery itself.

### Lifecycle

```
plant cards (porchAckPending: true)
        │
        ▼
next generation for that diary owner
        │
        ├─ build PorchNightInjection from all pending cards for this owner
        ├─ place block in prompt plan (same neighborhood as Chance Time /
        │     needs catastrophe — high recency, not mid-history)
        └─ mark porchAckPending: false on those cards (delivered)
              │
              ▼
        subsequent turns: only ordinary Journal hot cards remain
              (still cool/recall normally; no more forced open)
```

**Regen / swipe of the reacting AI message:** keep re-injecting while
`porchAckPending` is still true, **or** mirror Chance Time’s
“delivered flag + clear on next user turn” window:

- Preferred v1 (simpler, durable): clear `porchAckPending` only after the
  generation that *included* the block completes successfully (or on mark
  delivered at inject time, accepting that a failed gen might skip the
  force — rare). Chance Time marks delivered at inject and keeps the text
  until the next user turn for regens; if we clear metadata at inject we
  lose regen re-inject unless we also keep an in-memory copy for the
  session.

**Locked v1 regen behavior (match Chance Time):**

1. At inject time: build block from cards with `porchAckPending == true`,
   stash the rendered injection string in a **session-scoped in-memory**
   field on the import/injection leaf (`_deliveredPorchNightInjection` +
   `_porchNightDelivered`), flip card metadata `porchAckPending → false`
   only on the **next user send** (or after successful save of the reacting
   message) so swipes/regens of that first AI reply still re-inject.
2. If the app restarts mid-window before clear: cards still have
   `porchAckPending: true` if we deferred the metadata flip — **or** if we
   flipped early, the night is only in the diary (acceptable floor).

Simplest durable floor that still matches user intent:

- Leave `porchAckPending: true` until the **first successful AI message**
  after import is saved for that session/owner.
- While true, every generation for that owner injects the block (regen-safe).
- After that message is persisted, clear flags.

### Injection text (house register — calm, firm, no ALL-CAPS jailbreak walls)

Macro-resolve `{{user}}` / `{{char}}` via the existing `_macroResolver` path
(same fix that landed for needs catastrophe). Never mention LLMerta, systems,
or “porch memories.”

Template (build from pending cards — table talk, not soft mood):

```text
[TABLE TALK — Mafia night is real shared history, not a metaphor for the scene:

HARD FACTS (use literally — do not invent other roles/votes):
- (shock) I thought {{user}} was Town — {{user}} was Mafia, I was Town.
- (betrayed) Day 2 bus / vote beat …
- (fond) Box-score frame with roles + winner …

REQUIRED OPENING: first 2–4 sentences = spoken table talk ("good game",
"I thought you were Town", bus/defend callouts). Then continue the scene.
Regen of that AI reply still re-injects until the next user send.]
```

Rules for the bullet list:

- Prefer card `content` as already first-person (LLMerta wrote it).
- Prefix with `(emotionLabel)` so the model sees the *feeling*, not just plot.
- Cap at ~6 bullets (salience DESC) so the block stays short.
- Multiple `gameId`s pending: one section per night, or one combined list
  (v1: combine; oldest-first nights).

### Placement in the prompt plan

Next to Chance Time / needs catastrophe in `chat_service_generation.dart`
(post-suffix / fixed high-recency sections that are not budget-trimmed). Do
**not** rely on Journal injection alone for the first reply.

If both Chance Time and a porch night are pending the same turn (rare): emit
**both** blocks; Chance Time is “this moment,” porch night is “recent shared
history” — they do not cancel each other.

### Group parity

Injection is **per diary owner / speaker**. When the upcoming group speaker
is the member who just received Mafia cards, inject for that speaker only
(same impersonation discipline as other per-character prompt bits).

---

## 8. `JournalStore.addCard` metadata shape after plant

```json
{
  "kind": "llmerta_game",
  "porchCardId": "game-123:1:busedByUser",
  "porchKind": "busedByUser",
  "gameId": "game-123",
  "finishedAt": "2026-07-25T18:30:00.000Z",
  "townName": "Brasshollow",
  "porchAckPending": true
}
```

After the first successful force-ack generation for that owner: set
`porchAckPending: false` on every card that was included in the block
(via `JournalStore.updateCardMetadata`).

Optional `storyDay` left unset (Mafia night is out-of-story-calendar unless
product later maps `dayHint` — v1 ignore `dayHint`).

---

## 9. Phases (implementation order)

### Phase A — Models + mailbox + tests
- Parsers + fixture `test/fixtures/llmerta_porch_bundle_v1.json`
- Unit tests: parse, schema skip, sort, category normalize
- Pure, no ChatService

### Phase B — Import service + Journal plant
- `PorchMemoryImportService` with injectable dir + store for tests
- Dedupe by `porchCardId`
- `porchAckPending: true` on every freshly planted card
- Delete only when fully consumed
- Never throw to callers

### Phase C — Force-ack injection + triggers + setting
- `PorchNightInjection` builder (unit-tested template from fixture cards)
- Wire into generation plan next to Chance Time / catastrophe
- Clear `porchAckPending` after first successful AI reply for that owner
- Session load / group focus import hooks
- Setting toggle (default on)
- Optional: Settings “N Mafia nights waiting” list + Discard (nice-to-have; can be Phase C.2)

### Phase D — Polish
- Journal chip “Mafia night”
- `docs/Rawhide.md` user bullet
- Hygiene: analyze, dead-code audit

---

## 10. Acceptance criteria (from handoff, FPA-side)

1. Bundle file present under mailbox after LLMerta game (producer already).
2. Open matching 1:1 as matching persona → multi-card plant, mixed emotions.
3. Open same character as **different** persona → no plant.
4. Second game → second file coexists until import.
5. After full import, file gone; reopen does not duplicate (`porchCardId`).
6. Missing mailbox / setting off / house-only games → clean no-op.
7. Unit tests: parse, match, plant, dedupe, delete.
8. **First AI reply after import opens on the Mafia night** (mentions the game
   and/or the feelings — not a pure small-talk ignore). Regen/swipe of that
   reply still carries the force-ack until it is cleared.
9. **Second AI reply** no longer carries the SCENE EVENT block; cards remain
   in the Journal as normal hot/cold memory.

---

## 11. Risk notes

| Risk | Mitigation |
|---|---|
| Hook on `loadSession` slows open | Fire-and-forget; mailbox list is few small JSON files; never await plant before UI paint |
| Cap trim drops fresh Mafia cards | Plant strong intensities; cap is 200 default; multi-card night is ≤8 |
| Ledger temptation | Do **not** mark ledger — would hide from hot injection |
| Growing `addCard` signature | One optional `extraMetadata` map; no second plant method |
| Custom FPA root vs LLMerta hard-coded paths | Scan both live root and producer’s known paths; union + de-dupe by `gameId` |
| Group member id vs library stableGroupId | Group members use own UUIDs for diary keys; only plant when member **origin** stableGroupId matches bundle `characterId` (use existing `member_origin_resolver` / origin field). **Critical for groups** — plant key is still the member’s journal `characterId` (UUID), identity match is on origin |
| Diary plant swallowed by model | **Force-ack SCENE EVENT block** (this section); do not ship plant-only |
| Hijacking ChaosModeService | Separate `PorchNightInjection` leaf — same register, different state |
| Force-ack forever | Clear `porchAckPending` after first successful reacting message |
| ALL-CAPS instruction walls | Match Chance Time / catastrophe calm register |

### Group identity detail (critical)

LLMerta’s `characterId` is the **library** `stableGroupId`. In 1:1,
`ChatParticipant.id == stableGroupId` — direct match.

In groups, diary keys are **member UUIDs**, not library basenames. Import must:

1. Match bundle `characterId` → library card / member **origin** `stableGroupId`.
2. Plant with `characterId = member.id` (the diary owner key Journal already uses).

Without this, group import would either no-op or plant under the wrong key.

---

## 12. File checklist (when implementing)

```
lib/services/chat/porch_memory_models.dart          NEW
lib/services/chat/porch_memory_mailbox.dart         NEW
lib/services/chat/porch_memory_import.dart          NEW
lib/services/chat/journal_store.dart                addCard extraMetadata
lib/services/storage/settings/memory_settings.dart  toggle
lib/services/chat/chat_service_session_load.dart    post-load hook
lib/services/chat/chat_service_group_*.dart         focus hook (if separate)
lib/ui/... journal chip (optional)
lib/ui/settings/... toggle
test/fixtures/llmerta_porch_bundle_v1.json          NEW
test/services/chat/porch_memory_*.dart              NEW
docs/Rawhide.md                                     user-facing note
docs/design/llmerta-porch-memories.md               this file
```

---

## 13. One-line for implementers

> Scan `{root}/KoboldManager/llmerta_porch_memories/*.json` (+ LLMerta fallback
> paths); on session open, if persona + character identity match, plant via
> `JournalStore.addCard` with `kind: llmerta_game` + `porchCardId` dedupe +
> `porchAckPending: true`, force the next AI reply with a Chance Time–register
> SCENE EVENT block built from those cards, clear the ack after that reply,
> then delete fully consumed bundles — never match on display names.

---

*Sketch for FPA consumer implementation. Producer contract is LLMerta’s
`PORCH_MEMORIES.md`; this doc is the FPA build plan grounded in Rawhide Journal.*
