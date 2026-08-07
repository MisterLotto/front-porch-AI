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

import 'package:front_porch_ai/models/models.dart';
import 'speaker_resolution.dart';
import 'package:front_porch_ai/services/chat/promise_debt_service.dart';

/// Words-only fragment: open commitments weighing on the speaker (Train B).
/// Empty when none. Never lists numbers, statuses, or quest-log chrome —
/// one short line the model can feel, not a checklist.
class PromiseDebtInjection with SpeakerCardResolver {
  final PromiseDebtService promiseDebtService;
  final String? Function() getSessionId;
  @override
  final CharacterCard? Function() getActiveCharacter;
  @override
  final bool Function() getIsGroupNonObserverMode;
  @override
  final String Function() getCurrentSpeakerIdForRealism;
  @override
  final List<CharacterCard> Function() getGroupCharacters;
  @override
  final String Function(CharacterCard) getCharacterIdFromCard;
  final String Function() getUserName;

  PromiseDebtInjection({
    required this.promiseDebtService,
    required this.getSessionId,
    required this.getActiveCharacter,
    required this.getIsGroupNonObserverMode,
    required this.getCurrentSpeakerIdForRealism,
    required this.getGroupCharacters,
    required this.getCharacterIdFromCard,
    required this.getUserName,
  });

  String buildPromiseDebtInjection() {
    final card = speakerCard();
    final sessionId = getSessionId();
    if (card == null || sessionId == null) return '';
    final charId = getCharacterIdFromCard(card);
    promiseDebtService.ensureCacheWarm(sessionId, charId);
    final open =
        promiseDebtService.cachedOpen(sessionId, charId) ?? const [];
    if (open.isEmpty) return '';
    // Anti-nag cadence: riding EVERY prompt made characters bring promises
    // up every turn — see PromiseDebtService.shouldInjectNow.
    if (!promiseDebtService.shouldInjectNow(sessionId, charId)) return '';

    final user = getUserName();
    final parts = <String>[];
    for (final p in open.take(2)) {
      if (p.party == 'user') {
        parts.add('$user still owes them this word: ${p.text}');
      } else {
        parts.add('they still owe $user this word: ${p.text}');
      }
    }
    if (parts.isEmpty) return '';
    return 'Open commitments: ${parts.join('; ')} — let these color trust, '
        'willingness, and quiet tension when relevant; never as a quest log '
        'or checklist, and only spoken about when the moment genuinely '
        'calls for it.';
  }
}
