// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// LLMerta → Journal porch memories: parse, inject text, mailbox, import.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:front_porch_ai/database/database.dart';
import 'package:front_porch_ai/services/chat/journal_physics.dart';
import 'package:front_porch_ai/services/chat/journal_store.dart';
import 'package:front_porch_ai/services/chat/porch_memory_import.dart';
import 'package:front_porch_ai/services/chat/porch_memory_mailbox.dart';
import 'package:front_porch_ai/services/chat/porch_memory_models.dart';
import 'package:front_porch_ai/services/chat/prompt_injection/porch_night_injection.dart';

void main() {
  group('PorchMemoryBundle.tryParse', () {
    test('parses fixture schema v1', () {
      final file = File('test/fixtures/llmerta_porch_bundle_v1.json');
      final raw = jsonDecode(file.readAsStringSync());
      final bundle = PorchMemoryBundle.tryParse(raw, sourcePath: file.path);
      expect(bundle, isNotNull);
      expect(bundle!.schemaVersion, 1);
      expect(bundle.gameId, 'game-test-001');
      expect(bundle.userPersonaId, 'persona-test-uuid');
      expect(bundle.townName, 'Brasshollow');
      expect(bundle.characters, hasLength(1));
      expect(bundle.characters.first.characterId, 'alma_card');
      expect(bundle.characters.first.cards, hasLength(3));
      expect(bundle.characters.first.cards.first.category, 'about_us');
      expect(bundle.characters.first.cards[1].emotionLabel, 'betrayed');
      expect(bundle.characters.first.cards[1].kind, 'busedByUser');
    });

    test('rejects unknown schemaVersion', () {
      final bundle = PorchMemoryBundle.tryParse({
        'schemaVersion': 99,
        'gameId': 'g',
        'userPersonaId': 'p',
        'characters': [
          {
            'characterId': 'c',
            'cards': [
              {
                'id': '1',
                'content': 'hi',
                'category': 'about_us',
              },
            ],
          },
        ],
      });
      expect(bundle, isNull);
    });

    test('normalizes category camelCase variants', () {
      final card = PorchMemoryCard.tryParse({
        'id': 'x',
        'content': 'text',
        'category': 'aboutUser',
        'kind': 'playedTogether',
        'emotionLabel': 'fond',
        'emotionIntensity': 'mild',
      });
      expect(card, isNotNull);
      expect(card!.category, 'about_user');
    });

    test('unknown kind still plants when content valid', () {
      final card = PorchMemoryCard.tryParse({
        'id': 'x',
        'content': 'text',
        'category': 'moment',
        'kind': 'futureKindXYZ',
        'emotionIntensity': 'strong',
      });
      expect(card, isNotNull);
      expect(card!.kind, 'futureKindXYZ');
    });
  });

  group('PorchNightInjection.build', () {
    test('empty bullets → empty', () {
      expect(PorchNightInjection.build(bullets: const []), isEmpty);
    });

    test('includes town, feelings, and force-ack register', () {
      final text = PorchNightInjection.build(
        townName: 'Brasshollow',
        bullets: const [
          (emotion: 'fond', content: 'We played Mafia together.'),
          (emotion: 'betrayed', content: 'They bussed me.'),
        ],
      );
      expect(text, contains('RECENT CANON'));
      expect(text, contains('Brasshollow'));
      expect(text, contains('{{user}}'));
      expect(text, contains('{{char}}'));
      expect(text, contains('(fond) We played Mafia together.'));
      expect(text, contains('(betrayed) They bussed me.'));
      expect(text, contains('Open the reply'));
      expect(text, isNot(contains('LLMerta')));
      expect(text, isNot(contains('Chance Time')));
    });

    test('caps bullets at kMaxBullets', () {
      final bullets = List.generate(
        10,
        (i) => (emotion: 'e$i', content: 'c$i'),
      );
      final text = PorchNightInjection.build(bullets: bullets);
      expect(text, contains('(e0) c0'));
      expect(text, contains('(e5) c5'));
      expect(text, isNot(contains('(e6) c6')));
    });
  });

  group('PorchNightAckState', () {
    test('take marks delivered; clearDelivered frees regen window', () {
      final state = PorchNightAckState();
      state.arm(
        diaryCharacterId: 'alma',
        injectionText: 'BLOCK',
        journalCardIds: const ['c1', 'c2'],
      );
      expect(state.takeForPrompt('alma'), 'BLOCK');
      expect(state.takeForPrompt('alma'), 'BLOCK'); // regen
      expect(state.deliveredCardIds(), ['c1', 'c2']);
      state.clearDelivered();
      expect(state.takeForPrompt('alma'), isEmpty);
    });
  });

  group('PorchMemoryMailbox + import', () {
    late Directory tmp;
    late AppDatabase db;
    late JournalStore store;
    late Set<String> consumed;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('porch_mem_');
      db = AppDatabase.forTesting();
      store = JournalStore(getDb: () => db);
      consumed = {};
    });

    tearDown(() async {
      await db.close();
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    test('listPendingBundles sorts oldest first and skips bad schema', () async {
      final dir = Directory(p.join(tmp.path, 'mail'));
      await dir.create(recursive: true);
      await File(p.join(dir.path, 'old.json')).writeAsString(
        jsonEncode({
          'schemaVersion': 1,
          'gameId': 'game-old',
          'finishedAt': '2026-01-01T00:00:00.000Z',
          'userPersonaId': 'persona-test-uuid',
          'userPersonaName': 'Alex',
          'characters': [
            {
              'characterId': 'alma_card',
              'characterName': 'Alma',
              'cards': [
                {
                  'id': 'old:1',
                  'content': 'old night',
                  'category': 'about_us',
                  'kind': 'playedTogether',
                  'emotionLabel': 'fond',
                  'emotionIntensity': 'mild',
                  'salience': 0.5,
                },
              ],
            },
          ],
        }),
      );
      await File(p.join(dir.path, 'new.json')).writeAsString(
        jsonEncode({
          'schemaVersion': 1,
          'gameId': 'game-new',
          'finishedAt': '2026-07-01T00:00:00.000Z',
          'userPersonaId': 'persona-test-uuid',
          'userPersonaName': 'Alex',
          'characters': [
            {
              'characterId': 'alma_card',
              'characterName': 'Alma',
              'cards': [
                {
                  'id': 'new:1',
                  'content': 'new night',
                  'category': 'about_us',
                  'kind': 'playedTogether',
                  'emotionLabel': 'fond',
                  'emotionIntensity': 'mild',
                  'salience': 0.5,
                },
              ],
            },
          ],
        }),
      );
      await File(p.join(dir.path, 'bad.json')).writeAsString(
        jsonEncode({'schemaVersion': 9, 'gameId': 'x'}),
      );

      final list = await PorchMemoryMailbox.listPendingBundles(
        dirsOverride: [dir],
      );
      expect(list.map((b) => b.gameId).toList(), ['game-old', 'game-new']);
    });

    test('import plants cards, arms ack, dedupes, deletes when done', () async {
      final dir = Directory(p.join(tmp.path, 'mail'));
      await dir.create(recursive: true);
      final fixture = File('test/fixtures/llmerta_porch_bundle_v1.json');
      final dest = File(p.join(dir.path, 'game-test-001.json'));
      await dest.writeAsString(await fixture.readAsString());

      final import = PorchMemoryImportService(
        journalStore: store,
        getFpaRootPath: () => null,
        isImportEnabled: () => true,
        getMaxCards: () => 200,
        libraryStableGroupIds: () => {'alma_card'},
        getConsumedBlockKeys: () => consumed,
        setConsumedBlockKeys: (k) async => consumed = Set.from(k),
        mailboxDirsOverride: [dir],
      );

      final n = await import.tryImportForSession(
        sessionId: 'sess-1',
        userPersonaId: 'persona-test-uuid',
        targets: const [
          PorchDiaryTarget(
            libraryStableGroupId: 'alma_card',
            diaryCharacterId: 'alma_card',
          ),
        ],
      );
      expect(n, 3);

      final cards = await store.cardsFor('sess-1', 'alma_card');
      expect(cards, hasLength(3));
      expect(
        cards.every((c) => JournalPhysics.cardKind(c) == 'llmerta_game'),
        isTrue,
      );
      expect(
        cards.every((c) {
          final m = jsonDecode(c.metadata!) as Map;
          return m['porchAckPending'] == true;
        }),
        isTrue,
      );

      final injection = import.takeInjectionForDiary('alma_card');
      expect(injection, contains('Mafia'));
      expect(injection, contains('RECENT CANON'));

      // Dedupe: re-import does not double-plant
      final n2 = await import.tryImportForSession(
        sessionId: 'sess-1',
        userPersonaId: 'persona-test-uuid',
        targets: const [
          PorchDiaryTarget(
            libraryStableGroupId: 'alma_card',
            diaryCharacterId: 'alma_card',
          ),
        ],
      );
      expect(n2, 0);
      expect(await store.cardsFor('sess-1', 'alma_card'), hasLength(3));

      // Bundle deleted after full consume
      expect(await dest.exists(), isFalse);

      // Wrong persona: no plant (use a fresh file)
      await dest.writeAsString(await fixture.readAsString());
      final n3 = await import.tryImportForSession(
        sessionId: 'sess-1',
        userPersonaId: 'other-persona',
        targets: const [
          PorchDiaryTarget(
            libraryStableGroupId: 'alma_card',
            diaryCharacterId: 'alma_card',
          ),
        ],
      );
      expect(n3, 0);
      // File left for the correct persona (but block already consumed in prefs —
      // wait: wrong persona continues without adding to consumed for plant.
      // Block was already in consumed from first import, so file would be deleted
      // on allDone check... Actually first import deleted the re-written? We rewrote
      // dest after delete. On wrong persona: continues early on persona mismatch
      // without touching consumed. File should still exist.
      expect(await dest.exists(), isTrue);
    });

    test('import setting off leaves files untouched', () async {
      final dir = Directory(p.join(tmp.path, 'mail'));
      await dir.create(recursive: true);
      final dest = File(p.join(dir.path, 'g.json'));
      await dest.writeAsString(
        await File('test/fixtures/llmerta_porch_bundle_v1.json').readAsString(),
      );

      final import = PorchMemoryImportService(
        journalStore: store,
        getFpaRootPath: () => null,
        isImportEnabled: () => false,
        getMaxCards: () => 200,
        libraryStableGroupIds: () => {'alma_card'},
        getConsumedBlockKeys: () => consumed,
        setConsumedBlockKeys: (k) async => consumed = Set.from(k),
        mailboxDirsOverride: [dir],
      );

      final n = await import.tryImportForSession(
        sessionId: 's',
        userPersonaId: 'persona-test-uuid',
        targets: const [
          PorchDiaryTarget(
            libraryStableGroupId: 'alma_card',
            diaryCharacterId: 'alma_card',
          ),
        ],
      );
      expect(n, 0);
      expect(await dest.exists(), isTrue);
      expect(await store.cardsFor('s', 'alma_card'), isEmpty);
    });
  });
}
