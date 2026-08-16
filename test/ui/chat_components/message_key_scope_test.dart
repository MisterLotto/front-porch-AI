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

// BUBBLE KEYS MUST BE OWNED PER PAGE, NEVER MINTED FROM THE MESSAGE ALONE
// (2026-08-10 maintainer repro). Two ChatPage routes can be alive in the
// same frame — a push over a not-yet-disposed page, or the frames of a
// route transition — and both listen to the same ChatService, so a chat
// switch has BOTH building bubbles for the same ChatMessage objects. With
// bubbles keyed `GlobalObjectKey(msg)` (identity = the message alone, scope
// = the whole app) that was one duplicate-GlobalKey crash per visible
// message, followed by cascading tree corruption ("child._parent == this",
// "wrong build scope", overlay assertions — the exact storm in the report).
//
// The fix: each page owns an identity map of plain GlobalKeys
// (chat_page.dart `_bubbleKeys`), so two pages can never claim one key.
// This harness pins the requirement at the mechanism level: two lists, the
// SAME message instances, pumped in one frame.
//
// The red-proof is BUILT IN as the second test: the old GlobalObjectKey
// scheme, in this exact harness, throws the duplicate-key error — proving
// the harness reproduces the maintainer's crash and that reverting the
// page to message-derived global keys would be caught here.

import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/models/chat_message.dart';

Widget _twoLists(
  List<ChatMessage> messages,
  Key Function(ChatMessage) keyFor1,
  Key Function(ChatMessage) keyFor2,
) {
  Widget list(Key Function(ChatMessage) keyFor) => Expanded(
    child: ListView(
      children: [
        for (final m in messages)
          SizedBox(key: keyFor(m), height: 40, child: Text(m.text)),
      ],
    ),
  );
  return MaterialApp(
    home: Scaffold(
      body: Column(children: [list(keyFor1), list(keyFor2)]),
    ),
  );
}

void main() {
  final messages = List.generate(
    5,
    (i) => ChatMessage(text: 'message $i', sender: 'S', isUser: i.isEven),
  );

  testWidgets(
    'two lists showing the same messages coexist when each owns its keys',
    (tester) async {
      final keys1 = HashMap<ChatMessage, GlobalKey>.identity();
      final keys2 = HashMap<ChatMessage, GlobalKey>.identity();
      await tester.pumpWidget(
        _twoLists(
          messages,
          (m) => keys1.putIfAbsent(m, GlobalKey.new),
          (m) => keys2.putIfAbsent(m, GlobalKey.new),
        ),
      );
      expect(
        tester.takeException(),
        isNull,
        reason:
            'THE CRASH. Two live chat routes build the same ChatService '
            'messages during a switch; per-page keys are what makes that '
            'legal.',
      );
      expect(find.text('message 0'), findsNWidgets(2));
    },
  );

  testWidgets(
    'RED-PROOF: the old message-derived GlobalObjectKey scheme throws '
    'exactly the duplicate-key error the maintainer hit',
    (tester) async {
      await tester.pumpWidget(
        _twoLists(
          messages,
          GlobalObjectKey.new,
          GlobalObjectKey.new,
        ),
      );
      final e = tester.takeException();
      expect(
        e,
        isNotNull,
        reason:
            'if this stops throwing, the harness no longer reproduces the '
            'crash and the sibling test proves nothing',
      );
      expect('$e', contains('Multiple widgets used the same GlobalKey'));
    },
  );
}
