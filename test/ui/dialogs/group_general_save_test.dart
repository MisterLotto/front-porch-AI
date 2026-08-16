// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Group Settings → General never wrote the live group. The footer Save
// called groupRepo.save(activeGroup) on the UNTOUCHED object while name /
// scenario / first message / turn rules sat in local controllers. This
// drives the real dialog: type a new name, press Save, assert activeGroup
// (and the repo) got the typed value.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/services/services.dart';
import 'package:front_porch_ai/ui/dialogs/group_settings/group_settings.dart';
import 'package:front_porch_ai/ui/dialogs/group_settings_dialog.dart';

import '../../golden/support/fakes.dart';

class _ChatWithGroup extends FakeChatService {
  _ChatWithGroup(this._group);
  final GroupChat _group;

  @override
  GroupChat? get activeGroup => _group;
}

class _RecordingRepo extends FakeGroupChatRepository {
  GroupChat? saved;

  @override
  Future<void> save(GroupChat group) async {
    saved = group;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Save applies General tab name onto the live group',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final group = GroupChat(id: 'g1', name: 'The Fellowship');
      final chat = _ChatWithGroup(group);
      final repo = _RecordingRepo();
      final worlds = FakeWorldRepository();
      addTearDown(chat.dispose);
      addTearDown(repo.dispose);
      addTearDown(worlds.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ChatService>.value(value: chat),
            ChangeNotifierProvider<WorldRepository>.value(
              value: worlds,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: GroupSettingsDialog(
                chatService: chat,
                groupRepo: repo,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final generalTab = find.text('General');
      await tester.ensureVisible(generalTab);
      await tester.tap(generalTab);
      await tester.pumpAndSettle();

      expect(find.byType(GroupGeneralTab), findsOneWidget);

      final nameField = find.descendant(
        of: find.byType(GroupGeneralTab),
        matching: find.byType(TextField),
      ).first;
      await tester.enterText(nameField, 'The New Fellowship');
      await tester.pump();

      // Controllers hold the edit; the live group is still the old name
      // until Save applies.
      expect(group.name, 'The Fellowship');

      await tester.tap(find.widgetWithText(OutlinedButton, 'Save'));
      await tester.pump();

      expect(group.name, 'The New Fellowship');
      expect(repo.saved, same(group));
      expect(repo.saved!.name, 'The New Fellowship');
    },
  );
}
