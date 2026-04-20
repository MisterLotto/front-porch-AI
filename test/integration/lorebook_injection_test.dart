// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Integration tests for lorebook entry matching and injection.
// Tests the core logic of _scanLorebook and _decrementLoreDepth
// extracted from ChatService.

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/models/lorebook.dart';

/// Simulates the lorebook scanning and depth management logic from ChatService.
class _LorebookSimulator {
  final List<LorebookEntry> _entries = [];

  List<LorebookEntry> get entries => List.unmodifiable(_entries);

  void addEntry({
    required String key,
    required String content,
    String name = '',
    bool enabled = true,
    bool constant = false,
    int stickyDepth = 1,
  }) {
    _entries.add(LorebookEntry(
      name: name,
      key: key,
      content: content,
      enabled: enabled,
      constant: constant,
      stickyDepth: stickyDepth,
    ));
  }

  /// Mirrors ChatService._scanLorebook (lines 4121-4182).
  void scanLorebook(String text) {
    final lowerText = text.toLowerCase();
    for (final entry in _entries) {
      if (!entry.enabled) continue;
      if (entry.constant) {
        // Constant entries are always "active" — just mark as triggered
        entry.isTriggered = true;
        entry.remainingDepth = entry.stickyDepth;
        continue;
      }
      final keys = entry.key
          .split(',')
          .map((k) => k.trim().toLowerCase())
          .where((k) => k.isNotEmpty);
      for (final key in keys) {
        if (lowerText.contains(key)) {
          if (!entry.isTriggered) {
            entry.isTriggered = true;
          }
          entry.remainingDepth = entry.stickyDepth;
          break;
        }
      }
    }
  }

  /// Mirrors ChatService._decrementLoreDepth (lines 4184-4225).
  void decrementLoreDepth() {
    for (final entry in _entries) {
      if (entry.isTriggered && !entry.constant) {
        entry.remainingDepth--;
        if (entry.remainingDepth <= 0) {
          entry.isTriggered = false;
        }
      }
    }
  }

  /// Get active (triggered and not expired) entries.
  List<LorebookEntry> getActiveEntries() {
    return _entries.where((e) => e.isTriggered && e.remainingDepth > 0).toList();
  }
}

void main() {
  // ─── 4.3: Lorebook Injection ───────────────────────────────────────

  group('Lorebook Injection', () {
    test('constant entries always match', () {
      final sim = _LorebookSimulator();
      sim.addEntry(
        key: 'dragon',
        content: 'Dragons are ancient and powerful.',
        name: 'Dragon Lore',
        constant: true,
      );

      // Even without scanning, constant entries should be triggered
      sim.scanLorebook('I see a dragon');

      final active = sim.getActiveEntries();
      expect(active, hasLength(1));
      expect(active[0].content, 'Dragons are ancient and powerful.');
    });

    test('keyword-triggered entries match on keywords', () {
      final sim = _LorebookSimulator();
      sim.addEntry(
        key: 'dragon, wyrm',
        content: 'Dragons breathe fire.',
        name: 'Dragon Info',
        constant: false,
        stickyDepth: 2,
      );

      sim.scanLorebook('I see a dragon');
      var active = sim.getActiveEntries();
      expect(active, hasLength(1));
      expect(active[0].remainingDepth, 2);

      // After one decrement, still active
      sim.decrementLoreDepth();
      active = sim.getActiveEntries();
      expect(active, hasLength(1));
      expect(active[0].remainingDepth, 1);

      // After another decrement, expires
      sim.decrementLoreDepth();
      active = sim.getActiveEntries();
      expect(active, isEmpty);
    });

    test('entries do not match on unrelated keywords', () {
      final sim = _LorebookSimulator();
      sim.addEntry(
        key: 'dragon',
        content: 'Dragons are fire-breathing reptiles.',
        constant: false,
      );

      sim.scanLorebook('I see a horse');

      expect(sim.getActiveEntries(), isEmpty,
          reason: 'unrelated text should not trigger the entry');
    });

    test('multiple keywords in one entry — any match triggers', () {
      final sim = _LorebookSimulator();
      sim.addEntry(
        key: 'elf, elven, highborn',
        content: 'Elves are long-lived beings.',
        constant: false,
      );

      sim.scanLorebook('The elven ranger approaches');
      expect(sim.getActiveEntries(), hasLength(1));

      final sim2 = _LorebookSimulator();
      sim2.addEntry(
        key: 'elf, elven, highborn',
        content: 'Elves are long-lived beings.',
        constant: false,
      );
      sim2.scanLorebook('A highborn noble enters');
      expect(sim2.getActiveEntries(), hasLength(1));

      final sim3 = _LorebookSimulator();
      sim3.addEntry(
        key: 'elf, elven, highborn',
        content: 'Elves are long-lived beings.',
        constant: false,
      );
      sim3.scanLorebook('Nothing here');
      expect(sim3.getActiveEntries(), isEmpty);
    });

    test('disabled entries do not match', () {
      final sim = _LorebookSimulator();
      sim.addEntry(
        key: 'dragon',
        content: 'Dragons are dangerous.',
        enabled: false,
      );

      sim.scanLorebook('I see a dragon');
      expect(sim.getActiveEntries(), isEmpty);
    });

    test('case-insensitive keyword matching', () {
      final sim = _LorebookSimulator();
      sim.addEntry(
        key: 'Dragon',
        content: 'Dragons breathe fire.',
        constant: false,
      );

      sim.scanLorebook('i saw a DRAGON in the sky');
      expect(sim.getActiveEntries(), hasLength(1));
    });

    test('keyword matching is substring-based', () {
      final sim = _LorebookSimulator();
      sim.addEntry(
        key: 'fire',
        content: 'Fire is dangerous.',
        constant: false,
      );

      sim.scanLorebook('The dragon breathes fireballs');
      expect(sim.getActiveEntries(), hasLength(1),
          reason: '"fire" should match inside "fireballs"');
    });

    test('sticky depth extends on each match', () {
      final sim = _LorebookSimulator();
      sim.addEntry(
        key: 'dragon',
        content: 'Dragons are ancient.',
        stickyDepth: 2,
      );

      sim.scanLorebook('I see a dragon');
      expect(sim.getActiveEntries()[0].remainingDepth, 2);

      // Decrement once
      sim.decrementLoreDepth();
      expect(sim.getActiveEntries()[0].remainingDepth, 1);

      // Mention dragon again — depth resets
      sim.scanLorebook('The dragon roars');
      expect(sim.getActiveEntries()[0].remainingDepth, 2);
    });

    test('multiple entries can be active simultaneously', () {
      final sim = _LorebookSimulator();
      sim.addEntry(
        key: 'dragon',
        content: 'Dragons breathe fire.',
        stickyDepth: 3,
      );
      sim.addEntry(
        key: 'elf',
        content: 'Elves are graceful.',
        stickyDepth: 2,
      );

      sim.scanLorebook('An elf fights a dragon');

      final active = sim.getActiveEntries();
      expect(active, hasLength(2));
    });

    test('constant entries stay active regardless of depth', () {
      final sim = _LorebookSimulator();
      sim.addEntry(
        key: 'magic',
        content: 'Magic is rare in this world.',
        constant: true,
      );

      sim.scanLorebook('I see magic');
      expect(sim.getActiveEntries(), hasLength(1));

      // Decrement many times
      for (int i = 0; i < 100; i++) {
        sim.decrementLoreDepth();
      }

      // Constant entry should still be active
      expect(sim.getActiveEntries(), hasLength(1),
          reason: 'constant entries never expire');
    });

    test('re-scanning after expiry re-triggers the entry', () {
      final sim = _LorebookSimulator();
      sim.addEntry(
        key: 'dragon',
        content: 'Dragons are fierce.',
        stickyDepth: 1,
      );

      sim.scanLorebook('A dragon appears');
      expect(sim.getActiveEntries(), hasLength(1));

      // Decrement to expire
      sim.decrementLoreDepth();
      expect(sim.getActiveEntries(), isEmpty);

      // Re-scan with the same keyword
      sim.scanLorebook('The dragon returns');
      expect(sim.getActiveEntries(), hasLength(1),
          reason: 're-matching should re-trigger the entry');
    });

    test('empty key does not match', () {
      final sim = _LorebookSimulator();
      sim.addEntry(
        key: '',
        content: 'This should never match.',
      );

      sim.scanLorebook('anything at all');
      expect(sim.getActiveEntries(), isEmpty);
    });

    test('whitespace in keys is trimmed', () {
      final sim = _LorebookSimulator();
      sim.addEntry(
        key: ' dragon , wyrm ',
        content: 'Dragons are powerful.',
      );

      sim.scanLorebook('I see a dragon');
      expect(sim.getActiveEntries(), hasLength(1));
    });
  });
}
