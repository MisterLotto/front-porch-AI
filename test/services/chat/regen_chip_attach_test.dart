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

// A regenerated reply must carry needs chips exactly like the reply it
// replaced, and deleting it must refund them. Investigated 2026-08-04 after
// Windows CI showed chip-less regen replies: those were the settling-window
// race, but the dig found nothing in test/ ever called regenerateLastMessage
// at all — so the chip-on-regen contract (and the refund that depends on it)
// was pinned only by an E2E that asserts message counts, not chips.
//
// The full turn runs against the E2E FakeBackendServer through a real
// OpenRouterService (testLlmServiceOverride), so the canned needs-impact
// eval pays its usual deltas (hunger -4, fun +6, ...) on both the original
// turn and the regen. This is the first unit-level full-turn harness; the
// regen path shares it with the send path by construction.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:front_porch_ai/database/database.dart';
import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/services/services.dart';

import '../../../integration_test/support/fake_backend.dart';

void _setupPathProviderMock() {
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return Directory.systemTemp.createTempSync('fpai_docs_').path;
        }
        return null;
      });
}

/// Chip map ({need: {delta, reason}}) → {need: delta}, zero-delta entries
/// dropped — the same defensive read the bubbles and the E2E use.
Map<String, int> _deltasOf(Map<String, dynamic>? needsDeltas) {
  final out = <String, int>{};
  if (needsDeltas == null) return out;
  needsDeltas.forEach((need, chip) {
    if (chip is Map && chip['delta'] is int && chip['delta'] != 0) {
      out[need] = chip['delta'] as int;
    } else if (chip is int && chip != 0) {
      out[need] = chip;
    }
  });
  return out;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _setupPathProviderMock();

  late AppDatabase db;
  late ChatService chat;
  late FakeBackendServer backend;
  late OpenRouterService llm;

  setUp(() async {
    // TestWidgetsFlutterBinding installs an HttpOverrides that turns every
    // request into a bodiless 400 — clear it so the OpenRouterService can
    // genuinely reach the loopback fake.
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({
      'update_auto_check': false,
      'realism_default': true,
    });
    db = AppDatabase.forTesting();
    backend = await FakeBackendServer.start(
      replyPieces: ['The fake backend replies ', 'about the regen contract.'],
    );
    llm = OpenRouterService(
      apiUrl: '${backend.baseUrl}/v1',
      modelName: 'smoke-model',
    );
    final storage = StorageService();
    final personas = UserPersonaService(db);
    final worlds = WorldRepository(storage, db);
    chat = ChatService(KoboldService(storage), personas, storage, worlds)
      ..setDatabase(db)
      ..testLlmServiceOverride = llm;
    await chat.setActiveCharacter(
      CharacterCard(
        name: 'Regen Tester',
        description: 'Exists only inside the regen-chip unit test.',
        firstMessage: 'Welcome to the regen porch.',
        frontPorchExtensions: FrontPorchExtensions(
          realismEnabled: true,
          needsSimEnabled: true,
          chaosModeEnabled: false,
        ),
      )..dbId = 'char-regen',
    );
  });

  tearDown(() async {
    chat.dispose();
    await backend.close();
    await db.close();
  });

  test(
    'a regenerated reply carries needs chips and deleting it refunds them',
    () async {
      await chat.sendMessage('The porch swing creaks as I sit down.');
      // The turn is fully settled when sendMessage returns (the settling flag
      // now spans the whole finalization), so chips are already attached.
      final original = chat.messages.last;
      expect(original.isUser, isFalse);
      final originalDeltas = _deltasOf(
        (original.activeMetadata?['needs_deltas'] as Map?)
            ?.cast<String, dynamic>(),
      );
      expect(
        originalDeltas,
        isNotEmpty,
        reason:
            'baseline: a fresh turn must attach nonzero chips before the '
            'regen contract can be tested '
            '(keys: ${original.activeMetadata?.keys.toList()})',
      );

      final chatCallsBeforeRegen = backend.chatRequests;
      await chat.regenerateLastMessage();
      expect(
        backend.chatRequests,
        greaterThan(chatCallsBeforeRegen),
        reason: 'the regenerate must actually reach the backend',
      );

      final regenerated = chat.messages.last;
      expect(regenerated.isUser, isFalse);
      expect(
        regenerated.swipes.length,
        2,
        reason: 'the regen must graft a second swipe, not replace or stack',
      );
      expect(regenerated.swipeIndex, 1, reason: 'the new swipe is accepted');
      final regenDeltas = _deltasOf(
        (regenerated.activeMetadata?['needs_deltas'] as Map?)
            ?.cast<String, dynamic>(),
      );
      expect(
        regenDeltas,
        isNotEmpty,
        reason:
            'the regenerated swipe must carry chips — the in-generate attach '
            'runs for regens and the swipe-merge must not drop them '
            '(keys: ${regenerated.activeMetadata?.keys.toList()})',
      );
      expect(
        regenDeltas,
        originalDeltas,
        reason:
            'evals run at temperature 0.1 against identical input — a regen '
            'reproduces the same deltas (two regens disagreeing is a rewind '
            'bug, per the engine doctrine)',
      );

      // The settling hold must be fully released or every later action wedges.
      expect(chat.isSettlingTurn, isFalse);
      expect(chat.isGenerating, isFalse);

      final needsBefore = Map<String, int>.from(chat.needsSimulation.vector);
      chat.deleteMessage(chat.messages.length - 1);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      for (final e in regenDeltas.entries) {
        expect(
          chat.needsSimulation.vector[e.key],
          (needsBefore[e.key]! - e.value).clamp(0, 100),
          reason:
              'deleting the regenerated reply must refund its ${e.key} chip '
              '(${e.value}) — the reopened-refund-hole this test pins shut',
        );
      }

      expect(
        backend.unexpectedPaths,
        isEmpty,
        reason: 'the fake backend must only see known endpoints',
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
