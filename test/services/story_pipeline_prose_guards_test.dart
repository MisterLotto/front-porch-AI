// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Guards for three Porch Stories defects fixed together:
//
//  1. getChatPreviewMessages ignored project.chatHistorySessionIds, so the
//     "Raw Messages" preview showed chats the story would never use (the two
//     real consumers in story_pipeline_service.llm.dart already filtered).
//  2. runDraftAndEdit read project.beats/scenes OUTSIDE the try whose
//     `finally` clears _isRunning, so a stale index (a deep-linked web writer
//     URL, or a beat list the validator shortened mid-run) latched the flag on
//     and froze every story page on the spinner until restart.
//  3. autoWriteScene iterated a beats list it captured before the loop, while
//     runBeatValidator REPLACES project.beats[sId] with a different list — so
//     rectified beats past the stale length were never written.
//
// Real StoryPipelineService, real in-memory database, scripted LLM.

// ignore_for_file: must_call_super

import 'dart:io';

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
          return Directory.systemTemp.createTempSync('fpai_story_prose_').path;
        }
        return null;
      });
}

/// Answers by prompt SHAPE rather than call order, so the assertions stay
/// readable when the number of drafter/editor/validator calls is the very
/// thing under test.
class _ShapedLlm extends LLMService {
  final String Function(String prompt) reply;
  final List<String> capturedPrompts = [];

  _ShapedLlm(this.reply);

  @override
  bool get isReady => true;

  @override
  String get backendName => 'shaped-fake';

  @override
  Stream<String> generateStream(GenerationParams params) async* {
    capturedPrompts.add(params.prompt);
    yield reply(params.prompt);
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
  final _ShapedLlm llm;
  final StoryPipelineService pipeline;

  _Harness(this.db, this.llm, this.pipeline);

  Future<void> dispose() async => db.close();
}

Future<_Harness> _buildHarness({String Function(String)? reply}) async {
  final db = AppDatabase.forTesting(sameIsolate: true);
  final repo = StoryRepository(db);
  final storage = StorageService();
  final memory = MemoryService(EmbeddingService(storage), storage, db);
  final llm = _ShapedLlm(reply ?? (_) => '{}');
  final pipeline = StoryPipelineService(repo, llm, memory, db);
  return _Harness(db, llm, pipeline);
}

StoryProject _sceneProject({required int beatCount}) {
  final project = StoryProject(title: 'Two Porches');
  project.acts.add(StoryAct(number: 1, title: 'Arrival'));
  project.scenes[0] = [
    StoryScene(number: 1, title: 'The Dock', description: 'She waits.'),
  ];
  project.beats['0-0'] = [
    for (int i = 0; i < beatCount; i++)
      StoryBeat(number: i + 1, description: 'Beat ${i + 1}'),
  ];
  return project;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _setupPathProviderMock();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('getChatPreviewMessages session scoping', () {
    test(
      'previews ONLY the chosen session when chatHistorySessionIds is set',
      () async {
        final h = await _buildHarness();
        await h.db.insertCharacter(
          CharactersCompanion(
            id: const Value('char-a'),
            name: const Value('Nora'),
          ),
        );
        for (final sid in ['sess-chosen', 'sess-other']) {
          await h.db.insertSession(
            SessionsCompanion(
              id: Value(sid),
              characterId: const Value('char-a'),
            ),
          );
          await h.db.insertMessage(
            MessagesCompanion(
              id: Value('msg-$sid'),
              sessionId: Value(sid),
              position: const Value(0),
              sender: const Value('Nora'),
              isUser: const Value(false),
              swipes: Value('["Hello from $sid"]'),
            ),
          );
        }

        final scoped = StoryProject(
          useChatHistory: true,
          chatHistoryCharacterIds: ['char-a'],
          chatHistorySessionIds: ['sess-chosen'],
        );
        final preview = await h.pipeline.getChatPreviewMessages(scoped);
        expect(preview.any((m) => m.contains('Hello from sess-chosen')), isTrue);
        expect(
          preview.any((m) => m.contains('Hello from sess-other')),
          isFalse,
          reason:
              'the distiller and the raw-history fallback both skip unlisted '
              'sessions, so the preview must not advertise them',
        );

        // Empty list keeps the historical all-sessions behavior.
        final unscoped = StoryProject(
          useChatHistory: true,
          chatHistoryCharacterIds: ['char-a'],
        );
        final all = await h.pipeline.getChatPreviewMessages(unscoped);
        expect(all.any((m) => m.contains('Hello from sess-chosen')), isTrue);
        expect(all.any((m) => m.contains('Hello from sess-other')), isTrue);
        await h.dispose();
      },
    );
  });

  group('runDraftAndEdit index safety', () {
    test('an out-of-range beat index never latches isRunning', () async {
      final h = await _buildHarness();
      final project = _sceneProject(beatCount: 2);

      await h.pipeline.runDraftAndEdit(project, 0, 0, 7);

      expect(
        h.pipeline.isRunning,
        isFalse,
        reason:
            'the guarded read must sit inside the try that owns the finally; '
            'a latched flag freezes every story page on the spinner',
      );
      expect(h.llm.capturedPrompts, isEmpty);
      await h.dispose();
    });

    test('a missing act/scene never latches isRunning', () async {
      final h = await _buildHarness();
      final project = _sceneProject(beatCount: 2);
      project.beats['4-0'] = [StoryBeat(number: 1, description: 'Orphan')];

      await h.pipeline.runDraftAndEdit(project, 4, 0, 0);

      expect(h.pipeline.isRunning, isFalse);
      expect(h.llm.capturedPrompts, isEmpty);
      await h.dispose();
    });
  });

  group('autoWriteScene re-reads the beats the validator replaced', () {
    test('writes the rectified beats added past the original length', () async {
      var rectifiedOnce = false;
      final h = await _buildHarness(
        reply: (prompt) {
          if (prompt.contains('Next Beat Plan:')) {
            if (rectifiedOnce) return '{"valid": true, "reason": ""}';
            rectifiedOnce = true;
            // Two beats replace the single remaining one: the stored list
            // grows from 2 to 4 (kept beat 0 + 3 rectified).
            return '{"valid": false, "reason": "drifted", "rectified_beats": '
                '[{"number": 2, "description": "Rectified A"},'
                ' {"number": 3, "description": "Rectified B"},'
                ' {"number": 4, "description": "Rectified C"}]}';
          }
          if (prompt.contains('Return ONLY the polished prose text')) {
            return 'Polished prose.';
          }
          if (prompt.contains('Write the prose now')) return 'Draft prose.';
          return '{}';
        },
      );
      final project = _sceneProject(beatCount: 2);

      await h.pipeline.autoWriteScene(project, 0, 0);

      expect(
        project.beats['0-0']!.length,
        4,
        reason: 'the validator rectified the tail of the scene',
      );
      for (int i = 0; i < 4; i++) {
        expect(
          project.prose['0-0-$i']?.final_,
          'Polished prose.',
          reason:
              'beat $i must be written — the loop bound has to come from the '
              'CURRENT project.beats list, not a stale local',
        );
      }
      expect(h.pipeline.isRunning, isFalse);
      await h.dispose();
    });

    test('stops cleanly when the validator SHORTENS the beat list', () async {
      final h = await _buildHarness(
        reply: (prompt) {
          if (prompt.contains('Next Beat Plan:')) {
            // valid:false with an empty rectified list — a very common model
            // slip; the stored list collapses to just the written beats.
            return '{"valid": false, "reason": "cut", "rectified_beats": []}';
          }
          if (prompt.contains('Return ONLY the polished prose text')) {
            return 'Polished prose.';
          }
          if (prompt.contains('Write the prose now')) return 'Draft prose.';
          return '{}';
        },
      );
      final project = _sceneProject(beatCount: 4);

      await h.pipeline.autoWriteScene(project, 0, 0);

      expect(project.beats['0-0']!.length, 1);
      expect(project.prose['0-0-0']?.final_, 'Polished prose.');
      expect(
        project.prose.containsKey('0-0-1'),
        isFalse,
        reason: 'beats the validator removed must not be written',
      );
      expect(h.pipeline.isRunning, isFalse);
      await h.dispose();
    });

    test('a validator that never stops rectifying still terminates', () async {
      // The runaway: every check says "still invalid, here are three more
      // beats", so the stored list grows exactly as fast as the loop consumes
      // it. Re-reading the length without a ceiling is an uncancellable
      // infinite loop burning three LLM calls a turn.
      //
      // The fake relents after 40 checks ONLY so this guard fails fast and
      // deterministically instead of hanging CI: past the ceiling of 26 the
      // unbounded loop keeps writing, and the count assertion below catches
      // it well before the fake stops feeding it.
      var checks = 0;
      final h = await _buildHarness(
        reply: (prompt) {
          if (prompt.contains('Next Beat Plan:')) {
            if (++checks > 40) return '{"valid": true, "reason": ""}';
            return '{"valid": false, "reason": "drifted", "rectified_beats": '
                '[{"number": 1, "description": "More A"},'
                ' {"number": 2, "description": "More B"},'
                ' {"number": 3, "description": "More C"}]}';
          }
          if (prompt.contains('Return ONLY the polished prose text')) {
            return 'Polished prose.';
          }
          if (prompt.contains('Write the prose now')) return 'Draft prose.';
          return '{}';
        },
      );
      final project = _sceneProject(beatCount: 2);

      await h.pipeline.autoWriteScene(project, 0, 0);

      expect(
        project.prose.length,
        lessThanOrEqualTo(26),
        reason:
            '2 starting beats + the documented slack of 24; without the '
            'ceiling the loop writes for as long as the validator keeps '
            'appending',
      );
      expect(h.pipeline.isRunning, isFalse);
      await h.dispose();
    });
  });
}
