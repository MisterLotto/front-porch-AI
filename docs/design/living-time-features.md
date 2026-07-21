# The "Living Time" Release — Feature Scoping

**Status: SCOPED (2026-07-21) — awaiting maintainer priority call.**
Five features that make characters feel like they live in time, scoped against
the actual Rawhide codebase. Release theme for the update dialog: *"Your
character lives in time — they dream, they notice your absence, weather rolls
through their days, and your story together becomes a book."*

**Cross-cutting design wins (deliberate, all five):**
- **Zero schema changes.** Weather is recomputed (pure function of existing
  state), milestones ride the existing `journal_cards` table, absence is
  computed from existing timestamps, dreams are ordinary messages + journal
  cards, novella export adds only additive JSON fields to `StoryProject`.
- **No new native/sidecar anything.** Every LLM call goes through
  `LlmEvalEngine` (think-strip, retry/cancel, local-model floor).
- **1:1/group parity by construction** — each feature's state is either
  per-chat-shared (weather, absence) or keyed the same way the Journal already
  keys per-character state (`ChatParticipant.id`).
- **Web parity planned per feature** (facade + web_ui surface listed in each).

---

## 1. Dreams 💤 (Effort: S–M, ~2–3 days)

When the story clock crosses a night (or an AFK nap fires), the character
dreams — seeded from what the Journal says actually mattered.

### Behavior
- On the first turn after `TimeService.dayCount` increments past a night
  period (or after an AFK sleep/nap snapshot), a short first-person dream
  (2–4 sentences) arrives as a special narration before the morning reply:
  hazy, associative, referencing real memories — never new canon facts.
- The dream is also planted as a journal card (`metadata.kind = 'dream'`,
  low heat, unpinned) so it appears in the diary and can resurface later.

### Architecture
- **New leaf:** `lib/services/chat/dream_service.dart` (<300 LOC) — pending
  flag, prompt builder, forgiving parse (plain text; sanity/length floor —
  a garbage local-model output silently skips the dream), card plant via
  `JournalStore`.
- **Seed inputs (all existing):** top-N hottest cards via
  `JournalPhysics.cooledHeat` ordering; active fixation
  (`RelationshipService`); current `_characterEmotion` scalar; the "Where we
  are" recap.
- **Trigger wiring:** day-rollover detection in the existing
  `TimeService.advanceTimePeriods` callback path + the AFK activity hook in
  `chat_service_idle_autonomous.dart` (which already advances time and has
  the `_pendingIdleCue` mechanism — dreams ride an identical
  `_pendingDreamCue`).
- **Rendering:** reuse the Chance Time centered-banner style in
  `message_bubble.dart` (`metadata['is_dream']`), moon icon, porch-amber
  chrome.
- **Group parity:** dreams are per-character; the speaker whose turn follows
  the night crossing dreams. Cards key off `ChatParticipant.id` exactly like
  the Journal.
- **Web:** free for the message (arrives via `chat_facade` like any message);
  diary card appears in the web journal surface.

### Settings
"Dreams" toggle in the realism cluster; effective-on requires Journal +
passage-of-time on. Default ON when both are on.

### Risks
Local-model dream quality → mitigated by skip-on-garbage floor. One extra
LLM call per story-day maximum (bounded, off the hot path).

---

## 2. Real-absence awareness + "Previously on…" 📺 (Effort: S, ~1–2 days)

The character notices you were gone; the app reminds you where you left off.

### Behavior
- **"Previously on" banner (no LLM, always tasteful):** opening a chat after
  a real-world gap ≥ threshold (default 24h) shows a dismissible banner:
  *"It's been 4 days — where we left off:"* + the existing `Sessions.summary`
  recap. Pure read-model.
- **In-character acknowledgment (opt-in, one-shot):** the first exchange
  after the gap carries a single injection line telling the model N real days
  passed and to acknowledge naturally without dwelling. Consumed after one
  response — never repeats. The *story* clock is untouched; this is
  meta-awareness, deliberately opt-in (some users find it
  immersion-breaking).

### Architecture
- Gap computation on session load in `chat_service_session_load.dart` from
  the last message's DB timestamp → `_absenceGapHours` scalar + one-shot
  flag. No storage.
- Injection line added to the existing
  `chat/prompt_injection/time_injection.dart` (guarded by the one-shot flag).
- **New widget:** `ui/chat_components/overlays/absence_recap_banner.dart`
  (AppColors throughout).
- **Web:** the facade already exposes the recap; add `absenceGapHours` to the
  chat snapshot and mirror the banner in web_ui (both phone + wide layouts).
- **Group:** gap is per-chat; the injection addresses the group collectively.

### Settings
Toggle + threshold (12h/24h/3d/1w) in General; acknowledgment sub-toggle
default OFF, banner default ON.

### Risks
Essentially none. Guard: never fire for gaps while the app was merely
backgrounded mid-session (anchor to last *message*, not last app-open).

---

## 3. Weather & seasons 🌦 (Effort: M, ~3–4 days)

Deterministic weather over the story calendar, felt in prompts, Needs, and
the sidebar.

### Behavior
- Each story day has weather (condition + temperature band) with day-to-day
  continuity (a storm system passes through; it doesn't strobe). Seasons fall
  out of `TimeService.clock` — it is a real `DateTime`, so month → season is
  free.
- Consumers: one injection line ("Cold steady rain since morning; late
  autumn."), gentle Needs effects (comfort decays slightly faster in
  storms/heat; small fun scene-reward bonus on clear days — magnitudes tiny),
  and a weather glyph next to the existing scene-time display.

### Architecture
- **New pure leaf:** `lib/services/chat/weather_engine.dart` — seeded PRNG
  keyed on `(sessionId.hashCode, dayCount)`, yesterday-biased Markov step,
  season from clock month. **Same inputs → same weather, so nothing is
  stored** — recomputed on demand, save/load-proof, zero schema.
- **New builder:** `chat/prompt_injection/weather_injection.dart`, registered
  beside `time_injection`.
- **Needs hook:** apply identically in the 1:1 scalar path and the
  `_groupRealism` per-speaker path (weather is per-chat shared state, so
  parity is trivial — but the change touches decay/reward, so the mandatory
  dead-code audit + both-paths check from CLAUDE.md applies).
- **UI:** glyph + tooltip in the sidebar scene-time section; same in web_ui
  (facade adds `weather` to the realism read snapshot).
- **Tests:** golden determinism tests on `WeatherEngine` (fixed seeds → fixed
  sequences) + season boundaries.
- **Future (explicitly out of scope now):** auto-background switching.

### Settings
"Weather" toggle, default ON when passage-of-time is on; per-chat override
("always sunny here") stored in the existing session `generation_settings`
JSON blob — additive, no schema.

### Risks
Needs balance — keep deltas ±1-grade and behind the toggle. Parity audit is
the real work item.

---

## 4. Chat → novella export 📖 (Effort: M, ~3–5 days)

Turn a beloved chat into a formatted story/EPUB keepsake.

### Key finding — mostly built already
`StoryPipelineService.runChatDistiller` already ingests chat history into a
StoryProject; the full stage chain (architect → acts → scenes → draft/edit)
exists; **`EpubGeneratorService` and the web `story_export_facade.epub()`
already ship.** What's missing is the one-tap flow and a *faithful* mode.

### Behavior
- Chat menu: **"Turn this chat into a story…"** → small config dialog
  (length: short story / novella; POV: third-limited / first; mode: faithful
  retelling / inspired-by) → lands in the existing Story dashboard with a
  pre-configured project; the familiar pipeline UI takes it from there →
  export EPUB/Markdown as today.

### Architecture
- **StoryProject model:** add `chatHistorySessionIds` (additive JSON field)
  so the distiller can scope to *this session* instead of all sessions for
  the character (current behavior), plus a `faithfulMode` flag.
- **Faithful mode prompts:** architect/scene stages constrained to follow the
  chat's actual events in order. The outline spine comes free from data we
  already have: the "Where we are" recap + salient journal cards (which carry
  `storyDay`/`storyClock` metadata — the emotionally-important beats,
  pre-identified). New prompt variants live in a new
  `lib/services/story/faithful_mode.dart` leaf (StoryPipelineService is
  already huge; do not grow it).
- **Entry point:** chat page menu item + config dialog (follows standard
  dialog patterns; it is not a wizard — the Story dashboard is the flow).
- **Web:** story facades exist; add the same entry to the web chat menu and
  pass through to the existing story surfaces.

### Risks
Very long chats vs context — the distiller already chunks; verify at 1k+
messages. Set expectations in UI copy: it produces a *draft* the user can
regenerate per scene (existing per-scene controls).

---

## 7. Milestones timeline — "Our Story" 🏆 (Effort: M, ~3–4 days)

One chronological timeline of everything that mattered: growth rings, Chance
Time strikes, completed objectives, flashbulb memories, bond thresholds.

### Architecture — a read-model first, one new write second
**v1 (pure aggregation, zero new writes):**
- **New leaf:** `lib/services/chat/milestone_feed.dart` (<300 LOC) merging
  four existing sources per session+character, sorted by story time:
  1. `growth_rings` table (already indexed by session/character)
  2. Journal cards where pinned / flashbulb-grade heat/intensity
     (`storyDay`/`storyClock` metadata already stamped on every card)
  3. Messages with `is_chance_time_narration` metadata
  4. Completed objectives (objectives table, per-chat)
- **UI:** a second tab inside the existing `journal_dialog.dart` —
  **"Diary | Our Story"** — vertical timeline grouped by story day
  (TimeService date formatting), typed icons (🌱 ring, ⚡ chance, 🎯
  objective, 📔 memory, 💞 bond). Tap-to-jump reuses `message_jump.dart`
  wherever a source message exists. No new dialog surface.
**v1.5 (one new write path):**
- Bond/trust **threshold crossings** recorded at the moment they happen via a
  hook in `RelationshipService` — written as journal cards with
  `metadata.kind = 'milestone'`. Reuses `journal_cards` (no schema), inherits
  delete-with-chat and review-first for free. Small `JournalPhysics`
  exemption: milestone cards never cool (pinned-equivalent).

### Parity
Per-character in groups — identical keying to the Journal
(`ChatParticipant.id` is the storage key). Web: `chat_facade` exposes a
`milestones` list; web_ui renders the same timeline (phone + wide layouts).

### Risks
Historical bond thresholds (before the feature existed) are only
approximately reconstructable from per-message realism metadata — v1 simply
starts recording from feature-on, which is honest and cheap.

---

## Suggested build order & release plan

| # | Feature | Effort | Depends on |
|---|---------|--------|-----------|
| 1 | Weather & seasons | M | — (pure foundation, fully testable) |
| 2 | Absence awareness | S | — |
| 3 | Dreams | S–M | Journal (exists); weather line enriches dream prompts |
| 4 | Milestones timeline | M | Dreams adds `kind='dream'` cards to the feed |
| 5 | Novella export | M | — (independent; biggest UX surface) |

≈ 3–4 weeks of focused work including web parity, tests, and Rawhide.md
copy. Each feature is independently shippable — nothing blocks on anything
else, so nightly users get value incrementally.

**Per-feature done-criteria (per CLAUDE.md):** web_ui counterpart in the same
body of work; `flutter analyze` clean; dead-code audit on touched
`chat_service` paths; 1:1/group parity audit for anything touching Needs or
realism; `docs/Rawhide.md` user-facing bullet; AppColors-only chrome.
