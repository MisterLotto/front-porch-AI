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

import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:front_porch_ai/models/lorebook.dart';
import 'package:front_porch_ai/services/chat/lorebook_collection.dart';
import 'package:front_porch_ai/services/chat/lorebook_matcher.dart';

/// Plain (non-ChangeNotifier) domain service owning lorebook keyword scanning,
/// trigger/depth state mutation on the live LorebookEntry objects, depth
/// decrement (post-AI only for pre-AI triggered entries to preserve sticky for
/// AI-discovered lore), and reset of non-constant trigger state.
///
/// Matching semantics live in lorebook_matcher.dart (ST-parity: regex keys,
/// per-entry case/whole-word overrides, `*` wildcards). Per-entry activation
/// gates handled here: secondary-key selective logic, probability rolls
/// (skipped while an entry is already active, so sticky entries never
/// re-roll), and the enabled flag. Positions/order/budget/recursion/timed
/// effects are stored on the model but engine support is a later phase.
///
/// The scanner mutates entries in-place; it owns no separate trigger map.
/// The entry universe (group book + group worlds + member/1:1 books +
/// attached worlds) comes from the shared [collectLoreEntryRefs] enumerator
/// via the [getEntryRefs] callback, which keeps the service testable in
/// isolation and preserves exact 1:1/group parity: scan/reset always process
/// whatever the callback yields. The callback MUST yield live instances
/// (ChatService's cached group book, live World objects) — trigger state on
/// a fresh parse is invisible to injection.
///
/// The "keep reset blocks in sync" call sites in ChatService (startNewChat,
/// setActive*, _loadLastSession, setActiveGroup, ext-seed, delete, fork,
/// regen/swipe) all route through [resetLorebookTriggerState].
class LorebookScanner {
  final VoidCallback onNotify;
  final List<LoreEntryRef> Function() getEntryRefs;
  final Random _rng;

  LorebookScanner({
    required this.onNotify,
    required this.getEntryRefs,
    Random? rng,
  }) : _rng = rng ?? Random();

  /// Distinct live entries in the current context. A world attached both at
  /// group level and by a member yields the same live objects twice —
  /// identity-dedup so a probability gate can never roll twice per scan.
  Iterable<LorebookEntry> _distinctEntries() {
    final seen = <LorebookEntry>{};
    return [
      for (final ref in getEntryRefs())
        if (seen.add(ref.entry)) ref.entry,
    ];
  }

  /// Scan the given text against every lorebook in the current context.
  /// On a hit that passes the secondary-logic and probability gates:
  /// isTriggered=true, remainingDepth=stickyDepth. Notifies on any change.
  void scanLorebook(String text) {
    bool changed = false;
    for (final entry in _distinctEntries()) {
      if (!entry.enabled) continue;

      bool matches(String key) => keyMatchesText(
            key,
            text,
            caseSensitive: entry.caseSensitive ?? false,
            matchWholeWords: entry.matchWholeWords,
            forceRegex: entry.useRegex,
          );

      if (!entry.keys.any(matches)) continue;
      if (!secondaryLogicSatisfied(entry, matches)) continue;

      // Probability gate: rolled only when the entry is not already
      // active — an active (sticky) entry refreshes without re-rolling.
      if (!entry.isTriggered &&
          entry.useProbability &&
          entry.probability < 100) {
        if (_rng.nextInt(100) >= entry.probability) continue;
      }

      if (!entry.isTriggered) {
        entry.isTriggered = true;
        changed = true;
      }
      entry.remainingDepth = entry.stickyDepth;
    }

    if (changed) {
      onNotify();
    }
  }

  /// Public exposure of the single-key matcher for tests and direct callers.
  bool matchKeyword(String key, String text) =>
      keyMatchesText(key.toLowerCase(), text.toLowerCase());

  /// Decrement remainingDepth only for the provided set of entries.
  /// Used after AI response finalization so that lore entries *discovered in
  /// the AI's own response* keep their full stickyDepth for the next user
  /// turn. Only non-constant entries are decremented; when remaining <= 0,
  /// isTriggered=false. If any un-trigger happens, calls onNotify.
  void decrementLoreDepthForEntries(Set<LorebookEntry> entriesToDecrement) {
    if (entriesToDecrement.isEmpty) return;
    bool changed = false;

    for (final entry in entriesToDecrement) {
      if (entry.isTriggered && !entry.constant) {
        entry.remainingDepth--;
        if (entry.remainingDepth <= 0) {
          entry.isTriggered = false;
          changed = true;
        }
      }
    }

    if (changed) {
      onNotify();
    }
  }

  /// Reset lorebook trigger state (isTriggered=false + remainingDepth=0) for
  /// all non-constant entries in the current context (group book + worlds +
  /// character books). Constant entries are skipped (always active if
  /// enabled). No notify — callers drive subsequent UI updates.
  void resetLorebookTriggerState() {
    for (final entry in _distinctEntries()) {
      if (!entry.constant) {
        entry.isTriggered = false;
        entry.remainingDepth = 0;
      }
    }
  }
}
