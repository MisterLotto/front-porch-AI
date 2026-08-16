// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// This file is part of Front Porch AI.
//
// Front Porch AI is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// The Call System Prompt box edits a value that lives in StorageService, so
// every keystroke notifies and rebuilds the whole Voice & Media tab. It used
// to carry `key: ValueKey(prompt.hashCode)`, so that rebuild handed it a NEW
// key — canUpdate failed, the EditableText was destroyed and re-inflated with
// a fresh FocusNode, and the caret vanished after the first character.
//
// The harness below is that exact loop: the parent stores the value and
// rebuilds on every onChanged, just like StorageService.notifyListeners().

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/ui/settings/tabs/voice_media_tab.dart';

/// Parent that owns the value and rebuilds on every change (the StorageService
/// notify loop), plus a Reset button that writes a new value from OUTSIDE.
class _Host extends StatefulWidget {
  const _Host({required this.initial, required this.resetTo});
  final String initial;
  final String resetTo;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late String value = widget.initial;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            TextButton(
              onPressed: () => setState(() => value = widget.resetTo),
              child: const Text('Reset'),
            ),
            CallSystemPromptField(
              value: value,
              onChanged: (v) => setState(() => value = v),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  testWidgets('typing keeps one live field — focus and caret survive', (
    tester,
  ) async {
    await tester.pumpWidget(
      const _Host(initial: 'speak naturally', resetTo: 'DEFAULT'),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();
    final before = tester.state(find.byType(EditableText));
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );

    await tester.enterText(find.byType(TextField), 'speak naturally and');
    await tester.pump();

    final after = tester.state(find.byType(EditableText));
    expect(
      identical(before, after),
      isTrue,
      reason: 'the field must not be torn down and rebuilt while typing',
    );
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.focusNode.hasFocus, isTrue);
    expect(editable.controller.text, 'speak naturally and');
    expect(editable.controller.selection.isValid, isTrue);
  });

  testWidgets('Reset (an external write) still lands in the box', (
    tester,
  ) async {
    await tester.pumpWidget(
      const _Host(initial: 'speak naturally', resetTo: 'DEFAULT PROMPT'),
    );

    await tester.enterText(find.byType(TextField), 'typed by hand');
    await tester.pump();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      'typed by hand',
    );

    await tester.tap(find.text('Reset'));
    await tester.pump();

    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.controller.text, 'DEFAULT PROMPT');
    expect(editable.controller.selection.baseOffset, 'DEFAULT PROMPT'.length);
  });
}
