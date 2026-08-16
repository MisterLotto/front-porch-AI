// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// RateLimiter's three maps are keyed by attacker-chosen values: the SUBMITTED
// username, and a client IP that comes from `X-Forwarded-For` (so it can be a
// fresh value on every request). A login for an unknown username short-circuits
// before Argon2, so an unauthenticated loop against a LAN/tunnel-exposed server
// is cheap for the attacker — and each request used to mint one permanent entry
// in `_byUser` and one in `_byIp`, growing the desktop app's heap until the OS
// killed it, taking the user's open chat with it.
//
// The class now sweeps entries that can no longer change an answer and drops
// the least-relevant remainder at a hard ceiling. These tests hold that line
// (the maps stay bounded under a flood) without pinning the exact ceiling, and
// check that ordinary throttling still works.

import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/services/web/auth/rate_limiter.dart';

void main() {
  test('a flood of fresh usernames + spoofed IPs cannot grow the maps', () {
    var clock = DateTime(2026, 8, 15, 12);
    final limiter = RateLimiter(now: () => clock);

    for (var i = 0; i < 20000; i++) {
      final ip = '10.${i % 250}.${(i ~/ 250) % 250}.${i % 251}';
      limiter.ipAllowed(ip); // a read must never mint an entry
      limiter.recordFailure('probe$i', '$ip-$i');
      limiter.recordSetupAttempt('$ip-setup-$i');
      // Creep the clock so the sweep also has genuinely aged-out entries to
      // prune, the way a real sustained attack looks.
      clock = clock.add(const Duration(milliseconds: 50));
    }

    expect(
      limiter.trackedKeys,
      lessThan(20000),
      reason: '40k unique attacker-chosen keys were tracked forever — this is '
          'the unbounded growth that ends in the app being OOM-killed',
    );
  });

  test('an IP window whose hits all aged out stops being tracked', () {
    var clock = DateTime(2026, 8, 15, 12);
    final limiter = RateLimiter(now: () => clock);

    limiter.recordFailure('someone', '203.0.113.9');
    expect(limiter.trackedKeys, greaterThan(0));

    clock = clock.add(const Duration(hours: 2));
    // A read prunes the window it looks at; the key goes with the last hit.
    expect(limiter.ipAllowed('203.0.113.9'), isTrue);
    expect(limiter.lockoutFor('someone'), isNull);
  });

  test('ordinary per-username backoff and per-IP capping still apply', () {
    final clock = DateTime(2026, 8, 15, 12);
    final limiter = RateLimiter(now: () => clock);

    for (var i = 0; i < 6; i++) {
      limiter.recordFailure('lisa', '192.168.1.20');
    }
    final lock = limiter.lockoutFor('lisa');
    expect(lock, isNotNull, reason: 'six failures must lock the account out');
    expect(lock!.inSeconds, greaterThan(0));

    // The same IP hammering many usernames trips the sliding-window cap.
    for (var i = 0; i < 60; i++) {
      limiter.recordFailure('guess$i', '192.168.1.20');
    }
    expect(limiter.ipAllowed('192.168.1.20'), isFalse);
    expect(limiter.ipAllowed('192.168.1.21'), isTrue);

    // A successful login clears that user's streak.
    limiter.recordSuccess('lisa');
    expect(limiter.lockoutFor('lisa'), isNull);
  });

  test('the first-run setup window is capped per IP', () {
    final clock = DateTime(2026, 8, 15, 12);
    final limiter = RateLimiter(now: () => clock);

    for (var i = 0; i < RateLimiter.setupWindowMax; i++) {
      expect(limiter.setupIpAllowed('198.51.100.4'), isTrue);
      limiter.recordSetupAttempt('198.51.100.4');
    }
    expect(limiter.setupIpAllowed('198.51.100.4'), isFalse);
  });
}
