// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Live comments client hits the hub, not the in-memory notepad.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/services/backporch/backporch_api.dart';
import 'package:front_porch_ai/services/backporch/backporch_user.dart';
import 'package:front_porch_ai/services/backporch/http_stoop_comments_client.dart';

BackporchUser get _user => const BackporchUser(
  id: 'u1',
  email: 'a@b.c',
  displayName: 'Ada',
  role: 'USER',
  ageVerified: true,
  emailVerified: true,
  nsfwEnabled: false,
  acceptedPolicyVersion: '1',
  twoFactorEnabled: false,
);

void main() {
  setUpAll(() => HttpOverrides.global = null);

  test('list/create talk to /characters/:id/comments', () async {
    String? seenMethod;
    String? seenPath;
    String? seenAuth;
    String? seenBody;
    final upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => upstream.close(force: true));
    upstream.listen((req) async {
      seenMethod = req.method;
      seenPath = req.uri.path;
      seenAuth = req.headers.value('authorization');
      seenBody = await utf8.decoder.bind(req).join();
      req.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json;
      if (req.method == 'GET') {
        req.response.write(
          jsonEncode({
            'items': [
              {
                'id': 'c1',
                'cardId': 'card1',
                'authorId': 'u2',
                'displayName': 'Bea',
                'createdAt': '2026-08-01T00:00:00Z',
                'body': 'hello',
              },
            ],
          }),
        );
      } else {
        req.response.write(
          jsonEncode({
            'id': 'c2',
            'cardId': 'card1',
            'authorId': 'u1',
            'displayName': 'Ada',
            'createdAt': '2026-08-01T00:00:00Z',
            'body': 'yo',
          }),
        );
      }
      await req.response.close();
    });

    final client = HttpStoopCommentsClient(
      BackporchApi(baseUrl: 'http://127.0.0.1:${upstream.port}'),
      () => 'tok',
    );

    final listed = await client.list('card1');
    expect(seenMethod, 'GET');
    expect(seenPath, '/characters/card1/comments');
    expect(seenAuth, 'Bearer tok');
    expect(listed, hasLength(1));
    expect(listed.single.body, 'hello');

    final created = await client.create(
      cardId: 'card1',
      body: 'yo',
      author: _user,
    );
    expect(seenMethod, 'POST');
    expect(jsonDecode(seenBody!), {'body': 'yo'});
    expect(created.id, 'c2');
  });

  test('hub error codes surface as BackporchApiException', () async {
    final upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => upstream.close(force: true));
    upstream.listen((req) async {
      req.response
        ..statusCode = 403
        ..headers.contentType = ContentType.json
        ..write('{"error":"comments_disabled"}');
      await req.response.close();
    });
    final client = HttpStoopCommentsClient(
      BackporchApi(baseUrl: 'http://127.0.0.1:${upstream.port}'),
      () => 'tok',
    );
    expect(
      () => client.create(cardId: 'card1', body: 'yo', author: _user),
      throwsA(
        isA<BackporchApiException>().having(
          (e) => e.code,
          'code',
          'comments_disabled',
        ),
      ),
    );
  });
}
