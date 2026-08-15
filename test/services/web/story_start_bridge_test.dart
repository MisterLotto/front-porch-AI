// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// `storyStartDate` / `storyStartTime` / `favoriteAvatarId` across the web
// bridge — the same bug `inventory_bridge_test.dart` was written for, in three
// fields that were missed when that one was fixed.
//
// THE BUG. `frontPorchFromFields` rebuilds a WHOLE new FrontPorchExtensions and
// carries non-form state forward from `base:` by hand. These three appeared
// nowhere — not in the reads, not in the carried list — so they took their
// `null` constructor defaults on every web save. `CharacterFacade.update`
// calls this on EVERY web edit and then rewrites the PNG, so changing one word
// of a description from a phone erased the authored "Story Begins" date/time
// (new chats then opened at "the day the chat starts" with the period-default
// clock) and un-starred the canonical avatar (the export cover and the face a
// new chat opens with revert to the portrait). Nothing on screen suggested the
// edit had touched any of it, and the originals were unrecoverable.
//
// The desktop twin (edit_character_page.dart, via copyWith) preserves all
// three, so this was also a desktop↔web parity break.

import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/services/web/util/util.dart';

void main() {
  /// A card whose author set a story anchor and starred a gallery look, plus
  /// one unrelated field so a failure can be read as "only these were lost"
  /// rather than "nothing was carried at all".
  FrontPorchExtensions seeded() => FrontPorchExtensions(
    ambitions: ['finish the porch swing'],
    storyStartDate: '1987-06-02',
    storyStartTime: '06:00',
    favoriteAvatarId: 'avatar-row-42',
  );

  group('a web save must not erase the story anchor or the starred look', () {
    test('a payload that never mentions them keeps the base values', () {
      // The exact shape of the bug: the React editor has no control for any of
      // these, so a save with the keys entirely absent is EVERY web edit today,
      // not an edge case.
      final back = frontPorchFromFields(const {
        'realismEnabled': true,
        'trustLevel': 5,
      }, base: seeded());

      expect(back.storyStartDate, '1987-06-02');
      expect(back.storyStartTime, '06:00');
      expect(back.favoriteAvatarId, 'avatar-row-42');
      // The edit itself must still land, and unrelated state must survive.
      expect(back.realismEnabled, isTrue);
      expect(back.trustLevel, 5);
      expect(back.ambitions, ['finish the porch swing']);
    });

    test('an author who never set them still gets nulls, not invented values',
        () {
      final back = frontPorchFromFields(const {'trustLevel': 1});

      expect(back.storyStartDate, isNull);
      expect(back.storyStartTime, isNull);
      expect(back.favoriteAvatarId, isNull);
    });

    test('they survive a full round-trip of repeated web edits', () {
      // A phone user editing the same card three times in a row is where the
      // silent loss actually happened.
      var ext = seeded();
      for (var i = 0; i < 3; i++) {
        ext = frontPorchFromFields({'trustLevel': i}, base: ext);
      }

      expect(ext.storyStartDate, '1987-06-02');
      expect(ext.storyStartTime, '06:00');
      expect(ext.favoriteAvatarId, 'avatar-row-42');
    });
  });
}
