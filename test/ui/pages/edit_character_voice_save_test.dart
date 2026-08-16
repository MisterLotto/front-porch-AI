// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

// The character editor's Voice card (2026-08-14) — the surface that made the
// per-character TTS override visible and CLEARABLE.
//
// Why it exists: a character's own voice overrides the global Settings voice,
// and one can arrive without the user ever choosing it (`tts_voice` is read
// straight off an imported card). Until this card there was no field for it
// anywhere in the 1:1 editor, so the Discord report — "I picked Adam and the
// TTS still uses a female voice" — had no fix available to the user at all.
//
// Why it drives the REAL page instead of calling a helper: the same lesson as
// the sibling identity-save suite. The question is not whether a mapping
// function is right, it is whether the editor REACHES it — the bug class here
// is "the field exists but Save doesn't carry it".
//
// Red-proven: with `widget.character.ttsVoice = ...` removed from
// _saveCharacter, 'clearing the voice ... survives Save' fails (the override
// stays on the card — precisely the unclearable state users were stuck in).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/services/services.dart';
import 'package:front_porch_ai/ui/pages/edit_character_page.dart';
import 'package:front_porch_ai/ui/widgets/widgets.dart';

import '../../golden/support/fakes.dart';
import '../../golden/support/fakes_storage.dart';

/// The Details tab calls [coverImageFileFor]; the shared golden fake answers
/// unknown members by throwing. Same shim the sibling suites use.
class _RepoWithCover extends FakeCharacterRepository {
  @override
  File? coverImageFileFor(CharacterCard card) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<CharacterCard? Function()> pumpEditor(
    WidgetTester tester,
    CharacterCard card,
  ) async {
    CharacterCard? saved;
    await tester.binding.setSurfaceSize(const Size(1280, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repo = _RepoWithCover();
    final chat = FakeChatService();
    final storage = FakeStorageService();
    final worlds = FakeWorldRepository();
    addTearDown(repo.dispose);
    addTearDown(chat.dispose);
    addTearDown(storage.dispose);
    addTearDown(worlds.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CharacterRepository>.value(value: repo),
          ChangeNotifierProvider<ChatService>.value(value: chat),
          ChangeNotifierProvider<StorageService>.value(value: storage),
          ChangeNotifierProvider<WorldRepository>.value(value: worlds),
        ],
        child: MaterialApp(
          home: EditCharacterPage(
            character: card,
            onSaveOverride: (c) async => saved = c,
          ),
        ),
      ),
    );
    await tester.pump();
    return () => saved;
  }

  testWidgets('the Details tab shows a Voice card — the override is no longer '
      'invisible', (tester) async {
    await pumpEditor(
      tester,
      CharacterCard(name: 'Nina', description: 'has a baked-in voice')
        ..ttsVoice = 'af_heart',
    );
    expect(find.text('Voice'), findsOneWidget);
    expect(
      find.textContaining('their own voice'),
      findsOneWidget,
      reason: 'an assigned voice must SAY that Settings will not apply',
    );
  });

  testWidgets('a character with no voice says it is following the global one',
      (tester) async {
    await pumpEditor(
      tester,
      CharacterCard(name: 'Nina', description: 'follows the global voice'),
    );
    expect(find.textContaining('Following the voice set in Settings'),
        findsOneWidget);
  });

  testWidgets('clearing the voice through the picker survives Save as null',
      (tester) async {
    final card = CharacterCard(name: 'Nina', description: 'x')
      ..ttsVoice = 'af_heart';
    final saved = await pumpEditor(tester, card);

    // Drive the real picker's callback — the widget is on screen and this is
    // the exact value its "use the global voice" option carries.
    final picker = tester.widget<CharacterVoicePicker>(
      find.byType(CharacterVoicePicker),
    );
    expect(picker.value, 'af_heart', reason: 'the card\'s voice is shown');
    picker.onChanged('');
    await tester.pump();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved(), isNotNull, reason: 'Save must have run');
    expect(
      saved()!.ttsVoice,
      isNull,
      reason: 'clearing stores null so the character follows the global '
          'voice — an override you cannot clear is the reported bug',
    );
  });

  testWidgets('assigning a voice survives Save', (tester) async {
    final card = CharacterCard(name: 'Nina', description: 'x');
    final saved = await pumpEditor(tester, card);

    tester
        .widget<CharacterVoicePicker>(find.byType(CharacterVoicePicker))
        .onChanged('am_adam');
    await tester.pump();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(saved()!.ttsVoice, 'am_adam');
  });
}
