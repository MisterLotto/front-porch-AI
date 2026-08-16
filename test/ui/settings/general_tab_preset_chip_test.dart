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

// Settings → General → Model Instructions: the built-in preset chips must move
// the VISIBLE text field as well as storage. The controller is owned by the
// settings page, so a notify-driven rebuild never touches its text — a chip
// that only wrote storage left the old prompt on screen, and the field's
// onChanged then saved that stale text straight back over the preset on the
// next keystroke.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:front_porch_ai/services/services.dart';
import 'package:front_porch_ai/ui/settings/tabs/general_tab.dart';

class _FakeStorage extends ChangeNotifier implements StorageService {
  String stored = 'MY OWN PROMPT';

  @override
  String get systemPrompt => stored;

  @override
  Future<void> setSystemPrompt(String v) async {
    stored = v;
    notifyListeners();
  }

  // Build-time reads of GeneralTab (everything else would surface loudly
  // through noSuchMethod rather than silently returning a wrong default).
  @override
  bool get isDark => true;
  @override
  double get textScale => 1.0;
  @override
  Color get globalUserBubbleColor => const Color(0xFF334155);
  @override
  Color get globalUserTextColor => const Color(0xFFFFFFFF);
  @override
  Color get globalAiBubbleColor => const Color(0xFF1E293B);
  @override
  Color get globalAiTextColor => const Color(0xFFFFFFFF);
  @override
  Color get globalDialogueColor => const Color(0xFFE2E8F0);
  @override
  Color get globalActionColor => const Color(0xFF94A3B8);
  @override
  String get globalChatFontFamily => '';
  @override
  bool get adultThemesEnabled => false;
  @override
  List<Map<String, String>> get savedPrompts => const [];
  @override
  String get spellCheckLanguage => kSpellCheckOff;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a preset chip updates the visible prompt field, not just storage', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final storage = _FakeStorage();
    addTearDown(storage.dispose);
    final controller = TextEditingController(text: storage.systemPrompt);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<StorageService>.value(
        value: storage,
        child: MaterialApp(
          home: Scaffold(
            body: GeneralTab(systemPromptController: controller),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final chip = find.widgetWithText(ActionChip, '🖥️ KoboldCPP');
    expect(chip, findsOneWidget);
    await tester.ensureVisible(chip);
    // NOT pumpAndSettle: the spell-check row's spinner is an infinite
    // animation while its platform lookup is pending.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(chip);
    await tester.pump();

    expect(storage.stored, defaultKoboldSystemPrompt);
    // The field the user is looking at — the half that was missing.
    expect(controller.text, defaultKoboldSystemPrompt);

    // And the next keystroke can no longer resurrect the old prompt: the
    // field's onChanged now carries the preset, not the stale text.
    final field = find.byWidgetPredicate(
      (w) => w is TextField && w.controller == controller,
    );
    expect(field, findsOneWidget);
    await tester.ensureVisible(field);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(field, '${controller.text} extra');
    await tester.pump();
    expect(storage.stored, '$defaultKoboldSystemPrompt extra');
  });
}
