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

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/services/story/story.dart';
import 'package:front_porch_ai/services/story_repository.dart';
import 'package:front_porch_ai/services/llm_service.dart';
import 'package:front_porch_ai/services/memory_service.dart';
import 'package:front_porch_ai/services/story_stage_params.dart';
import 'package:front_porch_ai/database/database.dart' hide StoryProject;

part 'story_pipeline_service.llm.dart';
part 'story_pipeline_service.planning.dart';
part 'story_pipeline_service.prose.dart';
part 'story_pipeline_service.acts.dart';

/// Orchestrates the multi-agent AI novel-writing pipeline for Porch Stories.
///
/// Each stage constructs a specialized prompt, calls the LLM via [LLMService],
/// parses the structured JSON response, and updates the [StoryProject] state.
/// Supports three prompt complexity tiers for different model capabilities.
class StoryPipelineService extends ChangeNotifier {
  final StoryRepository _repository;
  final LLMService _llmService;
  final MemoryService
  _memoryService; // ignore: unused_field - Reserved for future story RAG / memory injection
  AppDatabase _db;

  bool _isRunning = false;
  String _currentStep = '';
  String _statusMessage = '';
  String _streamingText = '';
  int _tokenCount = 0;

  bool get isRunning => _isRunning;
  String get currentStep => _currentStep;
  String get statusMessage => _statusMessage;
  String get streamingText => _streamingText;
  int get tokenCount => _tokenCount;

  StoryPipelineService(
    this._repository,
    this._llmService,
    this._memoryService,
    this._db,
  );

  /// Re-point at a reopened database (backup restore, storage move, stable-DB
  /// import) — same contract as StoryRepository.updateDatabase. Without this
  /// the pipeline kept the CLOSED startup handle until an unrelated provider
  /// notification happened to rebuild it, and Porch Stories looked empty (or
  /// threw) until then.
  void updateDatabase(AppDatabase db) {
    _db = db;
  }

  /// Public method for the UI to preview what chat history will be imported.
  /// Always pulls full messages from the DB (not RAG embeddings which are windowed summaries).
  Future<List<String>> getChatPreviewMessages(StoryProject project) async {
    if (!project.useChatHistory || project.chatHistoryCharacterIds.isEmpty) {
      return [];
    }
    final messages = <String>[];
    try {
      final resolvedIds = await _resolveSessionCharacterIds(
        project.chatHistoryCharacterIds,
      );
      for (final charId in resolvedIds) {
        final sessions = await _db.getSessionsForCharacter(charId);
        for (final session in sessions) {
          // Living Time §4: same session scoping as the distiller and the raw
          // fallback in story_pipeline_service.llm.dart (keep in sync — all
          // three are "the chat history" for a project, and a preview that
          // shows chats the story will never use is a lie).
          if (project.chatHistorySessionIds.isNotEmpty &&
              !project.chatHistorySessionIds.contains(session.id)) {
            continue;
          }
          final msgs = await _db.getMessagesForSession(session.id);
          for (final msg in msgs) {
            try {
              final swipes = jsonDecode(msg.swipes) as List;
              final text = swipes.isNotEmpty
                  ? swipes[msg.swipeIndex.clamp(0, swipes.length - 1)]
                  : '';
              if (text.toString().trim().isNotEmpty) {
                messages.add('${msg.sender}: $text');
              }
            } catch (_) {}
          }
          messages.add('--- (session break) ---');
        }
      }
    } catch (e) {
      debugPrint('[StoryPipeline] Chat preview error: $e');
    }
    return messages;
  }

  /// Resolve character IDs to actual session characterIds.
  /// The stored IDs might be embed-IDs, DB PKs, or filename-based IDs.
  /// This method cross-references by character name to find ALL session IDs.
  Future<Set<String>> _resolveSessionCharacterIds(
    List<String> storedIds,
  ) async {
    final resolved = <String>{};
    resolved.addAll(storedIds);

    try {
      final allChars = await _db.select(_db.characters).get();
      final allSessions = await _db.select(_db.sessions).get();

      for (final storedId in storedIds) {
        // Find this character in the Characters table
        final matchingChar = allChars.where((c) => c.id == storedId);
        if (matchingChar.isEmpty) continue;

        final charName = matchingChar.first.name;

        // Find ALL sessions whose characterId maps to a character with the same name
        for (final sess in allSessions) {
          if (sess.characterId == null) continue;
          final sessChar = allChars.where((c) => c.id == sess.characterId);
          if (sessChar.isNotEmpty && sessChar.first.name == charName) {
            resolved.add(sess.characterId!);
          }
        }
      }
    } catch (e) {
      debugPrint('[StoryPipeline] ID resolution error: $e');
    }

    // Remove the original stored IDs if they don't match any sessions
    // (only keep IDs that actually have sessions)
    return resolved;
  }

  void _setStatus(String step, String message) {
    _currentStep = step;
    _statusMessage = message;
    notifyListeners();
  }

  // Extension parts call this instead of the inherited `notifyListeners()`
  // directly. [ChangeNotifier.notifyListeners] is `@protected` /
  // `@visibleForTesting`; unlike `ChatService` (which sidesteps the same
  // problem by overriding `notifyListeners()` for its own disposal guard),
  // this class inherits it unmodified, and Dart's protected-member check
  // does not treat an `extension … on StoryPipelineService` body as "an
  // instance member of a subclass" the way it treats a real method on this
  // class — so a bare call from inside a part's extension trips
  // invalid_use_of_protected_member / invalid_use_of_visible_for_testing_member.
  // This one-line pass-through, kept as a real class member, sidesteps that
  // with zero behavior change.
  void _notify() => notifyListeners();

  // ── Forwarders to lib/services/story/ leaves ────────────────────────
  // Kept as class members so external call sites (story pages, the web
  // facade, and the story_pipeline_leaves_test.dart provability net) need
  // zero changes. See the split map (H3) — generateArchetypes/exportAsText/
  // exportAsMarkdown are map-prescribed; parseJson is an ADDITIONAL
  // forwarder the map didn't call for (it assumed zero external callers,
  // which was true against the map's base commit but no longer holds now
  // that story_pipeline_leaves_test.dart — added after the map was written
  // — calls `StoryPipelineService.parseJson` directly as its provability
  // net for the JSON-repair machinery). cleanJson keeps NO forwarder: it
  // still has zero external callers, including in that new test file.

  /// Generate random story concept archetypes for the user to choose from.
  static List<Map<String, String>> generateArchetypes({int count = 10}) =>
      StoryArchetypes.generate(count: count);

  /// Parse JSON with fallback for malformed/truncated responses.
  static Map<String, dynamic>? parseJson(String raw) =>
      StoryJson.parseJson(raw);

  /// Export the full story as plain text.
  String exportAsText(StoryProject project) => StoryContext.exportText(project);

  /// Export the full story as Markdown.
  String exportAsMarkdown(StoryProject project) =>
      StoryContext.exportMarkdown(project);
}
