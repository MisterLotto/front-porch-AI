// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The AI character creator has THREE modes (automated, guided, quick), but the
// save/load pair only knew two: saveState() wrote
// `_creatorMode == CreatorMode.guided ? 'guided' : 'automated'` and loadSavedState()
// mirrored it. So picking Quick Create and coming back to the wizard silently
// put the user on the automated form instead — their mode choice was thrown
// away, with no message. Both sides now round-trip the enum's own name.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:front_porch_ai/ui/character_creator/creator_state.dart';

/// Save [mode] from one wizard instance, then read it back in a fresh one —
/// the reopen the user actually performs.
Future<CreatorMode> roundTrip(CreatorMode mode) async {
  final saver = CreatorState()..creatorMode = mode;
  await saver.saveState();
  final loader = CreatorState();
  await loader.loadSavedState();
  return loader.creatorMode;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(const {}));

  test('every creator mode survives a save/load round-trip', () async {
    for (final mode in CreatorMode.values) {
      expect(
        await roundTrip(mode),
        mode,
        reason: '${mode.name} mode was not persisted — reopening the wizard '
            'silently reverts the user to a different form',
      );
    }
  });

  test('an unknown or legacy stored mode falls back to automated', () async {
    SharedPreferences.setMockInitialValues(const {
      'chargen_creator_mode': 'something_we_removed',
    });
    final state = CreatorState();
    await state.loadSavedState();
    expect(state.creatorMode, CreatorMode.automated);

    // 'guided'/'automated' are what old installs already have on disk.
    SharedPreferences.setMockInitialValues(const {
      'chargen_creator_mode': 'guided',
    });
    final legacy = CreatorState();
    await legacy.loadSavedState();
    expect(legacy.creatorMode, CreatorMode.guided);
  });
}
