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

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/services/engine_health.dart';

void main() {
  final health = EngineHealth.instance;

  setUp(health.resetForTest);
  tearDown(health.resetForTest);

  test('all engines listed in stable order, idle by default', () {
    final names = health.entries.map((e) => e.name).toList();
    expect(names, [
      EngineHealth.expressions,
      EngineHealth.kokoro,
      EngineHealth.piper,
      EngineHealth.whisper,
      EngineHealth.drawThings,
    ]);
    expect(health.hasFallbacks, isFalse);
    for (final e in health.entries) {
      expect(e.nativeCount, 0);
      expect(e.fallbackCount, 0);
    }
  });

  test('reportNative and reportFallback tally per engine', () {
    health.reportNative(EngineHealth.kokoro);
    health.reportNative(EngineHealth.kokoro);
    health.reportFallback(EngineHealth.whisper, 'native failed: boom');

    final kokoro = health.entries.firstWhere(
      (e) => e.name == EngineHealth.kokoro,
    );
    final whisper = health.entries.firstWhere(
      (e) => e.name == EngineHealth.whisper,
    );
    expect(kokoro.nativeCount, 2);
    expect(kokoro.fallbackCount, 0);
    expect(whisper.fallbackCount, 1);
    expect(whisper.lastFallbackReason, 'native failed: boom');
    expect(whisper.lastFallbackAt, isNotNull);
    expect(health.hasFallbacks, isTrue);
  });

  test('unknown engine names are ignored, not crashed on', () {
    health.reportNative('No Such Engine');
    health.reportFallback('No Such Engine', 'whatever');
    expect(health.hasFallbacks, isFalse);
  });

  test('onFirstFallback fires exactly once per engine per session', () {
    final fired = <String>[];
    health.onFirstFallback = (engine, reason) => fired.add('$engine|$reason');

    health.reportFallback(EngineHealth.piper, 'first');
    health.reportFallback(EngineHealth.piper, 'second');
    health.reportFallback(EngineHealth.expressions, 'model missing');

    expect(fired, [
      '${EngineHealth.piper}|first',
      '${EngineHealth.expressions}|model missing',
    ]);
  });

  test('expected fallbacks are tallied but never fire the notice', () {
    final fired = <String>[];
    health.onFirstFallback = (engine, reason) => fired.add(engine);

    health.reportFallback(
      EngineHealth.whisper,
      'browser audio (not WAV) — known limitation',
      expected: true,
    );
    health.reportFallback(
      EngineHealth.piper,
      'no native voice (custom voice)',
      expected: true,
    );
    expect(fired, isEmpty);
    final whisper = health.entries.firstWhere(
      (e) => e.name == EngineHealth.whisper,
    );
    expect(whisper.fallbackCount, 1);
    expect(whisper.unexpectedFallbackCount, 0);

    // A real failure on the same engine still notices afterwards.
    health.reportFallback(EngineHealth.whisper, 'native crashed');
    expect(fired, [EngineHealth.whisper]);
    expect(whisper.unexpectedFallbackCount, 1);
  });

  test('snapshot is additive JSON with all engines', () {
    health.reportFallback(EngineHealth.expressions, 'model files not found');
    final snap = health.snapshot();
    final engines = (snap['engines'] as List).cast<Map<String, dynamic>>();
    expect(engines, hasLength(5));
    final expr = engines.firstWhere(
      (e) => e['name'] == EngineHealth.expressions,
    );
    expect(expr['fallbackCount'], 1);
    expect(expr['lastFallbackReason'], 'model files not found');
    expect(expr['lastFallbackAt'], isA<String>());
  });

  test('buildReport marks unused engines and carries fallback reasons', () {
    health.reportNative(EngineHealth.kokoro);
    health.reportFallback(EngineHealth.whisper, 'browser audio (not WAV)');
    final report = health.buildReport();
    expect(report, contains('${EngineHealth.expressions}: not used'));
    expect(report, contains('${EngineHealth.kokoro}: native ×1, fallback ×0'));
    expect(report, contains('browser audio (not WAV)'));
  });
}
