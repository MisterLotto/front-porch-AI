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

import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:front_porch_ai/app_version.dart';

/// Session ledger for the in-process engines that replaced the Python
/// sidecars (docs/design/sidecar-retirement.md): which path did each feature
/// actually take — native or legacy fallback — and why.
///
/// Exists because the automatic fallbacks are invisible by design, and a
/// silent fallback is indistinguishable from native success during a soak
/// (users only report what visibly breaks; the expression classifier fell
/// back silently for days before anyone noticed). Engines report here; the
/// app shell surfaces the first fallback per engine as a report-it notice on
/// pre-release builds, Settings shows the per-engine tally, and the web UI
/// reads [snapshot] through the facade.
///
/// In-memory and session-scoped on purpose — the question it answers is
/// "what happened on THIS machine since launch", not history.
class EngineHealth extends ChangeNotifier {
  EngineHealth._();

  /// Engines call this from deep leaves (isolate wiring, static transcribe
  /// paths) where constructor plumbing would touch a dozen files for a
  /// diagnostics-only concern.
  static final EngineHealth instance = EngineHealth._();

  // Engine keys double as the user-facing row labels.
  static const String expressions = 'Expressions';
  static const String kokoro = 'Kokoro voice';
  static const String piper = 'Piper voice';
  static const String whisper = 'Voice input';

  static const List<String> _order = [expressions, kokoro, piper, whisper];

  final Map<String, EngineHealthEntry> _entries = {
    for (final name in _order) name: EngineHealthEntry(name),
  };

  /// Set once by the app shell. Fired the FIRST time each engine falls back
  /// UNEXPECTEDLY this session (pre-release builds show the "please report
  /// this" notice). Expected fallbacks — documented limitations, forced-env
  /// levers, custom voices — are tallied for the panel but never nag: a
  /// report-it notice on intended behavior is alarm fatigue that trains
  /// soak testers to ignore the one notice that matters.
  void Function(String engine, String reason)? onFirstFallback;

  /// Rows in stable display order (all engines, including never-used ones).
  List<EngineHealthEntry> get entries => [
    for (final name in _order) _entries[name]!,
  ];

  bool get hasFallbacks => entries.any((e) => e.fallbackCount > 0);

  void reportNative(String engine) {
    final entry = _entries[engine];
    if (entry == null) return;
    entry.nativeCount++;
    notifyListeners();
  }

  /// [expected] marks documented legacy paths (webm browser audio, custom
  /// Piper voices, FP_*_SIDECAR=1): counted and shown, but no notice.
  void reportFallback(String engine, String reason, {bool expected = false}) {
    final entry = _entries[engine];
    if (entry == null) return;
    entry.fallbackCount++;
    if (!expected) entry.unexpectedFallbackCount++;
    entry.lastFallbackReason = reason;
    entry.lastFallbackAt = DateTime.now();
    if (!expected && !entry.noticeFired) {
      entry.noticeFired = true;
      onFirstFallback?.call(engine, reason);
    }
    notifyListeners();
  }

  /// Additive JSON for the web facade (`GET /api/engine-health`).
  Map<String, dynamic> snapshot() => {
    'engines': [
      for (final e in entries)
        {
          'name': e.name,
          'nativeCount': e.nativeCount,
          'fallbackCount': e.fallbackCount,
          'unexpectedFallbackCount': e.unexpectedFallbackCount,
          'lastFallbackReason': e.lastFallbackReason,
          'lastFallbackAt': e.lastFallbackAt?.toIso8601String(),
        },
    ],
  };

  /// Plain-text report for the clipboard (the snackbar's "Copy details"
  /// action) — everything a Discord bug report needs in one paste.
  String buildReport() {
    final b = StringBuffer()
      ..writeln('Front Porch AI $appVersion (${Platform.operatingSystem})')
      ..writeln('Engine status this session:');
    for (final e in entries) {
      b.write('- ${e.name}: ');
      if (e.nativeCount == 0 && e.fallbackCount == 0) {
        b.writeln('not used');
        continue;
      }
      b.writeln('native ×${e.nativeCount}, fallback ×${e.fallbackCount}');
      if (e.lastFallbackReason != null) {
        b.writeln('  last fallback: ${e.lastFallbackReason}');
      }
    }
    return b.toString();
  }

  @visibleForTesting
  void resetForTest() {
    for (final e in _entries.values) {
      e.nativeCount = 0;
      e.fallbackCount = 0;
      e.unexpectedFallbackCount = 0;
      e.lastFallbackReason = null;
      e.lastFallbackAt = null;
      e.noticeFired = false;
    }
    onFirstFallback = null;
  }
}

/// Mutable per-engine tally. Mutated only by [EngineHealth].
class EngineHealthEntry {
  final String name;
  int nativeCount = 0;
  int fallbackCount = 0;

  /// Fallbacks that were NOT documented/intentional paths — the count that
  /// actually matters for the soak.
  int unexpectedFallbackCount = 0;
  String? lastFallbackReason;
  DateTime? lastFallbackAt;
  bool noticeFired = false;

  EngineHealthEntry(this.name);
}
