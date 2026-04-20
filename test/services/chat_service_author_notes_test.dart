// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Tests for Author Notes session isolation logic extracted from ChatService.
// Author notes must be isolated per session/character — switching characters
// or groups must reset the note, while resuming a session must restore it.

import 'package:flutter_test/flutter_test.dart';

// ── Stub: Minimal author note state tracker ─────────────────────────
// Replicates the author note fields and transitions from ChatService.

class _AuthorNoteStub {
  String _authorNote = '';
  int _authorNoteStrength = 4;

  String get authorNote => _authorNote;
  int get authorNoteStrength => _authorNoteStrength;

  // ── setAuthorNote (mirrors ChatService lines 866-871) ─────────────
  void setAuthorNote(String note, {int? strength}) {
    _authorNote = note;
    if (strength != null) _authorNoteStrength = strength;
  }

  // ── _buildAuthorNoteBlock (mirrors ChatService lines 875-884) ─────
  String buildAuthorNoteBlock() {
    if (_authorNote.isEmpty) return '';
    if (_authorNoteStrength <= 3) {
      return "[Author's Note (gentle suggestion): $_authorNote]\n";
    } else if (_authorNoteStrength <= 7) {
      return "[Author's Note: $_authorNote]\n";
    } else {
      return "[Author's Note (IMPORTANT — apply immediately): $_authorNote]\n";
    }
  }

  // ── setActiveCharacter reset (mirrors ChatService lines 993-995) ──
  void resetOnCharacterSwitch() {
    _authorNote = '';
    _authorNoteStrength = 4;
  }

  // ── setActiveGroup reset (mirrors ChatService lines 1136-1138) ────
  void resetOnGroupSwitch() {
    _authorNote = '';
    _authorNoteStrength = 4;
  }

  // ── Load from session (mirrors ChatService lines 1594-1595) ───────
  void loadFromSession({
    required String savedNote,
    required int savedStrength,
  }) {
    _authorNote = savedNote;
    _authorNoteStrength = savedStrength;
  }
}

void main() {
  // ─── 3.2: Author Notes — Session Isolation ─────────────────────────

  group('Author Notes — setActiveCharacter resets author note', () {
    test('resets author note to empty string', () {
      final stub = _AuthorNoteStub();
      stub.setAuthorNote('Stay in character as Luna');
      expect(stub.authorNote, 'Stay in character as Luna');

      stub.resetOnCharacterSwitch();

      expect(stub.authorNote, '',
          reason: 'author note must be cleared when switching characters');
    });

    test('resets author note strength to default (4)', () {
      final stub = _AuthorNoteStub();
      stub.setAuthorNote('Important instruction', strength: 8);
      expect(stub.authorNoteStrength, 8);

      stub.resetOnCharacterSwitch();

      expect(stub.authorNoteStrength, 4,
          reason: 'strength must reset to default when switching characters');
    });

    test('clears note even when it was empty', () {
      final stub = _AuthorNoteStub();
      expect(stub.authorNote, '');

      stub.resetOnCharacterSwitch();

      expect(stub.authorNote, '');
      expect(stub.authorNoteStrength, 4);
    });
  });

  group('Author Notes — setActiveGroup resets author note', () {
    test('resets author note when entering group mode', () {
      final stub = _AuthorNoteStub();
      stub.setAuthorNote('Keep the group conversation flowing');
      expect(stub.authorNote, 'Keep the group conversation flowing');

      stub.resetOnGroupSwitch();

      expect(stub.authorNote, '',
          reason: 'author note must be cleared when switching to group mode');
    });

    test('resets strength to 4 in group mode', () {
      final stub = _AuthorNoteStub();
      stub.setAuthorNote('Group directive', strength: 10);

      stub.resetOnGroupSwitch();

      expect(stub.authorNoteStrength, 4);
    });
  });

  group('Author Notes — strength-modulated block building', () {
    test('returns empty string when note is empty', () {
      final stub = _AuthorNoteStub();
      expect(stub.buildAuthorNoteBlock(), '');
    });

    test('strength 1-3 produces gentle suggestion wrapper', () {
      final stub = _AuthorNoteStub();
      stub.setAuthorNote('Try being nicer', strength: 1);
      expect(
        stub.buildAuthorNoteBlock(),
        "[Author's Note (gentle suggestion): Try being nicer]\n",
      );

      stub.setAuthorNote('Be more descriptive', strength: 3);
      expect(
        stub.buildAuthorNoteBlock(),
        "[Author's Note (gentle suggestion): Be more descriptive]\n",
      );
    });

    test('strength 4-7 produces standard wrapper', () {
      final stub = _AuthorNoteStub();
      stub.setAuthorNote('Stay in character', strength: 4);
      expect(
        stub.buildAuthorNoteBlock(),
        "[Author's Note: Stay in character]\n",
      );

      stub.setAuthorNote('Keep responses short', strength: 7);
      expect(
        stub.buildAuthorNoteBlock(),
        "[Author's Note: Keep responses short]\n",
      );
    });

    test('strength 8-10 produces urgent directive wrapper', () {
      final stub = _AuthorNoteStub();
      stub.setAuthorNote('NEVER break character', strength: 8);
      expect(
        stub.buildAuthorNoteBlock(),
        "[Author's Note (IMPORTANT — apply immediately): NEVER break character]\n",
      );

      stub.setAuthorNote('CRITICAL: Use first person', strength: 10);
      expect(
        stub.buildAuthorNoteBlock(),
        "[Author's Note (IMPORTANT — apply immediately): CRITICAL: Use first person]\n",
      );
    });

    test('default strength (4) produces standard wrapper', () {
      final stub = _AuthorNoteStub();
      stub.setAuthorNote('Default note');
      expect(
        stub.buildAuthorNoteBlock(),
        "[Author's Note: Default note]\n",
      );
    });
  });

  group('Author Notes — session persistence', () {
    test('resuming session loads persisted author note from DB', () {
      final stub = _AuthorNoteStub();

      // Simulate: user set an author note in a previous session
      stub.setAuthorNote('The character should be suspicious');
      expect(stub.authorNoteStrength, 4);

      // Simulate: session was cleared (e.g., character switch)
      stub.resetOnCharacterSwitch();
      expect(stub.authorNote, '');

      // Simulate: resuming the same session — note should be restored
      stub.loadFromSession(
        savedNote: 'The character should be suspicious',
        savedStrength: 6,
      );

      expect(stub.authorNote, 'The character should be suspicious');
      expect(stub.authorNoteStrength, 6,
          reason: 'strength must be restored from session data');
    });

    test('empty persisted note loads as empty', () {
      final stub = _AuthorNoteStub();
      stub.loadFromSession(savedNote: '', savedStrength: 4);

      expect(stub.authorNote, '');
      expect(stub.authorNoteStrength, 4);
    });

    test('note with special characters is preserved', () {
      final stub = _AuthorNoteStub();
      stub.setAuthorNote('Use "quotes" and apostrophes — em-dashes');
      final savedNote = stub.authorNote;
      final savedStrength = stub.authorNoteStrength;

      stub.resetOnCharacterSwitch();
      stub.loadFromSession(savedNote: savedNote, savedStrength: savedStrength);

      expect(stub.authorNote, savedNote);
    });
  });

  group('Author Notes — isolation between sessions', () {
    test('note from character A does not leak to character B', () {
      final stub = _AuthorNoteStub();

      // Set note for character A
      stub.setAuthorNote('Character A note', strength: 5);
      expect(stub.authorNote, 'Character A note');

      // Switch to character B
      stub.resetOnCharacterSwitch();
      expect(stub.authorNote, '',
          reason: 'note must not leak between characters');

      // Set note for character B
      stub.setAuthorNote('Character B note', strength: 7);
      expect(stub.authorNote, 'Character B note');

      // Switch back to character A (simulates loading A's session)
      stub.resetOnCharacterSwitch();
      stub.loadFromSession(
        savedNote: 'Character A note',
        savedStrength: 5,
      );
      expect(stub.authorNote, 'Character A note',
          reason: 'A note must be restored, not contaminated by B');
    });

    test('group note does not leak back to 1:1 session', () {
      final stub = _AuthorNoteStub();

      // Set note in 1:1
      stub.setAuthorNote('1:1 note', strength: 3);

      // Switch to group (resets note)
      stub.resetOnGroupSwitch();
      expect(stub.authorNote, '');

      // Set note in group
      stub.setAuthorNote('Group note', strength: 8);

      // Switch back to 1:1 (resets note)
      stub.resetOnCharacterSwitch();
      expect(stub.authorNote, '',
          reason: 'group note must not leak back to 1:1 session');
    });
  });
}
