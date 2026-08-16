// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Tests for the Journal receipts tap-to-jump seek (message_jump.dart):
// jumpToMessage must land a far-away, not-yet-built bubble into the viewport
// of a reverse ListView.builder (the chat list's exact shape), and JumpFlash
// must tint only while flashed.
//
// AMENDED 2026-08-10: jumpToMessage now takes a `keyOf` lookup instead of
// minting `GlobalObjectKey(msg)` internally. The old scheme made a message's
// key app-global, and two chat routes alive in the same frame (push over a
// live page, or a route transition) both built the same ChatService
// messages — one duplicate-GlobalKey crash per bubble (maintainer repro).
// The harness below keys its list the way the fixed chat page does: a
// per-owner identity map of plain GlobalKeys. The two-routes regression
// itself is pinned in message_key_scope_test.dart.

import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/models/chat_message.dart';
import 'package:front_porch_ai/ui/chat_components/widgets/message_jump.dart';

void main() {
  Widget chatList(
    ScrollController controller,
    List<ChatMessage> messages,
    Map<ChatMessage, GlobalKey> keys,
  ) {
    return MaterialApp(
      home: Scaffold(
        body: ListView.builder(
          controller: controller,
          reverse: true,
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final msg = messages[messages.length - 1 - index];
            // Varying heights on purpose — the seek must not rely on uniform
            // extents (real bubbles never have them).
            return SizedBox(
              key: keys.putIfAbsent(msg, GlobalKey.new),
              height: 60.0 + (messages.indexOf(msg) % 5) * 25,
              child: Text(msg.text),
            );
          },
        ),
      ),
    );
  }

  testWidgets('jumpToMessage seeks a distant unbuilt bubble into view',
      (tester) async {
    final messages = List.generate(
      120,
      (i) => ChatMessage(text: 'message $i', sender: 'S', isUser: i.isEven),
    );
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final keys = HashMap<ChatMessage, GlobalKey>.identity();
    await tester.pumpWidget(chatList(controller, messages, keys));

    // Ancient message: the reverse list starts at the newest end, so #3 is
    // nowhere near built — its key does not even exist yet.
    final target = messages[3];
    expect(keys[target]?.currentContext, isNull);

    var done = false;
    unawaited(
      jumpToMessage(
        controller: controller,
        messages: messages,
        target: target,
        keyOf: (m) => keys[m],
      ).then((_) => done = true),
    );
    // Drive frames until the seek reports completion (each awaited endOfFrame
    // needs a pump; the bound is generous, the seek's own cap is tighter).
    for (var i = 0; i < 300 && !done; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }

    expect(done, isTrue);
    final ctx = keys[target]?.currentContext;
    expect(ctx, isNotNull);
    // Landed inside the viewport (600 logical px in the test harness).
    final box = ctx!.findRenderObject()! as RenderBox;
    final top = box.localToGlobal(Offset.zero).dy;
    expect(top, greaterThanOrEqualTo(0));
    expect(top, lessThan(600));
  });

  testWidgets('jumpToMessage is a safe no-op for an unknown message',
      (tester) async {
    final messages = List.generate(
      5,
      (i) => ChatMessage(text: 'm$i', sender: 'S', isUser: false),
    );
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final keys = HashMap<ChatMessage, GlobalKey>.identity();
    await tester.pumpWidget(chatList(controller, messages, keys));

    final stranger = ChatMessage(text: 'ghost', sender: 'S', isUser: false);
    var done = false;
    unawaited(
      jumpToMessage(
        controller: controller,
        messages: messages,
        target: stranger,
        keyOf: (m) => keys[m],
      ).then((_) => done = true),
    );
    await tester.pump();
    expect(done, isTrue); // returned immediately, no scroll, no throw
  });

  testWidgets('JumpFlash tints only while flashed', (tester) async {
    Widget build(bool flashed) => MaterialApp(
      home: Scaffold(
        body: JumpFlash(flashed: flashed, child: const Text('bubble')),
      ),
    );

    await tester.pumpWidget(build(false));
    var deco =
        tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
    expect((deco.decoration! as BoxDecoration).color, Colors.transparent);

    await tester.pumpWidget(build(true));
    await tester.pumpAndSettle();
    deco = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
    expect(
      (deco.decoration! as BoxDecoration).color,
      isNot(Colors.transparent),
    );
  });
}
