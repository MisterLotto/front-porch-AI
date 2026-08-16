// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// "Dinner is 6 p.m." / "Dinner's 6 p.m." are schedules, not the present.

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/services/chat/chat.dart';

void main() {
  final onePm = DateTime(2026, 3, 1, 13, 0);

  test('Dinner is / Dinner\'s 6 p.m. do not teleport the clock', () {
    expect(clockNamedInReply("Dinner is 6 p.m.", onePm), isNull);
    expect(clockNamedInReply("Dinner's 6 p.m.", onePm), isNull);
    expect(clockNamedInReply('It was 5 a.m. when we left.', onePm), isNull);
  });

  test('a present "it is 6 p.m." still lands', () {
    final six = clockNamedInReply('It is 6 p.m. and the porch is quiet.', onePm);
    expect(six, isNotNull);
    expect(six!.hour, 18);
  });
}
