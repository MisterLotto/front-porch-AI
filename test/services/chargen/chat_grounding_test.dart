// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/services/chargen/chat_grounding.dart';

void main() {
  group('groundedConceptFor', () {
    // BYTE-PIN: this exact text was moved verbatim from
    // SceneGuestFactory._buildGroundedConcept. Scene Guest minting and AI
    // Enhance now share it — if this wording changes, both features' grounding
    // prompts change, and that must be a deliberate decision, not drift.
    test('produces the exact Scene Guest grounding wording', () {
      final out = groundedConceptFor('Vanessa', 'a wry bartender', 'She winked.');
      expect(
        out,
        'a wry bartender\n\n'
        'Build "Vanessa" to match EXACTLY how they are portrayed in the '
        'roleplay excerpts below — their appearance, manner, role, speech, and '
        'relationships as actually shown. The excerpts also feature other '
        'characters (the narrator and the user); use ONLY the details that '
        'describe "Vanessa" and ignore traits that clearly belong to someone '
        'else. Do not invent a conflicting identity.\n\n'
        'How "Vanessa" has appeared in the scene so far:\nShe winked.',
      );
    });

    test('empty grounding returns concept unchanged', () {
      expect(groundedConceptFor('V', 'a bartender', '   '), 'a bartender');
    });

    test('empty concept omits the lead block', () {
      final out = groundedConceptFor('V', '', 'She winked.');
      expect(out, startsWith('Build "V" to match EXACTLY'));
    });
  });

  group('EnhanceSelection', () {
    test('defaults: persona + dialogue on, the rest off', () {
      const s = EnhanceSelection();
      expect(s.description, isTrue);
      expect(s.personality, isTrue);
      expect(s.exampleDialogue, isTrue);
      expect(s.scenario, isFalse);
      expect(s.greetings, isFalse);
      expect(s.lorebook, isFalse);
      expect(s.needsEnrichment, isTrue);
      expect(s.anySelected, isTrue);
    });

    test('JSON round-trip preserves every flag', () {
      const s = EnhanceSelection(
        description: false,
        personality: true,
        exampleDialogue: false,
        scenario: true,
        greetings: true,
        lorebook: true,
      );
      final back = EnhanceSelection.fromJson(s.toJson());
      expect(back.toJson(), s.toJson());
    });

    test('fromJson tolerates missing keys (web back-compat)', () {
      final s = EnhanceSelection.fromJson(const {});
      expect(s.toJson(), const EnhanceSelection().toJson());
    });

    test('needsEnrichment false when only dialogue picked', () {
      const s = EnhanceSelection(
        description: false,
        personality: false,
        exampleDialogue: true,
      );
      expect(s.needsEnrichment, isFalse);
      expect(s.anySelected, isTrue);
    });
  });

  group('buildChatExcerptBlock', () {
    const turns = <ChatTurn>[
      (speaker: 'User', text: 'oldest line'),
      (speaker: 'Nina', text: 'middle line'),
      (speaker: 'User', text: 'newest line'),
    ];

    test('recap first, then memories, then chronological turns', () {
      final out = buildChatExcerptBlock(
        turns: turns,
        recap: 'They met at the bar.',
        memoryCards: ['He made me laugh.'],
        maxChars: 10000,
      );
      expect(
        out,
        'Where the story is:\nThey met at the bar.\n\n'
        'Key memories:\n- He made me laugh.\n\n'
        'User: oldest line\nNina: middle line\nUser: newest line',
      );
    });

    test('budget keeps the NEWEST turns and drops the oldest', () {
      final out = buildChatExcerptBlock(
        turns: turns,
        maxChars: 'Nina: middle line\nUser: newest line'.length + 2,
      );
      expect(out, contains('newest line'));
      expect(out, contains('middle line'));
      expect(out, isNot(contains('oldest line')));
      // Kept turns stay in chronological order.
      expect(out.indexOf('middle'), lessThan(out.indexOf('newest')));
    });

    test('empty inputs produce an empty block', () {
      expect(
        buildChatExcerptBlock(turns: const [], maxChars: 1000),
        isEmpty,
      );
      expect(
        buildChatExcerptBlock(turns: turns, maxChars: 0),
        isEmpty,
      );
    });

    test('blank turns and cards are skipped, not emitted', () {
      final out = buildChatExcerptBlock(
        turns: const [(speaker: 'Nina', text: '   ')],
        memoryCards: const ['  '],
        maxChars: 1000,
      );
      expect(out, isEmpty);
    });
  });

  group('enhanceGroundingCharBudget', () {
    test('local Kobold small context: contextSize - 3000 tokens, x4 chars', () {
      expect(
        enhanceGroundingCharBudget(isLocalKobold: true, contextSize: 4096),
        (4096 - 3000) * 4,
      );
    });

    test('caps at 3000 tokens (12k chars) even with huge contexts', () {
      expect(
        enhanceGroundingCharBudget(isLocalKobold: true, contextSize: 32768),
        12000,
      );
      expect(
        enhanceGroundingCharBudget(isLocalKobold: false, contextSize: 0),
        12000,
      );
    });

    test('never negative on tiny local contexts', () {
      expect(
        enhanceGroundingCharBudget(isLocalKobold: true, contextSize: 2048),
        0,
      );
    });
  });
}
