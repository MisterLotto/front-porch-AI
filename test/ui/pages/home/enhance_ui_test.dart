// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

// AI Enhance desktop surfaces: the context-menu entry exists (the menu list
// was extracted to home_card_menu.dart in the same change — widget identity
// moved, so this is the interaction guard), the pre-flight checklist's
// defaults and cancel behavior, and the review page's render/toggle/discard
// path (Discard must write nothing and pop cleanly — a navigation
// interaction, per the routes-get-interaction-tests rule).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/services/chargen/chat_grounding.dart';
import 'package:front_porch_ai/ui/pages/home/cards/home_card_menu.dart';
import 'package:front_porch_ai/ui/pages/home/enhance/enhance_options_dialog.dart';
import 'package:front_porch_ai/ui/pages/home/enhance/enhance_review_page.dart';

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('characterCardMenuItems', () {
    testWidgets('contains AI Enhance between Edit and Avatar Gallery',
        (tester) async {
      late List<PopupMenuItem<String>> items;
      await tester.pumpWidget(_app(Builder(builder: (context) {
        items = characterCardMenuItems(context, inFolder: false);
        return const SizedBox.shrink();
      })));
      final values = items.map((i) => i.value).toList();
      expect(values, contains('ai_enhance'));
      expect(
        values.indexOf('ai_enhance'),
        values.indexOf('edit') + 1,
        reason: 'AI Enhance sits directly after Edit Character',
      );
      expect(values, isNot(contains('remove_folder')));

      // Full parity with the pre-extraction menu (plus the new entry).
      expect(values, [
        'new_chat', 'edit', 'ai_enhance', 'avatar_gallery', 'duplicate',
        'export', 'export_json', 'move_folder', 'delete', //
      ]);
    });

    testWidgets('inFolder adds remove_folder', (tester) async {
      late List<PopupMenuItem<String>> items;
      await tester.pumpWidget(_app(Builder(builder: (context) {
        items = characterCardMenuItems(context, inFolder: true);
        return const SizedBox.shrink();
      })));
      expect(items.map((i) => i.value), contains('remove_folder'));
    });
  });

  group('showEnhanceOptionsDialog', () {
    testWidgets('defaults: persona trio on; Enhance returns them',
        (tester) async {
      ({EnhanceSelection selection, bool nsfw})? result;
      await tester.pumpWidget(_app(Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await showEnhanceOptionsDialog(
              context,
              characterName: 'Nina',
              defaultNsfw: false,
              userTurnCount: 10,
            );
          },
          child: const Text('open'),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Description'), findsOneWidget);
      // No short-chat warning at 10 user turns.
      expect(find.textContaining('very short'), findsNothing);

      await tester.tap(find.text('Enhance'));
      await tester.pumpAndSettle();
      expect(result, isNotNull);
      expect(result!.selection.description, isTrue);
      expect(result!.selection.personality, isTrue);
      expect(result!.selection.exampleDialogue, isTrue);
      expect(result!.selection.scenario, isFalse);
      expect(result!.selection.greetings, isFalse);
      expect(result!.selection.lorebook, isFalse);
      expect(result!.nsfw, isFalse);
    });

    testWidgets('cancel returns null; short chat shows the warning',
        (tester) async {
      ({EnhanceSelection selection, bool nsfw})? result = (
        selection: const EnhanceSelection(),
        nsfw: true,
      );
      await tester.pumpWidget(_app(Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await showEnhanceOptionsDialog(
              context,
              characterName: 'Nina',
              defaultNsfw: false,
              userTurnCount: 1,
            );
          },
          child: const Text('open'),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.textContaining('very short'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isNull);
    });
  });

  group('EnhanceReviewPage', () {
    final original = CharacterCard(
      name: 'Nina',
      description: 'Old description',
      personality: 'Old personality',
      mesExample: 'Old example',
    );
    final enhanced = CharacterCard(
      name: 'Nina',
      description: 'New shiny description',
      personality: 'New shiny personality',
      mesExample: 'New shiny example',
    );

    testWidgets('shows old vs new for SELECTED fields only; discard pops '
        'without writing', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => EnhanceReviewPage(
                  original: original,
                  enhanced: enhanced,
                  selection: const EnhanceSelection(
                    description: true,
                    personality: false,
                    exampleDialogue: true,
                  ),
                ),
              ),
            ),
            child: const Text('go'),
          ),
        ),
      ));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.text('Old description'), findsOneWidget);
      expect(find.text('New shiny description'), findsOneWidget);
      expect(find.text('Old example'), findsOneWidget);
      // Personality was NOT selected → no section at all.
      expect(find.text('Old personality'), findsNothing);
      expect(find.text('New shiny personality'), findsNothing);

      // Unticking a field disables its editor.
      final firstSwitch = find.byType(Switch).first;
      await tester.tap(firstSwitch);
      await tester.pumpAndSettle();
      final descField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'New shiny description'),
      );
      expect(descField.enabled, isFalse);

      // Discard pops back with no providers touched (none are even wired —
      // a write attempt would throw ProviderNotFoundException and fail this).
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.text('go'), findsOneWidget);
      expect(find.byType(EnhanceReviewPage), findsNothing);
    });
  });
}
