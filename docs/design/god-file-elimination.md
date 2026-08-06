# God-File Elimination Campaign

**Mandate (maintainer, 2026-08-02):** "I want no god files left in the program.
I really only care about the ones that are 1,000 plus LOC."

**Definition of done:** `test/baselines/god_files.json` is `{}`. The ratchet
test (`test/hygiene/god_file_ratchet_test.dart`) is the single source of truth
for progress and the permanent guarantee it never regresses — see the CLAUDE.md
"Code File Size Limits" section for the four rules.

## Census at campaign start (2026-08-02: 26 files, 22,650 excess lines)

The live list is the baseline file; this snapshot is for orientation only.

## Tranches, in proposed execution order

### Tranche A — UI pages & dialogs (15 files, lowest risk)
`chat_page` 3521 · `create_group_chat_page` 3131 · `edit_character_page` 2059 ·
`create_character_page` 1999 · `message_bubble` 1866 · `story_reader_page` 1617 ·
`world_management_page` 1577 · `user_persona_page` 1477 · `tts_settings_dialog`
1474 · `story_dashboard_page` 1446 · `generation_options_tab` 1351 ·
`model_settings_dialog` 1277 · `voice_media_tab` 1273 · `edit_group_page` 1129 ·
`ui_settings_dialog` 1116

Pattern is settled precedent: the settings_page split (tabs + `part` files +
`rebuildState` bridge) and the group_settings split (5ab5b21c). Sections become
widgets/parts under a page-named directory; zero behavior change; goldens +
theme E2E + smoke suites are the net. `create_group_chat_page` and `chat_page`
were already named "next" in the standing shrink effort. Wizards keep the
mandatory step-indicator pattern.

### Tranche B — services (8 files, medium risk: behavior-identical extraction)
`image_gen_service` 2011 · `story_pipeline_service` 1977 · `character_repository`
1351 · `realism_evals` 1201 · `tts_service` 1191 · `relationship_service` 1138 ·
`creator_state_engine` 1031 · `chat_service_generation` 1978 (part of
ChatService — extract leaves, same rules as Tranche C's hub work).

Realism-touching ones (`realism_evals`, `relationship_service`,
`chat_service_generation`) carry the full parity duty: 1:1 vs group audited,
dead-code audit, the works.

### Tranche C — the protected core (3 files, maintainer sign-off per file)
- **`chat_service.dart` 4637** — the hub. Its size is class-body content:
  fields + ~10 giant `late final` leaf-service constructions (hundreds of
  callback wirings) + thin delegates. Extensions in `part` files cannot hold
  fields, but initializers can call extension methods — `late final _x =
  _buildX();` with `_buildX()` in a part is the lever. Wiring moves; state
  stays; no behavior change.
- **`main.dart` 2105** — service init order is delicate. Split into ordered
  startup builders that make the order *explicit* rather than positional.
- **`database.dart` 3716 — RE-SCOPED INTO THE CAMPAIGN (maintainer decision
  2026-08-06, superseding the 2026-08-03 exclusion).** The blocker was drift
  risk to user data; a feasibility spike answered it empirically: Drift's
  codegen is file-layout-insensitive — moving table classes to `part` files
  with declaration order preserved and the `@DriftDatabase(tables:[...])`
  list untouched regenerates `database.g.dart` BYTE-IDENTICAL (MD5-verified,
  including after `build_runner clean`). The split therefore carries a hard
  gate no other file had: **the regenerated `database.g.dart` must be
  byte-identical, or the split does not ship.** Additional gates: verbatim
  multiset audit of the `onUpgrade` ladder, full suite, goldens, and the
  backup/restore E2E. The campaign's finish line is now a baseline of `{}`.

**Decisions log (2026-08-03):** database.dart excluded; main.dart confirmed in
scope; execution order confirmed A → B → C, starting with `chat_page.dart`.
**Decisions log (2026-08-06):** database.dart re-scoped (spike-proven, hard
byte-identical-regen gate); Tranche C authorized to proceed without per-file
sign-off ("go ahead and do Tranche C on your own"), standard gates unchanged.

## The provability rule (added 2026-08-03, maintainer-prompted)

The maintainer asked the load-bearing question: "our E2E doesn't cover any
part of character creation — is this safe and provable?" Verbatim moves +
analyzer make a split *safe*; they do not make it *provable*, because the
hand-written seams are new code and the themes bug proved a seam can compile,
paint, and still eat every tap. Therefore:

**A page with no interaction coverage gets a pump test BEFORE it is split.**
Green on the unsplit file → split → still green. Pages that already have
step-walking goldens (create_character_page) or E2E coverage are exempt.
The two splits that predated this rule got their nets retroactively:
`edit_character_page_interaction_test.dart` (tab walk) and
`create_group_chat_page_interaction_test.dart` (full 8-step wizard walk).

## Per-split definition of done (every file, no exceptions)
1. Behavior-identical: extraction only, no logic edits smuggled in.
2. Extracted pieces land under 500 lines each (the CLAUDE.md cap for new files).
3. Baseline entry lowered/deleted in the same commit (the ratchet forces this).
4. `flutter analyze` clean · full suite green · `./scripts/ci-local.sh` green ·
   E2E on the affected surface.
5. Dead-code audit of the donor file while it is open; barrel-import duty per
   CLAUDE.md; Hygiene Summary reported.
6. Realism/Needs files additionally: 1:1 vs group parity audit.

## Progress log
- 2026-08-02 — Ratchet + baseline landed (26 entries). Campaign start (126383c3).
- 2026-08-02 — First kill: `chat_page` 3,521 → 979 (8ef67114); retroactive
  interaction nets for the two pre-rule splits (e91afa92).
- 2026-08-04 — Tranche A ten-file session, each with a proven-to-fail
  interaction net before its split: persona/worlds/tts-settings/story-reader
  (da3efc5b), story-dashboard/generation-options/model-settings/voice-media
  (816f915d), edit-group/ui-settings (927959f7, "TRANCHE A COMPLETE" — the
  message_bubble straggler remained). `create_character` split rode the
  realism time-travel fix (730eff3d). Baseline 22 → 12.
- 2026-08-06 — Tranche B round 3, the Realism-touching file: `chat_service_generation`
  1,956 → 324-line shell + `_GenTurn` per-turn carrier class + 6 sibling
  `chat_service_generation_{blocks,plan,rag,request,stream,postgen}.dart`
  parts (all < 500 lines) + a pure `generation_error_messages.dart` leaf
  (barrel-exported, with a proven-to-fail unit test). The file was a single
  ~1,886-line `_generateResponse` method with no member-level seams, so the
  split is a phase decomposition rather than a member move: every moved block
  is byte-verbatim except the mechanical `x` → `t.x` carrier rename for the
  ~36 locals crossing phase boundaries. The stream phase's user-cancel
  `return;` became a `Future<bool>` protocol (`true` = aborted; the shell does
  `if (await _consumeGenerationStream(t)) return;`) since a phase method can
  no longer exit `_generateResponse` directly. `_getMemorySourceIds`
  (RAG-only caller) relocated verbatim from `chat_service.dart` into the new
  RAG part to offset the added `part` directives against the ratchet — net
  chat_service.dart 4,583 → 4,547. All 30 1:1-vs-group branches landed whole
  in one destination file per the split map's §4 table; none straddle a seam.
  CLAUDE.md's "Tracing Realism/Needs" section now names
  `chat_service_generation_postgen.dart` for post-gen finalization.
  `image_gen_service` shipped in the same round: 2,011 → 498-line shell +
  5 parts + `image/image_gen_types.dart` leaf with a new `image/image.dart`
  barrel; the 19 fake-pinned interface members stay real class members (the
  9 big ones as one-line forwarders to `_xImpl` extension bodies); the map's
  dead-code candidates were correctly KEPT after re-grep found the new
  801-line provability net now pins them. **TRANCHE B COMPLETE.** Baseline
  5 → 3: only Tranche C remains (`chat_service.dart` 4,547, `main.dart`
  2,105, and the re-scoped `database.dart` 3,716). **Gates:** analyze 0 · `dart fix --dry-run` clean · ratchet green
  at 4 · targeted (`prompt_plan`, `prompt_plan_section_texts`,
  `regen_chip_attach`, `generation_stream_behavior`,
  `generation_error_messages` [new, proven-to-fail], `turn_speaker_resolver`,
  `stop_sequences`, `output_sanitizer_regex`, `llm_unreachable`) all green ·
  E2E `app_smoke` + `swipe_fork_cancel` (the H2 cancel path) +
  `group_smoke` (parity) on macOS, all green.
- 2026-08-06 — Tranche B round 1 + the Tranche A straggler, from
  workflow-generated split maps audited by hand (line-multiset audit per
  file): `message_bubble` 1,760 → 249 shell + 6 parts; `realism_evals`
  1,201 → 339 shell + 3 parts (byte-verbatim move, public extensions for
  cross-library resolution); `relationship_service` 1,138 → 367 shell +
  3 parts + new barrel-exported `RelationshipTiers` leaf (dead
  `buildRelationshipStateSnapshot` deleted; `loadScalars` kept on the class
  body so callers reaching the service through `ChatService` still resolve
  it without importing the library). Baseline 12 → 9.
- 2026-08-06 — Tranche B round 2, nets-first (33 provability tests landed
  green on the unsplit code in dd284c48, every pin negative-checked; the TTS
  net's authoring pass found and 2908ba9a fixed the "dollar one" markdown-link
  bug): `tts_service` 1,191 → 244 shell + 3 parts (dead 97-line
  `concatenateWavFiles` duplicate of WavUtils deleted); `character_repository`
  1,351 → 410 shell + 3 parts (dead `removeCharacter`/`setTtsVoice` deleted;
  the six fake-pinned members stay real class members); `creator_state_engine`
  1,031 → 243 shell + 3 parts + `chargen_json.dart` leaf; `story_pipeline_service`
  1,977 → 183 shell + 4 parts + four pure leaves under `services/story/` with a
  new `story.dart` barrel (prompts moved byte-identical — fake_backend's
  prompt-opener routing E2E-verified). Two map corrections now settled
  convention: cross-library callers force PUBLIC extension names, and split
  parts call a `_notify()` shell forwarder instead of @protected
  notifyListeners. Baseline 9 → 5; only chat_service, main, image_gen_service,
  chat_service_generation (+ the excluded database.dart) remain.
- 2026-08-06 — The re-scoped `database.dart` and `main.dart`, same night:
  `database.dart` 3,716 → 276 shell + 10 parts (two contiguous
  declaration-order-preserving table slices, the repair machinery, the
  `onUpgrade` ladder byte-verbatim in a private extension — the audit residue
  contained NOT ONE ladder line — data migrations, and five query extensions).
  **The hard gate held: `database.g.dart` regenerated BYTE-IDENTICAL five
  times total** (three in the worktree incl. after `build_runner clean`, once
  centrally after port, plus the original spike). One `show`-clause discovery:
  `insertCharacterReturningId` stays a class member (a protected test imports
  `show AppDatabase` and extension members don't ride the class name through
  `show`). The migrations part is 749 lines — deliberate 500-target exception;
  a seam inside the ladder would be less safe than a long file.
  `main.dart` 2,105 → 453 shell + 6 parts (five-phase startup in identical
  order, the 31-provider graph moved as one block — the StoryPipelineService
  ProxyProvider2 update closure verified char-for-char identical — lifecycle/
  recovery/migration/reunification extensions, 22 setState→_rebuild sites,
  `_dbHealthy` hoisted top-level). Boot-proven: app_smoke + backup_restore E2E
  plus a real `flutter run -d macos --release` cold boot with the phase
  sequence verified in the logs. Baseline 3 → 1: only `chat_service.dart`
  (4,547) remains, in flight.
- 2026-08-06 — **The finale: `chat_service.dart`**, 4,547 → 1,720 shell +
  8 parts via the settled lever (~38 giant `late final` constructions became
  one-line fields calling `_buildX()` builders in four wiring parts —
  realism/evals/memory/injection — laziness preserved so init order is
  untouched; four method-cluster parts — send/turn_flow/message_ops/
  guest_flow — moved whole). The ~60 fake-pinned members stayed on the class;
  every moved block whitespace-normalized-diffed against the original
  (~50 blocks, all byte-identical; the splitter's own hostile review caught
  and reverted its only two accidental rewraps before reporting). Gates:
  analyze 0 · 43 parity tests · full suite · goldens · app_smoke +
  group_smoke + group_realism_wiring + message_actions E2E. Baseline entry
  LOWERED 4,547 → 1,720 (not deleted): the shell is under 500 short of the
  1,000 bar and needs the documented "round 4" (condense extraction-history
  banners, move remaining small getters, possibly rebase the golden fakes
  onto a narrower interface — a protected-test decision) to leave the
  baseline. **Campaign state: 21 files fully eliminated + the hub at 38% of
  its size; the baseline holds ONE entry.** Round 4 is a maintainer-morning
  decision, not an overnight one.
