// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Guard: the textual SSRF bypasses that used to sail past isSafeOutboundUrl.
// The function's whole IP block was dead for anything the OS resolver — but
// not `InternetAddress.tryParse` — understands: `127.1`, `0x7f000001`, a
// trailing-dot `localhost.`, and the wildcard-DNS names that spell a private
// address (`127.0.0.1.nip.io`). Both callers (the lore scraper and the remote
// backend model probe) fetch from the desktop host and hand the result back to
// a web caller, so each of these was a live SSRF path.
//
// NOT covered, deliberately, because the check is synchronous and cannot be:
// a public name whose A record points into private space. Closing that needs
// resolve-and-pin at the call sites.

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/utils/utils.dart';

void main() {
  group('isSafeOutboundUrl — name-shaped bypasses', () {
    test('rejects the FQDN spelling of a blocked name', () {
      expect(isSafeOutboundUrl(Uri.parse('http://localhost./')), isFalse);
      expect(isSafeOutboundUrl(Uri.parse('http://printer.local./')), isFalse);
    });

    test('rejects inet_aton shorthand the resolver still accepts', () {
      // 127.1 and 0x7f000001 both reach 127.0.0.1 via getaddrinfo.
      expect(isSafeOutboundUrl(Uri.parse('http://127.1/')), isFalse);
      expect(isSafeOutboundUrl(Uri.parse('http://0x7f000001/')), isFalse);
      expect(isSafeOutboundUrl(Uri.parse('http://010.0.0.1/')), isFalse);
    });

    test('rejects wildcard-DNS names that spell a private address', () {
      expect(
        isSafeOutboundUrl(Uri.parse('http://127.0.0.1.nip.io:8085/api/')),
        isFalse,
      );
      expect(
        isSafeOutboundUrl(Uri.parse('http://169.254.169.254.nip.io/latest/')),
        isFalse,
      );
      expect(
        isSafeOutboundUrl(Uri.parse('http://10-0-0-5.sslip.io/')),
        isFalse,
      );
    });

    test('rejects CGNAT/Tailscale, protocol and multicast ranges', () {
      expect(isSafeOutboundUrl(Uri.parse('http://100.100.1.2/')), isFalse);
      expect(isSafeOutboundUrl(Uri.parse('http://192.0.0.8/')), isFalse);
      expect(isSafeOutboundUrl(Uri.parse('http://198.18.0.1/')), isFalse);
      expect(isSafeOutboundUrl(Uri.parse('http://239.255.255.250/')), isFalse);
    });

    test('still allows ordinary public destinations', () {
      expect(isSafeOutboundUrl(Uri.parse('https://example.com./wiki')), isTrue);
      expect(isSafeOutboundUrl(Uri.parse('https://en.wikipedia.org/wiki/X')), isTrue);
      expect(isSafeOutboundUrl(Uri.parse('http://my-server.example.com/x')), isTrue);
      expect(isSafeOutboundUrl(Uri.parse('http://8.8.8.8/')), isTrue);
      // A public literal spelled in a longer name must not be over-blocked.
      expect(isSafeOutboundUrl(Uri.parse('http://8.8.8.8.example.com/')), isTrue);
      expect(isSafeOutboundUrl(Uri.parse('https://openrouter.ai/api/v1')), isTrue);
    });
  });
}
