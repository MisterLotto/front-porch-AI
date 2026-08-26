// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Item-memory card write / retire / rewind stamps. Extracted from
// chat_service_pockets.dart so that file does not grow.

part of '../chat_service.dart';

extension ChatServiceItemCards on ChatService {
  /// Retire every live item-memory card about [itemName] for [ownerId].
  /// Shared by the post-gen feed (one live placement per item) and the
  /// eraser ([removePocketItem]) so neither path leaves a phantom diary.
  Future<void> _retireItemCardsFor(String ownerId, String itemName) async {
    final sid = _currentSessionId;
    if (sid == null || itemName.isEmpty) return;
    final existing = await _journalStore.cardsFor(sid, ownerId);
    for (final old in existing) {
      if (JournalPhysics.isItemCard(old) &&
          sameItem(JournalPhysics.itemOf(old) ?? '', itemName)) {
        await _journalStore.retireCard(old.id);
      }
    }
  }

  /// Write this turn's item-memory cards ([itemCardsFrom] decides which
  /// events are diary-worthy). One live placement memory per item: a new
  /// card about the same thing retires the old one first, so "where are my
  /// keys" always has exactly one answer in the diary. Cards carry the
  /// canonical item name in the metadata pouch (the keyword re-warm key),
  /// the story stamp, and the reply's **persist** position as their receipt
  /// — a tail window must cite base+index, not the on-screen 0..23.
  Future<void> _writeItemCards(
    String ownerId,
    List<PocketEvent> events, {
    required bool asContinuation,
  }) async {
    // A retire is a hard DB delete — right while this turn stands, wrong the
    // moment it is regenerated or tail-deleted. Stamp every card this turn is
    // about to retire onto THIS SWIPE (same contract as pockets_after:
    // replace on a normal turn, append on Continue) so the rewind can
    // re-plant them without copying swipe 0's retires onto swipe 1.
    final stamps = <ItemCardStamp>[];
    final planted = <ItemCardStamp>[];
    // Pickup writes no diary line but must retire the old placement card
    // ("I set my keys down") or "where are my keys?" stays wrong.
    for (final e in events) {
      if (e.kind == PocketOpKind.pickup) {
        final sid = _currentSessionId;
        if (sid != null) {
          stamps.addAll(
            itemCardStampsFrom(
              await _db.getJournalCardsForSession(sid),
              e.item,
            ),
          );
          await _journalStore.retireItemCardsInSession(sid, e.item);
        } else {
          await _retireItemCardsFor(ownerId, e.item);
        }
      }
    }
    final drafts = itemCardsFrom(events);
    if (drafts.isEmpty) {
      _stampItemCards(
        stamps,
        key: 'item_cards_retired',
        asContinuation: asContinuation,
      );
      return;
    }
    final sid = _currentSessionId!;
    final cite = persistTipCite(
      base: _history.basePosition,
      length: _messages.length,
    );
    for (final draft in drafts) {
      stamps.addAll(
        itemCardStampsFrom(
          await _journalStore.cardsFor(sid, ownerId),
          draft.item,
        ),
      );
      await _retireItemCardsFor(ownerId, draft.item);
      await _journalStore.addCard(
        sessionId: sid,
        characterId: ownerId,
        content: draft.content,
        category: 'item',
        kind: 'item',
        extraMetadata: {'item': draft.item},
        sourcePositions: cite,
        storyDay: _timeService.dayCount,
        storyClock: _timeService.storyClockIso,
        maxCards: _storageService.memorySettings.journalMaxCards,
      );
      planted.add(
        ItemCardStamp(
          owner: ownerId,
          item: draft.item,
          content: draft.content,
          positions: cite,
          storyDay: _timeService.dayCount,
          storyClock: _timeService.storyClockIso,
        ),
      );
    }
    _stampItemCards(
      stamps,
      key: 'item_cards_retired',
      asContinuation: asContinuation,
    );
    _stampItemCards(
      planted,
      key: 'item_cards_planted',
      asContinuation: asContinuation,
    );
    debugPrint(
      '[Journal] 📦 ${drafts.length} item card(s) for ${_activeCharacter?.name}',
    );
  }

  /// Ride item-card stamps on THIS SWIPE. Replace on a normal turn; append
  /// on Continue (the first half belongs to the same swipe). Swipe-scoped
  /// so regen of swipe 1 cannot replant swipe 0's retires. Older chats that
  /// wrote `item_cards_retired` on shared metadata still read via the
  /// activeMetadata → metadata fallback in [_replantItemCards].
  void _stampItemCards(
    List<ItemCardStamp> stamps, {
    required String key,
    required bool asContinuation,
  }) {
    if (_messages.isEmpty || _messages.last.isUser) return;
    final msg = _messages.last;
    final prior = asContinuation
        ? ItemCardStamp.listFrom(msg.activeMetadata?[key] ?? msg.metadata?[key])
        : const <ItemCardStamp>[];
    final all = [...prior, ...stamps];
    if (all.isEmpty) return;
    msg.activeMetadata = {
      ...?msg.activeMetadata,
      key: [for (final s in all) s.toJson()],
    };
  }

  /// Re-plant item cards stamped on [msg] under [key].
  /// `item_cards_retired`: regenerate / tail-delete (`after: false`).
  /// `item_cards_planted`: swipe-back after timeline invalidation.
  /// Retire-first so a double regenerate cannot duplicate a card.
  Future<void> _replantItemCards(ChatMessage msg, {required String key}) async {
    final sid = _currentSessionId;
    if (sid == null) return;
    final stamps = ItemCardStamp.listFrom(
      msg.activeMetadata?[key] ?? msg.metadata?[key],
    );
    for (final s in stamps) {
      try {
        await _retireItemCardsFor(s.owner, s.item);
        await _journalStore.addCard(
          sessionId: sid,
          characterId: s.owner,
          content: s.content,
          category: 'item',
          kind: 'item',
          extraMetadata: {'item': s.item},
          sourcePositions: s.positions,
          storyDay: s.storyDay,
          storyClock: s.storyClock,
          heat: s.heat,
          pinned: s.pinned,
          maxCards: _storageService.memorySettings.journalMaxCards,
        );
      } catch (e) {
        debugPrint('[Journal] item card re-plant skipped (${s.item}): $e');
      }
    }
  }
}
