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

/// The Scene Guest join/exit/mint FLOW layer: `/exit` undo, the joinable
/// roster, `/join` (lite guest or full member, incl. the 1:1→group
/// conversion), the detected-cast accept/dismiss popup, the guest minting
/// factory call, and the scene-change/id-resolve helpers the flow relies on.
/// `chat_service_scene_guest.dart` (existing part) holds the guest TURN path
/// (`generateGuestTurn`, direct-address routing, exit narration) — this file
/// is the layer on top of it. Extracted verbatim from `chat_service.dart` —
/// zero behaviour change.
extension ChatServiceGuestFlow on ChatService {
  /// Capture undo state right after a `/exit` departure turn finished. The
  /// just-generated host message (if any) is the departure to delete on undo.
  void armSceneGuestExitUndo(CharacterCard guest) {
    final departure =
        (_messages.isNotEmpty &&
            !_messages.last.isUser &&
            _messages.last.sender != 'System')
        ? _messages.last
        : null;
    _exitUndoGuest = guest;
    _exitUndoMessage = departure;
    _exitUndoOfferName = guest.name;
    notifyListeners();
  }

  void _clearExitUndo() {
    _exitUndoGuest = null;
    _exitUndoMessage = null;
    _exitUndoOfferName = null;
    // A pending full-member exit that is cleared WITHOUT committing (context
    // switch / new chat) is simply cancelled: the member's row was never deleted,
    // so they stay. The sendMessage commit path runs _commitPendingMemberExit
    // before this, so a real "continue" still finalizes the removal.
    _pendingMemberExit = null;
  }

  /// Undo the last `/exit`: delete the departure message (which reverts the host
  /// realism it applied, via [deleteMessage]'s rollback) and restore the guest
  /// to the scene with their full context (evolution + memory were never wiped).
  Future<void> undoLastExit() async {
    // Full group member (deferred-deletion): the member's DB row, realism,
    // evolution, quests and memory were never touched — restoring is just a
    // roster reload plus deleting their goodbye turn (which reverts the realism
    // that turn applied). The destructive removal never ran, so there is nothing
    // to un-collapse.
    final pendingMember = _pendingMemberExit;
    if (pendingMember != null) {
      final departure = _exitUndoMessage;
      _pendingMemberExit = null;
      _clearExitUndo();
      if (departure != null) {
        final idx = _messages.indexOf(departure);
        if (idx >= 0) deleteMessage(idx); // removes + reverts realism + saves
      }
      await _reloadGroupRoster();
      _setGuestStatus('${pendingMember.name} is back in the chat.');
      notifyListeners();
      return;
    }

    final guest = _exitUndoGuest;
    final departure = _exitUndoMessage;
    if (guest == null) return;
    _clearExitUndo();
    if (departure != null) {
      final idx = _messages.indexOf(departure);
      if (idx >= 0) deleteMessage(idx); // removes + reverts realism + saves
    }
    final id = guest.dbId;
    if (id != null && !_sceneGuestIds.contains(id)) {
      _sceneGuestIds.add(id);
      await _resolveSceneGuestCards();
      await _saveChat();
    }
    _setGuestStatus('${guest.name} is back in the scene.');
    notifyListeners();
  }

  /// Library characters eligible to `/join` this 1:1 scene as a Scene Guest:
  /// every loaded character EXCEPT the current host and anyone already present.
  /// Empty in group mode or before a 1:1 host is set. Drives both the `/join`
  /// name-resolution and the picker dialog's list.
  List<CharacterCard> get joinableGuestCharacters {
    final repo = _characterRepository;
    if (repo == null || _activeCharacter == null || _activeGroup != null) {
      return const [];
    }
    final hostId = _activeCharacter!.dbId;
    final present = _sceneGuestIds.toSet();
    return repo.characters.where((c) {
      final id = c.dbId;
      if (id == null) return false;
      if (hostId != null && id == hostId) return false; // can't invite the host
      if (present.contains(id)) return false; // already in the scene
      return true;
    }).toList();
  }

  /// Library characters eligible to `/join` an active GROUP as a full member:
  /// every loaded character except those already in the cast (excluded by name —
  /// addCharacterToGroup's stable-identity D5 guard is the real backstop). Empty
  /// outside a group. Drives `/join` resolution in group chats.
  List<CharacterCard> get joinableGroupCharacters {
    final repo = _characterRepository;
    if (repo == null || _activeGroup == null) return const [];
    final memberNames = _groupCharacters
        .map((c) => c.name.trim().toLowerCase())
        .toSet();
    return repo.characters
        .where((c) => !memberNames.contains(c.name.trim().toLowerCase()))
        .toList();
  }

  /// Bring an existing library [card] into the scene as a Scene Guest (the
  /// picker's selection handler; same parity-safe enter path as `/create`).
  Future<void> joinSceneGuest(CharacterCard card) =>
      _addGuestWithStatus(displayName: card.name, existing: card);

  /// Bring an existing library [card] in as a FULL participant (realism-bearing).
  ///
  /// In a 1:1 this converts the chat into a group *in place* (host + [card]) by
  /// reusing [forkToGroupChat]; in an existing group it adds the member via
  /// [addCharacterToGroup]. This is the macro path (`/join --full`) that replaces
  /// the separate Fork-to-Group wizard — same underlying machinery, no screen
  /// switch. Requires the group repository (wired from main.dart).
  Future<void> joinFull(CharacterCard card) async {
    final repo = _groupChatRepository;
    if (repo == null) {
      _setGuestStatus(
        '⚠ Group support is unavailable right now.',
        isError: true,
      );
      return;
    }
    if (_isTurnBusy) {
      _setGuestStatus(
        '⚠ Wait for the current reply to finish first.',
        isError: true,
      );
      return;
    }
    if (_activeGroup != null) {
      final ok = await addCharacterToGroup(card, repo);
      if (!ok) {
        // addCharacterToGroup already surfaced a specific reason (e.g. the D5
        // "already in this chat" banner); don't clobber it with a generic one.
        return;
      }
      // Members are copied under fresh UUIDs, so resolve the live member by name
      // before having them make their organic entrance.
      final resolved = groupCharacters.firstWhere(
        (c) => c.name == card.name,
        orElse: () => card,
      );
      await _generateMemberEntrance(
        resolved,
        'enter the scene naturally, reacting to what is happening',
      );
      return;
    }

    // 1:1 → group conversion. Bring EVERYONE currently in the scene along: the
    // host (added by forkToGroupChat) plus every present lite guest — lite NPCs
    // can't exist in a group, so they're promoted to full members rather than
    // dropped. A character who is already a present guest just gets promoted
    // (no fresh entrance); a brand-new arrival makes an organic, LLM-written
    // entrance from the chat so far + their card (mirroring the lite /join flow).
    final present = List<CharacterCard>.from(_sceneGuestCards);
    final cardId = _getCharacterIdFromCard(card);
    final isPresentGuest = present.any(
      (g) => _getCharacterIdFromCard(g) == cardId,
    );

    final additional = <CharacterCard>[if (!isPresentGuest) card, ...present];
    final entrances = isPresentGuest
        ? const <String, ({String text, bool creative})>{}
        : {
            cardId: (
              text: 'enter the scene naturally, reacting to what is happening',
              creative: true,
            ),
          };

    await _convertOneToOneToGroup(additional, entrances, repo);
  }

  /// Promote the entire present scene — the host plus every present lite guest —
  /// into a full group, with no new arrival. This is the bare `/join --full`
  /// (and any "make this a group" affordance): it turns a 1:1 that has picked up
  /// lite NPCs into a real group where everyone is a full, realism-bearing member.
  Future<void> promoteSceneToFull() async {
    final repo = _groupChatRepository;
    if (repo == null) {
      _setGuestStatus(
        '⚠ Group support is unavailable right now.',
        isError: true,
      );
      return;
    }
    if (_isTurnBusy) {
      _setGuestStatus(
        '⚠ Wait for the current reply to finish first.',
        isError: true,
      );
      return;
    }
    if (_activeGroup != null) return; // already a group
    final present = List<CharacterCard>.from(_sceneGuestCards);
    if (present.isEmpty) {
      _setGuestStatus(
        '⚠ No guests to promote — bring one in with /join --full <name>.',
        isError: true,
      );
      return;
    }
    // No fresh entrance: everyone is already in the scene, they just become full.
    await _convertOneToOneToGroup(
      present,
      const <String, ({String text, bool creative})>{},
      repo,
    );
  }

  /// Shared 1:1→group conversion core used by [joinFull] and
  /// [promoteSceneToFull]. Drops present guests' lite state (they become full
  /// members) and forks the current chat into a group with [additional] members
  /// and any creative [entrances], surfacing a failure banner if it can't.
  Future<void> _convertOneToOneToGroup(
    List<CharacterCard> additional,
    Map<String, ({String text, bool creative})> entrances,
    GroupChatRepository repo,
  ) async {
    // The present guests are becoming full members — drop their lite state so
    // they aren't represented twice once we switch into group mode.
    _sceneGuestIds.clear();

    final group = await forkToGroupChat(additional, repo, entrances: entrances);
    if (group == null) {
      _setGuestStatus(
        '⚠ Could not convert this chat into a group.',
        isError: true,
      );
    }
  }

  /// Have [resolved] (a current group member) make an organic, LLM-written
  /// entrance: force them to speak next under a hidden stage-direction so they
  /// write their own entrance from the chat so far + their card. Shared by the
  /// 1:1→group conversion (via forkToGroupChat) and live `/join --full` / sidebar
  /// adds. Returns true on success. [intent] is sanitized so it cannot break out
  /// of the bracketed directive injection.
  Future<bool> _generateMemberEntrance(
    CharacterCard resolved,
    String intent,
  ) async {
    final safeText = intent
        .replaceAll(']', ')')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    _groupManager?.setNextSpeaker(resolved);
    _entranceDirective =
        'Stage direction (hidden — do NOT quote, repeat, or copy this '
        'text into the reply): ${resolved.name} enters the scene now, '
        'following this intent — "$safeText". Write ${resolved.name}\'s '
        'entrance fresh, in their own voice and words.';
    try {
      await _generateResponse(GenerationMode.normal);
      return true;
    } catch (e) {
      debugPrint('[Join:Entrance] ${resolved.name} failed: $e');
      _entranceDirective = null; // don't leak into a later turn
      return false;
    }
  }

  /// Clear a pending picker request (user cancelled or finished picking).
  void dismissGuestPicker() {
    _pendingGuestPickerFilter = null;
    _pendingGuestPickerFull = false;
    notifyListeners();
  }

  /// Promote the pending detected character to a real Scene Guest via the
  /// EXISTING mint+add+enter path (same as `/create`). Seeds the guest from the
  /// detected name + descriptor (as concept). Surfaces errors like `/create`.
  Future<void> acceptDetectedGuest() async {
    final detected = _pendingGuestDetection;
    if (detected == null) return;
    _pendingGuestDetection = null;
    _offeredOrIgnoredGuestNames.add(detected.name.trim().toLowerCase());
    notifyListeners();

    await _addGuestWithStatus(
      displayName: detected.name,
      mint: (onStatus) => _mintSceneGuest(
        detected.name,
        detected.descriptor,
        onStatus: onStatus,
      ),
    );
  }

  /// Decline the pending detection; the name is remembered so it is never
  /// re-offered this session.
  void dismissDetectedGuest() {
    final detected = _pendingGuestDetection;
    if (detected != null) {
      _offeredOrIgnoredGuestNames.add(detected.name.trim().toLowerCase());
    }
    _pendingGuestDetection = null;
    notifyListeners();
  }

  /// Mint a Scene Guest (Lite NPC) via the extracted factory (gen + persist),
  /// using the active backend + the host character for scene context.
  Future<GuestMintResult> _mintSceneGuest(
    String name,
    String concept, {
    void Function(String step)? onStatus,
  }) async {
    final repo = _characterRepository;
    if (repo == null) return const GuestMintResult.failure('no repository');
    return SceneGuestFactory(repo, _storageService).mint(
      name: name,
      concept: concept,
      sceneGrounding: _buildGuestGrounding(name),
      llm: testLlmServiceOverride ?? _llmProvider?.activeService,
      host: _activeCharacter,
      onStatus: onStatus,
    );
  }

  /// Collect the in-chat narration that portrays [name] so a minted Scene Guest
  /// is built from how the character actually appeared — not invented from a
  /// bare name (which produced cards with nothing in common with the scene).
  /// Returns the most recent lines that mention the guest (by their first name,
  /// word-boundary), bounded for tokens; empty when the name hasn't come up yet.
  String _buildGuestGrounding(String name) {
    final first = name.trim().split(RegExp(r'\s+')).first;
    if (first.length < 2) return '';
    // If the guest's first name overlaps the host's or the user's name, the
    // name-matched excerpts are dominated by the host/user, and grounding would
    // build the guest FROM the host's portrayal (the "guest IS the host" bug).
    // Skip grounding in that case and let concept-only generation handle it.
    final firstLc = first.toLowerCase();
    final hostFirst = (_activeCharacter?.name ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .first
        .toLowerCase();
    final userFirst = _userPersonaService.persona.name
        .trim()
        .split(RegExp(r'\s+'))
        .first
        .toLowerCase();
    if (firstLc == hostFirst || firstLc == userFirst) return '';
    final re = RegExp(
      r'\b' + RegExp.escape(first) + r'\b',
      caseSensitive: false,
    );
    final hits = <String>[];
    for (final m in _messages) {
      if (m.sender == 'System') continue;
      final t = m.displayText.trim();
      if (t.isEmpty || !re.hasMatch(t)) continue;
      hits.add(t);
    }
    if (hits.isEmpty) return '';
    final recent = hits.length > 10 ? hits.sublist(hits.length - 10) : hits;
    var joined = recent.join('\n---\n');
    const cap = 4000;
    if (joined.length > cap) joined = joined.substring(joined.length - cap);
    return joined;
  }

  /// True when the active 1:1 scene changed (chat/character/session switched)
  /// or the service was disposed since [token] (a `_currentSessionId` snapshot)
  /// was captured. Fire-and-forget guest async work must bail — no state
  /// mutation, no DB, no UI signal — when this returns true after an `await`.
  bool _sceneChanged(String? token) => _disposed || _currentSessionId != token;

  /// Re-resolve `_sceneGuestCards` from `_sceneGuestIds` using the repository.
  /// Called whenever the id list changes or on session load. Drops ids that no
  /// longer resolve (e.g. the guest character was deleted from the library).
  ///
  /// IMPORTANT: a guest is NOT scenario-stripped on its shared library card here
  /// (getCharacterCardById returns the repository's live reference — mutating it
  /// would corrupt the character for when it's opened as a normal host). The
  /// guest's scenario is instead blanked only in the prompt at guest-turn time
  /// (see `guestSpeaker != null` in `_generateResponse`).
  Future<void> _resolveSceneGuestCards() async {
    if (_disposed) return;
    final repo = _characterRepository;
    if (repo == null) return;
    // Never run two passes at once: each awaits per-id DB reads and then mutates
    // the shared id/card lists, so overlapping passes could read a half-mutated
    // list or race the DB. Coalesce concurrent requests into one trailing re-run.
    if (_resolvingSceneGuests) {
      _sceneGuestsResolvePending = true;
      return;
    }
    final token = _currentSessionId;
    _resolvingSceneGuests = true;
    try {
      do {
        _sceneGuestsResolvePending = false;
        final resolved = <CharacterCard>[];
        final validIds = <String>[];
        for (final id in List<String>.from(_sceneGuestIds)) {
          if (_sceneChanged(token)) {
            return; // disposed or chat switched mid-pass
          }
          final card = await repo.getCharacterCardById(id);
          if (card != null) {
            resolved.add(card);
            validIds.add(id);
          }
        }
        if (_sceneChanged(token)) return;
        _sceneGuestIds
          ..clear()
          ..addAll(validIds);
        _sceneGuestCards
          ..clear()
          ..addAll(resolved);
        notifyListeners();
      } while (_sceneGuestsResolvePending && !_disposed);
    } finally {
      _resolvingSceneGuests = false;
    }
  }
}
