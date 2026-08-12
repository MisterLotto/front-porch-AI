// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/models/chat_message.dart';
import 'package:front_porch_ai/services/chat/fpchat_codec.dart';
import 'package:front_porch_ai/services/chat/fpchat_format.dart';

void main() {
  group('detectFpchatPayload', () {
    test('detects full FPAI timeline', () {
      final kind = detectFpchatPayload({
        'format': kFpchatFormatId,
        'messages': [],
        'fpai': {'version': 1},
      });
      expect(kind, FpchatPayloadKind.fpaiTimeline);
    });

    test('detects ST-ish messages-only', () {
      final kind = detectFpchatPayload({
        'messages': [
          {'name': 'User', 'is_user': true, 'mes': 'hi'},
        ],
      });
      expect(kind, FpchatPayloadKind.sillyTavernIsh);
    });

    test('unknown without messages', () {
      expect(detectFpchatPayload({'foo': 1}), FpchatPayloadKind.unknown);
    });
  });

  group('messagesFromPackage', () {
    test('merges Lane A + messages_extra stamps', () {
      final msgs = messagesFromPackage(
        laneA: [
          {'name': 'User', 'is_user': true, 'mes': 'hello'},
          {'name': 'Misty', 'is_user': false, 'mes': 'hi there'},
        ],
        extras: [
          {
            'i': 1,
            'swipes': ['hi there', 'alt'],
            'swipe_index': 0,
            'swipe_durations': [0, 0],
            'metadata': {
              'realism_state': {'affectionScore': 42, 'trustLevel': 10},
            },
          },
        ],
      );
      expect(msgs, hasLength(2));
      expect(msgs[0].text, 'hello');
      expect(msgs[1].swipes, ['hi there', 'alt']);
      expect(msgs[1].activeMetadata?['realism_state']?['affectionScore'], 42);
    });

    test('transcript-only when extras null', () {
      final msgs = messagesFromPackage(
        laneA: [
          {'name': 'A', 'is_user': false, 'mes': 'plain'},
        ],
      );
      expect(msgs.single.metadata, isNull);
      expect(msgs.single.text, 'plain');
    });
  });

  group('zip codec', () {
    test('round-trips chat.json + images', () {
      final root = {
        'format': kFpchatFormatId,
        'version': 1,
        'messages': [
          {'name': 'U', 'is_user': true, 'mes': 'x'},
        ],
        'fpai': {
          'version': 1,
          'stamp_version': kFpchatStampVersion,
          'messages_extra': [],
        },
      };
      final zip = encodeFpchatZip(
        chatJson: root,
        images: {
          'pic.png': utf8.encode('fake-png'),
        },
      );
      expect(zip, isA<Uint8List>());
      final decoded = decodeFpchatBytes(zip);
      expect(decoded.chatJson['format'], kFpchatFormatId);
      expect(utf8.decode(decoded.images['pic.png']!), 'fake-png');
    });

    test('raw JSON bytes decode as transcript', () {
      final raw = utf8.encode(
        jsonEncode({
          'messages': [
            {'name': 'U', 'is_user': true, 'mes': 'hi'},
          ],
        }),
      );
      final decoded = decodeFpchatBytes(Uint8List.fromList(raw));
      expect(
        detectFpchatPayload(decoded.chatJson),
        FpchatPayloadKind.sillyTavernIsh,
      );
      expect(decoded.images, isEmpty);
    });
  });

  group('lane builders', () {
    test('laneAMessage is ST-shaped', () {
      final m = ChatMessage(text: 'yo', sender: 'Bob', isUser: true);
      final a = laneAMessage(m);
      expect(a.keys, containsAll(['name', 'is_user', 'mes', 'send_date']));
      expect(a['name'], 'Bob');
      expect(a['is_user'], true);
      expect(a['mes'], 'yo');
    });
  });
}
