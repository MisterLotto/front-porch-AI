// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

// Audit P1.8: emptied 1:1 inventory must encode as JSON, not vanish to SQL NULL.
// NULL = "never seeded" (card kit re-applies); empty JSON = "intentionally empty".

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/services/chat/chat.dart' show Pockets;

void main() {
  test('empty Pockets encode to a non-empty JSON blob (not absent)', () {
    final empty = Pockets();
    expect(empty.isEmpty, isTrue);
    final encoded = jsonEncode(empty.toJson());
    expect(encoded, isNotEmpty);
    expect(encoded, isNot('null'));
    // Round-trip still empty, but presence is what seedPocketsFromCards checks.
    final back = Pockets.fromJson(jsonDecode(encoded));
    expect(back.isEmpty, isTrue);
    expect(back.toJson(), isA<Map>());
  });
}
