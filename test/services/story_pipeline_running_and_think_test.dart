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

// Two Porch Stories defects the 1.3 sweep confirmed, guarded against a REAL
// StoryPipelineService (real in-memory DB, real StoryRepository, scripted
// LLM) — the same harness shape as story_pipeline_leaves_test.dart:
//
//  1. generateFullAct lost its running flag. Every stage (Scene Weaver, Beat
//     Director) clears `_isRunning` in its own `finally`, and nothing re-armed
//     it — so the longest phase of the act, writing the prose, ran with
//     isRunning == false. The Structure page gates its progress overlay AND
//     every Generate button on exactly that flag, so the UI went idle-looking
//     mid-act and invited a second concurrent run on the same project.
//
//  2. runDraftAndEdit stored raw model output as the beat's prose. Reasoning
//     models leak <think> blocks in the content channel (the prompt only asks
//     them not to); the whole-act writer strips them, this path did not — so
//     the tags landed in the reader, in exports, and verbatim inside the
//     Editor prompt for the very next call.

// ignore_for_file: must_call_super

import 'dart:io';

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
          return Directory.systemTemp.createTempSync('fpai_story_flag_').path;
        }
        return null;
      });
}

/// Hands back canned responses in call order (clamping to the last one), and
/// records the prompts it was given so the Editor prompt can be inspected.
class _ScriptedLlm extends LLMService {
  _ScriptedLlm(this.responses);

  final List<String> responses;
  final List<String> capturedPrompts = [];
  int _callIndex = 0;

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
  _Harness(this.db, this.repo, this.llm, this.pipeline);

  final AppDatabase db;
  final StoryRepository repo;
  final _ScriptedLlm llm;
  final StoryPipelineService pipeline;

  Future<void> dispose() async => db.close();
}

Future<_Harness> _buildHarness(List<String> llmResponses) async {
  final db = AppDatabase.forTesting(sameIsolate: true);
  final repo = StoryRepository(db);
  final storage = StorageService();
  final memory = MemoryService(EmbeddingService(storage), storage, db);
  final llm = _ScriptedLlm(llmResponses);
  return _Harness(db, repo, llm, StoryPipelineService(repo, llm, memory, db));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _setupPathProviderMock();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'generateFullAct still reports isRunning while it writes the prose — the '
    'stages that clear the flag in their own finally must not leave the act '
    'looking idle',
    () async {
      const scenesJson =
          '{"scenes":[{"number":1,"title":"The Dock","location":"Harbor",'
          '"description":"A quiet start.","cast_names":["Nora"]}]}';
      const beatsJson =
          '{"beats":[{"number":1,"type":"Action","description":"She walks."}]}';
      const proseText = 'The gulls cried over the water.';

      final h = await _buildHarness([scenesJson, beatsJson, proseText]);
      final project = await h.repo.createProject(title: 'Two Porches');
      project.concept = 'A journey across the strait.';
      project.acts = [
        StoryAct(number: 1, title: 'Arrival', description: 'They land.'),
      ];

      // What a Consumer of the service actually sees: the step it announced
      // and whether it claimed to be running at that moment.
      final seen = <(String, bool)>[];
      void listener() =>
          seen.add((h.pipeline.currentStep, h.pipeline.isRunning));
      h.pipeline.addListener(listener);

      await h.pipeline.generateFullAct(project, 0);
      h.pipeline.removeListener(listener);

      final writing = seen.where((s) => s.$1.contains('Writing')).toList();
      expect(
        writing,
        isNotEmpty,
        reason: 'the prose phase must have announced itself at least once — '
            'otherwise this guard asserts nothing',
      );
      expect(
        writing.every((s) => s.$2),
        isTrue,
        reason: 'every notification sent while the act was being written must '
            'report isRunning == true; the Structure page gates its progress '
            'overlay and its Generate buttons on this flag',
      );

      // And the act really did finish (the flag is only cleared at the end).
      expect(project.prose['0-0-0']?.final_, proseText);
      expect(h.pipeline.isRunning, isFalse);
      await h.dispose();
    },
  );

  test(
    'runDraftAndEdit strips <think> from the draft, from the stored final '
    'prose, and from the Editor prompt it builds out of the draft',
    () async {
      const leaky =
          '<think>Okay, the beat is about arriving. Let me set the scene.'
          '</think>\nThe gulls cried over the water.';

      final h = await _buildHarness([leaky, leaky]);
      final project = await h.repo.createProject(title: 'Two Porches');
      project.acts = [
        StoryAct(number: 1, title: 'Arrival', description: 'They land.'),
      ];
      project.scenes[0] = [
        StoryScene(
          number: 1,
          title: 'The Dock',
          location: 'Harbor',
          description: 'A quiet start.',
          castNames: const ['Nora'],
        ),
      ];
      project.beats['0-0'] = [
        StoryBeat(number: 1, type: 'Action', description: 'She walks.'),
      ];

      await h.pipeline.runDraftAndEdit(project, 0, 0, 0);

      final prose = project.prose['0-0-0'];
      expect(prose, isNotNull);
      expect(
        prose!.final_,
        'The gulls cried over the water.',
        reason: 'the beat\'s finished prose is what the reader, the ePub '
            'export and the audiobook all read verbatim',
      );
      expect(prose.draft, 'The gulls cried over the water.');
      expect(prose.draft, isNot(contains('<think>')));

      // The second LLM call is the Editor pass — it quotes the draft back.
      // (Every prompt contains the literal string "<think>": _callLLM prepends
      // "Do NOT use <think> tags…". So look for the reasoning TEXT instead.)
      expect(h.llm.capturedPrompts, hasLength(2));
      expect(
        h.llm.capturedPrompts[1],
        isNot(contains('Okay, the beat is about arriving')),
        reason: 'an unstripped draft would feed the model its own reasoning '
            'as the text to polish',
      );
      await h.dispose();
    },
  );
}
