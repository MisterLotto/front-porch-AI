# Living Worlds — real worlds, weather biomes, and authored climates

**Status: PHASE 0 DONE · PHASE 1 MOSTLY DONE (medium batch) · PHASE 2/3 NOT STARTED**
(Last status audit: 2026-07-28 — medium tier landed. Branch: `Rawhide`.)
**Before push:** re-run weather / world_management widget goldens if they fail;
engine temperate path is intended bit-identical (regen only if a golden fails).

Rev.2 design retained below. Use **§ Implementation status** as the source of
truth for what landed vs what is still open; do not re-derive from the
narrative sections alone.

**Open decisions locked for this land:**
1. Phase 2 editor parity — defer (desktop authoring, use everywhere).
2. Migrated worlds: `inject_description = 0` by default. ✅ shipped in v40.
3. Multi-lorebook: `.fpworld` carries `lorebooks[]` (merged on import for now);
   single DB blob remains until a later cut. ✅ envelope ready; DB still one blob.

A three-phase arc that turns `worlds` from a lorebook folder into a portable
*place*, then gives places a climate, then lets users author their own.

---

## Implementation status (review snapshot)

Legend: **DONE** · **PARTIAL** · **NOT STARTED** · **OUT OF SCOPE (this land)**

Reviewers: read this table first, then sample the cited paths. Do not treat
design prose under §1–§3 as “implemented” unless it is marked DONE here.

### Phase 0 — Worlds become real places → **DONE**

| Item | Status | Where / notes |
|---|---|---|
| Schema v40 additive columns on `worlds` (`cover_image`, `format_version`, `source_id`, `linked_character_id`, `biome_id`, `biome_json`, `inject_description`) | **DONE** | `lib/database/database.dart` v39→v40 |
| `chat_worlds` join table + index | **DONE** | same |
| Forced pre-migration backup attempt | **DONE** | v40 block (non-fatal if backup path fails) |
| Name→UUID backfill for `groups.world_ids` + seed `chat_worlds` for existing group sessions | **DONE** | v40 backfill; unresolved refs logged/dropped |
| `linkedCharacterName` → `linked_character_id` backfill | **DONE** | v40 |
| Migrated worlds `inject_description = 0` | **DONE** | v40 one-shot UPDATE |
| UUID identity; rename does not cascade | **DONE** | `WorldRepository.renameWorld` |
| Chat-level attach (1:1 + group session); group `world_ids` = template only | **DONE** | `setChatWorldIds` / `chatWorldIds`; `applyGroupTemplateToChat` |
| Resolution by id (name fallback for legacy) | **DONE** | `resolveWorld`, `world_ref_resolver.dart` |
| World description injection (budget-capped, gated) | **DONE** | `prompt_injection/world_injection.dart` + `ChatService` wire |
| `.fpworld` encode/decode + ST bare-lorebook import | **DONE** | `fp_world_package.dart`; import Keep-both rename |
| Purge character-linked auto-import clones | **DONE** | Exports `.fpworld` to `worlds/recovered_character_lore_clones/` before hard delete (user-edited clone safety) |
| “From character” lore import (replace clone UX) | **DONE** | edit character / group lore / web |
| Place-only pickers (exclude character-linked leftovers) | **DONE** | `placeWorlds`; edit char/group/lorebook tab |
| Desktop Worlds authoring (climate picker + feel copy) | **DONE** | `world_management_page.dart` |
| Story Tools → **Places** panel (stay under Story Tools — no new sidebar leaf) | **DONE** | `chat_places_panel.dart` + `story_tools_group.dart` |
| Web Worlds page + chat Places section + facade/routes | **DONE** | `WorldsPage.tsx`, `ChatPlacesSection.tsx`, `world_facade` / `world_routes` |
| Cover image **column + model + .fpworld field** | **DONE** | schema / `World.coverImage` / envelope `cover` |
| Cover image **picker UI + grid thumbnails** | **DONE** | desktop dialog + `WorldPlaceCard`; web Worlds edit + `WorldCard`; `world_cover.dart` size-cap |
| Group card export dual `worldIds` (uuid) + `worldNames` (legacy) | **DONE** | `GroupCard.worldNames` + exporter resolves via `WorldRepository` |
| Cleanup counter rename + UUID/name resolution | **DONE** | `group_world_refs`; resolves names→ids when fixing |
| Migration fixture test (broken name refs, etc.) | **PARTIAL** | unit tests for resolver/package; no full fixture-DB migration test found |
| `.fpworld` round-trip + collision rename tests | **DONE** | `test/models/fp_world_package_test.dart`, world repo tests |

### Phase 1 — Built-in weather biomes → **MOSTLY DONE** (run-length deferred)

| Item | Status | Where / notes |
|---|---|---|
| `chat_biome_spans` table + insert/list | **DONE** | schema + `AppDatabase.insertBiomeSpan` / `getBiomeSpansForChat` |
| Built-in biomes (~7) + JSON round-trip + `validate()` + feel copy | **DONE** | `weather_biomes.dart` |
| `WeatherEngine.weatherFor(..., biome: / biomeAtDay:)` — null ≡ temperate | **DONE** | per-day climate for mid-chat spans; fixed path when `biomeAtDay` null |
| World default climate drives chat weather | **DONE** | schedule `worldDefault` from first attached place |
| Desktop/world editor climate picker with feel card | **DONE** | world management + web Worlds |
| `WorldRepository.setChatBiome` / span rows / schedule | **DONE** | + `biome_schedule.dart` |
| **Wire spans into weather walk** | **DONE** | `ChatService` hydrates schedule; all weather getters use `biomeAtDay` |
| Mid-chat climate picker UI (Places — no new leaf) | **DONE** | desktop `ChatPlacesPanel`; web `ChatPlacesSection` + `POST /api/chat/climate` |
| Foreshadow suppression on first day of a new span | **DONE** | `WeatherInjection.suppressForeshadow` |
| Run-length prose (“third straight day of rain”) | **NOT STARTED** | optional; deferred |
| Biome-scaled `diurnalAmplitude` in `weather_segments` | **DONE** | temperate 1.0 keeps °C goldens |
| WeatherChip uses ChatService (not temperate-only providers) | **DONE** | `weather_chip.dart` |
| Changeover property + foreshadow suppress tests | **DONE** | `test/services/chat/biome_schedule_test.dart` |
| Per-built-in golden sequences | **PARTIAL** | temperate goldens held; full per-biome pin optional |
| Web per-chat climate override | **DONE** | `/api/chat/climate` |

### Phase 2 — Authored climates (skins + stance) → **NOT STARTED**

| Item | Status | Notes |
|---|---|---|
| Stance-aware `dressCue` / conditionSkin behaviour | **NOT STARTED** | `ConditionSkin` + `conditionSkin` fields exist on model for forward schema; built-ins do not drive dressCue yet |
| Custom biome editor + preview harness | **NOT STARTED** | |
| `biomes` table + snapshot-on-attach | **NOT STARTED** | spans already store full JSON when used |

### Phase 3 — Stoop / sharing → **OUT OF SCOPE**

Sketch only. `.fpworld` envelope is intentionally Stoop-ready.

### Product decisions already applied (not re-open without maintainer)

- Places stay under **Story Tools** (no sidebar leaf creep).
- Objectives are their own accordion leaf, **collapsed by default**.
- Character-linked worlds purged; lore copy is **From character**, not Worlds clones.
- Multi-lorebook DB split deferred; envelope has `lorebooks[]`.

### Medium batch (landed 2026-07-28)

1. ~~Wire spans into ChatService~~ **DONE**
2. ~~Mid-chat climate UI (Places + web)~~ **DONE**
3. ~~Cover pick + thumbnails~~ **DONE**
4. ~~Desktop Worlds card polish (warm-porch)~~ **DONE** (`WorldPlaceCard`)
5. ~~`diurnalAmplitude` + foreshadow suppress~~ **DONE** (run-length still deferred)
6. **Regen goldens before push** if widget/engine goldens fail — temperate walk should stay bit-identical.

---

**Phase 0 is the prelude, by maintainer ruling.** It could technically be
decoupled — biomes attached to chats need worlds not at all — but worlds
carrying biomes is the destination, the worlds defects need fixing
regardless, and doing identity first avoids attaching climate data to
objects that cannot yet be safely referenced or shared.

**Target branch:** `Rawhide` (new feature per the branch workflow).

**On effort:** phases are marked by **risk**, not duration. Time estimates
in this repo's design docs are guesses with false precision; risk is the
information that actually changes decisions.

## Cross-cutting principles

- **Determinism is the contract.** The weather engine stores no weather; it
  recomputes story days 1..N from `(sessionSeed, dayCount, date)` on every
  turn. Anything that changes an input therefore rewrites *history*. Every
  decision below exists to keep already-written history immutable.
- **Default output must be bit-identical.** Existing chats must not observe
  a single changed day. See §2's acceptance gate for how this is enforced
  now that the naive version of that gate turned out to be unsatisfiable.
- **Snapshot, never reference.** Anything a chat's history depends on is
  *copied into* the chat at attach time. Edits, deletions and re-imports of
  the source must be incapable of reaching back in time. This rule now also
  governs world attachment (§1), not just biomes.
- **Remembered, not simulated.** The app has never modelled world state —
  no location, no travel, no inventory — and this work does not start. What
  weather *does* to the world is carried by the Journal, which already
  records what mattered and resurfaces it. Nothing here plants cards of its
  own; it gives the diary better material and lets its salience logic
  decide.
- **No `sessions` / `groups` column churn, and no table rebuilds.**
  Character Card Forge writes those tables directly via raw SQL. New state
  lives in new tables. Constraints on existing tables are *not* dropped —
  SQLite has no `ALTER TABLE DROP CONSTRAINT`, so dropping one means a
  create-copy-drop-rename rebuild of a live user database, which is not a
  risk this feature needs to take.
- **Riverpod codegen for new state**, domain logic in pure leaves under
  `lib/services/chat/`, per the maintainer directive (2026-07-21).
- **Web parity per phase**, listed explicitly in each phase.
- **Words-only prompt contract** (`prompt-state-injection.md`): temperatures
  stay UI-only; the model receives prose.

---

## 1. Phase 0 — Worlds become real places

**Implementation: DONE** (cover-image *UI* and dual group-card name export still open — see status table).

**Risk: HIGH.** Contains the only schema migration and the only step in the
arc that can lose user data.

### The problem, as it exists today

`Worlds` is `id, name (UNIQUE), description, lorebook (one JSON blob),
linkedCharacterName, updatedAt, deletedAt`. Verified defects:

1. **Name is the de-facto identity.** `groups.world_ids` stores *names*;
   `chat_service.dart:1480` passes them as `groupWorldNames` and line 1482
   resolves via `w.name == name`. The `id` column is unused for linking.
2. **Renaming hand-rolls a cascade.** `world_repository.dart:193` rewrites
   every group's list on rename because there is no real reference.
3. **Group cards already ship world names across machines.**
   `group_card_exporter.dart:173` / `group_card_importer.dart:317` carry
   `worldIds`. Importing a card that references "Glorb" binds to whatever
   local world shares that name — today that silently swaps lorebooks;
   after phase 1 it would silently swap the climate.
4. **`name` is UNIQUE**, so importing a world whose name already exists is a
   hard constraint failure rather than a merge.
5. **Worlds cannot attach to 1:1 chats at all** — only `groups` has
   `world_ids`.
6. **`description` never reaches the prompt.** A world is a library label,
   not a place the character inhabits.
7. **`linkedCharacterName` is a second name-based reference** with the same
   fragility as (1).

### Behavior

- A world becomes a first-class object with stable UUID identity, a
  description that reaches the story, an optional cover image, and
  single-file export/import.
- Worlds attach to **any** chat — 1:1 and group alike.
- Importing a world whose name collides **auto-renames** ("Glorb (2)").
  That is what Keep both means, and it lets `UNIQUE` stay in place.
- Renaming a world breaks nothing.

### Attachment model (audit finding — behaviour change, resolved)

Worlds attach to the **chat**. A group's world list becomes a **template
copied in at chat creation**, not a live reference.

Rev.1 keyed attachment on the chat and silently changed semantics: today
worlds hang off the *group definition*, so all chats of a group share them,
and a user with three chats would suddenly need to attach three times. The
template model preserves that behaviour (a new chat inherits the group's
worlds automatically), extends it to 1:1, and follows the same
snapshot-never-reference rule as biomes. Existing chats are backfilled from
their group's list at migration.

### Architecture

- **Migration (schemaVersion 39 → 40), strictly additive:**
  - `worlds`: add `cover_image` (nullable), `format_version` (int, default
    1), `source_id` (nullable — provenance for imports), `linked_character_id`
    (nullable, backfilled from `linkedCharacterName`). **`UNIQUE(name)`
    stays.**
  - New table `chat_worlds`: `id (uuid) · chat_id · world_id · sort_order`.
    `chat_id` is the session id — group chats get session rows too
    (`chat_service_group_entry.dart:285`), so this is one id space.
  - `groups.world_ids` becomes a **template**, still written, no longer the
    resolution path.
- **Forced backup before migration.** `backup_service.dart` snapshots the
  database first. Drift migrations are one-way; without this, "recoverable"
  is a wish.
- **Name→UUID backfill:** resolve each group's stored names against
  `worlds.name`, seed `chat_worlds` for that group's existing chats.
  Unresolvable entries are logged and dropped — they are already broken
  refs, counted today by `database_cleanup.dart` under `group_world_ids`.
- **Resolution moves to id.** `chat_service.dart:1480–1482` stops resolving
  by name; `groupWorldNames` is renamed and re-typed. The hand-rolled rename
  cascade at `world_repository.dart:193` is **deleted** — dead the moment
  references are real.
- **`linkedCharacterName` → `linked_character_id`**, backfilled by name
  once, then name-resolution deleted (`world_repository.dart:91`).
- **World description injection:** new `world_injection.dart` in the
  existing prompt-injection family, own toggle, budget-capped, placed with
  the other scene-setting blocks. This is what makes a world a *place*.
- **Export format** — `.fpworld`, a JSON envelope:
  `{formatVersion, id, name, description, cover, lorebook, biome (null until
  phase 1), meta:{author, createdAt, appVersion}}`. Cover is size-capped and
  encode/decode happens off the UI thread. A PNG-embedded variant matching
  the character-card ecosystem is a deliberate later option, not v1.
- **Import tolerance:** a bare SillyTavern / Chub / NovelAI world-info file
  imports as a degenerate world (lorebook only, no biome), reusing the
  existing lorebook import parsers (`lorebook-parity.md`).
- **Cleanup path** (`database_cleanup.dart`): `group_world_ids` becomes
  `chat_world_refs` over the join table.

### Parity

Desktop world manager and web UI both get: world list, attach/detach,
import, export, description editor. No deferral requested.

### Risks

- **The backfill is the dangerous step.** Mitigation: forced pre-migration
  backup (the only place original name-list `world_ids` survive — the live
  column is rewritten in place to UUIDs and is **not** a re-runnable
  snapshot); pure-function resolver with unit tests; unresolved refs logged
  and dropped. Data mutations are single-run with schema 39→40 (not a
  repair tool).
- **Legacy group cards keep the collision bug permanently.** Cards already
  in circulation carry names, and no migration reaches them. Importing an
  old card can still bind to the wrong local world. Phase 0 fixes cards
  written from now on; the exporter emits both `worldIds` (uuid) and
  `worldNames` (legacy) so older clients keep working, and the importer
  accepts names forever. This is a permanent, accepted limitation — stated
  here so it is not rediscovered as a bug.
- **Description injection costs tokens every turn.** Gated, capped, and off
  by default for worlds migrated from existing rows, whose descriptions were
  written as library labels rather than prose.

---

## 2. Phase 1 — Weather biomes, built-in

**Implementation: MOSTLY DONE** — engine + spans wired + mid-chat UI +
diurnal amplitude + foreshadow suppress. Run-length prose still open.

**Risk: MEDIUM.** No migration of existing data; two new tables; the danger
is silently perturbing already-written weather history.

### Behavior

A chat's weather can follow a climate other than the temperate default: a
rainforest coast drizzles and rarely storms, a desert is relentlessly clear
with a savage day–night swing, a continental winter actually buries you.
Seasons still come from the story calendar, so the same biome reads
differently in January and July. Users pick per chat; a world may carry one,
which becomes the default when attached.

### The determinism contract and its acceptance gate

- `WeatherEngine._seasonWeights` and `_seasonBaseTemp` become
  biome-parameterised. **`temperate` is not a new table — it is today's
  numbers, renamed.** `NULL` biome ⇒ temperate ⇒ byte-identical output.
- **Gate (corrected).** Rev.1 required "the pinned golden test passes
  unmodified," which is unsatisfiable: adding a biome parameter changes the
  call site, so the test file must change, and a gate that gets waived on
  day one protects nothing. Instead: **extract the expected sequence into
  its own named constant, and require that constant to be untouched.** The
  call may change; the expected values may not. Reviewers check one diff
  hunk.

### Changeover semantics (the mid-chat switch)

- New table `chat_biome_spans`:
  `id (uuid) · chat_id · effective_from_day (int) · biome_json (text) ·
   created_at`. No `sessions`/`groups` columns touched.
- `biome_json` is a **full snapshot**, not a pointer, and is **size-capped**
  so one fat shared biome cannot bloat every chat that attaches it.
- The walk consults which span covers day *d*. Span boundaries are
  **precomputed once per walk**, not looked up per day — otherwise the walk
  is O(days × spans).
- **Why history survives:** each day's RNG is seeded from
  `base ^ (d * 0x9E3779B9)` — keyed on the *day index*, not drawn from a
  running stream. Days before a changeover draw identical numbers against an
  identical table and reproduce byte-identically. No weather snapshotting is
  required.
- Spans take effect from the current `dayCount`, never scheduled forward,
  which would collide with `upcomingWeather`.
- **Foreshadowing may lie for exactly one day after a switch.** Yesterday's
  prediction was computed under the old biome. The engine documents
  "foreshadowing never lies," so this is not left implicit: suppress the
  foreshadow line on the first day of a new span.

### The biome model

~35 integers plus metadata: `weights` (4 seasons × 7 conditions), `baseTemp`
(4 seasons → `TempBand`), `diurnalAmplitude` (scales
`WeatherSegments._diurnalOffsetC`; desert's signature), and `conditionSkin`
(sparse per-condition overrides — see §3; the field exists from phase 1 so
the schema is right the first time, but only built-ins populate it).

| Biome | Signature |
|---|---|
| `temperate` | today's tables, the default |
| `rainforest` | overcast/drizzle dominant, storms rare, fog common, mild wet winters (snow → rain) |
| `desert` | overwhelmingly clear, near-zero precipitation, huge day–night swing |
| `continental` | real snow and hard cold in winter, hot storm-heavy summers |
| `tropical` | hot and humid year-round, seasons nearly flat, afternoon storms as daily rhythm, snow impossible |
| `mediterranean` | inverted precipitation seasonality — dry hot summers, wet mild winters |
| `highland` | cold-shifted, snow into spring, fog, fast changes |

Mediterranean and tropical are why a biome **replaces** the season mapping
rather than scaling it: an inversion and a collapse of seasonality
respectively, which no multiplier expresses.

### Architecture

- **New leaf** `lib/services/chat/weather_biomes.dart` (<350 LOC): const
  built-in matrices, the `Biome` value type, JSON round-trip, `validate()`
  shared by import and (phase 2) the editor.
- `weather_engine.dart` takes a biome; the walk and `_conditionFor` /
  `_tempFor` index the supplied tables. No other logic changes.
- `weather_segments.dart` gains biome-aware diurnal amplitude.
- **New leaf** `lib/services/chat/biome_schedule.dart` (<200 LOC): span
  storage, `biomeAt(day)`, precomputed boundaries, cached per-chat schedule.
- **Run length (small, folded in here).** The walk already produces runs via
  the persistence roll but never counts them, so four straight days of rain
  emit the identical prompt line four times and nobody gets cabin fever.
  Track the run during the walk — derived, unstored, prefix-stable — and let
  prose escalate ("a third straight day of rain"). Count *anchor-condition*
  days; a changeover resets the count. This is also the cheap answer to the
  recurring accumulation request (§3). Not load-bearing: cut it if it
  threatens the phase.
- **Hot-path discipline:** the schedule loads once at session load with the
  other hydrated scalars (`chat_service_session_load.dart`) and invalidates
  on change. No DB read inside the walk, which runs once per turn per
  injection plus once per facade read plus the Riverpod UI provider.

### Settings & parity

Per-chat picker in the scene-time sidebar beside the weather toggle, plus
the world editor's default. **Desktop and web both** — a user-visible
configuration surface, non-negotiable.

### Risks

- **Feel, not correctness, is the hard part.** A mechanically valid but
  boring biome is the likely failure. Mitigation: build the phase-2 preview
  harness *here*, as a test utility, and tune the built-ins with it.
- **Zero-summed weights divide by zero** in `_conditionFor`
  (`rng.next() % total`). The engine gets a defensive fallback even for
  built-ins; validation is not left solely to the authoring layer.
- **Same-millisecond session-id collision** (pre-existing): session ids are
  `DateTime.now().millisecondsSinceEpoch.toString()`, not UUIDs, so two
  chats created in the same millisecond share an id — and now share rows in
  both new tables. Rare manually, plausible under scripted import. *Checked
  and dismissed:* that id is also the weather seed, but simulating 200
  consecutive-millisecond seeds shows day-one weather matching the intended
  distribution, so there is no seed correlation — only true collision.

---

## 3. Phase 2 — Authored climates: skins and stance

**Implementation: NOT STARTED** (model fields for `conditionSkin` / stance
exist for forward compatibility only).

**Risk: MEDIUM-LOW technically, HIGH on scope.** No migration; the danger is
that this is the fun part and gets built regardless of whether phase 1
landed. See §5.

### Why skins need stance — the failure this prevents

Renaming `rain` to "acid rain" is cosmetic unless meaning travels with the
word. Everything a character knows arrives through the prompt, and
`WeatherSegments.dressCue` is keyed on **temperature only** — it never
inspects the condition. A renamed label composes to:

> *Outside it is light-layers weather. Acid rain is falling.*

The character puts on a cardigan and walks into it. Blood rain gets danced
in; ashfall gets picnicked under. Not an edge case — the current code with a
renamed label.

### The model

A `conditionSkin` entry is **label + emoji + stance (+ optional flavour)**:

- `stance` ∈ `pleasant | ordinary | harsh | dangerous | deadly`
- **Stance is mandatory whenever a condition is renamed.** Validation
  rejects a rename without one, making the dangerous failure structurally
  impossible rather than something authors must remember.
- Stance drives **code-owned** behavioural text — never author prose — so a
  minimal-effort skin still behaves: `dangerous` ⇒ "being caught out in this
  is genuinely harmful; characters shelter, and going outside is a
  deliberate risk." Authors may add one flavour line on top.
- **`dressCue` becomes stance-aware**, since it is the surface that fails
  today. At `dangerous` and above the cover instruction overrides the
  temperature phrasing entirely.
- Built-ins carry stance too (ordinary rain `ordinary`, full storm `harsh`)
  — one field, one code path, no branch between "real" and "user" biomes.

### The payoff

Stance composes with the existing prophetic foreshadowing, which is exact
because tomorrow is already decided. Ordinary rain gives "smells like rain
tomorrow." Deadly rain gives a *deadline*: "the air tastes of metal — the
burn rain comes by evening, we need to be under cover before then."
Characters prepare, argue, and run out of time. Dangerous weather becomes
narrative structure rather than scenery, from machinery that already exists.

### The boundary (hold this line)

**Weather may have duration and intensity. Its consequences are remembered,
not simulated.**

A skin may change what weather is **called**, **how long it has been going
on**, and **how dangerous it is**. It may not introduce stored world state.

The recurring request is accumulation: ash piling up until the pass closes,
drought dropping the river. Accumulation *itself* is fine and cheap — the
walk already carries state day to day, and §2's run length is exactly that.
What breaks is the feedback loop, and it breaks either way you resolve it:

- **If depth is deterministic**, the engine owns it and the story cannot
  touch it. A character spends an afternoon clearing the road and next turn
  the prompt still says buried, because the walk recomputed from the seed and
  knows nothing happened. That contradicts fiction the user just created —
  worse than not having the feature.
- **If the story can change depth**, it is no longer derivable, so it must be
  stored and evolved per chat. Save/load, swipe, regenerate, group re-entry
  and the web facade stop agreeing for free and start needing to agree on
  mutable state — the entire property that makes this subsystem reliable,
  traded for one flourish.

Underneath both: **nothing enforces world facts.** Stance works because it is
a *behavioural* instruction, which models handle well. "The road is blocked"
is a constraint on future events, and with no location or travel model the
user types "let's drive to town" and the model either complies (fiction
broken) or refuses for no visible reason. It would promise a simulation the
app cannot back.

The consequence lives in the Journal — the existing mechanism for facts that
persist and resurface, and the only path where the character who clears the
road has changed something. This is a *stance, not a build*: weather plants
no cards of its own. Auto-planting would fill the diary with rainy Tuesdays.

Hard no: **user-authored rules.** Letting a shared world define its own
accumulation and consequence logic stops being a data format and becomes a
scripting language, and since world text reaches the prompt, author-written
rules escalate an accepted risk (imported text the model reads, as character
cards do today) into something closer to imported behaviour. Note the
sharper vector: stance flavour text sits *adjacent to a behavioural
directive* in the prompt, so it warrants tighter length and content limits
than lorebook prose.

### Authoring

- Editor with live **preview-as-validation**: run the candidate across
  **many seeds × many days** (one 500-day run is a single sample path, not a
  distribution) and report what actually came out — *"you asked for snowy
  summers, but your summer temperatures are warm, so every draw demoted to
  rain."* The preview is simultaneously the test, the tuning tool and the
  explanation.
- Hard validation: every season's weights sum > 0; ≥2 non-zero conditions
  per season; stance present on every rename; label and flavour length caps.
- Custom biomes live in a `biomes` table (uuid identity) and are
  **snapshotted into `chat_biome_spans` on attach**, so editing a biome
  never disturbs a chat already using it.

### Risks

- **Golden pinning is impossible for user data.** Pin the *engine* against a
  fixture biome; validate user biomes against invariants; the preview
  harness covers the rest.
- **Parity.** Using custom biomes must be desktop *and* web. The
  weight-matrix **editor** is a real desktop surface and an awkward phone
  one — see §6, needs an explicit ruling. Precedent: custom Piper voice
  import, authoring desktop-only, consumption everywhere (approved
  2026-07-25).

---

## 4. Phase 3 — Sharing (sketch only, not scoped)

**Implementation: OUT OF SCOPE.**

Worlds are portable after phase 0, so Stoop distribution is a backend
project rather than an extension of this work: a third content type, its own
moderation surface for names and descriptions, and the never-break-old-
clients API discipline. Explicitly **out of scope**; noted so the `.fpworld`
envelope is designed Stoop-ready rather than retrofitted.

## 5. How we would know this worked

Rev.1 had no success criteria, which meant phase 2 — the fun part — would be
built regardless of whether phase 1 landed. Gates:

- **Phase 0** justifies itself: the group-card collision bug is real and
  already causing silent wrong behaviour. Success = the bug is gone for new
  cards, no user reports data loss from the migration, worlds import/export
  round-trips.
- **Phase 1 → 2 gate:** do people actually change biome away from the
  default? If the overwhelming majority of chats stay temperate, the demand
  signal for *authoring* climates is absent, and phase 2 should not be built
  on the strength of it being interesting to build.
- **Phase 2 → 3 gate:** are users making biomes that others would want? If
  local custom biomes see little use, sharing infrastructure has nothing to
  carry.

## 6. Open decisions (maintainer)

1. **Phase 2 editor parity** — desktop-only authoring with use/download
   everywhere (Piper precedent), or a full web editor?
   → **Ruled: defer** (desktop authoring, consume everywhere).
2. **World description injection default** — on or off for worlds migrated
   from existing rows? (Recommendation: off; those descriptions were written
   as library labels, not prose.)
   → **Ruled: off** — shipped in v40 (`inject_description = 0` for migrated rows).
3. **Multiple lorebooks per world** — today it is one JSON blob. Real worlds
   may want several. It changes the `.fpworld` envelope, so it is cheaper to
   decide before v1 ships than after.
   → **Ruled for v1:** envelope has `lorebooks[]` (merge on import); single DB
   blob until a later cut.

**Ruled (2026-07-28):** phase 0 stays the prelude; effort estimates removed
in favour of risk markers; world attachment uses the chat-level +
group-template model (§1).

**Also applied in product (2026-07):** Places stay under Story Tools; no new
sidebar leaf for Places; Objectives leaf separate and collapsed by default.

## 7. Test strategy

Status of each gate (audit 2026-07-28):

- The pinned expected sequence constant is **untouched** — phase 1's
  acceptance gate. → **HOLDING** for temperate/null path; re-check after any
  engine change. **Regen goldens before push** if span/diurnal/run-length land.
- New pinned goldens per built-in biome (fixture seed, fixture dates). → **NOT DONE**
- Changeover property test: for any span boundary *k*, days `1..k-1`
  recompute byte-identically to the pre-switch run. → **NOT DONE** (spans unused)
- Migration test over a fixture DB with realistic broken data: name refs →
  uuid refs, group templates → `chat_worlds`, broken refs dropped and
  counted, `linkedCharacterName` → id. → **PARTIAL** (resolver unit tests only)
- Round-trip test: world → `.fpworld` → import → structurally identical,
  including a name collision auto-renaming to "Glorb (2)". → **DONE** (package/repo tests)
- Validation tests: zero-sum weights rejected; rename-without-stance
  rejected; `dressCue` at `dangerous` overrides temperature phrasing. → **PARTIAL**
  (weight validation exists; stance/dressCue is phase 2)
- Distribution envelopes per biome across many seeds (desert never snows;
  tropical never reaches the cold band; rainforest storm share under its
  ceiling). → **NOT DONE** / light coverage only
- Foreshadow suppression on the first day of a new span. → **NOT DONE**
