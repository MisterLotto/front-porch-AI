// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:io';

/// True when [uri] is a public http(s) destination the host may fetch.
///
/// Fail-closed: parse errors, missing host, and non-http(s) schemes are
/// unsafe. Rejects loopback, RFC1918, link-local (incl. 169.254.169.254),
/// IPv6 ULA, localhost, and `.local` names so an authenticated web caller
/// cannot SSRF the desktop host into the LAN or cloud metadata.
bool isSafeOutboundUrl(Uri uri) {
  try {
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return false;
    var host = uri.host.trim().toLowerCase();
    if (host.isEmpty) return false;
    if (host.startsWith('[') && host.endsWith(']')) {
      host = host.substring(1, host.length - 1);
    }
    if (host == 'localhost' || host.endsWith('.localhost')) return false;
    if (host.endsWith('.local')) return false;
    // Bare integers are a classic SSRF bypass (decimal IPv4).
    if (RegExp(r'^\d+$').hasMatch(host)) return false;

    final addr = InternetAddress.tryParse(host);
    if (addr == null) return true;
    if (addr.isLoopback || addr.isLinkLocal) return false;
    if (addr.type == InternetAddressType.IPv4) {
      return !_isBlockedIpv4(addr.rawAddress);
    }
    if (addr.type == InternetAddressType.IPv6) {
      return !_isBlockedIpv6(addr.rawAddress);
    }
    return false;
  } catch (_) {
    return false;
  }
}

bool _isBlockedIpv4(List<int> b) {
  if (b.length != 4) return true;
  final a = b[0], c = b[1];
  if (a == 0 || a == 10 || a == 127) return true;
  if (a == 169 && c == 254) return true;
  if (a == 172 && c >= 16 && c <= 31) return true;
  if (a == 192 && c == 168) return true;
  return false;
}

bool _isBlockedIpv6(List<int> b) {
  if (b.length != 16) return true;
  // Unique-local fc00::/7 (includes fd00::/8).
  if ((b[0] & 0xfe) == 0xfc) return true;
  // IPv4-mapped ::ffff:0:0/96 — apply the IPv4 rules to the tail.
  var mapped = true;
  for (var i = 0; i < 10; i++) {
    if (b[i] != 0) {
      mapped = false;
      break;
    }
  }
  if (mapped && b[10] == 0xff && b[11] == 0xff) {
    return _isBlockedIpv4(b.sublist(12));
  }
  return false;
}
