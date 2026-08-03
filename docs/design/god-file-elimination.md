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
- **`database.dart` 3717 — OUT OF SCOPE (maintainer decision 2026-08-03).**
  It keeps a permanent baseline entry; the campaign's finish line is a
  baseline containing exactly this one file. Do not propose splitting it
  again without a new maintainer decision.

**Decisions log (2026-08-03):** database.dart excluded; main.dart confirmed in
scope; execution order confirmed A → B → C, starting with `chat_page.dart`.

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
- 2026-08-02 — Ratchet + baseline landed (26 entries). Campaign start.
