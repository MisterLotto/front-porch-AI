// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/utils/utils.dart';

void main() {
  group('isSafeOutboundUrl', () {
    test('allows public http(s) hosts', () {
      expect(isSafeOutboundUrl(Uri.parse('https://example.com/wiki')), isTrue);
      expect(
        isSafeOutboundUrl(Uri.parse('http://openrouter.ai/api/v1')),
        isTrue,
      );
    });

    test('rejects loopback, localhost, and .local', () {
      expect(isSafeOutboundUrl(Uri.parse('http://127.0.0.1/admin')), isFalse);
      expect(isSafeOutboundUrl(Uri.parse('http://localhost:8080/')), isFalse);
      expect(isSafeOutboundUrl(Uri.parse('https://foo.localhost/')), isFalse);
      expect(isSafeOutboundUrl(Uri.parse('http://printer.local/')), isFalse);
      expect(isSafeOutboundUrl(Uri.parse('http://[::1]/')), isFalse);
    });

    test('rejects RFC1918, link-local, and cloud metadata', () {
      expect(isSafeOutboundUrl(Uri.parse('http://10.0.0.5/')), isFalse);
      expect(isSafeOutboundUrl(Uri.parse('http://192.168.1.1/')), isFalse);
      expect(isSafeOutboundUrl(Uri.parse('http://172.16.0.1/')), isFalse);
      expect(isSafeOutboundUrl(Uri.parse('http://172.31.255.1/')), isFalse);
      expect(
        isSafeOutboundUrl(Uri.parse('http://169.254.169.254/latest/meta-data/')),
        isFalse,
      );
    });

    test('rejects IPv6 ULA and IPv4-mapped private', () {
      expect(
        isSafeOutboundUrl(Uri.parse('http://[fd12:3456:789a::1]/')),
        isFalse,
      );
      expect(
        isSafeOutboundUrl(Uri.parse('http://[fc00::1]/')),
        isFalse,
      );
      expect(
        isSafeOutboundUrl(Uri.parse('http://[::ffff:127.0.0.1]/')),
        isFalse,
      );
      expect(
        isSafeOutboundUrl(Uri.parse('http://[::ffff:192.168.0.1]/')),
        isFalse,
      );
    });

    test('fails closed on non-http schemes, empty host, and decimal IPv4', () {
      expect(isSafeOutboundUrl(Uri.parse('ftp://example.com/')), isFalse);
      expect(isSafeOutboundUrl(Uri.parse('file:///etc/passwd')), isFalse);
      expect(isSafeOutboundUrl(Uri.parse('not a url')), isFalse);
      expect(isSafeOutboundUrl(Uri.parse('https://')), isFalse);
      // 127.0.0.1 as a decimal integer.
      expect(isSafeOutboundUrl(Uri.parse('http://2130706433/')), isFalse);
    });
  });
}
