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

/// Wall-clock startup tracing, off unless `FP_STARTUP_TRACE=1` is exported.
///
/// "The app feels slow to launch" is unactionable without per-step numbers, and
/// the interesting work is spread across `main()`, the provider-tree
/// constructors and the post-first-frame block — no single file can time it.
/// Enabled runs print `[startup] <ms>  <step>` to stdout; disabled runs cost one
/// `bool` read per call site.
///
/// Usage: `FP_STARTUP_TRACE=1 ./front_porch_ai` and read the trace off stdout.
class StartupTrace {
  StartupTrace._();

  static final Stopwatch _sw = Stopwatch()..start();
  static final bool enabled = Platform.environment['FP_STARTUP_TRACE'] == '1';

  /// Record a completed startup step.
  static void mark(String step) {
    if (!enabled) return;
    // ignore: avoid_print
    print('[startup] ${_sw.elapsedMilliseconds}ms  $step');
  }

  /// Time an async step and mark it with how long it took, so per-step cost is
  /// readable directly instead of by subtracting neighbouring timestamps.
  static Future<T> time<T>(String step, Future<T> Function() body) async {
    if (!enabled) return body();
    final start = _sw.elapsedMilliseconds;
    try {
      return await body();
    } finally {
      final end = _sw.elapsedMilliseconds;
      // ignore: avoid_print
      print('[startup] ${end}ms  $step (took ${end - start}ms)');
    }
  }
}
