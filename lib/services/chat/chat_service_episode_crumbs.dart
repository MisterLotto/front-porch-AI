// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Clock-out crumbs: when committed time leaves a shift, maybe write one
// episode card. Journal on, clock running, job on the card. No new toggle.

part of '../chat_service.dart';

extension ChatServiceEpisodeCrumbs on ChatService {
  Future<void> _maybeMintEpisodeCrumbs(DateTime before, DateTime after) async {
    if (!_clockRunning) return;
    if (!_storageService.memorySettings.journalEnabled) return;
    final sid = _currentSessionId;
    if (sid == null) return;
    if (!after.isAfter(before)) return;

    final people = _activeGroup != null
        ? _groupCharacters
        : [_activeCharacter].whereType<CharacterCard>();
    final leftDay = StoryClock.dayCountFor(before, _timeService.startDate);
    final cite = _messages.isEmpty ? const <int>[] : [_messages.length - 1];

    for (final card in people) {
      final work = _workFieldsFor(card);
      if (!clockedOutOfShift(
        occupation: work.occupation,
        hours: work.hours,
        workDays: work.workDays,
        before: before,
        after: after,
      )) {
        continue;
      }
      final owner = _getCharacterIdFromCard(card);
      final existing = await _journalStore.cardsFor(sid, owner);
      if (alreadyHasWorkEpisodeToday(cards: existing, storyDay: leftDay)) {
        continue;
      }
      final seed = workCrumbSeed(
        sessionId: sid,
        characterId: owner,
        storyDay: leftDay,
        shiftEndMinutes: shiftEndMinutesOf(work.hours),
      );
      if (!shouldMintWorkCrumb(seed)) continue;
      await _journalStore.addCard(
        sessionId: sid,
        characterId: owner,
        content: workCrumbContent(
          occupation: work.occupation,
          occupationBrief: work.occupationBrief,
          seed: seed,
        ),
        category: 'moment',
        kind: 'episode',
        extraMetadata: {'episode': 'work', 'occupation': work.occupation},
        sourcePositions: cite,
        storyDay: leftDay,
        storyClock: StoryClock.serializeClock(before),
        maxCards: _storageService.memorySettings.journalMaxCards,
      );
      debugPrint('[Journal] 💼 work crumb for ${card.name}');
    }
  }
}
