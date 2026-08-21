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

import 'package:front_porch_ai/services/services.dart';
import 'package:front_porch_ai/utils/utils.dart';

/// Session list / load / delete leaf for [ChatFacade]. Keeps chat_facade.dart
/// under the ratchet: list-by-character, list-by-group, and `action: delete`
/// all live here.
class ChatSessionFacade {
  ChatSessionFacade(this._chat, this._characters, this._notify);

  final ChatService _chat;
  final CharacterRepository _characters;
  final void Function() _notify;

  /// All saved conversations, newest first. [characterId] is a library dbId
  /// (mapped to stableGroupId). [groupId] lists that group's chats. Either
  /// lists WITHOUT touching the active chat. Absent both → active chat.
  Future<List<Map<String, dynamic>>> list({
    String? characterId,
    String? groupId,
  }) async {
    List<Map<String, dynamic>> raw;
    if (groupId != null && groupId.isNotEmpty) {
      raw = await _chat.getSessionsForId('group_$groupId');
    } else if (characterId != null && characterId.isNotEmpty) {
      final card = _characters.characters
          .where((c) => c.dbId == characterId)
          .firstOrNull;
      // getSessionsForId keys by imagePath basename (stableGroupId) — a UUID
      // silently returns [] (the documented fall-through).
      raw = card == null
          ? const []
          : await _chat.getSessionsForId(card.stableGroupId);
    } else {
      raw = await _chat.getSessions();
    }
    return raw.map((s) {
      final date = s['date'];
      return {...s, 'date': date is DateTime ? date.toIso8601String() : date};
    }).toList();
  }

  /// New chat, load an existing session, or delete one. Returns the resulting
  /// session id (nullable after a no-replacement delete of the last chat).
  Future<String?> apply({
    String? action,
    String? sessionId,
    bool startReplacement = true,
  }) async {
    if (action == 'new') {
      await _chat.startNewChat();
    } else if (action == 'delete') {
      if (sessionId == null || sessionId.isEmpty) return null;
      await _chat.deleteSession(sessionId, startReplacement: startReplacement);
    } else if (sessionId != null) {
      await _chat.loadSession(sessionId);
    } else {
      return null;
    }
    _notify();
    return _chat.currentSessionId;
  }
}
