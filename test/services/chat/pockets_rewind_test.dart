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

// THE POCKETS REWIND (hostile review 2026-08-11, the last P0). Pockets ops
// were the one non-scalar turn effect nothing ever put back: "she hands you
// her keys" → regenerate → she keeps knitting — and the keys were gone
// anyway. CLAUDE.md's own rule says non-scalar state feeding eval prompts
// joins the rewind machinery; this suite drives the REAL ChatService
// through all three seams:
//
//   * REGENERATE — the rejected turn's ops rewind to the pre-turn record
//     before the new pass replays from the same base;
//   * TAIL DELETE — deleting the last reply un-happens its turn (same
//     tail-only semantics realism time-travel has always had);
//   * SWIPE NAVIGATION — each variant carries its own post-turn record;
//     a variant whose pass changed nothing restores the shared base.
//
// Guard proven to fail before passing: with the regen seam's restore call
// removed, the regenerate test goes red (the keys stay parked).

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:front_porch_ai/database/database.dart';
import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/services/services.dart';
import 'package:front_porch_ai/services/chat/chat.dart' show Pockets;

void _setupPathProviderMock() {
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return Directory.systemTemp.createTempSync('fpai_rewind_').path;
        }
        return null;
      });
}

class _ScriptedLlm extends LLMService {
  String inventoryJson = '{"inventory_ops": []}';

  @override
  Stream<String> generateStream(GenerationParams params) async* {
    if (params.systemPrompt != null) {
      yield '*She hums on the porch, unhurried.*';
      return;
    }
    if (params.prompt.contains('You are keeping track of what')) {
      yield inventoryJson;
      return;
    }
    yield '';
  }

  @override
  bool get isReady => true;

  @override
  String get backendName => 'ScriptedLlm';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _setupPathProviderMock();

  late AppDatabase db;
  late StorageService storage;
  late ChatService chat;
  late _ScriptedLlm llm;

  setUp(() async {
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({
      'update_auto_check': false,
      'realism_default': false,
      'pockets_enabled': true,
      // Journal off on purpose: card invalidation has its own guards; this
      // suite is about the RECORD, and one moving part per suite.
      'journal_enabled': false,
    });
    db = AppDatabase.forTesting();
    storage = StorageService();
    llm = _ScriptedLlm();
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
  });

  tearDown(() async {
    chat.dispose();
    await db.close();
  });

  CharacterCard card(String dbId) => CharacterCard(
    name: 'Mara',
    description: 'Exists only inside the pockets-rewind test.',
    firstMessage: 'The porch light hums.',
    frontPorchExtensions: FrontPorchExtensions(
      realismEnabled: false,
      needsSimEnabled: false,
      chaosModeEnabled: false,
      inventory: {
        'carrying': ['car keys'],
      },
    ),
  )..dbId = dbId;

  Pockets record() => chat.pocketsFor(
    chat.characterIdFor(chat.activeCharacter!),
  )!;

  Future<void> drainUntil(bool Function() done) async {
    for (var i = 0; i < 300 && !done(); i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> parkTheKeys() async {
    llm.inventoryJson =
        '{"inventory_ops": [{"op": "setdown", "item": "keys", '
        '"where": "on the hallway table"}]}';
    await chat.sendMessage('Make yourself at home.');
    await drainUntil(() => record().setAside.isNotEmpty);
    expect(record().carrying, isEmpty);
    expect(record().setAside.single.item.name, 'car keys');
  }

  test('REGENERATE rewinds the rejected turn\'s ops before replaying', () async {
    await chat.setActiveCharacter(card('char-rewind-1'));
    await parkTheKeys();

    // The regenerated variant does nothing with the keys — so after the
    // rewind + replay, the record must be back to the pre-turn base.
    llm.inventoryJson = '{"inventory_ops": []}';
    await chat.regenerateLastMessage();
    await drainUntil(
      () => !chat.isGenerating && !chat.isSettlingTurn,
    );

    expect(
      record().carrying.single.name,
      'car keys',
      reason:
          'the rejected swipe parked them; the accepted variant never did — '
          'keys back in hand, not stranded on a table nobody mentioned',
    );
    expect(record().setAside, isEmpty);
  });

  test('TAIL DELETE un-happens the turn', () async {
    await chat.setActiveCharacter(card('char-rewind-2'));
    await parkTheKeys();

    chat.deleteMessage(chat.messages.length - 1);
    await drainUntil(() => record().setAside.isEmpty);

    expect(record().carrying.single.name, 'car keys');
    expect(record().setAside, isEmpty);
  });

  test('SWIPE NAVIGATION carries each variant\'s own record', () async {
    await chat.setActiveCharacter(card('char-rewind-3'));
    await parkTheKeys();

    // Regen to a variant that touches nothing: base restored, new swipe
    // stamped with no ops.
    llm.inventoryJson = '{"inventory_ops": []}';
    await chat.regenerateLastMessage();
    await drainUntil(() => !chat.isGenerating && !chat.isSettlingTurn);
    expect(record().carrying.single.name, 'car keys');

    final last = chat.messages.length - 1;
    // Back to the variant that parked them…
    await chat.swipeMessage(last, -1);
    expect(
      record().setAside.single.item.name,
      'car keys',
      reason: 'this variant\'s pass parked them — its record must say so',
    );
    // …and forward again to the variant that did not.
    await chat.swipeMessage(last, 1);
    expect(
      record().carrying.single.name,
      'car keys',
      reason: 'no-op variant restores the shared pre-turn base',
    );
  });

  test('GROUP give: regen rewinds BOTH giver and recipient', () async {
    // PRE-FIX: only the giver was stamped — Sam kept the keys after reject.
    await storage.realismSettings.setPocketsEnabled(true);
    await storage.realismSettings.setPocketTransfersEnabled(true);

    await db.insertGroup(
      GroupsCompanion.insert(id: 'grp-give', name: 'Porch Duo'),
    );
    await db.insertGroupMember(
      GroupMembersCompanion.insert(
        id: 'mem-mara',
        groupId: 'grp-give',
        name: 'Mara',
        frontPorchExtensions: Value(
          jsonEncode({
            'realism_engine': {
              'inventory': Pockets.cardJsonFrom(
                worn: const [],
                carrying: const ['car keys'],
              ),
            },
          }),
        ),
      ),
    );
    await db.insertGroupMember(
      GroupMembersCompanion.insert(
        id: 'mem-sam',
        groupId: 'grp-give',
        name: 'Sam',
        frontPorchExtensions: Value(
          jsonEncode({
            'realism_engine': {
              'inventory': Pockets.cardJsonFrom(
                worn: const [],
                carrying: const [],
              ),
            },
          }),
        ),
      ),
    );
    await chat.setActiveGroup(
      GroupChat(id: 'grp-give', name: 'Porch Duo'),
      groupRepo: GroupChatRepository(storage, db),
    );

    String idOf(String name) {
      final c = chat.groupCharacters.firstWhere((x) => x.name == name);
      return chat.characterIdFor(c);
    }

    Pockets? kit(String name) => chat.pocketsFor(idOf(name));

    // Seed must be live before the turn (wardrobe_message_zero contract).
    expect(kit('Mara')?.carrying.single.name, 'car keys');

    llm.inventoryJson =
        '{"inventory_ops": [{"op": "give", "item": "keys", "to": "Sam"}]}';
    await chat.sendMessage('Say goodnight to Sam.');
    await drainUntil(
      () =>
          (kit('Mara')?.carrying.isEmpty ?? false) &&
          (kit('Sam')?.carrying.any((i) => i.name == 'car keys') ?? false),
    );
    expect(kit('Sam')!.carrying.single.name, 'car keys');

    llm.inventoryJson = '{"inventory_ops": []}';
    await chat.regenerateLastMessage();
    await drainUntil(() => !chat.isGenerating && !chat.isSettlingTurn);

    expect(
      kit('Mara')?.carrying.any((i) => i.name == 'car keys') ?? false,
      isTrue,
      reason: 'giver must get the keys back when the give is rejected',
    );
    expect(
      kit('Sam')?.carrying.where((i) => i.name == 'car keys') ?? const [],
      isEmpty,
      reason: 'recipient must not keep a gift from a discarded swipe',
    );
  });
}
