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

// THE SALIENT-KICK COOLDOWN (2026-08-10, maintainer-approved). A hot scene
// clears the ±12 bond bar turn after turn, and every clear fired an
// immediate full Journal pass AND Growth pass — ~95k chars / ~26s of
// background LLM per kick in the maintainer's EvalTraffic capture, mostly
// re-reading what the previous kick's pass had already covered. The gate
// rate-limits the kick MECHANISM upstream of both features' flags; a
// suppressed kick just waits for the scheduled cadence.
//
// The first kick of a session always fires — which is why the protected
// journal_review_test / growth_rings_test E2E fixtures (one salient send
// each) hold WITHOUT amendment, and the maintainer's pre-approval to edit
// them went unused.
//
// Guards proven to fail before passing: neutering the gap check (always
// allow) sends the suppression tests red; dropping the session reset sends
// the fresh-session test red.

import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/services/chat/chat.dart'
    show SalienceKickGate, kSalienceKickMinGapMessages;

void main() {
  group('SalienceKickGate', () {
    test('the first kick of a session always fires', () {
      expect(
        SalienceKickGate().allow(sessionId: 's1', messageCount: 3),
        isTrue,
        reason:
            'the protected journal_review/growth_rings fixtures fire exactly '
            'one kick — first-kick immediacy is what keeps them green',
      );
    });

    test(
      'a second kick inside the gap is suppressed; after the gap it fires',
      () {
        final g = SalienceKickGate();
        expect(g.allow(sessionId: 's1', messageCount: 10), isTrue);
        expect(
          g.allow(
            sessionId: 's1',
            messageCount: 10 + kSalienceKickMinGapMessages - 1,
          ),
          isFalse,
          reason:
              'THE WASTE. Every cleared salience bar inside a hot scene used '
              'to fire a fresh ~95k-char Journal+Growth double-pass',
        );
        expect(
          g.allow(
            sessionId: 's1',
            messageCount: 10 + kSalienceKickMinGapMessages,
          ),
          isTrue,
        );
      },
    );

    test('a suppressed kick does not claim the slot', () {
      final g = SalienceKickGate();
      g.allow(sessionId: 's1', messageCount: 10);
      g.allow(sessionId: 's1', messageCount: 11); // suppressed
      expect(
        g.allow(
          sessionId: 's1',
          messageCount: 10 + kSalienceKickMinGapMessages,
        ),
        isTrue,
        reason:
            'suppression must measure from the last FIRED kick — measuring '
            'from suppressed attempts lets a busy scene push the window '
            'forever and starve the kick entirely',
      );
    });

    test('a session switch resets the window', () {
      final g = SalienceKickGate();
      expect(g.allow(sessionId: 's1', messageCount: 50), isTrue);
      expect(
        g.allow(sessionId: 's2', messageCount: 51),
        isTrue,
        reason:
            'a fresh chat\'s first salient moment must never be muffled by '
            'the previous chat\'s cooldown',
      );
    });

    test('a null session (no chat loaded) never throws', () {
      expect(
        SalienceKickGate().allow(sessionId: null, messageCount: 0),
        isTrue,
      );
    });
  });
}
