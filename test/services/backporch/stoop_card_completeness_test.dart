// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/services/backporch/stoop_card_completeness.dart';

void main() {
  group('StoopCardCompleteness', () {
    test('flags solo shell with only system_prompt', () {
      final r = StoopCardCompleteness.assess({
        'name': 'Test (export)',
        'first_mes': '',
        'description': '',
        'personality': '',
        'scenario': '',
        'system_prompt': 'x' * 600,
      }, 'SOLO');
      expect(r.incomplete, isTrue);
      expect(r.missingCritical, contains('First message'));
      expect(r.missingCritical, contains('Description or personality'));
      expect(r.missingCritical, contains('Scenario'));
      expect(
        r.notes.any((n) => n.contains('template/shell')),
        isTrue,
      );
    });

    test('accepts solo with identity in description only', () {
      final r = StoopCardCompleteness.assess({
        'name': 'Flora',
        'first_mes': 'Hey.',
        'description': 'A farm tsundere.',
        'personality': '',
        'scenario': 'You inherit the farm.',
      }, 'SOLO');
      expect(r.incomplete, isFalse);
      expect(r.missingCritical, isEmpty);
    });

    test('world lorebook is optional when climate present', () {
      final r = StoopCardCompleteness.assess({
        'name': 'Ashfields',
        'biome': {'displayName': 'Volcanic'},
        'lorebook': {'entries': <dynamic>[]},
      }, 'WORLD');
      expect(r.incomplete, isFalse);
      expect(r.missingOptional, contains('Lorebook content'));
    });

    test('world without climate is incomplete', () {
      final r = StoopCardCompleteness.assess({
        'name': 'Blank',
        'biome': <String, dynamic>{},
      }, 'WORLD');
      expect(r.incomplete, isTrue);
      expect(r.missingCritical, contains('Biome / climate'));
    });

    test('group needs first message and scenario', () {
      final r = StoopCardCompleteness.assess({
        'name': 'Cast',
        'first_message': '',
        'scenario': '',
        'members': [
          {'name': 'A', 'description': 'adult'},
        ],
      }, 'GROUP');
      expect(r.incomplete, isTrue);
      expect(r.missingCritical, contains('Group first message'));
      expect(r.missingCritical, contains('Group scenario'));
    });
  });
}
