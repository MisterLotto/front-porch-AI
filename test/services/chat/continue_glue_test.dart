// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

// Pure Continue word-break glue (Discord 2026-08-15). The mash
// "garden.The" is the product bug; a double space is the over-fix.

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/services/chat/chat.dart';

void main() {
  test('glue inserts a space when the prefix has no trailing whitespace', () {
    expect(
      glueContinueText('She waved from the steps.', 'Then she sat.'),
      'She waved from the steps. Then she sat.',
    );
    expect(
      glueContinueText('She looked at the garden', 'and sighed.'),
      'She looked at the garden and sighed.',
    );
  });

  test('glue does not double a model-emitted leading space', () {
    expect(
      glueContinueText('She waved from the steps.', ' Then she sat.'),
      'She waved from the steps. Then she sat.',
    );
    expect(
      glueContinueText('She waved from the steps. ', 'Then she sat.'),
      'She waved from the steps. Then she sat.',
    );
    expect(
      glueContinueText('She waved from the steps. ', ' Then she sat.'),
      'She waved from the steps. Then she sat.',
    );
  });

  test('glue leaves an empty new part as the trimmed prefix', () {
    expect(glueContinueText('She waved. ', ''), 'She waved.');
    expect(glueContinueText('', 'Then she sat.'), 'Then she sat.');
  });

  test('pad adds a trailing space only when the partial needs one', () {
    expect(padContinuePartial('She waved.'), 'She waved. ');
    expect(padContinuePartial('She waved. '), 'She waved. ');
    expect(padContinuePartial(''), '');
    expect(padContinuePartial('She waved.\n'), 'She waved.\n');
  });

  test('old concat still mashes — the bug this helper exists to stop', () {
    const prefix = 'She waved from the steps.';
    const newPart = 'Then she sat.';
    expect('$prefix$newPart', 'She waved from the steps.Then she sat.');
    expect(
      glueContinueText(prefix, newPart),
      isNot(contains('steps.Then')),
    );
  });
}
