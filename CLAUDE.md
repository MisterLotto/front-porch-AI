# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Front Porch AI is a Flutter desktop application (Windows/Linux/macOS) for AI-powered character chat using local LLMs via KoboldCpp. It features a "Realism Engine" for emotion/trust/relationship tracking, RAG memory via ONNX embeddings, TTS/STT, a novel generator, **The Stoop** (a built-in, opt-in community character hub — see its section below), and a companion **web/mobile UI** (`web_ui/`). (Cloud Sync has been removed; automatic local backups are its replacement.)

**License:** AGPL-3.0 (v0.9.0+), GPLv3 (earlier)
**State management:** Provider (migrating to Riverpod for new code)
**Database:** SQLite via Drift ORM

## Key Commands

```bash
# Setup
flutter pub get
dart run build_runner build --delete-conflicting-outputs
                                     # Codegen — required after a Drift schema change
                                     #   (regenerates database.g.dart) and after adding
                                     #   any @riverpod provider.

# Development
flutter run                          # Debug run
flutter analyze                      # Lint (0 warnings on active rules; CI runs on changed .dart files for PRs + full scheduled job)
dart format --set-exit-if-changed .  # Format check. NOT `flutter format` — that
                                     #   subcommand was removed; it errors with
                                     #   "Could not find a command named format".
                                     #   Do NOT bulk-run this: see "Verification".

# Tests
flutter test --concurrency=1 --exclude-tags golden
                                     # What CI actually runs. Bare `flutter test`
                                     #   races the realism-engine integration tests
                                     #   at default concurrency.
flutter test --coverage              # With coverage
flutter test test/path/to/file.dart  # Single test file
flutter test -n "test name"          # Run specific test by name

# The Linux-gated gate — MANDATORY before pushing
./scripts/ci-local.sh                # Runs the pixel goldens in the fpai-golden
                                     #   linux/amd64 container. 18 golden files are
                                     #   @TestOn('linux'), so a green macOS run never
                                     #   executes them — that is exactly how a red-CI
                                     #   commit once reached Rawhide.
                                     #   Also: ci-local.sh test | all | update-goldens

# E2E (integration_test/) — one invocation PER FILE
flutter test integration_test/app_smoke_test.dart -d macos
                                     # Never `flutter test integration_test/` — a single
                                     #   invocation launches a second app while the first
                                     #   still holds the device, and the second file dies
                                     #   at "loading" with no stack. CI loops per file.

# WebUI (web_ui/ — the React PWA; desktop parity is mandatory)
cd web_ui && npm ci                  # Setup
cd web_ui && npm run dev             # Vite dev server
cd web_ui && npm run lint && npm test  # What the `web-tests` CI job runs (tsc + vitest)
cd web_ui && npm run build           # REQUIRED after ANY web_ui change: vite writes to
                                     #   ../assets/web_app, which is the bundle the Flutter
                                     #   app serves. No build = your change ships nothing.

# Release builds
flutter build linux                  # Linux
flutter build windows                # Windows
./scripts/build-macos.sh             # macOS (signs + packages + notarizes)
```

## Architecture

### Directory Structure

```
lib/
├── main.dart                    # Entry point; initializes all services, window config, SIGINT handling
├── app_version.dart             # Version constant + isPreRelease flag
├── database/
│   ├── database.dart            # Drift schema (characters, chats, messages, lorebooks, worlds, etc.)
│   ├── database.g.dart          # Generated Drift code
│   ├── database_cleanup.dart    # Database cleanup helpers
│   └── data_migration_service.dart # Data migrations between schemas
├── models/                      # Data models (character_card.dart, lorebook.dart, world.dart, etc.)
├── providers/
│   └── app_state.dart           # Global app state (ChangeNotifier)
├── services/                    # Business logic (~50 services)
│   ├── chat/                    # Domain subservices for chat mechanics (extracted from chat_service.dart)
│   │   ├── needs_simulation.dart        # Sims-style needs (decay, buffers, apply/compute deltas)
│   │   ├── needs_impact_evaluator.dart  # Needs impact eval (LLM JSON + activity table + modifiers pipeline)
│   │   ├── chaos_mode_service.dart      # Chaos Mode / Chance Time event simulation
│   │   ├── relationship_service.dart    # Bond/trust/fixation/spatial/inter-char tracking
│   │   ├── expression_classifier.dart   # ExpressionService wrapper used inside ChatService
│   │   ├── llm_eval_engine.dart         # Shared LLM eval plumbing (fire, strip think-blocks, extract JSON)
│   │   ├── realism_evals.dart           # The 5 realism evaluation calls + prompts + parse
│   │   ├── objective_proposal.dart      # Objective proposal + task generation + completion checks
│   │   ├── journal_maintenance.dart     # The Journal: one periodic pass → memory cards + recap
│   │   ├── journal_store.dart           # Journal card persistence (per-chat, per-character)
│   │   ├── journal_ops.dart             # Journal XML transport parsing (pure functions)
│   │   ├── journal_physics.dart         # Journal emotional physics: heat/flashbulb decay, mood recall, event salience (pure)
│   │   ├── journal_prompt.dart          # Journal maintenance prompt builder (XML + tools variants, salience annotations)
│   │   ├── journal_review.dart          # Journal proposals + the ONE applier; review-first parking (apply/discard)
│   │   ├── growth_service.dart          # Growth Rings — character evolution (replaced the
│   │   │                                #   DELETED evolution_service.dart; + growth_store/_ops)
│   │   ├── time_service.dart            # Story clock — CONTINUOUS per-turn advance (no 6-turn gate)
│   │   └── story_clock.dart             # Clock math: periods, dayCount, weekday, per-turn clamps
│   │   ├── prompt_injection/    # prompt-injection builders (author_note, relationship, emotion,
│   │                            #   behavioral, time, nsfw, chaos, needs, realism_state, journal)
│   ├── grpc/                    # gRPC-generated code and services (e.g. Draw Things)
│   ├── chat_service.dart        # Core chat orchestration: context building, streaming, Realism
│   │                            #   orchestration, _groupRealism map, post-gen wiring (see notes below)
│   ├── kobold_service.dart      # KoboldCpp API client
│   ├── llm_provider.dart        # Abstraction over Kobold/OpenRouter/external APIs
│   ├── character_repository.dart # Character CRUD via Drift
│   ├── storage_service.dart     # File system paths, beta/stable data dir isolation
│   ├── embedding_service.dart   # In-process RAG embeddings (nomic via onnxruntime)
│   ├── memory_service.dart      # RAG memory extraction and retrieval
│   ├── tts_service.dart         # TTS orchestration (Kokoro, ElevenLabs, OpenAI, Piper)
│   ├── stt_service.dart         # Whisper STT via in-process sherpa-onnx
│   ├── backup_service.dart      # Automatic local DB backups + restore
│   ├── hardware_service.dart    # GPU detection, VRAM estimation
│   ├── backend_manager.dart     # KoboldCpp lifecycle (start/stop/restart)
│   ├── services.dart            # Curated public barrel (high-frequency surface; does NOT re-export chat/ leaves)
│   └── ... (40+ other top-level service files)
├── ui/
│   ├── chat_components/         # Componentized chat UI elements
│   │   ├── chat_components.dart # Main barrel for chat components
│   │   ├── bubbles/             # Chat bubbles (message bubbles, styled message content)
│   │   ├── overlays/            # Overlays (RAG setup, generation status, realism processing)
│   │   ├── sidebar/             # Chat sidebar tab sections (memory, realism, chaos, nsfw, scene time)
│   │   └── widgets/             # Granular interactive chat buttons and pills
│   ├── layout/main_layout.dart  # Main shell with sidebar + content area
│   ├── pages/                   # Screen pages (chat_page, home_page, etc.)
│   │   ├── settings_page.dart          # Settings shell only (~400 LOC): tab scaffold, state,
│   │   │                               #   `rebuildState(fn)` public setState bridge for the parts
│   │   ├── settings_page.controls.dart # `part of` — generation/sampler control builders
│   │   ├── settings_page.advanced.dart # `part of` — advanced/experimental settings
│   │   ├── settings_page.hardware.dart # `part of` — hardware/VRAM detection UI
│   │   ├── settings_page.gpu.dart      # `part of` — GPU layer/offload UI
│   │   └── settings_page.launch.dart   # `part of` — backend launch/args UI
│   ├── settings/                # Settings screen, extracted from the old god file (all < 500 LOC
│   │   │                        #   except voice_media_tab; extend these, don't regrow settings_page)
│   │   ├── tabs/                # One file per Settings tab: general_tab, generation_tab,
│   │   │   │                    #   backend_tab, voice_media_tab
│   │   │   └── backend/         # Backend tab sections: backend_mode_selector, remote_api_section,
│   │   │                        #   omlx_section, managed_backend_section
│   │   ├── dialogs/             # Settings-local dialogs: color_picker, model_search, prompt_save/delete
│   │   └── widgets/             # Settings-local widgets: section_header, slider_setting, color_row,
│   │                            #   api_preset_chip, image_gen_enable_section, photo_understanding_card,
│   │                            #   web_login_section
│   ├── dialogs/                 # Modal dialogs
│   ├── theme/app_colors.dart    # Central theme + warm-porch palette (porchAmber/formMasterAccent/
│   │                            #   onChaosAccent/porchAmberOf); dark/light color helpers
│   └── widgets/                 # Reusable layout widgets (inputs, cards, sliders, dropdowns, etc.)
└── utils/                       # Helpers (emotion_labels, vram_estimator, gguf_parser, etc.)
```

### Critical Services

- **ChatService** (`lib/services/chat_service.dart`): The orchestration hub. **It is a `part`-file library**: 28 `part 'chat/chat_service_*.dart';` directives mean a great deal of "ChatService" code lives in `chat/` files that can touch its privates directly — when hunting a method, grep `lib/services/chat/` too, not just this file. Builds context windows, handles message streaming, coordinates Realism Engine evaluations and post-generation needs/climax/sexual/daily checks, owns the `_groupRealism` map and load/save scalars for per-character group state, attaches chip deltas to messages, and wires all cross-service callbacks. The domain logic lives in the `chat/` leaf services below; ChatService stays the thin coordinator. **It is still large — do not grow it. Extract cohesive logic into new `chat/` leaves instead.**
- **NeedsSimulation** (`lib/services/chat/needs_simulation.dart`): Sims-style needs (hunger, bladder, energy, social, fun, hygiene, comfort) — decay, post-climax arousal suppression/afterglow buffers, catastrophe narrative triggers, `applyNeedsDeltas`, `applySceneImpact`, `computeNeedsDeltasWithReasons`, and context helpers. Pure class; all cross-state (group, time, arousal) via callbacks.
- **NeedsImpactEvaluator** (`lib/services/chat/needs_impact_evaluator.dart`): Post-gen needs impact layer (LLM "needs_impact" JSON + declarative activity table + ordered modifiers pipeline for romance/stance/enjoys). Produces a `NeedsImpact` and applies it via the simulation.
- **ChaosModeService** (`lib/services/chat/chaos_mode_service.dart`): Chaos Mode pressure growth, Chance Time random event selection, custom event prompt injection.
- **RelationshipService** (`lib/services/chat/relationship_service.dart`): Bond/trust/fixation/spatial stance/inter-character feelings.
- **ExpressionClassifier** (`lib/services/chat/expression_classifier.dart`): ONNX + LLM emotion classification and reclassification (inertia, manual overrides, avatar selection). The core classifier impls still live in the legacy `lib/services/expression_classifier.dart`; the `chat/` version delegates to it.
- **LlmEvalEngine** (`lib/services/chat/llm_eval_engine.dart`): Shared eval plumbing — streaming LLM fire with retry/cancel, central think-block stripping, JSON extraction. Used by `realism_evals`, `objective_proposal`, and others.
- **RealismEvals** (`lib/services/chat/realism_evals.dart`): The 5 realism evaluation calls (relationship, emotional state, physical state, narrative, one-shot) plus their prompt builders, orchestration, and parse (bond/trust/emotion/arousal/fixation/spatial/time deltas + pending chip metadata).
- **ObjectiveProposal** (`lib/services/chat/objective_proposal.dart`): Objective proposal handling (autonomous "none" vs value, dedup, auto task-gen for autonomous), `generateObjectiveTasks`, and background task-completion checks.
- **The Journal** (`lib/services/chat/journal_maintenance.dart` + `journal_store.dart` + `journal_ops.dart` + `journal_physics.dart` + `prompt_injection/journal_injection.dart`; design: `docs/design/journal-memory.md`): the unified emotional memory system. One periodic maintenance pass per diary owner produces (a) per-chat, per-character **memory cards** (with emotion label + intensity stamped deterministically from the message metadata the Realism Engine already wrote) and (b) the per-chat **"Where we are" recap**, which reuses the old summary scalars/column (`_summary`, `Sessions.summary`, `summaryLastIndex` as the pass cursor) so EvolutionService, the sidebar, and the web facade surface kept working. Cards are strictly session-scoped — **no memory ever crosses chats** — and are deleted with the chat. XML-tag transport parsed forgivingly (local-model floor); reasoning off + think-strip via LlmEvalEngine. Replaced the deleted `SummaryService` + `FactExtraction` (and the persona learned-facts feature; `Personas.learnedFacts` column is dormant). **Emotional physics** (phase 2, all constants/math in `journal_physics.dart`, pure + deterministic): cards carry heat that cools one step per pass with flashbulb resistance (strong feelings barely fade; pinned never), cold cards (heat < 0.35) leave the always-injected hot set but resurface via cosine search against the recent turn (re-warmed to 0.75 + access recorded), hot-set ordering gets a mood-congruence boost (emotion families via `EmotionLabels.nuancedToStandard`, read from the same `_characterEmotion` scalar the group pre-gen load sets per speaker — parity), cap trims the coldest unpinned card, salient events (|bond/trust delta| ≥ 12, trust repair, Chance Time, objective completion via `ObjectiveProposal.onObjectiveCompleted` → `eventKickPending`) trigger an immediate pass from `_maybeRunJournalPass`, and a virgin journal on a long chat reads only the trailing 50 messages. Card embeddings ride `MemoryService.embedText` and are strictly optional (no-RAG floor: hot/pinned injection never needs the sidecar). **UI** (phase 3): sidebar peek `ui/chat_components/sidebar/journal_memory/journal_panel.dart` (follows the focused participant — `ChatParticipant.id` IS the cards' storage key) + full diary `ui/dialogs/journal_dialog.dart` + shared plant/edit editor `ui/dialogs/journal_card_editor.dart`; the UI mutates `ChatService.journalStore` directly and the injection builder re-reads the DB each turn, so edits need no extra plumbing. Receipts quote the cited lines AND tap-to-jump: `ui/chat_components/widgets/message_jump.dart` seeks the chat's reverse `ListView.builder` (bubbles keyed `GlobalObjectKey(msg)` — was ObjectKey) by proportional hop + viewport paging until the target key materializes, then `ensureVisible` + a brief `JumpFlash` tint. **Phase 4** — two transports, ONE applier (`journal_review.dart`): the pass (`_runExchange`) probes `LLMService.generateWithTools` once per backend identity per run (`kJournalTools` schemas + `parseJournalToolCalls` in journal_ops; OpenRouterService implements over its shared `_chatPayload`; KoboldCpp + PseudoRemote implement via the shared `postOpenAiChatWithTools` in openai_chat_stream.dart — Qwen3-class local models call tools fine, per user decision 2026-07-03), salvages tags from text-only replies, and remembers XML-only backends per backend+model identity (remote model name AND local model path ride the key). **Review-first mode** (`journal_review_first`, default off, toggle in the recap gear): the pass resolves ops into id-addressed `JournalProposedOp`s and parks a session-guarded `JournalReviewBatch` (blocks further auto passes; cursor moves only on Apply/Discard); sidebar banner → `journal_review_dialog.dart` checkboxes → Apply routes through the same `applyOwnerProposals` normal mode uses. Prompt building lives in `journal_prompt.dart` (XML + tools closing sections over an identical body).
- **Growth Rings** (`lib/services/chat/growth_service.dart` + `growth_store.dart` + `growth_ops.dart`): character evolution. NOTE: the old `EvolutionService` and `chat/evolution_service.dart` were DELETED — only tombstone comments remain. Scenario evolution was retired with it. Do not reference either name.
- **KoboldService** (`lib/services/kobold_service.dart`): HTTP client for KoboldCpp (`/api/v1/generate`, `/api/extras/abort`, etc.).
- **StorageService** (`lib/services/storage_service.dart`): Data directories. Beta builds use `FrontPorchAI-Beta/` with `beta_` prefixed SharedPreferences keys.
- **EmbeddingService** (`lib/services/embedding_service.dart`): In-process RAG embeddings — nomic-embed-text-v1.5 via onnxruntime in a persistent worker isolate (`embedding/native_embedding_engine.dart`), golden-pinned to the retired Rust server's exact vectors so stored embeddings stay valid. Owns the model download/setup flow the RAG consent dialog drives.

### Native Engines (no sidecars at all)

Every sidecar was retired in 2026-07 (docs/design/sidecar-retirement.md — read it before touching any engine). TTS (Kokoro/Piper via sherpa-onnx), STT (Whisper via sherpa-onnx), expression classification (onnxruntime), RAG embeddings (nomic via onnxruntime, golden-pinned to the old Rust server's vectors), and Draw Things (pure-Dart gRPC + fpzip FFI) all run **in-process** — the app spawns no helper processes. Engine successes/failures report to `EngineHealth` (`lib/services/engine_health.dart`); pre-release builds surface the first unexpected failure loudly. Do not reintroduce sidecar processes.

### Database

Drift ORM with SQLite. Schema in `lib/database/database.dart`. Run `dart run build_runner build` after schema changes to regenerate `database.g.dart`.

Key tables (REAL SQL names — verify against `database.g.dart`, not memory): `characters`, `sessions`, `messages`, `groups`, `group_members`, `folders`, `personas`, `worlds`, `chat_worlds`, `chat_biome_spans`, `message_embeddings`, `objectives`, `data_bank_entries`, `avatar_images`, `journal_memories`, `sync_meta`. 21 tables in total. UUID primary keys for merge compatibility.

**Identity gotcha that has already caused data loss:** `objectives`, `message_embeddings` and `data_bank_entries` key their `character_id` by the character's **stableGroupId** (the portable image-filename basename, e.g. `Jennifer_1782587668376`), NOT by the `characters.id` UUID. `avatar_images` DOES use the UUID. Joining the former against `characters.id` matches nothing and marks every row an orphan — that shipped in Database Cleanup and would have deleted 107/107 objectives and 68/68 RAG embeddings on a real library. Resolve identities via `stableGroupIdFrom()` in `lib/utils/character_id.dart`.

**Important — external direct writers**: A community companion app (Character Card Forge — https://github.com/FrozenKangaroo/Character-Card-Forge) performs direct raw SQL `INSERT`/`UPDATE` into the database files (primarily `characters`, `sessions`, `messages`, `avatar_images`, `sync_meta`). Schema changes can break it. See "Files Requiring Discussion Before Changes".

### Realism Engine

A multi-component system spanning `chat_service.dart` (orchestration, `_groupRealism`, post-gen hooks, message metadata), the `chat/` domain services, and the LLM provider:
- Emotion tracking with inertia between turns (ExpressionClassifier)
- Bond/trust relationship scoring (bond clamped to ±300, arousal ±100) (RelationshipService)
- Time progression — `lib/services/chat/time_service.dart` (`TimeService`) + `story_clock.dart`. Advancement is CONTINUOUS AND PER-TURN: the scene-time eval reports `minutes_elapsed` for the exchange, clamped by `StoryClock.maxMinutesPerTurn`, with `StoryClock.failureDriftMinutes` as the deterministic floor when the eval fails and a `stallBackstopTurns` backstop so time can never freeze. **The old 6-turn gate and its `hold_time` veto are GONE** — do not reason about a turn counter.

  **PASSAGE OF TIME CANNOT BE DECOUPLED FROM REALISM. Settled 2026-08-02 — do
  not re-propose it.** TimeService looks separable (clean constructor, no
  realism input, a test suite that builds it with realism nowhere in sight) and
  that appearance is why the idea keeps recurring. Four reasons, all verified:
  (1) the clock's ACCURACY is an LLM eval — `_fireSceneTimeEval` asks the model
  how long the exchange took, and without it the only fallback is
  `failureDriftMinutes`, a fixed constant, so a two-line greeting and a two-hour
  dinner would move the clock equally; (2) that eval is FUSED with posture, a
  realism scalar, so splitting costs a second model call every turn or keeps the
  coupling anyway; (3) one-shot mode has no separate time call to extract — it
  fuses `minutes_elapsed`/`new_day` into the realism JSON; (4) the clock is
  persisted and restored through each message's `realism_state`, so decoupling
  is a migration, not a code move. The OOC skip path (`detectOocTimeSkip`) is
  regex and would survive alone, but it only matches enumerated phrasings and is
  itself gated on `passageOfTimeEnabled` — it is a fast path, not a substitute.
  COROLLARY: never un-gate the time PROMPT FRAGMENT for realism-off users; the
  clock cannot advance in that state, so it would inject the same frozen
  timestamp every turn. Formalise the seam; do not cut it.
- Fixation engine (emotional obsessions)
- Character evolution (trait development) (EvolutionService)
- Chaos Mode / "Chance Time" random events (ChaosModeService)
- Sims-style Needs Simulation (NeedsSimulation): straight per-turn decay ticks (needDecay plus exactly six `decayModifiers` — four cross-boosts `low_energy_hunger_boost` / `low_energy_comfort_boost` / `low_fun_social_boost` / `low_bladder_comfort_boost`, and two weather ones `weather_rough_comfort` / `weather_clear_fun` that vanish when weather is off. **There is no time-of-day decay term** — earlier wording here claimed one), scene deltas, stepped descriptions, hygiene inversion for "enjoys low hygiene". **The afterglow / lust-haze / post-climax-crash / arousal-suppression BUFFERS were removed** (see the class doc in `needs_simulation.dart`) — do not reason about buffer state.
- Escape hatch: `cancelRealismEval()` aborts in-flight evals via `_isCancellingRealismEval` + `abortGeneration()`

**Known gotcha**: GBNF grammar constraints cause many KoboldCPP models to return empty eval responses. Evals use stop sequences + regex parsing (no grammar). Remote APIs work fine without grammar. **Tools transport (2026-07-06)**: every flat-JSON eval — the 4 realism evals (relationship, emotional, narrative, one-shot), the needs-impact eval, the scene-time/posture eval, the expression reclassifier, and the cast detector — tries native tool calls first (`realism_tools.dart` schemas + the ONE shared negotiation `fireStructuredEval` in `pass_support.dart`, same probe-and-fallback as Journal/Growth via the shared `ToolTransportProbe`); a successful call is converted to the canonical flat-JSON text and flows through the UNCHANGED verifier/parse/apply pipeline, so parity holds by construction. The regex text path remains the floor and the sole path for tool-less backends. Deliberately text-only: the Director/verifier critique output, the AI character creator, and the story pipeline (streaming live-preview + their own repair machinery).

**The eval scores the USER's message, never the character's own reply. Settled
2026-08-02 — do not re-propose post-generation evaluation.** Evals fire BEFORE
generation (`_evaluateRealismForUpcomingSpeaker`), so realism deliberately lags
one exchange. That is the design, not an oversight: bond/trust/emotion answer
"how does this character feel about what the user just did". If the eval scored
the reply instead, the character's mood would be set by whichever words the
model happened to pick for them — so **rerolling a line would reroll their
feelings**, turning bond and trust into a slot machine the user pulls by
pressing Regenerate. COROLLARY: **a regen is SUPPOSED to reproduce the same
deltas.** Its input (the user's message + the pre-turn state) is identical, and
evals run at temperature 0.1 (`llm_eval_engine.dart`), so an identical prompt
must give an identical answer. Two regens disagreeing is a **rewind bug** — some
state the turn changed was not put back — not the engine being lifelike. The
non-scalar state that regen must rewind lives in `captureCadenceAndFeelings` /
`restoreFromMessageState` (`relationship_service.dart`); anything new that feeds
an eval prompt and is NOT a scalar must join that pair.

**One-shot vs Normal Path Parity (strict)**: When `_storageService.realismOneShotEval` is true, `_evaluateOneShotCall` **must** produce 1:1 equivalent outputs for Bond/Trust/Emotion/Arousal/Fixation/Spatial Stance/Time/Needs deltas as the normal multi-call path (relationship + emotional-state + physical-state + narrative calls). The one-shot path exists purely for token/latency optimization — it must not change observable Realism or Needs behavior.

**Realism & Needs Parity (1:1 vs Group)**: Observable behavior (bond/trust deltas, emotion inertia, needs decay + scene rewards + buffers + catastrophes, time advance every 6, climax refractory, etc.) must be identical whether a character is in a 1:1 chat or a group (per-speaker). Orchestration differs (scalar fields vs `_groupRealism` map + load/save + speaker impersonation), but the simulation results and UI must not diverge. Any change touching these areas requires auditing both paths and the "keep reset blocks in sync" sites in `chat_service.dart`.

### Tracing Realism/Needs/Group Post-Generation, Chips, Sidebar & Climax Checks

Because core simulation lives in the `chat/` leaves while orchestration, the `_groupRealism` map, message metadata, UI attachment, and cross-speaker coordination stay in `chat_service.dart`, tracing post-turn bugs means following a few specific execution paths. Use this when you see:
- Needs chips/sidebar not updating or showing stale values (especially in groups)
- A climax/sexual/daily LLM eval firing twice for one response
- Group members not reflecting scene rewards (fun/social/hygiene) or decay
- Chips showing cross-character deltas or all "X 0"

**Where the pieces live:**
- **Orchestration + group state + chip attachment** — `chat_service.dart`:
  - Pre-turn capture (in `sendMessage`): `preTurnVector` (`chat_service.dart:~3699`) before `tickDecay`. (There is no `groupSpeakerPreDecayNeeds` — that symbol was removed.)
  - Group per-speaker pre-gen: **`_evaluateRealismForUpcomingSpeaker`** (no "Group" in the name; `chat_service.dart:2782` + the `chat/chat_service_realism_dance.dart` part) — `_loadGroupRealismIntoScalars` → run evals under impersonation → `_saveScalarsIntoGroupRealism` → stamp `realism_state` metadata on the new message.
  - Post-gen finalization (late in `_generateResponse`): temporarily re-set `_activeCharacter` + `_loadGroupRealismIntoScalars` so checks see the right character, `await _runPostGenNeedsChecks(finalResponse)` (climax → sexual → daily → fulfillment) — SKIPPED when the generation mode is `continue_`, because a continuation extends the same exchange and used to apply its scene deltas a second time — then **`_saveScalarsIntoGroupRealism`** (the critical persist — without it scene deltas never reach `_groupRealism`).
  - Chip delta computation/attach (after `_generateResponse` in the `sendMessage` caller): the `if (_needsSimEnabled && _messages.isNotEmpty)` block; 1:1 uses `preTurnVector`, group uses the pre-decay snapshot. Sets `metadata['needs_deltas']`.
  - Group helpers: `_getGroupNeeds`/`_setGroupNeeds`, `_loadGroupRealismIntoScalars`/`_saveScalarsIntoGroupRealism`, `getNeedsForGroupCharacter`, `_getCurrentSpeakerIdForRealism`, `nextCharacter`.
- **Domain simulation** — `chat/needs_simulation.dart`: `applyNeedsDeltas`, `applySceneImpact`, `computeNeedsDeltasWithReasons` (feeds the chips), `tickDecay` (has the explicit group vs 1:1 branch), buffer state (afterglow, postClimaxCrash, arousalSuppression, pendingCatastrophe), `initializeFresh`.
- **Needs impact eval** — `chat/needs_impact_evaluator.dart`: `evaluateAndApply(responseText)` is the single post-gen entry; activity table + modifiers pipeline; decoupled from the god via callbacks.
- **Display consumers**:
  - Per-message chips: `lib/ui/chat_components/bubbles/message_bubble.dart` `_buildRealismIndicator` reads `metadata['needs_deltas']` (skips zero-delta needs).
  - Sidebar levels/bars: `lib/ui/chat_components/sidebar/character_state/` (`bond_bars.dart`, `character_state_group.dart`, …) reads **`chat.needsSimulation.vector`** and the per-member getters `getNeedsForGroupCharacter` / `getAffectionForGroupCharacter` / `getTrustForGroupCharacter`. (There is no `realism_section.dart`, and `needsVector` is a DB column, not a ChatService getter.)
  - Group member cards: `lib/ui/widgets/group_member_card.dart` → `getNeedsForGroupCharacter` → `NeedsGrid`.
  - Bar/grid widgets: `lib/ui/widgets/needs_bar.dart`.

**Tracing recipe:**
1. Reproduce with logging on (`[Realism:Needs]`, `[Realism:Climax]`, `[Realism:RawEval]`).
2. At the post-gen block, print `_activeCharacter?.name` and the speaker of the message being finalized.
3. Confirm `_saveScalarsIntoGroupRealism` ran for the right sid.
4. For chips, print the pre-vector passed to `computeNeedsDeltasWithReasons` and the resulting map.
5. For sidebar/cards, compare `getNeedsForGroupCharacter` against `_needsSimulation.vector`.
6. In group, walk: load → tick (on map) → per-speaker load (sets scalar) → gen → post apply (on scalar) → saveScalars (writes map).
7. The impersonation dance is only for the *checks* (so prompts name the right character); the scalars are already the right speaker's when post runs.

When you touch any of the above you **must**: keep 1:1 and group producing equivalent observable behavior; run the dead-code audit + analyze/format/build gates; update this section if the tracing surface changes; and consider whether new logic belongs in an extracted leaf rather than the god file.

### Story Pipeline (Porch Stories)

`StoryPipelineService` is created via `ChangeNotifierProxyProvider2` in `main.dart`. The `update` function must NOT return the previous instance early — it must recreate the service with `llmProvider.activeService` each time so backend switches (Kobold ↔ OpenRouter/Nano-GPT) take effect.

## The Stoop (Community Character Hub) & Its Backend

**The Stoop** is the built-in, opt-in, account-gated, strictly-18+ community hub for sharing character and group cards (browse/search, upload, download, upvotes, follow creators, and mod↔user messaging). It is served by a **companion backend API** (an independent service) that the app talks to over HTTPS. The Dart client lives in **`lib/services/backporch/`** — auth, browse/search, upload, downloads, messaging (+ a WebSocket for live messages/typing), and models such as `StoopCard` / `StoopCardDetail`. Everything else in the app remains local-first; The Stoop and any remote APIs are opt-in.

**The backend's source, hosting, and deployment are maintained privately and are NOT part of this repository.** Do not add operational details (hosts, IPs, deploy steps, buckets, credentials) to this file or the repo.

**There is a SECOND Stoop client, and parity work must update it too.** The PWA never
calls the backend directly: `web_ui/src/stoop/` (`stoopApi.ts`, `StoopContext.tsx`,
`stoopTypes.ts`, `pages/stoop/*`, `components/stoop/*`) talks to the Dart server's
**`/api/stoop/*` relay** — `lib/services/web/routes/stoop_routes.dart` plus
`facade/stoop_facade.dart`, which wrap `BackporchApi` and proxy the messaging
WebSocket. A new Stoop endpoint or field therefore needs three edits: the Dart client,
the relay route/facade, and the TS client. The web side authenticates with its own
`X-Stoop-Token` from browser localStorage — deliberately separate from the desktop
`AuthState` session.

### API backward-compatibility (non-negotiable)
The backend is deployed independently and **far more frequently** than the app, and users update the app slowly — so the live fleet is **always a mix of app versions**. A backend change must never break an already-installed app:
- **Responses are additive-only.** Never remove, rename, or change the type/meaning of a field an app reads. New response fields are **optional/nullable**.
- Never make a previously-optional **request** field required, and never tighten validation to reject payloads older apps send. Prefer computing derived values **server-side** over demanding new client inputs (e.g. a card's token count is computed on the server from the card the app already uploads).
- **DB migrations stay additive** (nullable columns / defaults) so a mixed fleet — and a rollback — stay safe.
- The Dart client must **parse defensively**: null-safe casts with defaults; tolerate missing *and* unknown fields.
- A genuinely breaking change ships as a **new endpoint** (e.g. `/v2/…`), never by mutating an existing one, and keeps the old one alive until the fleet ages out.

There is no app-version gating in the backend, and there must not be — the contract above is what keeps old and new apps interoperable.

## Branch Workflow

| Change Type                  | Target Branch              |
|------------------------------|----------------------------|
| New features & experiments   | `Rawhide`                  |
| Bug fixes for current stable | `dev`                      |
| Bug fixes for active beta    | The active `*-Beta` branch |
| Release tagging              | `main`                     |

- **Rawhide** — primary rolling development branch. All new features, UI changes, major refactors, and experimental work target Rawhide.
- **dev** — bug fixes for the current stable release (when no beta branch is active).
- **Beta branches** (`0.9.x-Beta`) — created to stabilize an upcoming release. While active, only bug fixes for that beta are accepted; no new features.
- **main** — final, tagged stable releases only. Direct PRs are almost never accepted.

When a release cycle begins, a beta branch is cut from Rawhide; Rawhide keeps moving forward while the beta stabilizes.

**Cron gotcha:** GitHub evaluates `schedule:` triggers ONLY from workflow files on the
repository's DEFAULT branch. `nightly.yml` therefore runs `main`'s copy — any change to
it must be synced to `main` or the nightly silently keeps using the old version.
The same applies to `test-integrity.yml`: `pull_request_target` runs the BASE branch's
copy, so it protects only branches that actually carry the file.

## Important Constraints

- Beta builds MUST isolate data: `FrontPorchAI-Beta/` directory, `beta_` prefixed SharedPreferences keys.
- All AI processing is local/offline by default; cloud APIs (ElevenLabs, OpenRouter) are opt-in.
- Character cards follow V2/V2.5 spec (PNG/JSON with embedded metadata).
- Drift database uses UUID primary keys for cloud sync merge compatibility.
- **Database schema changes affecting external direct writers**: Character Card Forge writes directly via SQL. Any schema change that could break it (non-nullable new columns, removed/renamed columns, structural changes to `characters`/`sessions`/`avatar_images`/`sync_meta`) requires explicit maintainer approval before implementation.

## Files Requiring Discussion Before Changes

### Never touch without discussion
- `lib/database/database.dart` (the Drift schema + its `onUpgrade` migration ladder; there is NO `database/migrations/` directory) — schema changes require migration planning. **Do not introduce breaking changes** (especially to columns/tables written by external tools such as `characters`, `sessions`, `messages`, `avatar_images`, `sync_meta`) without direct maintainer confirmation. Character Card Forge relies on direct raw SQL writes.
- `lib/main.dart` — service initialization order is delicate.
- `pubspec.yaml` — **do not edit unless directly instructed.** CI/CD normalizes the release version. Local dev uses standard semver (e.g. `0.9.8+1`).
- `analysis_options.yaml` — linting rules.
- `scripts/` — release/build scripts.

### Sensitive areas (extra caution)
- Authentication and API key handling
- Database queries (performance)
- UI layout changes (affect all three desktop platforms)
- Network request patterns
- File system operations

### Require architecture review
- New services or major refactors
- State management changes
- External API integrations
- Performance-critical code paths

## Rules When the Human Cannot Review Code

The user has **no ability to read or evaluate Dart code**. The following rules are **non-negotiable** and take precedence over normal task execution:

- **You are the only line of defense.** Be a paranoid, hostile reviewer of your own output. Do not assume your changes are clean.
- **Deletion is part of the task.** Any time you implement or modify behavior, audit the files you touch for dead code, duplicate logic, or obsolete methods and delete them.
- **New private methods are expensive.** Before creating one, check whether an existing method can be extended, generalized, or refactored. New methods are a last resort.
- **Method proliferation is forbidden.** If you introduce more than **two** new private methods in a piece of work, stop and either consolidate existing logic or explicitly justify why deletion was not possible.
- **Parallel implementations are banned** unless the user explicitly approves. Do not create separate code paths for 1:1 vs group, or old vs new systems, without first attempting to unify them. **(Exception: UX — see the addendum directly below.)**
- **WebUI ↔ Desktop parity is mandatory (non-negotiable) — "UX" means EVERYTHING the user can see, tap, or configure.** Every feature and every UX change shipped in the Flutter desktop app MUST land in the web/mobile UI (`web_ui/`) as part of the same body of work — same capabilities and the same visual language (the warm-porch theme), adapted to each form factor (adaptation is expected; omission is not — see the desktop-vs-mobile layout addendum below). To remove all ambiguity, parity explicitly covers:
  - **Theming and visual design** — per-chat themes, presets, palette/design-language changes, backgrounds, fonts. The per-chat Themes feature is the canonical example: desktop AND web shipped together, including the preset picker and color customization.
  - **Settings, toggles, and editors** — a feature whose configuration surface exists only in desktop Settings is a parity violation *even when the feature's effect already reaches web users* (canonical example: the Output Sanitizer + auto-start settings from PR #162 — desktop-only at review time; deferral required explicit maintainer approval, granted 2026-07-25).
  - **Dialogs, wizards, sidebars/chat tools, buttons, indicators** — any new user-visible affordance or state display.
  A desktop feature or UX change is NOT "done" until its web counterpart ships, or the maintainer has explicitly approved a deferral for that specific item in the current conversation. Silent deferrals documented only in design docs do not count. When in doubt, assume parity is required and ask.
- **UX takes priority over de-duplication (addendum).** When proper UX/UI genuinely requires it, separate or duplicated implementations are acceptable and expected — correct user experience outweighs the anti-duplication rules in this section. The canonical case is **distinct desktop vs. mobile layouts** in the web UI (`web_ui/`): do **not** force a single responsive layout, component tree, or CSS path to serve both form factors when that degrades either one. Build separate desktop and mobile shells/styles (e.g. branch on `useLayout()` `wide`/`isPhone` and scope CSS so the two can't bleed into each other), duplicating as needed for a genuinely good experience on each. This exception covers **presentation/UX only** — it is not a license for duplicated business logic, services, data access, or Realism/Needs engine code, where consolidation still strictly applies.
- **Overlapping / redundant features — offer deprecation or removal** (mandatory). When a request overlaps with or makes an existing feature redundant, proactively offer to deprecate and/or fully remove the now-useless feature as part of the same work. Do not leave dead enum values, old UI surfaces, parallel paths, orphaned tests, or stale docs. Document the rationale in your response, the relevant `docs/Rawhide.md` entry, and any changelog. Ask for confirmation if the removal scope is large, but default to offering the cleanup. (The Image Studio "Visualize N-slider vs. old Message Illustration" work is the canonical precedent.)
- **Mandatory commands at the end of non-trivial work** (run and report results):
  - `flutter analyze --no-fatal-warnings --no-fatal-infos`
  - `dart fix --dry-run` (apply safe fixes where appropriate)
  - Grep/search recently added methods to verify older similar methods are not now dead.
- **UI consistency for creation wizards** (mandatory): All "Create X" flows must use the **same top-bar step indicator pattern** and linear progression as `create_character_page.dart` (horizontal step dots + labels + connecting lines in the AppBar, `AnimatedSwitcher` driven by a `_currentStep` int, `_buildNavButtons` at the bottom). Do not invent side menus, tab bars, or free-jumping section lists for wizards.
- **Compilation gate after any structural change or major refactor** (non-negotiable): After deleting methods, large refactors, or changes to `home_page.dart`/`main.dart`/service init/widget trees, run a full `flutter analyze` (and ideally `flutter build macos` or `flutter run -d macos`) **before** claiming completion. "It looks good" is not sufficient. Leave the tree in a runnable state.
- **All widgets, dialogs, menus, toggles, cards, and surfaces must honor the AppColors system** (non-negotiable): Use `AppColors` from `lib/ui/theme/app_colors.dart` exclusively. Prefer helpers — `backgroundOf/cardOf/surfaceOf/surfaceContainerOf(context)`, `textPrimary/Secondary/Tertiary(context)`, `iconPrimary/Secondary(context)`, `borderOf(context)`, and `AppColors.resolve(context, dark, light)` for custom accents. Hard-coded `Color(0xFF...)` or raw `Colors.whiteXX`/`Colors.blackXX` are forbidden in new or refactored UI (except the few semantic accent constants that already have light variants in AppColors).
- **Warm-porch accent standard for every new widget, button, icon, border, spinner, and surface** (non-negotiable, CI-enforced): The app has ONE warm-porch accent palette. Any new or refactored chrome accent MUST use `AppColors.formMasterAccent` (the const primary amber) or `AppColors.porchAmberOf(context)` (brightness-aware), with `AppColors.onChaosAccent` (near-black ink) as the foreground on any solid amber fill (white-on-amber is unreadable). **Raw `Colors.blueAccent` is banned** — the whole ~225-site cool-blue chrome set was retired to porch amber (see `.claude/changelog.md` "blueAccent → porch amber sweep" clusters 1–4). Do not reintroduce cool-blue (or any other off-palette) chrome for new buttons/toggles/cards/menus. **Verification (mandatory):** the `theme-lint` CI job (`.github/workflows/ci.yml`) fails any PR that *adds* a raw `Colors.blueAccent` line under `lib/**/*.dart`; after adding UI, also grep your diff for stray `Colors.blueAccent`/`Colors.blue`/off-palette hex. **Only exception:** a genuinely *semantic* color (a status/indicator/legend hue whose meaning depends on being non-amber — e.g. Realism trust chips, live-call status colors, the lorebook "always-on vs enabled" 2-state markers) may stay off-palette **only when the maintainer explicitly requests/approves it in the current conversation**, and it MUST carry a trailing `// theme-keep: <reason>` comment (the CI gate's allow-list marker). Absent explicit approval, warm it.
- **Destructive git operations on files are forbidden without explicit approval** (data loss risk): **Never** run `git checkout -- <file>`, `git restore <file>`, `git checkout HEAD -- <file>`, `git checkout <commit> -- <file>`, or anything that discards uncommitted local changes. Work is frequently done to files without immediate commits; these commands silently destroy it. Allowed only if the human explicitly authorizes the exact command in the current conversation. Prefer `git diff`, saving a patch (`git diff > /tmp/backup.patch`), or `git stash push -m "temp" -- <file>` (only when confirmed safe). If a file seems to need a destructive checkout to recover, **stop and ask** instead of acting.

**Hygiene Summary Requirement**: At the end of any response involving non-trivial changes, include a short "Hygiene Summary" covering:
- New private methods added (list them)
- Methods deleted (list them)
- Whether `flutter analyze` is clean
- Any duplication or dead code you chose not to remove and why
- **Barrels + boilerplate on every file touched**: confirm each edited file was
  left on barrel imports (or that its remaining direct imports are all on the
  exemption list, naming which), and what repetition you collapsed while you
  were in there. "None found" is a valid answer; silence is not.

## Code Style & Conventions

### Code File Size Limits & Single Responsibility

To prevent "God files" (historically some `.dart` files exceeded 9,000 lines):
- **Do One Thing and Do It Well**: Every class, widget, or service has exactly one primary purpose. Extract complex sub-domains into distinct, focused files rather than piling them into existing god files.
- **Strict File Size Cap**: Every Dart source file (excluding generated `.g.dart` and third-party code) **must be kept under 500 lines**.
- **Action on Existing Files**: If modifying a file that already exceeds 500 lines (such as `chat_service.dart`), do not grow it. Extract cohesive chunks into new, focused classes under 500 lines.
- **The 1,000-line ratchet is CI-enforced** (maintainer-set 2026-08-02, elimination campaign: `docs/design/god-file-elimination.md`): `test/hygiene/god_file_ratchet_test.dart` + `test/baselines/god_files.json` make the god-file count monotonically decreasing. No file outside the baseline may ever reach 1,000 lines; baseline files may only shrink; a shrink must lower its baseline entry in the same change; below 1,000 the entry is deleted forever. The baseline **only ever loses entries** — adding one requires the maintainer's `approved-test-change` label. The 500 cap above remains the target for new and extracted files; the ratchet sits at 1,000 so routine fixes to mid-size files never fight CI.

### Reuse Existing Code
- **Prefer existing variables and scaffolds** — do not add complexity when unnecessary.
- **Utilize existing functions whenever possible** — reuse patterns that already work.
- **Cost-audit every reuse in its NEW call context** (mandatory): a function that is correct and cheap where it was written can be a regression where you call it. Before reusing, ask: how often does the new call site run (once per event? per message? per widget build/frame during streaming?), and what does the function actually cost (disk I/O, DB query, process spawn, large allocation)? State the answer to "will this slow down or speed up the app?" in your response for any reuse in a hot path. **Synchronous I/O (`existsSync`, `readAs*Sync`, `lengthSync`, `Process.runSync`, DB queries) is banned in widget `build` paths and per-frame/per-token code** — resolve it once and cache/memoize (invalidate on the events that change the answer), or move it off the UI thread. **Verification (mandatory):** the `io-lint` CI job (`.github/workflows/ci.yml`) fails any PR that *adds* a synchronous I/O call under `lib/ui/**`; a line that genuinely cannot run in a build/frame path may carry a trailing `// io-ok: <reason>` comment (the allow-list marker). Canonical incident: `coverImageFileFor` (one `existsSync`, written for once-per-event surfaces) was reused per message bubble per rebuild — invisible on macOS/APFS, 10–100x slower on Windows under Defender, shipped as the 20260716-nightly "app is sluggish / replies don't appear" regression. Cheap-on-the-dev-Mac is not cheap everywhere; platform-asymmetric cost is part of the cross-platform verification duty.
- **Avoid over-engineering** — simpler solutions are better when they achieve the same goal.
- **Leverage shared state** (e.g., `StorageService`) as the single source of truth.
- **Consolidate before extending**: In complex areas (Realism Engine, Needs, group chat), first try to generalize or extend existing methods rather than creating new ones. Parallel helpers for similar functionality are not acceptable. (Presentation exception: distinct desktop vs. mobile UI layouts may be duplicated where UX requires it — see "UX takes priority over de-duplication" above. This applies to layout/CSS only, not logic.)

### Verification
- **ALWAYS run `flutter analyze` after making code changes** — the project is at 0 warnings on the active rule set. New code must not introduce warnings. Never claim changes are "verified" without running it. Variables declared inside `try` blocks are not accessible outside — declare them before the `try` with defaults.
- **Do NOT bulk-run `dart format` / `flutter format` on whole files.** The codebase is mid-migration to the Dart 3.11 "tall style" formatter, so running the new formatter on a not-yet-migrated file rewraps **hundreds of unrelated lines** (and can even introduce lint errors — e.g. splitting a one-line `if (x) return;` trips `curly_braces_in_flow_control_structures`), burying your real change in churn. Match the surrounding style **by hand** in the regions you edit; the Edit tool already preserves it. A whole-file reformat is its own intentional, isolated commit — never a side effect of a feature change.
- **Cross-platform verification is mandatory.** Front Porch AI is a Windows + macOS + Linux desktop app. Every non-trivial change must be checked (or have an explicit plan) so it does not regress on any platform — especially file paths, process spawning, native libraries (sherpa-onnx, onnxruntime, libfpzip), and anything touching `dart:io` or native binaries.
- **Realism & Needs parity is mandatory** (see the dedicated section). Any change to the Realism Engine or Needs simulation must keep 1:1 and group behavior consistent unless explicitly approved otherwise.
- **Because the user cannot review code**, treat every change as if it will be accepted without scrutiny. Leave the codebase strictly cleaner (or at minimum no worse) than you found it.

### Task Completion Rules
- **No skeleton or partial implementations.** Never create stub files, placeholder methods with only TODOs, incomplete classes, or "skeleton" functionality to finish later.
- **All tasks must be completed in full during the turn they are started.** If a request cannot be fully implemented, pass `flutter analyze` (0 errors on changed files), be grepped for dead code, **actually compile and launch** (`flutter run -d macos` or equivalent with no red startup exceptions), and be manually verified — all within a single interaction — do not begin writing the code. Ask the user to clarify scope or break the work into smaller pieces instead.
- This rule takes precedence over "getting something started." Partial progress that leaves the codebase broken or misleading is not acceptable.
- Only mark a task complete after it is fully functional and all verification steps (analyze + grep + manual review) have passed.

**Mandatory Cleanup Requirements (especially when the user cannot review code):**
- Delete any code no longer reachable or needed as part of completing the task.
- Consolidate duplicate or near-duplicate logic instead of leaving parallel implementations.
- Remove any new private methods that became dead or obsolete during the work.
- "It works" is not sufficient — the codebase must be measurably cleaner (or at least not worse) than when you started.

### Realism & Needs System Parity
- The Realism Engine (Bond/Trust/Emotion/Arousal/Fixation) and especially the **Needs/Sims simulation** must maintain full functional parity between 1:1 and group chats at all times.
- Any fix, refactor, behavioral change, new feature, or tuning **must** treat both modes equivalently, unless explicitly discussed and approved as group-only or 1:1-only.
- Core simulation logic (decay rules, step thresholds, catastrophe text, erotic buffers) is intentionally shared. When editing it, you are responsible for ensuring group per-character behavior does not regress or diverge.
- Storage and per-turn orchestration already branch (`_groupRealism` vs scalar fields, group vs 1:1 paths). Orchestration may differ, but the *observable simulation behavior* for a character must feel consistent across modes. When in doubt, default to parity — breaking it without discussion is a regression.

**Anti-Accumulation Rules for Realism/Needs (critical):** This area has historically been the largest source of dead code and duplicated helpers. Any work touching realism, needs, bond, trust, emotion, fixation, group state, or time progression **requires** an explicit dead-code audit of the affected methods in `chat_service.dart`. Actively look for and delete obsolete helper methods. Creating a new private method with "Group", "Needs", "Realism", or "Decay" in the name triggers a requirement to justify why existing methods could not be reused or deleted.

### Cross-Platform Compatibility (critical)
- **Never hardcode Unix paths** (`/tmp`, `/Users/`, `~/`). Use `Directory.systemTemp`, `getApplicationDocumentsDirectory()`, `StorageService.rootPath`, or `path_provider` + `package:path/path.dart` with `p.join()`.
- **Native libraries** (sherpa-onnx, onnxruntime, libfpzip): the sherpa/ort libs ship inside their pub packages for all three platforms; libfpzip is macOS-only (Draw Things is macOS-only software). Never assume a dylib/so/dll path — resolve via the existing helpers (`sherpa_runtime.dart`, `dt_fpzip.dart`).
- **Process management** (KoboldCpp and other external tools): use `Process.start(..., includeParentEnvironment: true)`; expect `process.kill()` differences (Unix SIGTERM vs Windows TerminateProcess).
- **Before marking a task "done"**, either run the affected feature on at least two platforms, or explicitly document the platform-specific limitation + mitigation.

### Dart conventions
- Follow `flutter_lints` rules (see `analysis_options.yaml`).
- camelCase for variables/methods, PascalCase for classes.
- Prefix private members with `_`. Prefer `final` over `var`.
- One class per file (except small related classes). snake_case file names.
- Use barrel files for new or refactored code to reduce import boilerplate.

### Import order
1. Dart SDK (`dart:*`)
2. Packages (`package:*`)
3. Local imports (`../`, `./`)

### Barrel files and import hygiene (policy)
Barrel files reduce repetitive intra-package imports. **17 exist today** — run
`find lib -name '*.dart' | awk -F/ '$NF==$(NF-1)".dart"'` for the live list rather
than trusting this one. The high-frequency ones:
- `package:front_porch_ai/models/models.dart`
- `package:front_porch_ai/utils/utils.dart`
- `package:front_porch_ai/services/services.dart` (curated — only the high-frequency public surface)
- `package:front_porch_ai/services/chat/chat.dart` (the chat domain leaves; `services.dart` deliberately does NOT re-export them)
- `package:front_porch_ai/services/capability/capability.dart`
- `package:front_porch_ai/services/image_prompt/image_prompt.dart`
- `package:front_porch_ai/services/web/util/util.dart`
- `package:front_porch_ai/services/web/tunnels/tunnels.dart`
- `package:front_porch_ai/services/backporch/backporch.dart`
- `package:front_porch_ai/ui/widgets/widgets.dart`
- `package:front_porch_ai/ui/chat_components/chat_components.dart`
- `package:front_porch_ai/ui/dialogs/dialogs.dart`
- `package:front_porch_ai/ui/pages/pages.dart`
- `package:front_porch_ai/ui/pages/repository/repository.dart`
- `package:front_porch_ai/ui/character_creator/character_creator.dart` (+ `widgets/widgets.dart`)
- `package:front_porch_ai/ui/settings/widgets/widgets.dart`
- `package:front_porch_ai/ui/image_studio/image_studio.dart`

**Barrel imports are the required style — solo single-file imports are no
longer "legal forever" (maintainer directive, 2026-08-01).** The previous
wording blessed direct imports as a permanent, acceptable state for
"internal-only or one-off modules"; that clause is REVOKED and is why the
boilerplate accumulated. If a barrel covers the file, you import the barrel.
Converting the stragglers is mandatory ongoing work, not a nice-to-have.

**If no barrel covers it, create one (self-extending rule).** Converting alone
can never finish the job: 1,101 solo imports live in directories that have no
barrel at all. So when you find yourself importing **2+ siblings from the same
un-barrelled directory**, add a barrel for that directory in the same change
and use it. **All seven directories previously listed here as "most needing
one" now HAVE a barrel** (added 2026-08-01, 263 solo imports collapsed across 72
files) — `services/chat`, `services/web/util`, `ui/pages/repository`,
`ui/character_creator`, `ui/dialogs`, `ui/pages`, `services/capability`, plus
`services/image_prompt`, `services/web/tunnels`, `ui/character_creator/widgets`
and `ui/settings/widgets`. Do NOT re-derive that stale list; re-measure before
claiming a directory needs one.

`services/chat` keeps its OWN `chat/chat.dart` barrel — the curated
`services.dart` deliberately does not re-export the chat leaves, and that stays
true. Note `chat.dart` exports only the 59 non-`part` files: the 28
`chat_service_*.dart` part files belong to `chat_service.dart` and must never be
exported.

**The one place a solo import is still right:** a directory where every
importer only ever needs ONE file from it (11 such directories today). Wrapping
a single import in a barrel is ceremony, not hygiene. Don't.

**Migration status: the one-time sweep is DONE (2026-08-01, maintainer-directed).**
Every convertible single-file import in `lib/` was converted to its barrel in
one commit. The rules previously forbade exactly this ("no dedicated import
cleanup effort", "mass automated find/replace ... is forbidden"); the
maintainer overrode them to clear the backlog in one pass rather than bleed it
out opportunistically forever. That override was for the sweep itself and is
now spent — **do not run another mass import rewrite.** Keeping it clean is
now a per-file duty:

**Every file you touch, you leave on barrels (mandatory).** Opening a file for
ANY reason — a one-line bug fix, a feature, a rename — obliges you to convert
its convertible single-file imports to the barrel *in that same change*. This
is no longer "opportunistic" and it is not optional. The codebase accumulated
hundreds of hand-written import lines precisely because "convert it if you
happen to be in there" had no teeth. **A diff that edits a file and leaves a
convertible import block behind is incomplete work.**

**Same visit, same rule for boilerplate (mandatory).** While you are in that
file, collapse the repetition you find: an identical widget / `ListTile` /
`PopupMenuItem` shape pasted N times becomes one helper; a copy-pasted guard
becomes one function; three private copies of the same filter become one
shared function. Two precedents that set this rule — `homeCardMenuItem()`
replaced ~14 copies of an 18-line `PopupMenuItem`/`ListTile` block across two
card files (and brought `character_grid_card.dart` back *under* the 500-line
cap while ADDING a menu entry), and `buildFolderPickView()` replaced three
private copies of the same folder-filtering logic. **Extraction that shrinks
the file always beats adding to it.**

**When you add a service/model/widget used from 3+ locations** and not purely
internal, add the export to the appropriate barrel **in the same PR**. The
sweep found `picker_prefs.dart` (24 importers), `model_manager.dart` (11),
`engine_health.dart`, `expression_pack_service.dart`, `model_fetch.dart` and
`realism_form_section.dart` all missing from their barrels — every one of
those absences forced N callers to hand-write a single-file import. This is
the rule that actually prevents a repeat; the sweep only cleared the symptom.

**The only exemptions** are the cases below. If a file you touched still has
direct imports afterwards, they must ALL be from this list — and say so in your
Hygiene Summary rather than leaving it unexplained.

**The only structural exemptions** (everything else must be converted):
- A file that lives in its own barrel's directory — it would self-import.
  `lib/services/foo.dart` importing `lib/services/bar.dart` is correct and
  unavoidable.
- Part files (`part of`), which cannot carry imports at all.
- A directory where importers only ever need one file from it (see above).

Note `show`/`hide`/`as` is NOT an exemption: `import 'models.dart' show
CharacterCard;` is valid and preferred over reaching for the single file. Only
keep the direct import when the barrel genuinely reintroduces a collision the
`hide` was there to solve (`import database.dart hide World` is that case —
and `database.dart` has no barrel anyway).

### Riverpod patterns (for new code)
- **The decision rule (maintainer-set, 2026-07-25): Riverpod is allowed when the state can be fully owned and tested without replacing `ChatService`, `StorageService`, or the `main.dart` provider graph; otherwise Provider stays.** There is NO project to migrate the whole codebase — a full Provider→Riverpod conversion was explicitly evaluated and rejected (dual-model review): it would churn ~634 consumer call sites, 39 ChangeNotifier services, the delicate `main.dart` init order, and the Realism/Needs parity hub for zero user-visible benefit. Do not start one, and do not convert files "while you're in there" unless the feature you're shipping needs it.
- **Qualifies for Riverpod:** new self-contained features (the weather provider — pure engine + `@riverpod` codegen + `ProviderContainer` tests — is the template), UI-local ephemeral state, read-only projections over existing public APIs, greenfield modules outside the ProxyProvider chain.
- **Off-limits as "migration work":** `ChatService` + Realism/Needs orchestration, `StorageService`, the `main.dart` MultiProvider/ProxyProvider graph, mass UI conversion, test-suite rewrites, backend/engine lifecycle services, the web facade's ChatService binding.
- **Revisit full migration only when** ChatService has naturally shrunk to a thin coordinator via leaf extraction AND Realism parity has strong automated tests — then it's a modest finishing step, not a gamble.
- Use `AsyncNotifier` for async operations.
- `ref.watch` for reactive dependencies, `ref.read` for one-time actions.
- Proper error handling with `AsyncValue`.
- Prefer `@riverpod` codegen style (maintainer directive 2026-07-21): family parameters as plain named args, autoDispose default.

### Error handling
- Never silently swallow errors; always log or surface to the user.
- Test error conditions explicitly.
- Mock external dependencies in unit tests.

## Testing Expectations

- **Goldens are Linux-gated.** 18 widget golden files carry `@TestOn('linux')` and the
  `golden` tag, so a green macOS `flutter test` NEVER runs them. Run
  `./scripts/ci-local.sh` (the fpai-golden linux/amd64 container) before pushing — the
  script's own header notes this is how a red-CI commit once reached Rawhide.
- **E2E lives in `integration_test/`** — the authoritative inventory (covered
  surfaces, priority order for the rest, rules for adding a suite) is
  `docs/design/e2e-coverage-map.md`; update it in the same PR as any new suite.
  Today: `app_smoke_test.dart` (1:1 journey — realism, needs, chaos, objectives,
  journal, persistence, backend-failure resilience, worlds + lorebook injection),
  `group_smoke_test.dart` (per-speaker `_groupRealism` isolation + settle-guarded
  reload persistence), `group_realism_wiring_test.dart` (post-reload turns),
  `realism_off_test.dart` (engine disabled), `theme_interaction_test.dart` (every
  theme preset must leave bubble controls hit-testable),
  `settings_persistence_test.dart` (the "Stays Put" class: settings survive page
  reopens + a settings-layer reload), `message_actions_test.dart` (edit /
  regenerate / delete-with-needs-refund through the real bubble controls). CI
  globs `integration_test/*_test.dart` and
  runs ONE invocation per file on macOS/Windows/Linux — a new suite is picked up
  automatically. Before capturing or persist-asserting chat state in ANY suite,
  `await d.waitSendable()` — the settling window (`isSettlingTurn`) is part of
  the turn, and skipping it is exactly the Windows reload flake.
- **Interaction coverage is the point.** Goldens answer "does it look right"; only an
  E2E tap answers "can a user actually do this". The 10-theme dead-button bug
  (512e4803) shipped with pixel-identical goldens and a fully green suite because
  nothing in CI had ever pressed a button. Prefer a few BROAD hit-test sweeps over a
  guard per widget.
- **Do not edit a test to make CI green.** `.github/workflows/test-integrity.yml` runs
  on `pull_request_target` (from the base branch, so a PR cannot weaken it) and FAILS
  any PR that modifies or deletes an existing test, golden, baseline,
  `test/deps/dependency_floors.json`, workflow, or `analysis_options.yaml`. Adding NEW
  test files never blocks. Clearing it needs a maintainer's `approved-test-change`
  label — an author cannot self-approve. `.github/CODEOWNERS` is the second gate.
  Precedent: PR #172 edited the dependency floors to pass, which would have
  reintroduced the sqlite3 3.2.0 → 2.9.4 downgrade that shipped v1.1.0 with no SQLite
  engine on Linux.
- Aim for **80%+ coverage** on new code.
- Test error conditions and edge cases.
- Mock external dependencies.
- Test async operations properly.

### Reviewing Sub-Agent / AI-Generated Work
- **Always perform a proper manual code review** of the actual changes before accepting the work.
- Do **not** rely solely on a sub-agent's self-report or the fact that `flutter analyze` passes.
- Read the modified code; evaluate logic, edge cases, consistency with existing architecture, and potential regressions.
- Only mark tasks complete after personal verification.
- Sub-agents must **never** produce skeleton code, stub files, or partial implementations.

## Commit Messages

Use the conventional commit prefix on the first line (`type(scope): short summary`), but **do not stop there**. Write for a human reading the git log months later. Explain:
- What the actual problem was
- Why it mattered (impact on users or developers)
- How it was fixed and why that approach was chosen
- Any important context, gotchas, or trade-offs

**Bad (too terse):**
```
fix(lorebook): correct keyword matching regex to use proper word boundaries
```

**Good (clear and relatable):**
```
fix(lorebook): keyword triggers were completely dead even for single-word keys

The regex in _matchKeyword was written as RegExp(r'\b${key}\b') inside
a Dart raw string. Because raw strings don't interpolate ${}, it was
literally searching for the text "\bkey\b" (with literal backslashes)
instead of using word boundaries.

This meant no keyword-based lorebook entry would ever activate
(isTriggered stayed false), which is why the green dot in the sidebar
never lit up and nothing ever appeared in the Context Viewer — even
when the user typed the exact trigger word.

Fixed by using explicit string concatenation instead of ${} inside
a raw string so the regex is actually built correctly.
```

Write like you're explaining the change to a teammate who wasn't in the room.

## Changelog Tracking

After making any code changes, append an entry to `.claude/changelog.md` with:
- Date (UTC)
- Files changed
- Brief reason for the change
- Commit hash (if committed)

This enables regression tracing.

## User-Facing Changelog for the Update Dialog

The in-app "Update Available" dialog renders a non-technical "What's New" section (sourced from the GitHub release body). Users who never visit GitHub or Discord rely on this text.

You are responsible for keeping it current:
- User-facing "What's New" notes go in `docs/Rawhide.md` — short benefit-oriented bullets with emojis (e.g. "🎭 Character Expressions now support sidebar mode").
- When preparing a release, use the relevant `docs/Rawhide.md` content for the GitHub release body.
- Never use raw commit messages, `.claude/changelog.md` contents, or technical PR lists — those are internal.
- `docs/release-notes.md` remains the long-form historical document.
- Update `docs/Rawhide.md` as part of any user-visible work.

## Community

- Discord: https://discord.gg/e4tET6rpdv

## Git Contributions

- Never amend or rewrite commits from other authors.
- This file (CLAUDE.md) is committed to the repository so contributors and their AI agents can follow the project's guidelines.
