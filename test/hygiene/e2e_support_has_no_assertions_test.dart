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

// `integration_test/support/` must contain HARNESS, never EVIDENCE.
//
// This is the load-bearing half of a deliberate hole in the safety net.
// test-integrity.yml blocks a PR that modifies an existing test, golden or
// baseline until a maintainer applies `approved-test-change`. As of 2026-08-08
// the E2E support directory is carved out of the BLOCKING half and merely
// reported, because a fake server has to change whenever the app adds an API
// call — that is ordinary work, and blocking it behind a label is the "gate that
// cries wolf" the workflow's own notes warn about.
//
// That carve-out is only safe while the premise holds: these files assert
// nothing, so editing one cannot weaken a check. Today that is literally true —
// there is not a single `expect(` in the directory, which is a driver, a
// sandbox and three fake servers.
//
// The moment somebody puts an assertion in there, the premise is false and the
// hole becomes a way to weaken a real check with only a notice. Nothing would
// announce that; the workflow sees filenames, not contents. So this test is the
// announcement. If it fails, do NOT relax it — either move the assertion into
// the suite it belongs to, or narrow the carve-out in test-integrity.yml.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final dir = Directory('integration_test/support');

  test('the E2E support directory exists where the workflow expects it', () {
    // A rename would silently turn the carve-out into a no-op AND orphan this
    // guard, so the path itself is part of the contract.
    expect(
      dir.existsSync(),
      isTrue,
      reason: 'test-integrity.yml carves out integration_test/support/ by that '
          'exact prefix — if the directory moved, update both',
    );
  });

  test('nothing in it asserts anything', () {
    final offenders = <String>[];

    for (final f in dir.listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      // `expect(` is the marker that matters: it is what makes a file a claim
      // about how the product should behave. Deliberately crude — a substring,
      // not a parse — because the property being defended is "a reader can see
      // at a glance that this file only drives the app", and anything subtle
      // enough to dodge a substring check is subtle enough to deserve review.
      //
      // `fail(` is NOT on this list, and the first draft of this test had it
      // there and went red on five real call sites. They are all the harness
      // giving up and saying why: four timeouts (waitFor, waitForWidget, a hung
      // pump) and one post-mortem dump when sendMessage is refused eight times.
      // None is a claim about the product — they report that the harness could
      // not proceed.
      //
      // The residual risk was checked rather than assumed. Deleting any of them
      // does not create a false pass: every one sits inside a `while
      // (!condition())` with no other exit, so removing it hangs the suite until
      // CI kills it, and the sendMessage one is followed in every suite by a
      // waitFor that would time out anyway. Loud either way, which is what the
      // carve-out needs.
      for (final marker in const ['expect(', 'expectLater(']) {
        if (src.contains(marker)) {
          offenders.add('${f.path} contains $marker');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'These files are exempt from test-integrity.yml\'s BLOCKING half on '
          'the premise that they are harness, not evidence — a change to them '
          'is reported on the PR but does not require the '
          '`approved-test-change` label. An assertion living here would be a '
          'real check that could be weakened with nobody stopping it.\n\n'
          'Fix by moving the assertion into the suite that owns it, not by '
          'loosening this test.\n\nFound:\n  ${offenders.join('\n  ')}',
    );
  });
}
