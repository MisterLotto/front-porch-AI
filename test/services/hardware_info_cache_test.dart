// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// HardwareService used to re-detect from its constructor on every launch and
// never persist the answer — on Windows that is up to four PowerShell spawns
// plus nvidia-smi, running while the provider tree builds and the library
// loads. The result is now cached so the next launch has correct VRAM and
// CPU-only warnings from the first frame. These tests cover the serialisation
// that cache depends on, including entries written by an older build.

import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/services/hardware_service.dart';

void main() {
  test('HardwareInfo survives a JSON round-trip intact', () {
    final info = HardwareInfo(
      gpuName: 'NVIDIA GeForce RTX 4070',
      vramMb: 12288,
      ramMb: 32768,
      vendor: 'Nvidia',
      hasCuda: true,
      hasRocm: false,
      hasMetal: false,
      isSharedMemory: false,
      linuxDistro: 'arch',
    );

    final restored = HardwareInfo.fromJson(info.toJson());

    expect(restored, isNotNull);
    expect(restored!.gpuName, info.gpuName);
    expect(restored.vramMb, info.vramMb);
    expect(restored.ramMb, info.ramMb);
    expect(restored.vendor, info.vendor);
    expect(restored.hasCuda, isTrue);
    expect(restored.hasRocm, isFalse);
    expect(restored.hasMetal, isFalse);
    expect(restored.isSharedMemory, isFalse);
    expect(restored.linuxDistro, 'arch');
  });

  test('a cache entry from an older build degrades instead of throwing', () {
    // Only the fields an older build knew about. Everything else must fall back
    // to a safe default — a startup crash over a stale cache would be a far
    // worse bug than the slow detection this replaced.
    final restored = HardwareInfo.fromJson({
      'gpuName': 'Intel Arc A770',
      'vramMb': 8192,
    });

    expect(restored, isNotNull);
    expect(restored!.gpuName, 'Intel Arc A770');
    expect(restored.vramMb, 8192);
    expect(restored.ramMb, 0);
    expect(restored.vendor, 'Unknown');
    expect(restored.hasCuda, isFalse);
    expect(restored.isSharedMemory, isFalse);
    expect(restored.linuxDistro, 'unknown');
  });

  test('a junk cache entry yields null so detection just re-runs', () {
    expect(HardwareInfo.fromJson(const {}), isNull);
    expect(HardwareInfo.fromJson(const {'gpuName': 42}), isNull);
  });

  test('numeric fields tolerate being stored as doubles', () {
    // jsonDecode hands back num; a value that round-tripped through a double
    // must not blow up the cast.
    final restored = HardwareInfo.fromJson(const {
      'gpuName': 'Radeon RX 7900 XTX',
      'vramMb': 24576.0,
      'ramMb': 65536.0,
    });
    expect(restored!.vramMb, 24576);
    expect(restored.ramMb, 65536);
  });
}
