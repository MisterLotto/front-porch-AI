// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

// Continue-after-cancel glued new words onto an unclosed <think>, then
// closed the tag AFTER them — displayText swallowed the continuation.
// closeOpenThink must run on the PREFIX before merge.

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/utils/think_tags.dart';

void main() {
  test('balanced text is unchanged', () {
    expect(closeOpenThink('Hi. <think>plan</think> Bye.'),
        'Hi. <think>plan</think> Bye.');
    expect(closeOpenThink('No think here.'), 'No think here.');
  });

  test('unclosed think is closed so later words stay outside', () {
    final closed = closeOpenThink('She waved. <think>plan');
    expect(closed, contains('</think>'));
    final merged = '$closed Softly.';
    expect(splitMessageForEdit(merged).body.trim(), 'She waved. Softly.');
    expect(splitMessageForEdit(merged).thinking, 'plan');
  });

  test('closing AFTER concat (the old bug) swallows the continuation', () {
    const prefix = 'She waved. <think>plan';
    const newPart = ' Softly.';
    final wrong = '$prefix$newPart\n</think>';
    expect(splitMessageForEdit(wrong).body.trim(), 'She waved.');
    expect(splitMessageForEdit(wrong).thinking, contains('Softly'));
  });
}
