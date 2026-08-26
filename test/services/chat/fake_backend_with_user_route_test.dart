// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The With-you glance pass is a standalone post-reply eval. If the E2E fake
// does not recognize `"with_user"`, it answers with canned CHAT prose, bumps
// chatRequests, and clobbers lastChatBody — which is how group_smoke /
// group_realism_wiring / lorebook_chat went red on 21bfd8c3.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/services/chat/chat.dart';

import '../../../integration_test/support/fake_backend.dart';

void main() {
  test('with_user glance prompt is EVAL, not CHAT', () async {
    HttpOverrides.global = null;
    final backend = await FakeBackendServer.start(
      replyPieces: const ['Wired for sound, ', 'both of us.'],
    );
    addTearDown(backend.close);

    final prompt = WithUserEval.buildPrompt(
      charName: 'Ada',
      userName: 'Ben',
      reply: 'Wired for sound, both of us.',
      recentExchange: '',
      stance: 'standing',
      toolsMode: false,
    );

    final glance = await _complete(backend.baseUrl, prompt);
    expect(
      backend.evalRequests,
      1,
      reason: 'the glance pass must count as an eval, not a conversation turn',
    );
    expect(backend.chatRequests, 0);
    expect(backend.lastChatBody, isEmpty);
    expect(jsonDecode(glance), {'with_user': true});

    final chat = await _complete(backend.baseUrl, 'Hello from the porch.');
    expect(backend.chatRequests, 1);
    expect(backend.evalRequests, 1);
    expect(chat, 'Wired for sound, both of us.');
    expect(backend.lastChatBody, contains('Hello from the porch.'));
  });
}

Future<String> _complete(String baseUrl, String content) async {
  final client = HttpClient();
  addTearDown(client.close);
  final req = await client.postUrl(Uri.parse('$baseUrl/v1/chat/completions'));
  req.headers.contentType = ContentType.json;
  req.write(
    jsonEncode({
      'model': 'smoke-model',
      'stream': true,
      'messages': [
        {'role': 'user', 'content': content},
      ],
    }),
  );
  final resp = await req.close();
  expect(resp.statusCode, 200);
  final raw = await utf8.decodeStream(resp);
  final buf = StringBuffer();
  for (final line in raw.split('\n')) {
    if (!line.startsWith('data: ')) continue;
    final data = line.substring(6).trim();
    if (data == '[DONE]' || data.isEmpty) continue;
    final decoded = jsonDecode(data) as Map<String, dynamic>;
    final choices = decoded['choices'] as List<dynamic>;
    final delta = (choices.first as Map<String, dynamic>)['delta'];
    final piece = (delta as Map<String, dynamic>)['content'];
    if (piece is String) buf.write(piece);
  }
  return buf.toString();
}
