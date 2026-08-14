// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

// Group follow-up speakers used to score the previous NPC's reply for
// bond/mood/arousal. Pre-gen judges must cut the window at the last user.

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/models/chat_message.dart';
import 'package:front_porch_ai/services/chat/llm_eval_engine.dart';

void main() {
  ChatMessage u(String t) =>
      ChatMessage(text: t, sender: 'You', isUser: true);
  ChatMessage a(String t) =>
      ChatMessage(text: t, sender: 'Alex', isUser: false);
  ChatMessage b(String t) =>
      ChatMessage(text: t, sender: 'Blake', isUser: false);

  test('throughLastUser drops NPC lines after the user', () {
    final msgs = [u('hi'), a('hello'), b('wait up')];
    final cut = messagesThroughLastUser(msgs);
    expect(cut, hasLength(1));
    expect(cut.single.text, 'hi');
    expect(recentExchangeThroughLastUser(msgs), isNot(contains('wait up')));
    expect(recentExchangeThroughLastUser(msgs), contains('hi'));
  });

  test('1:1 after the user message is a no-op', () {
    final msgs = [a('greeting'), u('how are you')];
    expect(messagesThroughLastUser(msgs), msgs);
  });
}
