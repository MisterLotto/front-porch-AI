// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Phase 2: ST JSONL + growth/objectives package fields (pure format +
// codec paths; no real chat content).

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/models/chat_message.dart';
import 'package:front_porch_ai/services/chat/fpchat_codec.dart';
import 'package:front_porch_ai/services/chat/fpchat_format.dart';

void main() {
  test('encodeSillyTavernJsonl is multi-line ST JSONL with header', () {
    final text = encodeSillyTavernJsonl(
      [
        ChatMessage(text: 'hi', sender: 'User', isUser: true),
        ChatMessage(text: 'hello', sender: 'Misty', isUser: false),
      ],
      userName: 'Alex',
      characterName: 'Misty',
    );
    final lines = text.trim().split('\n');
    expect(lines.length, 3);
    final header = jsonDecode(lines[0]) as Map;
    expect(header['user_name'], 'Alex');
    expect(header['character_name'], 'Misty');
    expect(header.containsKey('mes'), isFalse);
    final m0 = jsonDecode(lines[1]) as Map;
    expect(m0['is_user'], isTrue);
    expect(m0['mes'], 'hi');
    final m1 = jsonDecode(lines[2]) as Map;
    expect(m1['is_user'], isFalse);
    expect(m1['mes'], 'hello');
  });

  test('tryParseSillyTavernJsonl rebuilds messages list', () {
    final raw = encodeSillyTavernJsonl(
      [
        ChatMessage(text: 'a', sender: 'User', isUser: true),
        ChatMessage(text: 'b', sender: 'Misty', isUser: false),
      ],
    );
    final root = tryParseSillyTavernJsonl(raw);
    expect(root, isNotNull);
    expect(detectFpchatPayload(root!), FpchatPayloadKind.sillyTavernIsh);
    final msgs = messagesFromPackage(laneA: root['messages'] as List);
    expect(msgs, hasLength(2));
    expect(msgs[0].isUser, isTrue);
    expect(msgs[0].text, 'a');
    expect(msgs[1].sender, 'Misty');
  });

  test('decodeFpchatBytes accepts JSONL bytes as transcript', () {
    final raw = encodeSillyTavernJsonl(
      [
        ChatMessage(text: 'x', sender: 'User', isUser: true),
        ChatMessage(text: 'y', sender: 'Nia', isUser: false),
      ],
    );
    final decoded = decodeFpchatBytes(Uint8List.fromList(utf8.encode(raw)));
    expect(decoded.chatJson['messages'], hasLength(2));
    expect(detectFpchatPayload(decoded.chatJson), FpchatPayloadKind.sillyTavernIsh);
  });

  test('single-object ST JSON still works (not mistaken for broken JSONL)', () {
    final single = jsonEncode({
      'messages': [
        {'name': 'User', 'is_user': true, 'mes': 'only'},
      ],
    });
    expect(tryParseSillyTavernJsonl(single), isNull);
    final root = decodeChatJson(single);
    expect(detectFpchatPayload(root), FpchatPayloadKind.sillyTavernIsh);
  });

  test('JSONL strips think tags and keeps swipe alternates', () {
    final msg = ChatMessage(
      text: '<think>secret plan</think>Hello visible',
      sender: 'Misty',
      isUser: false,
      swipes: const [
        '<think>plan A</think>Hello A',
        '<think>plan B</think>Hello B',
      ],
      swipeIndex: 1,
      swipeDurations: const [0, 0],
    );
    final raw = encodeSillyTavernJsonl([msg], characterName: 'Misty');
    expect(raw, isNot(contains('<think>')));
    expect(raw, contains('Hello B'));
    final root = tryParseSillyTavernJsonl(raw)!;
    final rebuilt = messagesFromPackage(laneA: root['messages'] as List);
    expect(rebuilt, hasLength(1));
    expect(rebuilt.first.text, 'Hello B');
    expect(rebuilt.first.swipes, ['Hello A', 'Hello B']);
    expect(rebuilt.first.swipeIndex, 1);
  });

  test('fpai growth/objectives keys are additive on timeline packages', () {
    final root = {
      'format': kFpchatFormatId,
      'version': 1,
      'messages': [
        {'name': 'User', 'is_user': true, 'mes': 'hi'},
      ],
      'fpai': {
        'version': 1,
        'stamp_version': kFpchatStampVersion,
        'growth': {
          'cursor': 2,
          'rings': [
            {
              'character_id': 'Misty',
              'content': 'She keeps a spare key.',
              'category': 'habit',
              'strength': 0.4,
              'pinned': false,
              'retired': false,
            },
          ],
        },
        'objectives': [
          {
            'character_id': 'Misty',
            'objective': 'Find the spare key',
            'tasks': '[]',
            'active': true,
            'is_primary': true,
          },
        ],
      },
    };
    expect(detectFpchatPayload(root), FpchatPayloadKind.fpaiTimeline);
    final fpai = Map<String, dynamic>.from(root['fpai']! as Map);
    final g = Map<String, dynamic>.from(fpai['growth'] as Map);
    expect(g['rings'], hasLength(1));
    expect(
      (fpai['objectives'] as List).first as Map,
      containsPair('objective', contains('spare key')),
    );
  });
}
