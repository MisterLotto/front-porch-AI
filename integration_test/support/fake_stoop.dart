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

  final List<String> unexpectedPaths = [];
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
      await utf8.decodeStream(req); // drain any body (JSON or multipart)
      Object? reply;
      switch ('${req.method} $path') {
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
      // Usually a request racing test teardown — logged so a genuine handler
      // bug can't hide. ignore: avoid_print — test support.
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
