// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// This file is part of Front Porch AI.
//
// Front Porch AI is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Front Porch AI is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with Front Porch AI. If not, see <https://www.gnu.org/licenses/>.

// PROVABILITY NET for the future split of
// lib/ui/character_creator/creator_state_engine.dart (see
// docs/design maps/creator_state_engine.map.md). This file exists to be
// GREEN before the split and to STAY GREEN after it, proving the split moved
// code verbatim.
//
// test/golden/creator/creator_engine_golden_test.dart already pins
// saveCharacter and quick-mode generateFromMode (the future "shell" /
// Cluster A + a slice of Cluster D). It deliberately does NOT touch:
//   - the guided and automated mode assemblers (future
//     creator_state_engine.modes.dart / Cluster C) — the field-labeling,
//     '. '-joining, and NSFW-gating logic that builds the `concept` string
//     handed to the LLM, and (automated only) the post-hoc override that
//     replaces the model's description with the user-assembled text;
//   - randomizeName (future creator_state_engine.tools.dart / Cluster B) and
//     the forgiving 3-stage JSON extractor it depends on (future
//     chargen_json.dart / Cluster E, H4: the ONLY non-verbatim rename in the
//     whole split).
//
// A verbatim split cannot change what these produce. If it silently does —
// a clause dropped while re-pasting a 100+ line method into a new part file,
// a static reference (H5) that stops resolving, the H4 rename missing one of
// its 3 call sites — these tests catch it because they assert on the actual
// downstream artifact (the prompt text handed to the LLM, or the final
// card), not on internal wiring.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/database/database.dart';
import 'package:front_porch_ai/services/backend_manager.dart';
import 'package:front_porch_ai/services/kobold_service.dart';
import 'package:front_porch_ai/services/llm_provider.dart';
import 'package:front_porch_ai/services/llm_service.dart';
import 'package:front_porch_ai/services/open_router_service.dart';
import 'package:front_porch_ai/services/storage_service.dart';
import 'package:front_porch_ai/services/user_persona_service.dart';
import 'package:front_porch_ai/ui/character_creator/creator_state.dart';
import 'package:front_porch_ai/ui/character_creator/creator_state_engine.dart';

import '../../golden/support/creator_test_support.dart';

/// A scripted LLM that (a) records every prompt it was asked to generate from
/// and (b) always answers with the same canned response, counting calls. The
/// same harness shape as `creator_engine_golden_test.dart`'s `_ScriptedLlm`
/// (reused pattern, not the same private class — that one can't be imported
/// across library files).
class _ScriptedLlm extends LLMService {
  _ScriptedLlm(this.response);
  final String response;
  int callCount = 0;
  final List<String> capturedPrompts = [];

  @override
  Stream<String> generateStream(GenerationParams params) async* {
    callCount++;
    capturedPrompts.add(params.prompt);
    yield response;
  }

  @override
  bool get isReady => true;

  @override
  String get backendName => 'scripted-test';
}

/// Minimal LLMProvider whose active service is the scripted fake — identical
/// shape to the golden suite's harness.
class _FakeLLMProvider extends LLMProvider {
  _FakeLLMProvider(
    this._svc,
    KoboldService k,
    OpenRouterService o,
    StorageService s,
    BackendManager b,
  ) : super(k, o, s, b);
  final LLMService _svc;

  @override
  LLMService get activeService => _svc;
  @override
  BackendType get activeBackend => BackendType.kobold;
  @override
  bool get hasManagedProcess => true;
}

_FakeLLMProvider _makeProvider(LLMService svc, StorageService storage) {
  return _FakeLLMProvider(
    svc,
    KoboldService(storage),
    OpenRouterService(),
    storage,
    BackendManager(storage),
  );
}

/// One canned chargen JSON reused for every LLM call in a run (base card,
/// interview turns, enrichment, example dialogue, lorebook, greetings, image
/// prompt) — every call in the pipeline tolerates the same blob, exactly as
/// the existing quick-mode golden proves. `entries: []` deliberately forces
/// the separate post-interview lorebook call, matching the existing golden.
String _cannedCardJson({String sentinel = 'ZZSENTINELZZ'}) => jsonEncode({
  'description':
      '$sentinel {{char}} is a wandering cartographer who maps the drowned '
          'coast, sketching ruins the tide reveals at dawn.',
  'personality':
      '$sentinel Curious, meticulous, quietly brave; speaks in measured, '
          'vivid observations and never leaves a map unfinished.',
  'scenario':
      '{{user}} finds {{char}} pinning a half-drawn chart to a tavern wall.',
  'first_message':
      '"You have the look of someone who is also lost," {{char}} says.',
  'example_dialogue': '{{user}}: Hello\n{{char}}: The roads moved again.',
  'system_prompt': '',
  'tags': ['explorer'],
  'image_prompt': 'a cartographer at a candlelit table, portrait',
  'lorebook': {'entries': []},
});

/// Builds the persona service + persona DB the same way the wizard would
/// hand it to the engine (empty roster — exercises the empty-persona path,
/// same as the existing golden's quick-mode test).
Future<UserPersonaService> _makePersonaService() async {
  final db = AppDatabase.forTesting();
  addTearDown(() async => db.close());
  final persona = UserPersonaService(db);
  addTearDown(persona.dispose);
  return persona;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupPathProviderMock();

  group('CreatorEngine.generateFromMode — guided assembler', () {
    test(
      'guided mode joins labeled fields into the concept and OMITS NSFW '
      'labels when NSFW is off',
      () async {
        final storage = await makeGoldenStorage();
        final llm = _ScriptedLlm(_cannedCardJson());
        final provider = _makeProvider(llm, storage);
        addTearDown(provider.dispose);
        final persona = await _makePersonaService();

        final state = CreatorState();
        addTearDown(state.dispose);
        state.creatorMode = CreatorMode.guided;
        state.nameController.text = 'Wren Ashby';
        state.guidedAppearanceController.text = "toned swimmer's build";
        state.guidedRaceController.text = 'half-elf';
        state.generationDetail = 'Detailed';
        state.nsfwEnabled = false;
        state.guidedNsfwKinksController.text = 'should never appear';

        await state.generateFromMode(
          llmProvider: provider,
          storage: storage,
          personaService: persona,
        );

        expect(
          llm.callCount,
          greaterThan(0),
          reason: 'guided generation must actually drive the model',
        );
        expect(llm.capturedPrompts, isNotEmpty);
        final basePrompt = llm.capturedPrompts.first;

        // The field-labeling + '. '-join in _generateGuided's `parts` list
        // (Cluster C) flows straight into `Concept: $concept` in the base
        // prompt (character_gen_prompts.dart) — a copy/paste slip while
        // moving this into the modes part would change or drop the label.
        expect(
          basePrompt,
          contains("Physical build: toned swimmer's build"),
          reason: 'the guided appearance field must reach the concept '
              'under its labeled form',
        );
        expect(
          basePrompt,
          contains('Race/Species: half-elf'),
          reason: 'the guided race field must reach the concept',
        );

        // NSFW-gated fields must be absent when nsfwEnabled is false — the
        // `if (nsfwEnabled) { add(...) }` block in _generateGuided.
        expect(
          basePrompt,
          isNot(contains('should never appear')),
          reason: 'NSFW-only guided fields must not leak into the concept '
              'when NSFW is off',
        );

        // generationDetail: 'Detailed' resolves through the STATIC
        // `CreatorState.generationDetailOptions` map (H5) into
        // descriptionDetail, which only shows up in the base prompt when
        // generateDescription is true (guided always passes true).
        expect(
          basePrompt,
          contains('3-4 paragraphs (300-500 words max)'),
          reason: 'generationDetail must resolve through the static options '
              'map into the description-length instruction',
        );

        expect(state.isGenerating, isFalse);
        expect(state.currentStep, 4);
      },
    );

    test('guided mode includes labeled NSFW fields when NSFW is on', () async {
      final storage = await makeGoldenStorage();
      final llm = _ScriptedLlm(_cannedCardJson());
      final provider = _makeProvider(llm, storage);
      addTearDown(provider.dispose);
      final persona = await _makePersonaService();

      final state = CreatorState();
      addTearDown(state.dispose);
      state.creatorMode = CreatorMode.guided;
      state.nameController.text = 'Wren Ashby';
      state.nsfwEnabled = true;
      state.guidedNsfwKinksController.text = 'praise, aftercare';

      await state.generateFromMode(
        llmProvider: provider,
        storage: storage,
        personaService: persona,
      );

      expect(llm.capturedPrompts, isNotEmpty);
      expect(
        llm.capturedPrompts.first,
        contains('Turn-ons/kinks: praise, aftercare'),
        reason: 'NSFW guided fields must reach the concept when NSFW is on',
      );
    });
  });

  group('CreatorEngine.generateFromMode — automated assembler', () {
    test(
      'automated mode OVERWRITES the model description with the assembled '
      'appearance + NSFW text (post-hoc override survives the model call)',
      () async {
        final storage = await makeGoldenStorage();
        const sentinel = 'ZZSENTINELZZ';
        final llm = _ScriptedLlm(_cannedCardJson(sentinel: sentinel));
        final provider = _makeProvider(llm, storage);
        addTearDown(provider.dispose);
        final persona = await _makePersonaService();

        final state = CreatorState();
        addTearDown(state.dispose);
        state.creatorMode = CreatorMode.automated;
        state.nameController.text = 'Sable Marrow';
        state.conceptController.text =
            'A wandering elf ranger seeking her lost brother.';
        state.race = 'Elf';
        state.bodyType = 'Athletic';
        state.nsfwEnabled = true;
        state.chestSize = 'Modest';
        state.experience = 'Adventurous';
        state.dominance = 'Switch';
        state.selectedKinks = {'Praise'};
        state.outfitVibe = 'Leather armor';

        await state.generateFromMode(
          llmProvider: provider,
          storage: storage,
          personaService: persona,
        );

        expect(
          llm.callCount,
          greaterThan(0),
          reason: 'automated generation must actually drive the model',
        );

        final card = state.generatedCard;
        expect(card, isNotNull);

        // The exact literal `_generateAutomated` builds by hand from the
        // fixture above, mirroring the concatenation order in the method
        // (concept, then '. Physical appearance: ...', then the joined NSFW
        // sentence fragments) — computed independently of the engine so this
        // is a real behavioral pin, not a tautology.
        const expectedEnriched =
            'A wandering elf ranger seeking her lost brother.. Physical '
            'appearance: Elf race/species, Athletic build, Modest chest. '
            'Sexual experience: Adventurous. Dominance: Switch. Kinks: '
            'Praise. Typical outfit vibe: Leather armor';
        expect(
          card!.description,
          expectedEnriched,
          reason: 'automated mode must overwrite the model-authored '
              'description with the user-assembled appearance/NSFW text — '
              'the model never gets the final say on description in this '
              'mode',
        );
        expect(
          card.description,
          isNot(contains(sentinel)),
          reason: 'the post-hoc override must fully replace the model '
              'output, not merely append to it',
        );

        expect(state.isGenerating, isFalse);
        expect(state.currentStep, 4);
      },
    );

    test(
      'automated mode omits NSFW appearance/trait text when NSFW is off',
      () async {
        final storage = await makeGoldenStorage();
        final llm = _ScriptedLlm(_cannedCardJson());
        final provider = _makeProvider(llm, storage);
        addTearDown(provider.dispose);
        final persona = await _makePersonaService();

        final state = CreatorState();
        addTearDown(state.dispose);
        state.creatorMode = CreatorMode.automated;
        state.nameController.text = 'Sable Marrow';
        state.conceptController.text = 'A wandering elf ranger.';
        state.race = 'Elf';
        state.bodyType = 'Athletic';
        state.nsfwEnabled = false;
        // Set but must be ignored while nsfwEnabled is false.
        state.chestSize = 'Modest';
        state.experience = 'Adventurous';
        state.outfitVibe = 'Leather armor';

        await state.generateFromMode(
          llmProvider: provider,
          storage: storage,
          personaService: persona,
        );

        final card = state.generatedCard;
        expect(card, isNotNull);
        expect(
          card!.description,
          'A wandering elf ranger.. Physical appearance: Elf race/species, '
          'Athletic build',
          reason: 'NSFW appearance/trait fragments must be excluded from '
              'the assembled description while NSFW is off',
        );
      },
    );
  });

  group('CreatorEngine.randomizeName — JSON repair leaf', () {
    test(
      'recovers the name when an earlier field has a stray unescaped quote '
      '(stage 1 direct-parse AND stage 2 newline/comma repair both fail — '
      'only the stage 3 local regex fallback can)',
      () async {
        final storage = await makeGoldenStorage();
        // The "description" value above contains an unescaped internal
        // quote ("cursed"), so:
        //  - stage 1 (json.decode) throws: after the stray quote the parser
        //    hits the bare word `cursed` where a comma/brace was expected.
        //  - stage 2 (escape raw newlines + strip trailing commas, then
        //    retry json.decode) changes nothing here — there are no raw
        //    newlines or trailing commas to fix — so it hits the SAME
        //    FormatException.
        //  - stage 3 (regex `"name"\s*:\s*"` + local char scan for the
        //    closing quote) never looks at the broken "description" field at
        //    all; it only has to be right about "name", which is clean.
        const malformed = '''
Sure! Here's a name for your character:
```json
{"description": "A drifter with a "cursed" locket", "name": "Elandra Duskwhisper"}
```
''';
        final llm = _ScriptedLlm(malformed);
        final provider = _makeProvider(llm, storage);
        addTearDown(provider.dispose);

        final state = CreatorState();
        addTearDown(state.dispose);
        state.selectedArchetype = 'wandering rogue';

        await state.randomizeName(llmProvider: provider, storage: storage);

        expect(llm.callCount, greaterThan(0));
        expect(
          state.nameController.text,
          'Elandra Duskwhisper',
          reason: 'only the stage-3 regex fallback in the JSON extractor '
              '(future chargen_json.dart leaf) can recover a value next to '
              'malformed JSON elsewhere in the same object',
        );
        expect(state.isRandomizing, isFalse);
      },
    );
  });
}
