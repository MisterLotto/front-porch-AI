// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Download import kind: honor the client-sent type, then payload type, then
// WORLD-shape / members fallbacks. Used by the web Stoop relay.

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/services/web/facade/stoop_import_kind.dart';

void main() {
  test('payload type wins over a conflicting client hint on a character', () {
    expect(
      stoopImportKind(
        clientType: 'WORLD',
        payloadType: 'SOLO',
        card: {'first_mes': 'hi', 'personality': 'kind'},
      ),
      'SOLO',
    );
  });

  test('payload type is used when the client omits type', () {
    expect(
      stoopImportKind(payloadType: 'GROUP', card: {'first_mes': 'hi'}),
      'GROUP',
    );
  });

  test('WORLD-shape fallback when neither type is set', () {
    expect(
      stoopImportKind(
        card: {
          'name': 'The Creek',
          'biome': {'displayName': 'temperate'},
          'place_traits': {'quiet': true},
        },
      ),
      'WORLD',
    );
  });

  test(
    'SOLO client (what the PWA always sends) still upgrades a world card',
    () {
      expect(
        stoopImportKind(
          clientType: 'SOLO',
          card: {
            'name': 'The Creek',
            'biome': {'displayName': 'temperate'},
          },
        ),
        'WORLD',
      );
    },
  );

  test('members fallback is GROUP even under a SOLO client label', () {
    expect(
      stoopImportKind(
        clientType: 'SOLO',
        card: {
          'members': [
            {'name': 'A'},
          ],
        },
      ),
      'GROUP',
    );
  });

  test('a character lorebook is not a world', () {
    expect(
      stoopImportKind(
        card: {
          'first_mes': 'hello',
          'personality': 'kind',
          'character_book': {
            'entries': [1],
          },
        },
      ),
      'SOLO',
    );
  });
}
