// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:io';

/// True when [uri] is a public http(s) destination the host may fetch.
///
/// Fail-closed: parse errors, missing host, and non-http(s) schemes are
/// unsafe. Rejects loopback, RFC1918, CGNAT, link-local (incl.
/// 169.254.169.254), IPv6 ULA, localhost, and `.local` names so an
/// authenticated web caller cannot SSRF the desktop host into the LAN or
/// cloud metadata.
///
/// LIMIT, stated honestly: this check is synchronous, so a DNS **name** is
/// never resolved here — a public name whose A record points at private space
/// (wildcard-DNS services, an attacker-controlled record) still passes, and a
/// rebind between check and connect is possible regardless. Closing that
/// needs the caller to resolve, validate every returned address, and pin the
/// connection to a vetted one. What IS closed textually: names that spell a
/// private literal (`127.0.0.1.nip.io`, `10-0-0-1.example`) and the inet_aton
/// shorthands the OS resolver accepts (`127.1`, `0x7f000001`, `2130706433`).
bool isSafeOutboundUrl(Uri uri) {
  try {
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return false;
    var host = uri.host.trim().toLowerCase();
    if (host.startsWith('[') && host.endsWith(']')) {
      host = host.substring(1, host.length - 1);
    }
    // `localhost.` is the FQDN spelling of `localhost` and resolves the same,
    // so strip trailing dots before any name comparison.
    while (host.endsWith('.')) {
      host = host.substring(0, host.length - 1);
    }
    if (host.isEmpty) return false;
    if (host == 'localhost' || host.endsWith('.localhost')) return false;
    if (host.endsWith('.local')) return false;

    final addr = InternetAddress.tryParse(host);
    if (addr != null) {
      if (addr.isLoopback || addr.isLinkLocal) return false;
      if (addr.type == InternetAddressType.IPv4) {
        return !_isBlockedIpv4(addr.rawAddress);
      }
      if (addr.type == InternetAddressType.IPv6) {
        return !_isBlockedIpv6(addr.rawAddress);
      }
      return false;
    }

    // Not a literal address, so it is a name. A real domain never ends in an
    // all-numeric (or 0x-hex) label — but `getaddrinfo` still turns those into
    // addresses, which is the classic decimal/octal/hex IPv4 bypass.
    final labels = host.split('.');
    if (RegExp(r'^(0x[0-9a-f]+|\d+)$').hasMatch(labels.last)) return false;
    if (_spellsBlockedIpv4(labels)) return false;
    return true;
  } catch (_) {
    return false;
  }
}

/// True when the leading labels of a host name spell a blocked IPv4 address —
/// the wildcard-DNS pattern (`127.0.0.1.nip.io`, `10-0-0-1.sslip.io`), which
/// resolves straight back to the address it names.
bool _spellsBlockedIpv4(List<String> labels) {
  final candidates = <String>[
    if (labels.length >= 4) labels.take(4).join('.'),
    if (labels.isNotEmpty && labels.first.contains('-'))
      labels.first.replaceAll('-', '.'),
  ];
  for (final c in candidates) {
    final a = InternetAddress.tryParse(c);
    if (a == null || a.type != InternetAddressType.IPv4) continue;
    if (a.isLoopback || a.isLinkLocal || _isBlockedIpv4(a.rawAddress)) {
      return true;
    }
  }
  return false;
}

bool _isBlockedIpv4(List<int> b) {
  if (b.length != 4) return true;
  final a = b[0], c = b[1];
  if (a == 0 || a == 10 || a == 127) return true;
  if (a == 169 && c == 254) return true;
  if (a == 172 && c >= 16 && c <= 31) return true;
  if (a == 192 && c == 168) return true;
  // Carrier-grade NAT 100.64.0.0/10 — also the Tailscale range this app is
  // routinely reached over, so it is LAN as far as SSRF is concerned.
  if (a == 100 && c >= 64 && c <= 127) return true;
  // IETF protocol assignments 192.0.0.0/24 and benchmarking 198.18.0.0/15.
  if (a == 192 && c == 0 && b[2] == 0) return true;
  if (a == 198 && (c == 18 || c == 19)) return true;
  // Multicast, reserved, and broadcast (224.0.0.0/4 upward).
  if (a >= 224) return true;
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
