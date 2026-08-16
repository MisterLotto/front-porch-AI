// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// THE OPENING POSTURE SEED MUST NOT BE ABLE TO BREAK THE REALISM ENGINE.
//
// Regression guards for a defect that SHIPPED into the working tree on
// 2026-08-08 and was caught by the maintainer using the app, not by a test:
//
//     "something is legit broken with realism at the moment in the current
//      tree, no deltas emotion is sticking across messages."
//
// Their Nina session carried the fingerprint exactly — one reply whose
// realism_state was {characterEmotion: 'satisfied', trustLevel: 0,
// spatialStance: ''} with `shortTermBond`, `longTermBond` and `arousal`
// ABSENT, because the code that writes them never ran.
//
// Cause: moving posture to a post-generation pass left the very first turn
// with no position on record, so a seed call was added to
// `_evaluateRealismForUpcomingSpeaker`. That method is `try { … } finally { … }`
// with NO catch, and the seed was awaited raw — so one failing network call
// propagated out and skipped every eval below it. A nice-to-have baseline
// could take down bond, trust, emotion and arousal.
//
// Compounding it: `setSpatialStance` normalises '' and 'none' to empty, and
// the seed's guard is `isEmpty` — so a scene the model reads as having no
// clear position re-armed the seed on EVERY subsequent turn, giving it a
// fresh chance to fail each time (and costing a model call per reply against
// a release note promising one call per conversation).
//
// Two independent guards, because the two halves fail independently.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/database/database.dart';
import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/services/character_repository.dart';
import 'package:front_porch_ai/services/chat_service.dart';
import 'package:front_porch_ai/services/kobold_service.dart';
import 'package:front_porch_ai/services/llm_service.dart';
import 'package:front_porch_ai/services/storage_service.dart';
import 'package:front_porch_ai/services/user_persona_service.dart';
import 'package:front_porch_ai/services/world_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void _setupPathProviderMock() {
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return Directory.systemTemp.createTempSync('fpai_seed_iso_').path;
        }
        return null;
      });
}

/// Answers every eval normally EXCEPT the posture pass, which either throws or
/// answers "none" — the two shapes that broke the engine.
class _PostureHostileLlm extends LLMService {
  _PostureHostileLlm({required this.reply, required this.postureMode});

  final String reply;

  /// 'throw' — the seed call blows up (a timeout, a dead backend, a 500).
  /// 'none'  — a legitimate answer that leaves the stance empty.
  final String postureMode;

  int postureCalls = 0;

  @override
  Stream<String> generateStream(GenerationParams params) async* {
    final p = params.prompt;

    if (params.systemPrompt != null) {
      yield reply;
      return;
    }

    if (p.contains('current physical position and stance')) {
      postureCalls++;
      if (postureMode == 'throw') {
        throw const SocketException('posture backend down');
      }
      yield jsonEncode({'posture': 'none'});
      return;
    }
    // The judges the engine must still run even when posture is broken.
    if (p.contains('relationship_delta')) {
      yield '{"relationship_delta":7,"trust_delta":4,'
          '"bond_reason":"warmth","trust_reason":"kept a promise"}';
      return;
    }
    if (p.contains('emotion_intensity')) {
      yield '{"emotion":"delighted","emotion_intensity":"strong"}';
      return;
    }
    if (p.contains('minutes_elapsed')) {
      yield '{"minutes_elapsed": 5, "new_day": false}';
      return;
    }
    if (p.contains('fixation_topic')) {
      yield '{"fixation_topic":"none","proposed_objective":"none"}';
      return;
    }
    yield '';
  }

  @override
  bool get isReady => true;

  @override
  String get backendName => 'PostureHostileLlm';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late StorageService storage;
  late ChatService chat;
  late _PostureHostileLlm llm;

  Future<void> boot(String postureMode) async {
    HttpOverrides.global = null;
    _setupPathProviderMock();
    SharedPreferences.setMockInitialValues({
      'update_auto_check': false,
      'realism_default': true,
    });
    db = AppDatabase.forTesting();
    storage = StorageService();
    llm = _PostureHostileLlm(
      reply: '*She smiles and sets the cup down.*',
      postureMode: postureMode,
    );
    chat =
        ChatService(
            KoboldService(storage),
            UserPersonaService(db),
            storage,
            WorldRepository(storage, db),
          )
          ..setDatabase(db)
          ..setCharacterRepository(CharacterRepository(db, storage))
          ..testLlmServiceOverride = llm;
    await storage.initialized;
    await chat.setActiveCharacter(
      CharacterCard(
        name: 'Nina',
        description: 'Carries realism setup, like every authored card.',
        firstMessage: 'She is already pouring the tea when you arrive.',
        frontPorchExtensions: FrontPorchExtensions(
          realismEnabled: true,
          needsSimEnabled: false,
          chaosModeEnabled: false,
        ),
      )..dbId = 'char-nina-isolation',
    );
  }

  tearDown(() async => db.close());

  test('a posture seed that THROWS does not stop bond/trust/emotion',
      timeout: const Timeout(Duration(minutes: 2)), () async {
    // PRE-FIX RESULT: FAILED. The seed's exception escaped
    // _evaluateRealismForUpcomingSpeaker (try/finally, no catch) and every
    // eval below it was skipped — exactly the maintainer's Nina row.
    await boot('throw');

    await chat.sendMessage('I brought you the good biscuits.');

    expect(
      llm.postureCalls,
      greaterThan(0),
      reason: 'the seed must actually have been attempted and blown up',
    );

    // The engine has to have carried on regardless.
    expect(
      chat.relationshipService.affectionScore,
      isNot(0),
      reason: 'bond/affection delta must still be applied when the seed fails',
    );
    expect(
      chat.relationshipService.trustLevel,
      isNot(0),
      reason: 'trust delta must still be applied when the seed fails',
    );
    expect(
      chat.characterEmotion,
      'delighted',
      reason: 'emotion must still update when the seed fails — the reported '
          'symptom was emotion sticking across messages',
    );
  });

  test('a posture answer of "none" seeds once, not once per turn',
      timeout: const Timeout(Duration(minutes: 2)), () async {
    // PRE-FIX RESULT: FAILED with 3 calls for 3 turns. setSpatialStance
    // normalises 'none' to empty and the guard is isEmpty, so the seed
    // re-armed every turn: a model call per reply, and one more chance per
    // turn to take the engine down.
    await boot('none');

    await chat.sendMessage('First.');
    await chat.sendMessage('Second.');
    await chat.sendMessage('Third.');

    // postureCalls counts BOTH kinds of posture pass, so the arithmetic is
    // the assertion: one opening seed + one post-reply pass per turn = 4.
    // Pre-fix the seed re-armed every turn (its guard is `isEmpty` and 'none'
    // normalises to empty), giving 3 seeds + 3 post-reply passes = 6. So 4 vs
    // 6 is exactly the difference between "seeded once" and "seeded per turn",
    // and this assertion moves if either half regresses.
    expect(
      llm.postureCalls,
      4,
      reason: 'one opening seed + one post-reply pass per reply. 6 would mean '
          'the seed re-armed on every turn, which is the reported bug: a model '
          'call per reply, and one more chance per turn to break the engine',
    );
  });
}
