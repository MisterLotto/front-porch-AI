// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// In-process stand-in for the backporch API (The Stoop's backend), pointed
// at via BackporchApi.overrideBaseUrl. Models the endpoints of a sign-in →
// policy gate → browse → download → upload journey; unmodeled paths land in
// [unexpectedPaths], asserted empty by the suite.
//
// Stateful on purpose in exactly one place: the AUP gate. Login returns a
// user whose acceptedPolicyVersion is EMPTY against policyVersion 1.3, so
// the real StoopPolicyGate renders; POST /auth/accept-policy flips
// [policyAccepted] and later /auth/me-shaped payloads carry the accepted
// version — proving the gate's whole loop rather than skipping it.

import 'dart:convert';
import 'dart:io';

class FakeStoopServer {
  FakeStoopServer._(this._server);

  final HttpServer _server;

  static const String policyVersion = '1.3';

  bool policyAccepted = false;
  int loginRequests = 0;
  int browseRequests = 0;
  int detailRequests = 0;
  int downloadRequests = 0;
  int uploadRequests = 0;
  int creatorRequests = 0;

  final List<String> unexpectedPaths = [];

  /// Handler crashes. Asserted empty by the suite: a fake that throws while
  /// serving answers nothing, the app sees an empty response, and the test
  /// dies at whatever it was waiting for — naming a symptom minutes later
  /// instead of the broken handler. That cost a full CI round when the
  /// multipart upload was drained with utf8.decodeStream.
  final List<String> handlerErrors = [];
  final List<WebSocket> _sockets = [];

  String get baseUrl => 'http://127.0.0.1:${_server.port}';

  static Future<FakeStoopServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fake = FakeStoopServer._(server);
    server.listen(fake._handle);
    return fake;
  }

  Map<String, dynamic> get _user => {
    'id': 'u1',
    'email': 'porch@example.com',
    'displayName': 'PorchFriend',
    'role': 'USER',
    'ageVerified': true,
    'emailVerified': true,
    'nsfwEnabled': false,
    'acceptedPolicyVersion': policyAccepted ? policyVersion : '',
    'twoFactorEnabled': false,
    'createdAt': '2026-01-01T00:00:00Z',
  };

  static const Map<String, dynamic> _browseCard = {
    'id': 'c1',
    'name': 'Misty',
    'summary': 'A gentle porch spirit who remembers every guest.',
    'type': 'SOLO',
    'nsfw': false,
    'score': 4,
    'downloadCount': 9,
    'modPick': false,
    'creator': {'id': 'u2', 'displayName': 'NeighborJo'},
  };

  /// A real Character Card V2 envelope — the solo download path writes this
  /// to card.json and V2CardService must parse it, so a lazy stub here means
  /// 'parse failed' in the app.
  static const Map<String, dynamic> _cardV2 = {
    'spec': 'chara_card_v2',
    'spec_version': '2.0',
    'data': {
      'name': 'Misty',
      'description': 'A gentle porch spirit who remembers every guest.',
      'personality': 'Warm, wistful, watchful.',
      'first_mes': 'The porch boards barely creak as Misty appears.',
      'scenario': 'Dusk on the porch.',
    },
  };

  Future<void> _handle(HttpRequest req) async {
    final path = req.uri.path;
    try {
      if (path == '/ws') {
        // Hold the messaging socket open so the bell's 3s reconnect timer
        // stays quiet for the whole run.
        final socket = await WebSocketTransformer.upgrade(req);
        _sockets.add(socket);
        return; // upgraded — no response object to close
      }
      // Drain as BYTES, never utf8.decodeStream: the upload endpoint is
      // multipart carrying a PNG, and UTF-8 decoding binary throws
      // "Unexpected extension byte" — which surfaced only as a swallowed
      // handler error while the suite waited out a four-minute timeout.
      await req.drain<void>();
      Object? reply;
      // Creator ids are data, not routes — collapse /creators/<anything> to
      // one case so a new fixture id can't reopen the unmodelled-path hole.
      // unexpectedPaths still records the REAL path for diagnostics.
      final route = path.startsWith('/creators/') && !path.endsWith('/follow')
          ? '${req.method} /creators/*'
          : '${req.method} $path';
      switch (route) {
        case 'POST /auth/login':
          loginRequests++;
          reply = {
            'user': _user,
            'accessToken': 'fake-access',
            'refreshToken': 'fake-refresh',
            'policyVersion': policyVersion,
          };
        case 'POST /auth/accept-policy':
          policyAccepted = true;
          reply = {'user': _user, 'policyVersion': policyVersion};
        case 'GET /characters':
          browseRequests++;
          reply = {
            'total': 1,
            'page': 0,
            'items': [_browseCard],
          };
        case 'GET /characters/c1':
          detailRequests++;
          reply = {
            ..._browseCard,
            'version': 1,
            'tags': ['cozy', 'porch'],
            'myVote': 0,
            'card': _cardV2,
          };
        case 'POST /characters/c1/download':
          downloadRequests++;
          reply = {'card': _cardV2, 'downloadCount': 10};
        case 'POST /characters':
          uploadRequests++;
          reply = {'id': 'up1', 'status': 'PENDING'};
        case 'GET /creators/*':
          // The @you tab renders the signed-in user's own creator profile.
          // Every field is defaulted by StoopCreator.fromJson, so a minimal
          // profile parses fine.
          creatorRequests++;
          reply = {
            'id': path.split('/').last,
            'displayName': 'PorchFriend',
            'followers': 0,
            'following': false,
            'isMe': path.endsWith('u1'),
            'cards': <Object>[],
            'bio': '',
            'links': <String>[],
            'stats': {'cards': 0, 'downloads': 0, 'score': 0},
          };
        case 'GET /me/messages/unread':
          reply = {'count': 0};
        case 'GET /me/characters':
        case 'GET /me/downloads':
        case 'GET /me/following':
          reply = {'items': <Object>[]};
        case 'POST /me/app-ping':
          req.response.statusCode = HttpStatus.noContent;
        default:
          unexpectedPaths.add('${req.method} $path');
          req.response.statusCode = HttpStatus.notFound;
          req.response.headers.contentType = ContentType.json;
          req.response.write(jsonEncode({'error': 'not_modeled'}));
      }
      if (reply != null) {
        req.response.headers.contentType = ContentType.json;
        req.response.write(jsonEncode(reply));
      }
    } catch (e) {
      handlerErrors.add('${req.method} $path: $e');
      // ignore: avoid_print — test support; print reaches the suite log.
      print('[FakeStoopServer] handler error on $path: $e');
    } finally {
      if (path != '/ws') {
        try {
          await req.response.close();
        } catch (_) {}
      }
    }
  }

  Future<void> close() async {
    for (final s in _sockets) {
      try {
        await s.close();
      } catch (_) {}
    }
    await _server.close(force: true);
  }
}
