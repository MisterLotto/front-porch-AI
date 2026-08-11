// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/services/web/auth/setup_gate.dart';

void main() {
  group('SetupGate', () {
    test('direct loopback without proxy headers is local', () {
      expect(
        SetupGate.isDirectLoopbackClient(peerIsLoopback: true),
        isTrue,
      );
    });

    test('non-loopback peer is not local', () {
      expect(
        SetupGate.isDirectLoopbackClient(peerIsLoopback: false),
        isFalse,
      );
    });

    test('loopback peer with X-Forwarded-For is treated as remote (tunnel)', () {
      expect(
        SetupGate.isDirectLoopbackClient(
          peerIsLoopback: true,
          xForwardedFor: '203.0.113.10',
        ),
        isFalse,
      );
    });

    test('loopback peer with X-Forwarded-Proto is treated as remote', () {
      expect(
        SetupGate.isDirectLoopbackClient(
          peerIsLoopback: true,
          xForwardedProto: 'https',
        ),
        isFalse,
      );
    });

    test('tokensMatch is length-sensitive and rejects blanks', () {
      final t = SetupGate.generateToken();
      expect(SetupGate.tokensMatch(t, t), isTrue);
      expect(SetupGate.tokensMatch(' $t ', t), isTrue);
      expect(SetupGate.tokensMatch(null, t), isFalse);
      expect(SetupGate.tokensMatch(t, null), isFalse);
      expect(SetupGate.tokensMatch('', t), isFalse);
      expect(SetupGate.tokensMatch('x' * t.length, t), isFalse);
    });

    test('generateToken is long enough and URL-safe-ish', () {
      final a = SetupGate.generateToken();
      final b = SetupGate.generateToken();
      expect(a.length, greaterThanOrEqualTo(16));
      expect(a, isNot(b));
      expect(a.contains('='), isFalse);
    });
  });
}
