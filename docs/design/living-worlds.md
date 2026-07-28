# Living Worlds — real worlds, weather biomes, and authored climates

**Status: DRAFT (2026-07-28) — design only, no code written. Awaiting
maintainer sign-off on the open decisions in §5.**

> **⚠️ KNOWN DEFECTS — do not implement from this revision.** A hostile
> self-audit (2026-07-28) found two assertions below that are **false**, plus
> gaps listed here. Pending a single coherent revision once §5 and the
> flagged judgment calls are ruled on.
>
> 1. **"Additive only" is wrong** (principles + §1). Dropping `UNIQUE` on
>    `worlds.name` forces a full SQLite table rebuild — there is no
>    `ALTER TABLE DROP CONSTRAINT`. Intended fix: *keep* the constraint and
>    auto-rename on import collision ("Glorb (2)"), which is what Keep both
>    means anyway and removes the rebuild entirely.
> 2. **§2's acceptance gate is unsatisfiable.** "The pinned golden test
>    passes unmodified" cannot hold once `weatherFor` takes a biome
>    parameter — the call site must change. Intended fix: extract the
>    expected sequence to its own constant and require *that* to be
>    untouched.
> 3. **§1 changes world-attachment semantics without saying so.** Worlds
>    attach to the *group definition* today, so every chat of that group
>    shares them; `chat_worlds` keys on the *chat*. Needs a group-level
>    default plus session-level override, or explicit acceptance.
> 4. **`linkedCharacterName`** is listed as a defect in §1 and then never
>    addressed in the architecture.
> 5. **Legacy group cards keep the name-collision bug permanently** — cards
>    already in circulation carry names; phase 0 fixes new cards only.
> 6. **No rollback mechanism.** The 39→40 migration must force a
>    `backup_service` snapshot first; Drift migrations are one-way.
> 7. **Unspecified:** `biomeAt(day)` lookup cost inside the O(days) walk;
>    a size cap on the snapshot JSON; the preview harness needs N seeds, not
>    one 500-day sample path.
> 8. **Foreshadowing can lie for one day after a biome switch**, violating
>    the engine's stated "foreshadowing never lies" property.
> 9. **Effort estimates run ~2× optimistic**, worst in phase 0 — the phase
>    that contains the migration.
> 10. **Phase 0 is a prerequisite for phase 2, not for phase 1.** Biomes
>     attached to chats need worlds not at all. Ordering is still sound, but
>     phase 0 should ship and be validated as its own release justified by
>     its own bug, not as a prelude.
>
> Checked and **dismissed**: session ids are millisecond timestamps rather
> than UUIDs, and that string is the weather seed — but simulating 200
> consecutive-millisecond seeds shows day-one weather matching the intended
> distribution, so there is no seed correlation. Only true same-millisecond
> *collision* remains (pre-existing; this plan adds two tables keyed on it).

A three-phase arc that turns `worlds` from a lorebook folder into a portable
*place*, then gives places a climate, then lets users author their own.

The ordering is not cosmetic. Phase 1 (biomes) attaches climate data to
worlds, and phase 2 lets users author and share that data. Both collapse if
worlds are not first made into stable, self-contained, portable objects —
see §1 for the specific ways today's worlds would corrupt data the moment
weather rides along.

**Target branch:** `Rawhide` (new feature per the branch workflow).

## Cross-cutting principles

- **Determinism is the contract.** The weather engine stores no weather; it
  recomputes story days 1..N from `(sessionSeed, dayCount, date)` on every
  turn. Anything that changes an input therefore rewrites *history*. Every
  design decision below exists to keep already-written history immutable.
- **Default must be bit-identical.** The pinned golden sequence
  (`test/services/chat/weather_engine_test.dart:66`) must keep passing
  **unchanged** through all three phases. If it moves, we broke every
  existing chat's past. It is the regression oracle for this whole project.
- **Snapshot, never reference.** Anything a chat's history depends on is
  copied into the chat at attach time, never pointed at. Edits, deletions,
  and re-imports of the source must be incapable of reaching back in time.
- **Remembered, not simulated.** The app has never modelled world state —
  no location, no travel, no inventory — and this work does not start. What
  the weather *does* to the world is carried by the Journal, which already
  records what mattered and resurfaces it. Nothing here plants cards of its
  own; it just gives the diary better material to notice.
- **No `sessions` / `groups` column churn.** Character Card Forge writes
  those tables directly via raw SQL. New state lives in new tables keyed by
  chat id, so the external-writer contract is untouched.
- **Riverpod codegen for new state**, domain logic in pure leaves under
  `lib/services/chat/`, per the maintainer directive (2026-07-21).
- **Web parity per phase**, listed explicitly in each phase's Parity section.
- **Words-only prompt contract** (`prompt-state-injection.md`) holds
  throughout: temperatures stay UI-only; the model receives prose.

---

## 1. Phase 0 — Worlds become real places (Effort: M, ~3–5 days)

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
   local world happens to share that name — today that silently swaps
   lorebooks; after phase 1 it would silently swap the climate.
4. **`name` is UNIQUE**, so importing a world whose name already exists is a
   hard constraint failure, not a merge.
5. **Worlds cannot attach to 1:1 chats at all** — only `groups` has
   `world_ids`. Biomes on worlds would ship to group chats only.
6. **`description` never reaches the prompt.** A world is a library label,
   not a place the character inhabits.
7. **`linkedCharacterName` is another name-based reference** with the same
   fragility.

### Behavior

- A world becomes a first-class object with a stable UUID identity, a
  description that actually reaches the story, an optional cover image, and
  a single-file export/import.
- Worlds attach to **any** chat — 1:1 sessions and groups alike.
- Importing a world with a colliding name offers **Keep both / Replace**,
  reusing the pattern already shipped for same-name character imports.
- Renaming a world breaks nothing.

### Architecture

- **Migration (schemaVersion 39 → 40), additive only:**
  - `worlds`: drop the UNIQUE constraint on `name`; add
    `cover_image` (nullable), `format_version` (int, default 1),
    `source_id` (nullable — provenance for imported worlds).
  - New table `chat_worlds`: `id (uuid) · chat_id · world_id · sort_order`.
    One join table serving 1:1 and groups, replacing the JSON name array.
  - `groups.world_ids` is **migrated, then left in place and unread** for
    one release so Forge and any stale readers do not trip. Removal is a
    follow-up once the fleet ages out.
- **Name→UUID backfill:** on migration, resolve each group's stored names
  against `worlds.name`; unresolvable entries are logged and dropped (they
  are already broken refs — `database_cleanup.dart` counts them today under
  `group_world_ids`).
- **Resolution moves to id.** `chat_service.dart:1480–1482` stops resolving
  by name. The `groupWorldNames` parameter is renamed and re-typed. The
  hand-rolled rename cascade in `world_repository.dart:193` is **deleted** —
  it becomes dead code the moment references are real.
- **World description injection:** a new small block in the existing
  prompt-injection family (`world_injection.dart`), gated by its own toggle,
  budget-capped, placed with the other scene-setting blocks. This is what
  makes a world a *place* rather than a folder.
- **Export format** — `.fpworld`, a JSON envelope:
  `{formatVersion, id, name, description, cover (base64|null), lorebook,
    biome (null until phase 1), meta:{author, createdAt, appVersion}}`.
  JSON first; a PNG-embedded variant (matching the character-card
  ecosystem's shareability) is a deliberate later option, not v1.
- **Import tolerance:** a bare SillyTavern / Chub / NovelAI world-info file
  imports as a degenerate world — lorebook present, no biome, no
  description. Reuses the existing lorebook import wizard's parsers
  (`lorebook-parity.md`).
- **Cleanup path** (`database_cleanup.dart`) updated: the
  `group_world_ids` category becomes `chat_world_refs` over the join table.

### Parity

Desktop world manager and the web UI both get: world list, attach/detach to
a chat, import, export, and the description editor. No deferral requested.

### Risks

- **The backfill is the dangerous step.** It rewrites references for every
  existing group. Mitigation: pure-function resolver with its own unit
  tests over a fixture DB, dry-run count logged before write, and the legacy
  column preserved so a bad backfill is recoverable rather than terminal.
- **Group card compatibility.** Cards in the wild carry names. The importer
  must keep accepting names (resolve name → local world → id) forever, while
  the exporter starts writing both `worldIds` (uuid) and `worldNames`
  (legacy) so older clients keep working. Additive-only, same discipline as
  the Stoop API contract.
- **Description injection costs tokens** on every turn. Gated, capped, and
  off by default for worlds imported without one.

---

## 2. Phase 1 — Weather biomes, built-in (Effort: M, ~3–4 days)

### Behavior

A chat's weather can follow a climate other than the current temperate
default: a rainforest coast drizzles and rarely storms, a desert is
relentlessly clear with a savage day–night swing, a continental winter
actually buries you. Seasons still come from the story calendar, so the same
biome reads differently in January and July.

Users pick a biome per chat. A world may carry one, which becomes the
default when that world is attached.

### The determinism contract

- `WeatherEngine._seasonWeights` and `_seasonBaseTemp` become
  biome-parameterised. **`temperate` is not a new table — it is today's
  numbers, renamed.** `NULL` biome ⇒ temperate ⇒ byte-identical output.
- The pinned golden test must pass **unmodified**. That is the acceptance
  criterion for the entire phase.

### Changeover semantics (the mid-chat switch)

Switching biome mid-chat must not rewrite that chat's past.

- New table `chat_biome_spans`:
  `id (uuid) · chat_id · effective_from_day (int) · biome_json (text) ·
   created_at`. No `sessions`/`groups` columns touched.
- `biome_json` is a **full snapshot** of the definition, not a pointer.
  Editing, deleting, or re-importing the source world can never reach a
  chat's history.
- The walk consults "which span covers day *d*" as it steps.
- **Why this is nearly free:** each day's RNG is seeded from
  `base ^ (d * 0x9E3779B9)` — keyed on the *day index*, not drawn from a
  running stream. Days before a changeover therefore draw identical numbers
  against an identical table and reproduce byte-identically. History is
  immune by construction; no weather snapshotting is required.
- Spans always take effect from the current `dayCount` — never scheduled
  into the future, which would collide with `upcomingWeather` foreshadowing.

### The biome model

A biome is ~35 integers plus metadata:

- `weights`: 4 seasons × 7 conditions
- `baseTemp`: 4 seasons → `TempBand` index
- `diurnalAmplitude`: scales `WeatherSegments._diurnalOffsetC` (desert's
  signature; the offsets are currently fixed constants)
- `conditionSkin`: sparse per-condition overrides — **see §3**, the field
  exists from phase 1 so the schema is right the first time, but only
  built-ins populate it until phase 2.

Built-in set (seven, deliberately small — each must be identifiable
blindfolded):

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
rather than scaling it: their personalities are an inversion and a collapse
of seasonality respectively, which no multiplier expresses.

### Architecture

- **New leaf** `lib/services/chat/weather_biomes.dart` (<350 LOC): the
  const built-in matrices, the `Biome` value type, JSON round-trip, and a
  `validate()` used by both import and (phase 2) the editor.
- `weather_engine.dart` takes a biome parameter; the walk and
  `_conditionFor`/`_tempFor` index the supplied tables. No other logic
  changes.
- `weather_segments.dart` gains biome-aware diurnal amplitude.
- **Run length (small, folded in here).** The walk already produces runs of
  the same condition via the persistence roll; it just never counts them, so
  four straight days of rain emit the identical prompt line four times and
  nobody ever gets cabin fever. Track the current run during the walk —
  derived, unstored, prefix-stable — and let the prose escalate ("a third
  straight day of rain"). Rules: count *anchor-condition* days (a rain day
  with two dry segments still counts), and a biome changeover resets the
  count. This is also the cheap answer to the recurring "can ash accumulate
  and block the road" request — see §3's boundary. Not load-bearing: if it
  threatens the phase, cut it.
- **New leaf** `lib/services/chat/biome_schedule.dart` (<200 LOC): span
  storage, `biomeAt(day)`, and the cached per-chat schedule.
- **Hot-path discipline:** the schedule loads **once** at session load
  alongside the other hydrated scalars
  (`chat_service_session_load.dart:_hydrateSessionScalars`) and invalidates
  on change. No DB read inside the walk, which runs once per turn per
  injection plus once per facade read plus the Riverpod UI provider.

### Settings & parity

Per-chat biome picker in the scene-time sidebar section beside the existing
weather toggle, plus the world editor's default. **Desktop and web both**,
non-negotiable — it is a user-visible configuration surface.

### Risks

- **Feel, not correctness, is the hard part.** Seven hand-tuned matrices
  need play-testing; a biome that is mechanically valid but boring is the
  likely failure. Mitigation: the phase-2 preview harness (500 simulated
  days → distribution report) gets built here, as a test utility, and used
  to tune the built-ins before they ship.
- **Zero-summed weights divide by zero** in `_conditionFor`
  (`rng.next() % total`). Even for built-ins, the engine gets a defensive
  fallback; validation is not left solely to the authoring layer.

---

## 3. Phase 2 — Authored climates: skins and stance (Effort: M–L, ~5–7 days)

### Why skins need stance — the failure this prevents

Letting a biome rename `rain` to "acid rain" is cosmetic unless meaning
travels with the word. Everything a character knows arrives through the
prompt, and today `WeatherSegments.dressCue` is keyed on **temperature
only** — it never inspects the condition. A renamed label therefore composes
to:

> *Outside it is light-layers weather. Acid rain is falling.*

The character puts on a cardigan and goes for a walk in it. Blood rain gets
danced in; ashfall gets picnicked under. This is not an edge case — it is
the current code with a renamed label.

### The model

A `conditionSkin` entry is **label + emoji + stance (+ optional flavour)**:

- `stance` ∈ `pleasant | ordinary | harsh | dangerous | deadly`
- **Stance is mandatory whenever a condition is renamed.** Validation
  rejects a rename without one, making the dangerous failure structurally
  impossible rather than a thing authors must remember.
- Stance drives **code-owned** behavioural text in the injection — never
  author prose — so a minimal-effort skin still produces correct behaviour:
  `dangerous` ⇒ "being caught out in this is genuinely harmful; characters
  shelter, and going outside is a deliberate risk." Authors may add one
  flavour line ("burns exposed skin") on top.
- **`dressCue` becomes stance-aware**, since it is the exact surface that
  fails today. At `dangerous` and above, the cover instruction overrides the
  temperature phrasing entirely.
- Built-ins carry stance too (ordinary rain `ordinary`, full storm `harsh`)
  — one field, one code path, no branch between "real" and "user" biomes.

### The payoff

Stance composes with the existing prophetic foreshadowing
(`WeatherEngine.foreshadow`, already exact because tomorrow is decided
today). Ordinary rain gives "smells like rain tomorrow." Deadly rain gives a
*deadline*: "the air tastes of metal — the burn rain comes by evening, we
need to be under cover before then." Characters can prepare, argue, and run
out of time. Dangerous weather becomes narrative structure rather than
scenery, from machinery that already exists.

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
  the prompt still says it is buried, because the walk recomputed from the
  seed and knows nothing happened. That contradicts fiction the user just
  created — worse than not having the feature.
- **If the story can change depth**, it is no longer derivable, so it must be
  stored and evolved per chat. Save/load, swipe, regenerate, group re-entry
  and the web facade stop agreeing for free and start needing to agree on
  mutable state. That is the entire property that makes this subsystem
  reliable, traded for one narrative flourish.

Underneath both: **nothing enforces world facts.** Stance works because it is
a *behavioural* instruction, which is what models are good at. "The road is
blocked" is a constraint on future events, and with no location or travel
model, the user types "let's drive to town" and the model either complies
(fiction broken) or refuses for no visible reason. It would promise a
simulation the app cannot back.

Where the consequence actually lives is the Journal — the existing mechanism
for facts that persist and resurface, and the only path where the character
who clears the road has actually changed something. Note this is a *stance*,
not a build: weather does not plant its own cards. It just gives the diary
better material, and the diary's own salience logic decides. Auto-planting
weather cards would fill the diary with rainy Tuesdays nobody cares about.

Hard no, for the avoidance of doubt: **user-authored rules.** Letting a
shared world define its own accumulation and consequence logic stops being a
data format and becomes a scripting language, and since world text reaches
the prompt, author-written rules escalate an accepted risk (imported text the
model reads, as character cards do today) into something closer to imported
behaviour.

### Authoring

- Editor with live **preview-as-validation**: run the candidate across ~500
  simulated days and report the actual distribution back —
  *"you asked for snowy summers, but your summer temperatures are warm, so
  every draw demoted to rain."* The preview is simultaneously the test, the
  tuning tool, and the explanation.
- Hard validation: every season's weights sum > 0; ≥2 non-zero conditions
  per season; stance present on every rename; label/flavour length caps.
- Custom biomes live in a `biomes` table (uuid identity), and are
  **snapshotted into `chat_biome_spans` on attach** — so editing a biome
  never disturbs a chat already using it.

### Risks

- **Golden pinning is impossible for user data.** Mitigation: pin the
  *engine* against a fixture biome; validate user biomes against invariants;
  the preview harness covers the rest.
- **Parity.** Picking and using custom biomes must be desktop *and* web. The
  weight-matrix **editor** is a real desktop surface and an awkward phone
  one — see §5, this needs an explicit maintainer ruling. Precedent exists
  (custom Piper voice import: authoring desktop-only, consumption
  everywhere, maintainer-approved 2026-07-25).

---

## 4. Phase 3 — Sharing (sketch only, not scoped)

Worlds are already portable after phase 0, so Stoop distribution is a
backend project, not an extension of this work: a third content type, its
own moderation surface for names and descriptions, and the never-break-old-
clients API discipline. Explicitly **out of scope** here; noted so the
`.fpworld` envelope is designed to be Stoop-ready rather than retrofitted.

## 5. Open decisions (maintainer)

1. **Phase 2 editor parity** — desktop-only authoring with
   use/download everywhere (Piper precedent), or full web editor?
2. **World description injection default** — on or off for existing worlds
   after migration? (Recommendation: off; opt-in per world, since existing
   descriptions were written as library labels, not prose.)
3. **`groups.world_ids` retirement** — one release of dormancy as proposed,
   or longer given Forge writes that table?
4. **Multiple lorebooks per world** — today it is one JSON blob. Real worlds
   may want several. Deferred unless wanted now; it changes the `.fpworld`
   envelope, so it is cheaper to decide before v1 ships.

## 6. Test strategy

- The existing pinned golden sequence passes **unmodified** — phase 1's
  acceptance gate.
- New pinned goldens per built-in biome (fixture seed, fixture dates).
- Changeover property test: for any span boundary *k*, days `1..k-1`
  recompute byte-identically to the pre-switch run.
- Backfill test over a fixture DB: name refs → uuid refs, broken refs
  dropped and counted.
- Round-trip test: world → `.fpworld` → import → structurally identical,
  including a name collision resolving via Keep both.
- Validation tests: zero-sum weights rejected; rename-without-stance
  rejected; `dressCue` at `dangerous` overrides the temperature phrasing.
- Distribution envelopes per biome (desert never snows; tropical never
  reaches the cold band; rainforest storm share stays under its ceiling).
