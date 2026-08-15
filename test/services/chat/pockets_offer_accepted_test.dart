// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

// "The user hands her something" must reach the record (2026-08-14).
//
// The ops rubric used to exclude, flatly, anything the character "were
// offered". That clause is there to stop phantom acquisitions — a thing
// mentioned, wanted, or dangled in front of her is not a thing she has —
// but it also described the ONLY way a user can hand a character an item by
// narration. "Here, take my keys" IS an offer, so a character who then
// pocketed them scored nothing and the keys never entered her record. In a
// 1:1 chat that is the only kind of handover there is (the give/`to`
// machinery needs a second character with a record of their own, so it is
// group-only by construction), which is why the gap read as "gives don't
// work in 1:1" rather than as a prompt bug.
//
// The fix is one clause: an offer she ACCEPTS is a pickup; an offer left
// hanging is still ignored. This suite pins both halves — deleting the
// exclusion wholesale would "fix" acceptance by reopening phantom
// acquisitions, so the guard has to fail in BOTH directions.
//
// It also pins the two transports together. The rubric is shared verbatim
// between the standalone pockets prompt and the fused reply-facts prompt, so
// a future edit to one is an edit to both — but only as long as something
// checks that the fused prompt really is composed from the shared fragment
// rather than a drifted copy.
//
// Red-proven (2026-08-14):
//   * restoring the blanket 'were offered' → 'an offer she ACCEPTS is a
//     pickup' fails (the rubric tells the model to ignore the user's gift);
//   * deleting the exclusion entirely → 'an offer left hanging is still
//     ignored' fails (phantom acquisitions come back);
//   * dropping the accepting-a-handover clause from the pickup line →
//     'accepting a handover is spelled out as a pickup' fails.

import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/services/chat/pockets.dart';
import 'package:front_porch_ai/services/chat/pockets_eval.dart';
import 'package:front_porch_ai/services/chat/reply_facts_eval.dart';

void main() {
  group('the ops rubric', () {
    test('an offer she ACCEPTS is a pickup, not a non-event', () {
      final rubric = PocketsEval.opsRubric();
      expect(
        rubric.contains('accepting something handed over'),
        isTrue,
        reason: 'the user handing her something is the only narrated '
            'handover a 1:1 chat has — it must be named as a pickup',
      );
      expect(
        RegExp(r'were offered(?!\s+and did not take)').hasMatch(rubric),
        isFalse,
        reason: 'a blanket "were offered" exclusion tells the model to '
            'ignore the gift the user just handed over',
      );
    });

    test('an offer left hanging is still ignored', () {
      final rubric = PocketsEval.opsRubric();
      expect(
        rubric.contains('were offered and did not take'),
        isTrue,
        reason: 'removing the exclusion instead of qualifying it brings '
            'back phantom acquisitions — things merely dangled in front of '
            'her landing in the record',
      );
      // The siblings of that clause must survive the edit too.
      for (final excluded in ['mentioned', 'remembered', 'wanted']) {
        expect(rubric.contains(excluded), isTrue, reason: excluded);
      }
    });

    test('accepting a handover is spelled out on the pickup op', () {
      final rubric = PocketsEval.opsRubric();
      final pickupLine = rubric
          .split('\n')
          .firstWhere((l) => l.trimLeft().startsWith('pickup / drop'));
      // The op the acceptance must be reported AS — a clause floating in
      // the preamble would leave the model to guess which op applies.
      expect(pickupLine.contains('accepting something handed over'), isTrue);
    });
  });

  group('the group handover path is untouched', () {
    test('a roster still gets the exact-spelling give instruction', () {
      final rubric = PocketsEval.opsRubric(others: ['Sam', 'Evelyn']);
      expect(rubric.contains('give — handed to someone else'), isTrue);
      expect(rubric.contains('Sam, Evelyn'), isTrue);
      expect(
        rubric.contains('spelled EXACTLY'),
        isTrue,
        reason: 'the recipient name has to resolve against the roster the '
            'model was shown',
      );
    });

    test('no roster means the model is never invited to name a recipient', () {
      final rubric = PocketsEval.opsRubric();
      expect(rubric.contains('give — handed to someone else'), isTrue);
      expect(
        rubric.contains('spelled EXACTLY'),
        isFalse,
        reason: 'in a 1:1 there is nobody to name — a "to" nobody can '
            'resolve is a "to" that does nothing',
      );
    });
  });

  test('the fused reply-facts prompt carries the SAME rubric, verbatim', () {
    // Fusion is transport only: whatever the standalone pockets call asks,
    // the fused call must ask identically, or a user with two bookkeeping
    // passes live would get different item behaviour from one with one.
    final standalone = PocketsEval.buildPrompt(
      charName: 'Nina',
      current: Pockets(),
      reply: 'She takes the keys.',
      recentExchange: 'You: here, take my keys.',
      toolsMode: false,
    );
    final fused = ReplyFactsEval.buildPrompt(
      charName: 'Nina',
      reply: 'She takes the keys.',
      recentExchange: 'You: here, take my keys.',
      toolsMode: false,
      askClimax: true,
      pockets: Pockets(),
    );
    final rubric = PocketsEval.opsRubric();
    expect(standalone.contains(rubric), isTrue);
    expect(
      fused.contains(rubric),
      isTrue,
      reason: 'the fused prompt must compose the shared fragment, not a '
          'drifted copy of it',
    );
  });
}
