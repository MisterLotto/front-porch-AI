// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// This file is part of Front Porch AI.
//
// Front Porch AI is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Front Porch AI is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with Front Porch AI. If not, see <https://www.gnu.org/licenses/>.

// recentExchange READS promptText, NOT displayText (2026-08-10).
//
// The two differ only for photo messages: promptText carries the
// "[shared a photo: caption]" marker that keeps a photo turn from reading as
// a silent user. The realism judges already saw it (they read promptText);
// recentExchange fed needs/climax/pockets/objective-mention the bare
// displayText, so every eval built on this window was blind to a photo the
// exchange was about — a user who ANSWERED with a photo scored as having
// said nothing at all (eval review Tier-3 hygiene).
//
// Guard proven to fail: flipping recentExchange back to displayText sends
// the marker test red (window shows "You: " with nothing after it); restored,
// it is green again.

import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/services/chat/chat.dart' show recentExchange;

void main() {
  group('recentExchange photo visibility', () {
    test('a captioned photo turn carries its marker into the window', () {
      final msgs = [
        ChatMessage(text: 'an older turn', sender: 'Nia', isUser: false),
        ChatMessage(
          text: '',
          sender: 'You',
          isUser: true,
          metadata: {
            'is_user_image': true,
            'image_caption': 'a sunset over the bay',
          },
        ),
        ChatMessage(
          text: '*She leans in to look at the photo.*',
          sender: 'Nia',
          isUser: false,
        ),
      ];
      final window = recentExchange(msgs);
      expect(
        window,
        contains('You: [shared a photo: a sunset over the bay]'),
        reason:
            'THE BUG. displayText for a caption-only photo turn is empty, so '
            'needs/climax/pockets saw a silent user where the judges saw the '
            'photo. The window must carry the same promptText marker the '
            'judges read.',
      );
      expect(window, contains('Nia: *She leans in to look at the photo.*'));
    });

    test('an uncaptioned photo still shows the bare marker', () {
      final window = recentExchange([
        ChatMessage(
          text: 'look at this',
          sender: 'You',
          isUser: true,
          metadata: {'is_user_image': true},
        ),
      ]);
      expect(window, 'You: look at this [shared a photo]');
    });

    test('non-photo turns are byte-identical to the displayText window', () {
      final msgs = [
        ChatMessage(text: 'plain words', sender: 'You', isUser: true),
        ChatMessage(text: '*She nods.*', sender: 'Nia', isUser: false),
      ];
      expect(recentExchange(msgs), 'You: plain words\nNia: *She nods.*');
    });

    test('the 3-turn window itself is unchanged', () {
      final msgs = [
        for (var i = 1; i <= 5; i++)
          ChatMessage(text: 'turn $i', sender: 'You', isUser: true),
      ];
      expect(
        recentExchange(msgs),
        'You: turn 3\nYou: turn 4\nYou: turn 5',
        reason: 'the promptText switch must not touch the take window',
      );
    });
  });
}
