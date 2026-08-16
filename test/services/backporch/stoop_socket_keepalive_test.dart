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

// THE STOOP SOCKET HAS TO NOTICE WHEN IT DIES.
//
// Reconnection is driven purely by onDone/onError, which only fire when the
// peer actually signals a close. A NAT/router that silently drops an idle TCP
// connection (routine on home routers and hotspots) therefore left the socket
// half-open forever: no bell badge, no moderator-message snackbar, frozen
// vote/download counters — with nothing on screen saying so. `pingInterval`
// is what makes dart:io close (and so reconnect) when the pongs stop.
//
// Real loopback WebSocket, not a mock: the pref only exists on a live socket.
// Proven to fail: remove the `ws.pingInterval = ...` line in
// stoop_message_socket.dart and this goes red (null).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/services/backporch/backporch.dart';

void main() {
  late HttpServer server;
  final sockets = <WebSocket>[];

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      if (req.uri.path == '/ws' &&
          WebSocketTransformer.isUpgradeRequest(req)) {
        sockets.add(await WebSocketTransformer.upgrade(req));
        return;
      }
      // The bell's unread pre-fetch — answer it so nothing hangs.
      req.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write('{"count":0}');
      await req.response.close();
    });
    BackporchApi.overrideBaseUrl =
        'http://${server.address.address}:${server.port}';
  });

  tearDown(() async {
    BackporchApi.overrideBaseUrl = null;
    for (final s in sockets) {
      await s.close();
    }
    await server.close(force: true);
  });

  test('the live socket is armed with a keepalive ping', () async {
    final socket = StoopMessageSocket(() => 'test-token');
    addTearDown(socket.dispose);

    // Let the connect future land.
    for (var i = 0; i < 50 && socket.pingInterval == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    expect(
      sockets,
      isNotEmpty,
      reason: 'the client must have actually reached the loopback server',
    );
    expect(
      socket.pingInterval,
      isNotNull,
      reason:
          'THE BUG: with no ping the client never learns the peer is gone, so '
          'a silently dropped connection is never reconnected',
    );
    expect(socket.pingInterval, const Duration(seconds: 30));
  });
}
