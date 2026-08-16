// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// V2 creator / creator_notes / character_version must survive import+export.

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/services/v2_card_service.dart';

void main() {
  test('parseCardJson keeps V2 credits and toJson writes them back', () {
    const raw = '''
{"spec":"chara_card_v2","spec_version":"2.0","data":{
  "name":"Ada","description":"x","personality":"y","scenario":"z",
  "first_mes":"hi","mes_example":"","system_prompt":"",
  "post_history_instructions":"","alternate_greetings":[],"tags":[],
  "creator":"Moth","creator_notes":"be kind","character_version":"1.2"
}}
''';
    final card = V2CardService().parseCardJson(raw);
    expect(card, isNotNull);
    expect(card!.creator, 'Moth');
    expect(card.creatorNotes, 'be kind');
    expect(card.characterVersion, '1.2');
    final out = card.toJson();
    expect(out['creator'], 'Moth');
    expect(out['creator_notes'], 'be kind');
    expect(out['character_version'], '1.2');
  });
}
