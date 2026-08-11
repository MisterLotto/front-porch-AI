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

import 'dart:convert';
import 'dart:math';

/// Pure helpers for first-run web account claim (audit P0.5).
///
/// While setup is open, `POST /api/auth/setup` is a public API. A direct
/// browser on the host (loopback peer, no proxy headers) may claim the
/// account. LAN binds, Tailscale serve, and ngrok proxy from loopback but
/// set `X-Forwarded-*` — those clients need a one-time token shown only on
/// the desktop Settings card.
class SetupGate {
  SetupGate._();

  /// True when the TCP peer is loopback and no reverse-proxy headers are
  /// present. Proxies that terminate TLS on the host still connect as
  /// loopback, so forwarded headers are the remote-client signal.
  static bool isDirectLoopbackClient({
    required bool peerIsLoopback,
    String? xForwardedFor,
    String? xForwardedProto,
  }) {
    if (!peerIsLoopback) return false;
    if (xForwardedFor != null && xForwardedFor.trim().isNotEmpty) {
      return false;
    }
    if (xForwardedProto != null && xForwardedProto.trim().isNotEmpty) {
      return false;
    }
    return true;
  }

  /// Cryptographically random URL-safe token (~24 chars). Desktop-only
  /// display; never returned from HTTP APIs.
  static String generateToken() {
    final bytes = List<int>.generate(18, (_) => Random.secure().nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Constant-time equality for setup tokens (length mismatch fails closed).
  static bool tokensMatch(String? provided, String? expected) {
    if (provided == null || expected == null) return false;
    final a = provided.trim();
    final b = expected;
    if (a.isEmpty || b.isEmpty || a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
