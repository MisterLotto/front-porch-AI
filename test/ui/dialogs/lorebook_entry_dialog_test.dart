import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/ui/widgets/widgets.dart';
import 'package:front_porch_ai/ui/dialogs/lorebook_entry_dialog.dart';

/// Helper that opens the lorebook entry dialog and reports the result via
/// [onResult].
class LorebookEntryDialogOpener extends StatefulWidget {
  const LorebookEntryDialogOpener({super.key, this.existing, this.showEnabled = false, required this.onResult});

  final LorebookEntry? existing;
  final bool showEnabled;
  final void Function(LorebookEntry?) onResult;

  @override
  State<LorebookEntryDialogOpener> createState() =>
      _LorebookEntryDialogOpenerState();
}

class _LorebookEntryDialogOpenerState
    extends State<LorebookEntryDialogOpener> {
  Future<void> _open() async {
    final result = await showLorebookEntryDialog(
      context: context,
      existing: widget.existing,
      showEnabled: widget.showEnabled,
    );
    widget.onResult(result);
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _open,
      child: const Text('Open Lorebook Dialog'),
    );
  }
}

Widget _buildApp({
  LorebookEntry? existing,
  bool showEnabled = false,
  required void Function(LorebookEntry?) onResult,
}) {
  return MaterialApp(
    home: Scaffold(
      body: LorebookEntryDialogOpener(
        existing: existing,
        showEnabled: showEnabled,
        onResult: onResult,
      ),
    ),
  );
}

void main() {
  group('showLorebookEntryDialog', () {
    testWidgets('opens with Add title when creating new entry',
        (tester) async {
      await tester.pumpWidget(_buildApp(onResult: (_) {}));
      await tester.tap(find.text('Open Lorebook Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Add Lorebook Entry'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('opens with Edit title when editing existing entry',
        (tester) async {
      final existing = LorebookEntry(
        name: 'Test Entry',
        key: 'test',
        content: 'Test content',
      );
      await tester.pumpWidget(_buildApp(
        existing: existing,
        onResult: (_) {},
      ));
      await tester.tap(find.text('Open Lorebook Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Lorebook Entry'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('pre-fills fields from existing entry', (tester) async {
      final existing = LorebookEntry(
        name: 'Existing Entry',
        key: 'trigger1, trigger2',
        content: 'Existing content',
        constant: true,
        stickyDepth: 3,
        enabled: true,
      );
      await tester.pumpWidget(_buildApp(
        existing: existing,
        showEnabled: true,
        onResult: (_) {},
      ));
      await tester.tap(find.text('Open Lorebook Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Existing Entry'), findsOneWidget);
      expect(find.text('trigger1, trigger2'), findsOneWidget);
      expect(find.text('Existing content'), findsOneWidget);
    });

    testWidgets('Cancel returns null', (tester) async {
      LorebookEntry? result;
      await tester.pumpWidget(_buildApp(onResult: (r) => result = r));
      await tester.tap(find.text('Open Lorebook Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });

    testWidgets('Save returns constructed LorebookEntry', (tester) async {
      LorebookEntry? result;
      await tester.pumpWidget(_buildApp(onResult: (r) => result = r));
      await tester.tap(find.text('Open Lorebook Dialog'));
      await tester.pumpAndSettle();

      // AppTextField order in the dialog Column: [name, keywords, content]
      await tester.enterText(find.byType(AppTextField).at(0), 'My Entry');
      await tester.enterText(find.byType(AppTextField).at(1), 'mykey');
      await tester.enterText(find.byType(AppTextField).at(2), 'My lore content');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.name, 'My Entry');
      expect(result!.key, 'mykey');
      expect(result!.content, 'My lore content');
    });

    testWidgets('shows enabled toggle when showEnabled is true',
        (tester) async {
      await tester.pumpWidget(_buildApp(
        showEnabled: true,
        onResult: (_) {},
      ));
      await tester.tap(find.text('Open Lorebook Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Enabled'), findsOneWidget);
    });

    testWidgets('hides enabled toggle when showEnabled is false',
        (tester) async {
      await tester.pumpWidget(_buildApp(onResult: (_) {}));
      await tester.tap(find.text('Open Lorebook Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Enabled'), findsNothing);
    });

    testWidgets('toggling Always Active disables keywords field',
        (tester) async {
      await tester.pumpWidget(_buildApp(onResult: (_) {}));
      await tester.tap(find.text('Open Lorebook Dialog'));
      await tester.pumpAndSettle();

      // Ensure the toggle is visible (it may be scrolled off-screen)
      final switchFinder = find.byWidgetPredicate(
        (w) => w is Switch && w.value == false,
      );
      await tester.ensureVisible(switchFinder.last);
      await tester.pumpAndSettle();
      await tester.tap(switchFinder.last);
      await tester.pumpAndSettle();

      expect(
        find.text('Keywords (Disabled — Always Active)'),
        findsOneWidget,
      );
    });

    testWidgets('toggling Always Active hides sticky depth slider',
        (tester) async {
      await tester.pumpWidget(_buildApp(onResult: (_) {}));
      await tester.tap(find.text('Open Lorebook Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Sticky Depth'), findsOneWidget);

      final switchFinder = find.byWidgetPredicate(
        (w) => w is Switch && w.value == false,
      );
      await tester.ensureVisible(switchFinder.last);
      await tester.pumpAndSettle();
      await tester.tap(switchFinder.last);
      await tester.pumpAndSettle();

      expect(find.text('Sticky Depth'), findsNothing);
    });

    testWidgets('Save preserves advanced/imported fields via clone',
        (tester) async {
      final imported = LorebookEntry.fromJson({
        'keys': ['queen'],
        'keysecondary': ['court'],
        'content': 'Original content',
        'name': 'Queen',
        'probability': 25,
        'order': 250,
        'position': 4,
        'sticky': 3,
        'selectiveLogic': 3,
        'extensions': {'chub_thing': true},
      });

      LorebookEntry? result;
      await tester.pumpWidget(
        _buildApp(existing: imported, onResult: (r) => result = r),
      );
      await tester.tap(find.text('Open Lorebook Dialog'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(AppTextField).at(2), 'Edited content');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.content, 'Edited content');
      // Everything the simple editor doesn't show must survive the edit.
      expect(result!.secondaryKeys, ['court']);
      expect(result!.probability, 25);
      expect(result!.order, 250);
      expect(result!.position, 4);
      expect(result!.sticky, 3);
      expect(result!.selectiveLogic, SelectiveLogic.andAll);
      expect(result!.extensions['chub_thing'], true);
    });
  });
}
