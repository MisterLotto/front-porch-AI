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

part of '../chat_service.dart';

/// The Pockets & Wardrobe post-generation pass — the one place the eval is
/// fired and its result stored.
///
/// Kept to a single small extension rather than inlined into the six-phase
/// generation pipeline, because the pipeline part is already long and this is
/// self-contained: read the speaker's record, ask what changed, write it back.
extension ChatServicePockets on ChatService {
  /// Strike one item off by hand. The detection eval is a model doing
  /// bookkeeping; when it misses, this is what stops a wrong entry becoming
  /// permanent. Routed through the same setter the pass uses, so there is no
  /// second write path.
  Future<void> removePocketItem(
    String characterId, {
    required PocketSection section,
    required int index,
  }) async {
    final p = pocketsFor(characterId);
    if (p == null) return;
    // Expire first so the index the UI computed from the day-filtered view
    // lines up with the stored list it is about to strike from.
    p.expireSetAside(storyDayCount);
    final list = switch (section) {
      PocketSection.worn => p.worn,
      PocketSection.carrying => p.carrying,
      PocketSection.setAside => p.setAside,
    };
    if (index < 0 || index >= list.length) return;
    list.removeAt(index);
    setPocketsFor(characterId, p);
    await _saveChat();
    notifyListeners();
  }

  /// Persist [p] back to wherever that character's record lives.
  void setPocketsFor(String characterId, Pockets p) {
    if (_activeGroup == null) {
      _pockets = p;
      return;
    }
    (_groupRealism[characterId] ??= GroupMemberRealism()).pockets = p;
  }

  /// What [c]'s card says they START a chat with.
  ///
  /// One expression, named once, because three places need it and a card that
  /// disagrees with itself about its own starting kit is the kind of bug that
  /// only shows up as "sometimes she has the keys".
  Pockets startingPocketsFor(CharacterCard c) =>
      Pockets.fromJson(c.frontPorchExtensions?.inventory);

  /// Give every speaker in this chat the record their card starts them with,
  /// unless the chat already has one for them.
  ///
  /// WHY THIS EXISTS. The card seed used to happen only inside
  /// [_runPocketsPass], which runs AFTER a reply is generated. Counting the
  /// greeting as turn 0, that meant the character's first real reply — turn 1 —
  /// was generated with no inventory fragment in its prompt at all: an author
  /// could dress a character in a flour-dusted apron and she would answer the
  /// first message knowing nothing about it, then be wearing it from turn 2
  /// onward. The sidebar was blank for exactly as long. Authoring made that
  /// visible; before there was an editor, nobody could hit it.
  ///
  /// Deliberately NOT a fallback inside [pocketsFor]. That getter is read from
  /// the sidebar's `build`, which rebuilds on every `notifyListeners()` — once
  /// per streamed token — so parsing the card there would be the exact
  /// per-frame-work pattern the `coverImageFileFor` regression taught us to
  /// avoid: invisible on a dev Mac, expensive on Windows. This runs once per
  /// turn and short-circuits to a map lookup the moment a record exists.
  ///
  /// Idempotent, and identical for 1:1 and group by construction — one loop
  /// over one speaker list, writing through the same [setPocketsFor] the pass
  /// uses, so the two modes cannot diverge about what a character starts with.
  ///
  /// CALL SITES — there are FIVE and every one of them is load-bearing. Two are
  /// about generating (the top of `sendMessage`, and the pass's own `??` for a
  /// character who arrives mid-turn); three are about ENTERING a conversation:
  /// `setActiveCharacter`, `setActiveGroup` and `startNewChat`, each straight
  /// after the point where a restored session would have won.
  ///
  /// The entry three were missing until 2026-08-08, and the report was exact:
  /// "why do I not see pockets or wardrobe in the chat sidebar on message 0
  /// when pockets and wardrobe is enabled?" This function was written to fix
  /// turn 1's PROMPT and wired only where prompts get built — but the sidebar
  /// draws the moment a chat opens, and all three fresh-chat reset blocks set
  /// `_pockets = null` and stopped, each promising in a comment that the record
  /// would "re-seed from the card on the first pass". That was true when the
  /// seed lived inside [_runPocketsPass] and false the moment it moved earlier.
  /// So a freshly dressed character stood there empty-handed until the user
  /// typed something — precisely when her author was looking to check the
  /// wardrobe had saved.
  ///
  /// If you add a sixth entry path, call this from it.
  /// `test/services/chat/wardrobe_message_zero_test.dart` drives the real
  /// ChatService through entry and will catch a path that forgets.
  void seedPocketsFromCards() {
    // The one switch Pockets answers to. Seeding while it is off would let the
    // v47 save wire persist a record the user never asked for.
    if (!_storageService.realismSettings.pocketsEnabled) return;

    final speakers = _activeGroup == null
        ? [?_activeCharacter]
        : _groupCharacters;

    for (final c in speakers) {
      final id = _getCharacterIdFromCard(c);
      // Already has a record: this chat has moved on from whatever the card
      // said, and re-seeding would hand back things she put down.
      if (pocketsFor(id) != null) continue;
      final seed = startingPocketsFor(c);
      // Nothing authored — leave the record ABSENT rather than empty. Every
      // reader treats null and empty alike, but the web facade sends `null` to
      // hide its panel, so an empty record would show an empty panel instead.
      if (seed.isEmpty) continue;
      setPocketsFor(id, seed);
    }
  }


  /// Runs the detection pass for the speaker who just replied.
  ///
  /// Gated HERE and nowhere else, so there is exactly one place the feature is
  /// switched on. The eval leaf itself consults no settings — that separation
  /// is what stops a second gate appearing somewhere later and disagreeing
  /// with this one.
  Future<void> _runPocketsPass(String reply) async {
    if (!_storageService.realismSettings.pocketsEnabled) return;
    if (reply.trim().isEmpty) return;

    final speaker = _activeCharacter;
    if (speaker == null) return;
    final charId = _getCharacterIdFromCard(speaker);

    // Seed from the card the first time this chat asks: an author who wrote
    // `frontPorchExtensions.inventory` expects her to START with those things,
    // not to acquire them by accident later.
    // Still `??`-lazy, and still load-bearing: seedPocketsFromCards runs at
    // the top of a user turn, so a character who ARRIVES mid-turn (a Scene
    // Guest, a cast change) reaches this without having been seeded.
    final record = pocketsFor(charId) ?? startingPocketsFor(speaker);
    // Lazy morning housekeeping: yesterday's set-aside clothes leave the
    // record the first time it is touched on a new story day, BEFORE any
    // prompt or op can see them. Possessions stay (see SetAsideItem).
    final day = storyDayCount;
    record.expireSetAside(day);

    // Hand-offs (Porch Life -> "Hand things between characters"). Only ever in
    // a group: in a 1:1 the only other party is the user, who has no record to
    // put anything into, so the roster stays empty and the model is never
    // invited to name a recipient.
    final transfersOn =
        _storageService.realismSettings.pocketTransfersEnabled &&
        _activeGroup != null;
    final others = transfersOn
        ? [
            for (final c in _groupCharacters)
              if (_getCharacterIdFromCard(c) != charId) c.name,
          ]
        : const <String>[];

    final handedOver = <String, PocketItem>{};
    // Resolve against the roster the model was actually shown. An
    // unresolvable name is DROPPED, not guessed: the item still leaves
    // the giver (that much is true either way) and simply reaches
    // nobody, which is the behaviour every build before this one had.
    final onTransfer = transfersOn
        ? (String to, PocketItem item) {
            final match = resolveRecipient(to, others);
            if (match != null) handedOver[match] = item;
          }
        : null;

    // On a fused reply-facts turn the question was already asked (one call
    // for all three bookkeeping passes) — parse this pass's slice through
    // the SAME parser and applier the standalone call feeds. An answer with
    // no ops is the common case and applies nothing, exactly as today.
    final fused = _replyFactsRaw;
    final List<String> receipts;
    if (fused != null) {
      final ops = PocketsEval.parseOps(fused);
      receipts = ops.isEmpty
          ? const []
          : applyPocketOps(record, ops, onTransfer: onTransfer, day: day);
    } else {
      receipts = await _pocketsEval.evaluateAndApply(
        charName: speaker.name,
        pockets: record,
        reply: reply,
        // Without this a change the USER narrated — walking her out into the
        // rain — is invisible to the eval, and the dress stays recorded dry.
        recentExchange: recentExchange(_messages),
        others: others,
        onTransfer: onTransfer,
        day: day,
      );
    }

    // Apply the arrivals AFTER the giver's own record is settled, so a
    // hand-off can never be read back out of the giver mid-pass.
    for (final entry in handedOver.entries) {
      final matches = _groupCharacters.where((c) => c.name == entry.key);
      if (matches.isEmpty) continue;
      final recipient = matches.first;
      final rid = _getCharacterIdFromCard(recipient);
      final theirs = pocketsFor(rid) ?? startingPocketsFor(recipient);
      theirs.carrying.add(entry.value);
      while (theirs.carrying.length > kMaxCarrying) {
        theirs.carrying.removeAt(0);
      }
      setPocketsFor(rid, theirs);
      debugPrint(
        '[Pockets] ${speaker.name} -> ${recipient.name}: ${entry.value.display}',
      );
    }

    // Store even when nothing changed: the first turn is what promotes a
    // card-seeded record into the chat, and without this it would be re-seeded
    // (and re-diffed against) every single turn.
    setPocketsFor(charId, record);

    if (receipts.isEmpty) return;

    // Receipts ride the message metadata the same way needs deltas do, so the
    // bubble can show what changed without a second storage path.
    final msg = _messages.isNotEmpty ? _messages.last : null;
    if (msg != null && !msg.isUser) {
      msg.metadata = {...?msg.metadata, 'pocket_changes': receipts};
      await _saveChat();
    }
    notifyListeners();
  }
}
