// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Guards the StreamHub token coalescer: the generation loop pushes one event
// PER TOKEN, and relaying each as its own WS frame is what melted iPad Safari
// during fast local generation (a full client re-render per frame — the same
// failure the desktop's 33ms notify coalescer fixed). Tokens must batch into
// one frame per flush window, flush synchronously before done/error so no
// tail is lost, and concatenate in order. Same real-socket harness as
// stream_hub_test.dart.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:front_porch_ai/services/web/streaming/stream_hub.dart';

void main() {
  group('StreamHub token coalescing', () {
    late StreamController<String> tokens;
    late StreamHub hub;
    late dynamic server; // HttpServer
    late int port;

    setUp(() async {
      tokens = StreamController<String>.broadcast();
      hub = StreamHub(tokens.stream, () => false);
      final handler = webSocketHandler(
        (WebSocketChannel ch, String? _) => hub.register(ch),
      );
      server = await shelf_io.serve(handler, 'localhost', 0);
      port = server.port as int;
    });

    tearDown(() async {
      await hub.dispose();
      await tokens.close();
      await server.close(force: true);
    });

    Future<(List<Map<String, dynamic>>, WebSocketChannel)> connect() async {
      final client = WebSocketChannel.connect(
        Uri.parse('ws://localhost:$port/api/ws'),
      );
      await client.ready;
      final events = <Map<String, dynamic>>[];
      client.stream.listen(
        (msg) => events.add(jsonDecode(msg as String) as Map<String, dynamic>),
      );
      // Give the server a tick to register + send 'connected'.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return (events, client);
    }

    test('a burst of tokens coalesces into ONE frame, flushed before done',
        () async {
      final (events, client) = await connect();

      tokens.add('Hel');
      tokens.add('lo ');
      tokens.add('porch');
      tokens.add('__DONE__');
      await Future<void>.delayed(const Duration(milliseconds: 150));

      final tokenFrames = events.where((e) => e['event'] == 'token').toList();
      expect(
        tokenFrames,
        hasLength(1),
        reason: 'per-token frames melt iPad Safari — a burst inside one '
            'flush window must arrive as a single concatenated frame',
      );
      expect(tokenFrames.single['data'], 'Hello porch');

      final order = events.map((e) => e['event']).toList();
      expect(
        order.indexOf('token'),
        lessThan(order.indexOf('done')),
        reason: 'the buffered tail must flush BEFORE the done event or the '
            'client discards it',
      );
      await client.sink.close();
    });

    test('tokens flush on the timer when no terminal event arrives', () async {
      final (events, client) = await connect();

      tokens.add('slow');
      // Well within the flush window nothing should have arrived yet;
      // after it, exactly one frame.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final tokenFrames = events.where((e) => e['event'] == 'token').toList();
      expect(tokenFrames, hasLength(1));
      expect(tokenFrames.single['data'], 'slow');
      await client.sink.close();
    });

    test('error also flushes the pending tail first', () async {
      final (events, client) = await connect();

      tokens.add('partial');
      tokens.add('__ERROR__');
      await Future<void>.delayed(const Duration(milliseconds: 150));

      final order = events.map((e) => e['event']).toList();
      expect(order, containsAllInOrder(['token', 'error']));
      expect(
        events.firstWhere((e) => e['event'] == 'token')['data'],
        'partial',
      );
      await client.sink.close();
    });
  });
}
