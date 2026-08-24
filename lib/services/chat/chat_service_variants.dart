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

/// Shared greet / regenerated-swipe picker: list payload + commit-once select.
/// Chevron cycling reuses [selectGreeting] so emotion rules stay in one place.
extension ChatServiceVariants on ChatService {
  /// True when this bubble is the opening greet with more than one card greet
  /// and no stored regen swipes (those are variants, not greets).
  bool isSelectableGreeting(int messageIndex) {
    // Public accessors so FakeChatService (other library) can answer this
    // from a bubble build. `_messages` / `_activeCharacter` are library-
    // private and resolve as noSuchMethod on the fake.
    if (messageIndex < 0 || messageIndex >= messages.length) return false;
    final msg = messages[messageIndex];
    return usesGreetingPicker(
      messageIndex: messageIndex,
      isUser: msg.isUser,
      greetCount: activeCharacter?.allGreetings.length ?? 0,
      swipeCount: msg.swipes.length,
    );
  }

  /// Picker rows for [messageIndex]. Card greets are macro-resolved so the
  /// preview reads like the opening bubble, not `{{char}}` + HTML comments.
  List<VariantOption> variantsForMessage(int messageIndex) {
    if (messageIndex < 0 || messageIndex >= messages.length) {
      return const [];
    }
    if (isSelectableGreeting(messageIndex)) {
      final character = activeCharacter!;
      final resolved = [
        for (final g in character.allGreetings)
          _buildFirstMessage(character, greetingText: g),
      ];
      return buildVariantOptions(
        resolved,
        greetingIndex,
        kind: VariantKind.greet,
      );
    }
    final msg = messages[messageIndex];
    return buildVariantOptions(
      msg.swipes,
      msg.swipeIndex,
      kind: VariantKind.regen,
    );
  }

  Map<String, dynamic> variantPickerPayload(int messageIndex) {
    if (messageIndex < 0 || messageIndex >= messages.length) {
      return {
        'kind': 'regen',
        'title': 'Select variant',
        'currentIndex': 0,
        'variants': const [],
      };
    }
    final greet = isSelectableGreeting(messageIndex);
    final options = variantsForMessage(messageIndex);
    final current = options.where((v) => v.isCurrent);
    return {
      'kind': greet ? 'greet' : 'regen',
      'title': greet ? 'Select greet' : 'Select variant',
      'currentIndex': current.isEmpty ? 0 : current.first.index,
      'variants': [for (final v in options) v.toJson()],
    };
  }

  /// Commit one greet. First greet keeps starting emotion; alternatives
  /// fire reading-the-room once. Re-selecting the same index is a no-op
  /// (does not re-derive emotion).
  Future<void> selectGreeting(int index) async {
    if (_activeCharacter == null || _messages.isEmpty) return;
    final allGreetings = _activeCharacter!.allGreetings;
    if (allGreetings.length <= 1) return;
    if (index < 0 || index >= allGreetings.length) return;
    if (index == _greetingIndex) return;

    _greetingIndex = index;
    final greeting = allGreetings[_greetingIndex];
    final old = _messages[0];
    _messages[0] = ChatMessage(
      text: _buildFirstMessage(_activeCharacter!, greetingText: greeting),
      sender: _activeCharacter!.name,
      isUser: false,
      characterId: old.characterId,
    );
    await _saveChat();
    notifyListeners();

    if (shouldReadRoomForGreeting(index) && _realismActiveThisMode) {
      _runPostGreetingEval();
    }
  }

  /// Jump to an already-stored swipe. Never generates a new one (the
  /// chevron-past-the-end path in [swipeMessage] still does). Restores
  /// that swipe's snapshot when this message is the tip — no reading-the-room.
  Future<void> selectSwipe(int messageIndex, int swipeIndex) async {
    if (messageIndex < 0 || messageIndex >= _messages.length) return;
    final msg = _messages[messageIndex];
    if (msg.isUser || msg.sender == 'System') return;
    await _commitSwipeIndex(messageIndex, swipeIndex);
  }

  Future<void> selectVariant(int messageIndex, int variantIndex) async {
    if (isSelectableGreeting(messageIndex)) {
      await selectGreeting(variantIndex);
    } else {
      await selectSwipe(messageIndex, variantIndex);
    }
  }
}
