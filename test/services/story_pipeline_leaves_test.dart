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

// PROVABILITY NET for the story-pipeline god-file split
// (lib/services/story_pipeline_service.dart -> parts + lib/services/story/
// leaves; see the split map). This file must be green BEFORE the split and
// green AFTER it, with zero changes to its own assertions — that's what
// proves the split is behavior-identical.
//
// integration_test/story_pipeline_test.dart and story_autowrite_test.dart
// already pin the 5-stage wizard journey and the auto-write order end to
// end through a fake HTTP backend. What they do NOT reach is exercised here,
// at the unit level, against a REAL StoryPipelineService (never a
// noSuchMethod double) driven by a small scripted LLMService:
//   - the JSON repair machinery (cleanJson/parseJson/_repairTruncatedJson) —
//     destined for story_json.dart
//   - generateArchetypes — destined for story_archetypes.dart
//   - the two PURE context builders (_getCharacterCardContext,
//     _getPreviousActsContext) and the two export functions — all four
//     destined for the SAME leaf, story_context.dart. The context builders
//     are private, so they're pinned indirectly: through the exact prompt
//     text a scripted LLMService captures when a real stage runs.
//   - _resolveSessionCharacterIds, pinned through the public
//     getChatPreviewMessages surface it feeds.
//
// No network, no real model, no golden files. Every LLM response is a
// canned string; every character/session/message is fixture fiction.

// ignore_for_file: must_call_super

import 'dart:io';

// drift's `isNull` (a query-expression helper) collides with matcher's
// `isNull` (from flutter_test) — hide drift's, matching the fact that
// story_pipeline_service.dart itself imports database.dart hide StoryProject
// for the same reason (Drift generates a row class of that name too).
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:front_porch_ai/database/database.dart' hide StoryProject;
import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/services/embedding_service.dart';
import 'package:front_porch_ai/services/memory_service.dart';
import 'package:front_porch_ai/services/services.dart';

void _setupPathProviderMock() {
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return Directory.systemTemp.createTempSync('fpai_story_net_').path;
        }
        return null;
      });
}

/// Minimal scripted LLMService: records the exact prompt text every call
/// receives (post anti-thinking prefix — `_callLLM` prepends that, so tests
/// assert with `contains`, not equality) and hands back canned responses in
/// call order. Modeled on `_FakeLlmService` in llm_eval_engine_test.dart.
class _ScriptedLlm extends LLMService {
  final List<String> responses;
  final List<String> capturedPrompts = [];
  int _callIndex = 0;

  _ScriptedLlm(this.responses);

  @override
  bool get isReady => true;

  @override
  String get backendName => 'scripted-fake';

  @override
  Stream<String> generateStream(GenerationParams params) async* {
    capturedPrompts.add(params.prompt);
    final reply = responses.isEmpty
        ? '{}'
        : responses[_callIndex.clamp(0, responses.length - 1)];
    _callIndex++;
    yield reply;
  }

  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
  @override
  bool get hasListeners => false;
  @override
  void notifyListeners() {}
  @override
  void dispose() {}
}

class _Harness {
  final AppDatabase db;
  final StoryRepository repo;
  final _ScriptedLlm llm;
  final StoryPipelineService pipeline;

  _Harness(this.db, this.repo, this.llm, this.pipeline);

  Future<void> dispose() async => db.close();
}

/// Builds a real StoryPipelineService with a real (in-memory, same-isolate)
/// database and a real StoryRepository — never a noSuchMethod double — so
/// the pins below exercise the actual pipeline code, exactly as it will
/// exist post-split (through the shell's forwarders and part extensions).
Future<_Harness> _buildHarness({List<String> llmResponses = const []}) async {
  final db = AppDatabase.forTesting(sameIsolate: true);
  final repo = StoryRepository(db);
  final storage = StorageService();
  final memory = MemoryService(EmbeddingService(storage), storage, db);
  final llm = _ScriptedLlm(llmResponses);
  final pipeline = StoryPipelineService(repo, llm, memory, db);
  return _Harness(db, repo, llm, pipeline);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _setupPathProviderMock();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ── Cluster B, future story_json.dart — JSON repair machinery ──────────
  group('StoryPipelineService.parseJson / cleanJson (future story_json.dart)', () {
    test('parses clean, unwrapped JSON directly', () {
      final result = StoryPipelineService.parseJson(
        '{"concept": "c", "acts": []}',
      );
      expect(result, {'concept': 'c', 'acts': []});
    });

    test('strips a <think> preamble and a ```json fence before parsing', () {
      const raw =
          '<think>Let me plan this out...</think>\n'
          'Here is the result:\n'
          '```json\n'
          '{"valid": true, "reason": ""}\n'
          '```';
      final result = StoryPipelineService.parseJson(raw);
      expect(result, {'valid': true, 'reason': ''});
    });

    test('repairs a single-level truncation (array of primitives)', () {
      // Cut off mid-array, one unclosed [ and one unclosed { — the simple
      // case where "close every ] then every }" happens to be correct
      // because there is exactly one level of each.
      final result = StoryPipelineService.parseJson('{"acts": [1, 2, 3');
      expect(result, {
        'acts': [1, 2, 3],
      });
    });

    test(
      'gives up on a deeper truncation — an unclosed object nested inside '
      'an unclosed array (documents the repair\'s current limitation: it '
      'always closes every ] before every }, which produces invalid JSON '
      'once an object is the innermost unclosed structure)',
      () {
        final result = StoryPipelineService.parseJson(
          '{"beats": [{"number": 1, "type": "Action", "description": "cut off her',
        );
        expect(result, isNull);
      },
    );

    test('returns null for text with no JSON object in it at all', () {
      final result = StoryPipelineService.parseJson(
        'not json at all, sorry!',
      );
      expect(result, isNull);
    });
  });

  // ── Cluster C, future story_archetypes.dart ─────────────────────────────
  group(
    'StoryPipelineService.generateArchetypes (future story_archetypes.dart)',
    () {
      test('defaults to 10 options in the documented label/value shape', () {
        final options = StoryPipelineService.generateArchetypes();
        expect(options, hasLength(10));

        final labelShape = RegExp(r'^.+ / .+ / .+\.\.\.$');
        final valueShape = RegExp(
          r'^A .+ story written in a .+ style, wherein .+\.$',
        );
        for (final o in options) {
          expect(o.keys, containsAll(['label', 'value']));
          expect(labelShape.hasMatch(o['label']!), isTrue, reason: o['label']);
          expect(valueShape.hasMatch(o['value']!), isTrue, reason: o['value']);
        }
      });

      test('honors a custom count, including zero', () {
        expect(StoryPipelineService.generateArchetypes(count: 5), hasLength(5));
        expect(StoryPipelineService.generateArchetypes(count: 0), isEmpty);
      });
    },
  );

  // ── Cluster I, future story_context.dart (export half) ──────────────────
  group('StoryPipelineService export (future story_context.dart)', () {
    late StoryProject project;

    setUp(() {
      project = StoryProject(title: 'Two Porches');
      project.acts = [
        StoryAct(number: 1, title: 'Arrival', description: 'They land.'),
      ];
      project.scenes[0] = [
        StoryScene(
          number: 1,
          title: 'The Dock',
          location: 'Harbor',
          description: 'A quiet start.',
        ),
      ];
      // Two beats: only the first has finalized prose. The second must be
      // skipped silently — no crash, no placeholder text — pinning the
      // `prose?.final_ != null` guard in both export functions.
      project.beats['0-0'] = [
        StoryBeat(number: 1, type: 'Action', description: 'b1'),
        StoryBeat(number: 2, type: 'Reaction', description: 'b2'),
      ];
      project.prose['0-0-0'] = BeatProse(
        final_: 'The gulls cried over the water.',
      );
    });

    test(
      'exportAsText renders the uppercase title/act header and only '
      'finalized beats',
      () async {
        final h = await _buildHarness();
        final text = h.pipeline.exportAsText(project);
        expect(text, contains('TWO PORCHES'));
        expect(text, contains('=' * 'Two Porches'.length));
        expect(text, contains('ACT 1: ARRIVAL'));
        expect(text, contains('Chapter 1: The Dock'));
        expect(text, contains('The gulls cried over the water.'));
        await h.dispose();
      },
    );

    test(
      'exportAsMarkdown renders #/##/### headers and only finalized beats',
      () async {
        final h = await _buildHarness();
        final md = h.pipeline.exportAsMarkdown(project);
        expect(md, contains('# Two Porches'));
        expect(md, contains('## Act 1: Arrival'));
        expect(md, contains('### Chapter 1: The Dock'));
        expect(md, contains('The gulls cried over the water.'));
        await h.dispose();
      },
    );
  });

  // ── _resolveSessionCharacterIds, pinned via getChatPreviewMessages ──────
  group(
    '_resolveSessionCharacterIds via getChatPreviewMessages (private leaf helper)',
    () {
      test(
        'resolves sibling sessions for characters that share a display name',
        () async {
          final h = await _buildHarness();
          await h.db.insertCharacter(
            CharactersCompanion(
              id: const Value('char-a'),
              name: const Value('Nora'),
            ),
          );
          await h.db.insertCharacter(
            CharactersCompanion(
              id: const Value('char-b'),
              name: const Value('Nora'),
            ),
          );
          await h.db.insertSession(
            SessionsCompanion(
              id: const Value('sess-a'),
              characterId: const Value('char-a'),
            ),
          );
          await h.db.insertSession(
            SessionsCompanion(
              id: const Value('sess-b'),
              characterId: const Value('char-b'),
            ),
          );
          await h.db.insertMessage(
            MessagesCompanion(
              id: const Value('msg-a'),
              sessionId: const Value('sess-a'),
              position: const Value(0),
              sender: const Value('Nora'),
              isUser: const Value(false),
              swipes: const Value('["Hello from A"]'),
            ),
          );
          await h.db.insertMessage(
            MessagesCompanion(
              id: const Value('msg-b'),
              sessionId: const Value('sess-b'),
              position: const Value(0),
              sender: const Value('Nora'),
              isUser: const Value(false),
              swipes: const Value('["Hello from B"]'),
            ),
          );

          final project = StoryProject(
            useChatHistory: true,
            chatHistoryCharacterIds: ['char-a'],
          );
          final preview = await h.pipeline.getChatPreviewMessages(project);
          expect(preview.any((m) => m.contains('Hello from A')), isTrue);
          expect(
            preview.any((m) => m.contains('Hello from B')),
            isTrue,
            reason:
                'char-b shares char-a\'s display name, so the resolver must '
                'cross-reference and pull its session in too',
          );
          await h.dispose();
        },
      );

      test(
        'still previews a stored id\'s own session even when no character '
        'row matches it (stale/deleted-character id)',
        () async {
          final h = await _buildHarness();
          // Deliberately NO Characters row for 'char-ghost' — simulates an
          // old project still referencing a character id that no longer
          // resolves to a live Characters row.
          await h.db.insertSession(
            SessionsCompanion(
              id: const Value('sess-ghost'),
              characterId: const Value('char-ghost'),
            ),
          );
          await h.db.insertMessage(
            MessagesCompanion(
              id: const Value('msg-ghost'),
              sessionId: const Value('sess-ghost'),
              position: const Value(0),
              sender: const Value('Echo'),
              isUser: const Value(false),
              swipes: const Value('["Hello from the ghost"]'),
            ),
          );

          final project = StoryProject(
            useChatHistory: true,
            chatHistoryCharacterIds: ['char-ghost'],
          );
          final preview = await h.pipeline.getChatPreviewMessages(project);
          expect(
            preview.any((m) => m.contains('Hello from the ghost')),
            isTrue,
          );
          await h.dispose();
        },
      );
    },
  );

  // ── Context assembly funneled into real stage prompts ───────────────────
  // _getCharacterCardContext and _getPreviousActsContext are private and
  // PURE (per the split map, both move verbatim into story_context.dart).
  // They can't be called directly from this file's library, so they're
  // pinned through the one place their output is observable: the exact
  // prompt text a real stage hands to the LLM.
  group(
    'context builders funneled into stage prompts (future story_context.dart)',
    () {
      test(
        'runStoryArchitect folds character-card snapshots into the prompt '
        'AND seeds cast from them ahead of any LLM-generated protagonist',
        () async {
          const bibleJson = '''
{
  "concept": "A journey across the strait.",
  "status_quo": "sq",
  "inciting_incident": "ii",
  "themes": "t",
  "style": {"genre": "Drama", "mood": "Somber", "writing_guide": "wg"},
  "threads": [],
  "world_lore": []
}
''';
          final h = await _buildHarness(llmResponses: [bibleJson]);
          final project = await h.repo.createProject(title: 'Two Porches');
          project.concept = 'A journey across the strait.';
          project.characterCardSnapshots = [
            {
              'name': 'Nora Vance',
              'role': 'Protagonist',
              'description': 'A cartographer with a bad knee.',
              'personality': 'Curious and stubborn.',
              'scenario': 'Stranded on the tide flats.',
              'first_message': 'Where are we?',
              'system_prompt': 'Speak plainly.',
            },
            {
              'name': 'Jordan Ashworth',
              'role': 'Supporting',
              'self_insert': 'true',
            },
          ];

          await h.pipeline.runStoryArchitect(project);

          expect(h.llm.capturedPrompts, hasLength(1));
          final prompt = h.llm.capturedPrompts.single;
          expect(
            prompt,
            contains(
              '## Character Definitions (from imported character cards)',
            ),
          );
          expect(prompt, contains('### Character 1: Nora Vance (Protagonist)'));
          expect(
            prompt,
            contains('Description: A cartographer with a bad knee.'),
          );
          expect(prompt, contains('Personality: Curious and stubborn.'));
          expect(prompt, contains('Scenario: Stranded on the tide flats.'));
          expect(prompt, contains('Opening: Where are we?'));
          expect(prompt, contains('System context: Speak plainly.'));
          expect(
            prompt,
            contains(
              '### Character 2: Jordan Ashworth (Supporting — User Self-Insert)',
            ),
          );

          // Snapshot-priority branch: cast comes from the snapshots, not the
          // LLM response's (absent here) "protagonist" field.
          expect(
            project.cast.map((c) => c.name),
            ['Nora Vance', 'Jordan Ashworth'],
          );

          await h.dispose();
        },
      );

      test(
        'runSceneWeaver folds a "STORY SO FAR" recap of previous acts, '
        'truncated to exactly 300 chars per beat excerpt, into the prompt',
        () async {
          const scenesJson = '''
{"scenes": [{"number": 1, "title": "S", "description": "d",
  "active_thread_ids": [], "location": "L", "cast_names": ["Nora"],
  "valence": 0, "causality": {"interaction_type": "Isolation", "description": "d"}}]}
''';
          final h = await _buildHarness(llmResponses: [scenesJson]);
          final project = await h.repo.createProject(title: 'Two Porches');
          final longProse = ('A' * 300) + 'ZZTAIL-SHOULD-NOT-APPEAR';
          project.acts = [
            StoryAct(number: 1, title: 'Arrival', description: 'They land ashore.'),
            StoryAct(number: 2, title: 'Discovery', description: 'Secrets surface.'),
          ];
          project.scenes[0] = [
            StoryScene(
              number: 1,
              title: 'The Dock',
              location: 'Harbor',
              description: 'A quiet start.',
              castNames: ['Nora'],
            ),
          ];
          project.beats['0-0'] = [
            StoryBeat(number: 1, type: 'Action', description: 'b1'),
          ];
          project.prose['0-0-0'] = BeatProse(final_: longProse);
          project.cast = [StoryCastMember(name: 'Nora', role: 'Protagonist')];

          await h.pipeline.runSceneWeaver(project, 1);

          expect(h.llm.capturedPrompts, hasLength(1));
          final prompt = h.llm.capturedPrompts.single;
          expect(
            prompt,
            contains('## STORY SO FAR (Events from previous acts'),
          );
          expect(prompt, contains('### Act 1: Arrival'));
          expect(prompt, contains('They land ashore.'));
          expect(prompt, contains('The Dock (Harbor) — A quiet start.'));
          expect(prompt, contains('Characters: Nora'));
          expect(prompt, contains('What happened: ${'A' * 300}...'));
          expect(
            prompt,
            isNot(contains('ZZTAIL-SHOULD-NOT-APPEAR')),
            reason: 'the prose excerpt must be truncated to exactly 300 chars',
          );

          await h.dispose();
        },
      );
    },
  );
}
