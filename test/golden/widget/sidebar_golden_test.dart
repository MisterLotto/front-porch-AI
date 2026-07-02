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

@Tags(['golden'])
@TestOn('linux')
library;

// Widget pixel goldens for the chat sidebar sections — the first surface driven
// by the shared timer-free `FakeChatService`. Each section is a focused,
// character-behavior-facing panel; freezing them in light + dark locks the chat
// sidebar against UI regressions. Sections are added here as the fake grows to
// cover their `ChatService` read surface (see COVERAGE.md).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:front_porch_ai/models/character_card.dart';
import 'package:front_porch_ai/models/lorebook.dart';
import 'package:front_porch_ai/services/chat_service.dart';
import 'package:front_porch_ai/services/storage_service.dart';
import 'package:front_porch_ai/ui/chat_components/sidebar/author_note_section.dart';
import 'package:front_porch_ai/ui/chat_components/sidebar/chaos_mode_section.dart';
import 'package:front_porch_ai/ui/chat_components/sidebar/lorebook_section.dart';
import 'package:front_porch_ai/ui/chat_components/sidebar/nsfw_section.dart';
import 'package:front_porch_ai/ui/chat_components/sidebar/objective_section.dart';
import 'package:front_porch_ai/ui/chat_components/sidebar/realism_section.dart';
import 'package:front_porch_ai/ui/chat_components/sidebar/scene_time_section.dart';
import 'package:front_porch_ai/ui/chat_components/sidebar/summary_section.dart';

import '../support/creator_test_support.dart';
import '../support/fakes.dart';
import '../support/golden_app.dart';

/// A sync StorageService (defaults only) for sections that read a setting at
/// build. Its async init is irrelevant to a static golden.
StorageService _storage() {
  SharedPreferences.setMockInitialValues({});
  return StorageService();
}

void main() {
  setupPathProviderMock();

  testWidgets('SceneTimeSection — evening, day 3', (tester) async {
    final chat = FakeChatService(timeOfDay: 'evening', dayCount: 3);
    addTearDown(chat.dispose);
    await expectThemedGoldens(
      tester,
      child: SizedBox(width: 300, child: SceneTimeSection(chat: chat)),
      group: 'sidebar',
      name: 'scene_time_evening',
      surface: const Size(340, 120),
    );
  });

  testWidgets('SceneTimeSection — dawn, day 1', (tester) async {
    final chat = FakeChatService(timeOfDay: 'dawn', dayCount: 1);
    addTearDown(chat.dispose);
    await expectThemedGoldens(
      tester,
      child: SizedBox(width: 300, child: SceneTimeSection(chat: chat)),
      group: 'sidebar',
      name: 'scene_time_dawn',
      surface: const Size(340, 120),
    );
  });

  testWidgets('AuthorNoteSection — populated note', (tester) async {
    final chat = FakeChatService(
      authorNote: '[Keep the tone wry. {{char}} avoids direct answers.]',
      authorNoteStrength: 4,
    );
    addTearDown(chat.dispose);
    await expectThemedGoldens(
      tester,
      child: SizedBox(width: 320, child: AuthorNoteSection(chatService: chat)),
      group: 'sidebar',
      name: 'author_note',
      surface: const Size(360, 360),
      // Owns a text field (blinking-cursor ticker).
      settle: false,
    );
  });

  testWidgets('SummarySection — populated recap', (tester) async {
    final chat = FakeChatService(
      summary: '{{user}} and {{char}} agreed to meet at the harbor at dawn '
          'after {{char}} admitted the lighthouse logs were forged.',
      summaryLastIndex: 12,
    );
    addTearDown(chat.dispose);
    final storage = _storage();
    addTearDown(storage.dispose);
    await expectThemedGoldens(
      tester,
      child: ChangeNotifierProvider<StorageService>.value(
        value: storage,
        child: SizedBox(width: 320, child: SummarySection(chatService: chat)),
      ),
      group: 'sidebar',
      name: 'summary',
      surface: const Size(360, 420),
      settle: false,
      // The Journal is enabled by default but the section starts collapsed;
      // tapping the header expands it, revealing the recap body.
      afterPump: (t) => t.tap(find.text('Where we are')),
    );
  });

  testWidgets('NsfwEnhancementsSection — default state', (tester) async {
    final chat = FakeChatService();
    addTearDown(chat.dispose);
    await expectThemedGoldens(
      tester,
      child: SizedBox(width: 320, child: NsfwEnhancementsSection(chat: chat)),
      group: 'sidebar',
      name: 'nsfw',
      surface: const Size(360, 320),
      settle: false,
    );
  });

  testWidgets('ChaosModeSection — enabled with pressure', (tester) async {
    final chat = FakeChatService();
    addTearDown(chat.dispose);
    // Stateless section — seed the service before rendering to show the
    // enabled state (pressure gauge + spin control).
    chat.chaosModeService.loadScalars(modeEnabled: true, pressure: 60);
    await expectThemedGoldens(
      tester,
      child: SizedBox(
        width: 320,
        child: ChaosModeSection(chat: chat, onSpinRequested: () {}),
      ),
      group: 'sidebar',
      name: 'chaos',
      surface: const Size(360, 360),
    );
  });

  testWidgets('LorebookSection — character with entries', (tester) async {
    final character = CharacterCard(
      name: 'Aria Vale',
      lorebook: Lorebook(entries: [
        LorebookEntry(
            key: 'lighthouse', content: 'The lamp at the cape never goes dark.'),
        LorebookEntry(
            key: 'storm', content: 'A wreck washed in last winter; salvage debts linger.'),
      ]),
    );
    await expectThemedGoldens(
      tester,
      child: SizedBox(width: 340, child: LorebookSection(character: character)),
      group: 'sidebar',
      name: 'lorebook',
      surface: const Size(380, 420),
      settle: false,
    );
  });

  testWidgets('ObjectiveSection — no active objective', (tester) async {
    final chat = FakeChatService();
    addTearDown(chat.dispose);
    await expectThemedGoldens(
      tester,
      // The section nests a Consumer<ChatService>, so provide it in the tree.
      child: ChangeNotifierProvider<ChatService>.value(
        value: chat,
        child: SizedBox(width: 320, child: ObjectiveSection(chatService: chat)),
      ),
      group: 'sidebar',
      name: 'objective_empty',
      surface: const Size(360, 360),
      settle: false,
    );
  });

  testWidgets('RealismSection — bond/trust/needs populated', (tester) async {
    final chat = FakeChatService(
      activeCharacter: CharacterCard(name: 'Aria Vale'),
      characterEmotion: 'affection',
      emotionIntensity: 'strong',
    );
    addTearDown(chat.dispose);
    final storage = _storage();
    addTearDown(storage.dispose);
    await expectThemedGoldens(
      tester,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<StorageService>.value(value: storage),
          ChangeNotifierProvider<ChatService>.value(value: chat),
        ],
        child: SizedBox(width: 340, child: RealismSection(chatService: chat)),
      ),
      group: 'sidebar',
      name: 'realism',
      surface: const Size(380, 900),
      settle: false,
    );
  });
}
