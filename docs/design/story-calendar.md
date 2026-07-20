# The Story Calendar (design sketch)

**Status:** proposal — not yet implemented. Targets Rawhide.
**Depends on:** TimeService (`lib/services/chat/time_service.dart`), The Journal
(`docs/design/journal-memory.md`).

## 1. Motivation

Passage of time today is a *day tracker*: `dayCount` (an integer starting at
Day 1), a six-period `timeOfDay`, and a `startDayOfWeek` anchor that lets the
UI and prompt say "Tuesday (Day 5)". That gives scenes a rhythm, but no
*dates*. Characters can remember (via the Journal) how they felt about
something — they cannot remember **when** it happened, and "Day 47" is not how
anyone talks about a memory.

The Story Calendar gives every chat a real calendar — accurate months, days,
years (Gregorian, leap years and all) — so that:

- The scene has a real date ("It is morning on Tuesday, March 3rd, 2026").
- Journal memories are stamped with the story date they happened on, so a
  character remembers not only the feeling but the *when* ("that Friday on the
  pier, two weeks ago").
- The user gets an actual calendar surface: a month grid showing where the
  story is, with the days that hold memories marked on it.

## 2. Design principle: the calendar is a projection, not a second clock

**`dayCount` remains the single source of truth for elapsed story time.**
Nothing about the existing state machine changes: the deterministic 6-turn
clock, the LLM hold/new_day veto, manual nudge chevrons, the OOC time-skip
detector, AFK `advanceTimePeriods`, swipe/regen restore, 1:1↔group conversion
carry — all untouched.

We add exactly one new persisted scalar — a **story start date** — and derive
everything else:

```
storyDate(dayCount)   = storyStartDate + (dayCount − 1) days
narrativeWeekday      = weekday(storyDate)          // replaces the modulo-7 math
displayDate           = "Tuesday, March 3rd, 2026"  // via intl (already a dep)
```

Date arithmetic uses `DateTime.utc` (+ `Duration(days:)`) so DST can never
shift a story day, and Dart's calendar handles month lengths and leap years —
that is the "accurate months, days and years" requirement, for free.

This mirrors how `narrativeWeekday` already works (anchor + elapsed days) —
the weekday anchor simply grows into a full date anchor.

### What happens to `startDayOfWeek`

It becomes redundant: `weekday(storyStartDate)` for Day 1 gives the same
answer. Per the overlapping-features rule, the *logic* around
`startDayOfWeek` (the modulo-7 weekday computation in TimeService and
TimeInjection, `resolveStartDayOfWeek`, `ensureStartDayOfWeekAnchored`) is
retired in the same work and replaced by the date derivation. The DB *column*
stays (legacy rows, Character Card Forge reads, additive-only migrations) but
is no longer written with new meaning — it is populated on save purely as
`weekday(storyStartDate)` so any external reader keeps seeing a consistent
value.

## 3. Anchoring rules

- **Fresh chat:** `storyStartDate` = today's real-world date (UTC date of the
  local wall clock), same spirit as the current "anchor weekday to today"
  behavior. Day 1 is "today" unless the user says otherwise.
- **User override (the period-roleplay door):** the calendar UI lets the user
  set the story's start date to *anything* — 1887, 2187, last summer. Editing
  re-anchors the whole timeline; `dayCount` is untouched, so the current
  scene simply lands on `newStart + (dayCount − 1)`.
- **Legacy sessions (null `storyStartDate`):** resolved on first load the same
  way `resolveStartDayOfWeek` handles its legacy `0`: synthesize an anchor so
  the *currently displayed* weekday does not jump. Concretely: pick the most
  recent date such that Day `dayCount` falls on today, then — if the stored
  `startDayOfWeek` is set and disagrees — slide the anchor back 0–6 days so
  `weekday(anchor)` matches it. The visible "Tue · Day 5" stays identical
  across the upgrade; it just gains "Mar 3".

## 4. Persistence

One additive, nullable column on `Sessions`:

```dart
TextColumn get storyStartDate => text().nullable()(); // ISO-8601 'YYYY-MM-DD'
```

plus the usual load/seed/reset/capture wiring through the existing helpers
(`loadTimeScalars`, `seedFromV2OrExt`, `resetForFreshChat`,
`restoreTimeFromRealismState`, and the `realism_state` message snapshot so
conversion/swipe paths carry it).

> ⚠️ **Maintainer approval required before implementation.** `sessions` is
> written directly by Character Card Forge with raw SQL. The column is
> nullable-with-no-default-needed (safest additive shape), but a raw
> `INSERT` that does not name its columns would still break. This needs the
> explicit sign-off CLAUDE.md requires for `sessions` schema changes —
> including a check of how Card Forge writes its inserts.

Journal cards need **no migration**: `JournalMemories.metadata` is the JSON
pouch reserved for exactly this kind of additive growth.

## 5. Journal linkage — memories that know *when*

### Stamping (deterministic, no LLM)

Same philosophy as emotion stamping: the pass never asks the model for the
date. When `journal_maintenance` creates a card, it stamps the pouch:

```json
{ "storyDay": 5, "storyDate": "2026-03-03" }
```

`storyDay` is derived from the cited source messages: each message's
`realism_state` snapshot already carries `dayCount` at the moment it was
written, so the card's day is the modal/most-common `dayCount` among its
cited positions (fallback: the pass-time `dayCount`). `storyDate` is the
projection through the anchor, stored denormalized so a later anchor edit is
visible as such (the diary can show both "Day 5" — stable — and the date —
re-derived live from `storyDay` so anchor edits retro-date every memory
consistently; the stored string is only a fallback for exports).

Revisions keep the stamp (a memory reworked later still happened when it
happened). Cards written before this feature simply have no stamp — every
consumer treats it as optional (nullable-pouch floor).

### Injection

The journal injection builder gains a relative-time suffix per card, computed
from `storyDay` vs current `dayCount`:

```
- I still think about the pier. (felt: warm · Day 5, last Tuesday — 9 days ago)
```

Cheap, words-only (fits the prompt-state-injection doctrine), and gives the
model the material to say "remember two Fridays ago?" unprompted. Unstamped
cards render exactly as today.

### Diary UI

`journal_dialog` groups cards under date headers ("Day 5 — Tuesday, March
3rd") instead of a flat list; the sidebar peek shows the compact form ("Tue
Mar 3"). Unstamped cards group under "Before the calendar".

## 6. The calendar surface

**Desktop:** `TimeStrip` (the ONE scene-time widget) gains the date — the
"Tue · Day 5" chip becomes "Tue, Mar 3 · Day 5" — and tapping it opens the
new **calendar dialog**: a month grid (pure Dart/Drift-free, AppColors +
porch amber only) with

- the current story date highlighted (amber, `onChaosAccent` ink),
- a dot on every day that holds at least one journal memory for the focused
  participant (group: follows the same focused-participant convention as the
  journal panel; the data is one `cardsFor` read — cards are capped per
  owner, so grouping by `storyDay` in memory is trivial),
- tap a marked day → that day's memories (the diary dialog, pre-filtered),
- a gear → "story begins on…" date picker (the anchor override), plus the
  existing passage-of-time toggle relocated alongside for one coherent "time"
  settings spot,
- month/year chevrons for browsing; days before Day 1 and after "today" are
  dimmed (the story has no memories there yet).

This is a viewer/settings dialog, not a Create-X wizard — the step-indicator
rule does not apply.

**Web/mobile (`web_ui/`) — parity is part of the same body of work, not a
follow-up.** The facade (`chat_tools_facade.dart`) additively adds
`storyDate` + `storyStartDate` next to the existing
`timeOfDay`/`dayCount`/`weekday` fields; journal card payloads additively
carry the stamp. The web UI ships the same calendar (marked days, tap-to-see
memories, anchor editing), with distinct phone and desktop presentations per
the layout addendum (phone: full-screen sheet; desktop: dialog like the
native app).

## 7. Prompt changes

`TimeInjection` (words-only state block) becomes:

```
It is morning on Tuesday, March 3rd (day 5 of the story).
```

The year is appended only when the story is not anchored in the current
real-world year ("…March 3rd, 1887") — modern-day chats don't pay tokens for
a redundant year, period chats get the year that defines them.

**Optional extension (same work, small):** with real dates in hand, the OOC
time-skip detector's vocabulary can finally grow past "next day" — "a week
later" → `dayCount += 7`, "next month" → advance to the 1st of the following
month via the calendar. Kept behind the same `passageOfTimeEnabled` gate and
the same pending-metadata chip path ("Skipped to Mon, Mar 9").

## 8. Contracts honored

- **1:1 ↔ group parity:** time is chat-scoped (single per-chat scalars, not
  per-speaker) — the anchor rides the exact same load/save/capture sites, so
  parity holds by construction. No `_groupRealism` involvement.
- **One-shot vs normal path parity:** untouched — the clock tick and
  hold/new_day eval are unchanged; the date is a pure derivation of state
  both paths already maintain identically.
- **Journal invariants:** cards stay strictly session-scoped; stamping is
  deterministic metadata (no new LLM call, no new pass); no-RAG floor
  unaffected (dates never need embeddings).
- **Cross-platform:** pure `DateTime.utc` math + `intl` formatting — no
  paths, no processes, no natives.
- **Sync I/O:** the calendar dialog reads cards once on open (async), never
  in `build`.

## 9. Implementation shape (one PR, or two at most)

1. **Core:** `storyStartDate` on Sessions (approval first!), TimeService
   gains the anchor scalar + `storyDate`/`displayDate` getters, weekday
   derivation replaces the modulo-7 math (delete `resolveStartDayOfWeek` /
   `ensureStartDayOfWeekAnchored` in favor of the date-anchor equivalents),
   TimeInjection updated, capture/restore + all documented keep-in-sync
   reset sites.
2. **Journal stamping:** maintenance pass writes the pouch; injection builder
   adds the relative-time suffix; diary/panel render date groups.
3. **Calendar UI** (desktop dialog + TimeStrip entry) and **web parity**
   (facade fields + web calendar, phone + desktop layouts).
4. **Docs:** this file graduates from sketch to as-built; `docs/Rawhide.md`
   gets the user-facing bullet ("📅 A real calendar — your story has actual
   dates now, and characters remember *when* things happened").

Estimated new files: `chat/story_calendar.dart` (pure date math + formatting,
< 150 LOC), `ui/dialogs/story_calendar_dialog.dart`, web counterparts. No new
services, no new passes, no new toggles (the feature is always-on once the
anchor exists — it is a display/memory upgrade, not a new simulation).

## 10. Open questions for the maintainer

1. **Sessions column approval** (§4) — the hard gate. If Card Forge's raw
   inserts name their columns, the nullable column is safe; needs checking.
2. Default anchor = chat-creation day (recommended) — or should the picker be
   part of chat creation for new chats?
3. Should the marked-days dots in a *group* chat show the union of all
   members' memories or only the focused participant's (sketch says focused,
   matching the journal panel)?
4. Is the OOC week/month skip vocabulary (§7) wanted in the same PR, or
   parked?
