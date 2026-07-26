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

// LLMerta → FPA porch-memory bundle models (schemaVersion 1).
// Producer: LLMerta `packages/llm/lib/src/porch_memories.dart`.
// Design: docs/design/llmerta-porch-memories.md

/// One emotion-stamped diary seed about a Mafia night.
class PorchMemoryCard {
  final String id;
  final String kind;
  final String category;
  final String content;
  final String emotionLabel;
  final String emotionIntensity;
  final double salience;
  final int? dayHint;

  const PorchMemoryCard({
    required this.id,
    required this.kind,
    required this.category,
    required this.content,
    required this.emotionLabel,
    required this.emotionIntensity,
    required this.salience,
    this.dayHint,
  });

  /// Forgiving parse — missing required fields → null (caller skips card).
  static PorchMemoryCard? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final id = (m['id'] as String?)?.trim() ?? '';
    final content = (m['content'] as String?)?.trim() ?? '';
    if (id.isEmpty || content.isEmpty) return null;

    final category = _normalizeCategory(m['category']);
    final intensity = _normalizeIntensity(m['emotionIntensity']);
    final kind = (m['kind'] as String?)?.trim();
    final kindFromSource = m['source'] is Map
        ? (m['source'] as Map)['kind'] as String?
        : null;
    final resolvedKind = (kind != null && kind.isNotEmpty)
        ? kind
        : (kindFromSource?.trim().isNotEmpty == true
              ? kindFromSource!.trim()
              : 'unknown');

    final salRaw = m['salience'];
    final salience = salRaw is num
        ? salRaw.toDouble()
        : double.tryParse('$salRaw') ?? 0.5;

    final dayRaw = m['dayHint'];
    final dayHint = dayRaw is num
        ? dayRaw.toInt()
        : int.tryParse('$dayRaw');

    return PorchMemoryCard(
      id: id,
      kind: resolvedKind,
      category: category,
      content: content,
      emotionLabel: ((m['emotionLabel'] as String?)?.trim().isNotEmpty == true)
          ? (m['emotionLabel'] as String).trim()
          : 'reflective',
      emotionIntensity: intensity,
      salience: salience.clamp(0.0, 1.0),
      dayHint: dayHint,
    );
  }

  static String _normalizeCategory(Object? raw) {
    final s = (raw as String?)?.trim().toLowerCase() ?? '';
    return switch (s) {
      'about_user' || 'aboutuser' || 'about_user_' => 'about_user',
      'about_us' || 'aboutus' => 'about_us',
      'moment' => 'moment',
      'promise' => 'promise',
      _ => 'about_us',
    };
  }

  static String _normalizeIntensity(Object? raw) {
    final s = (raw as String?)?.trim().toLowerCase() ?? '';
    return switch (s) {
      'mild' || 'moderate' || 'strong' => s,
      _ => 'moderate',
    };
  }
}

/// Per-character block inside a finished-game bundle.
class PorchCharacterBlock {
  /// Library [CharacterCard.stableGroupId] (image basename) — not DB id.
  final String characterId;
  final String characterName;
  final List<PorchMemoryCard> cards;

  const PorchCharacterBlock({
    required this.characterId,
    required this.characterName,
    required this.cards,
  });

  static PorchCharacterBlock? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final characterId = (m['characterId'] as String?)?.trim() ?? '';
    if (characterId.isEmpty) return null;
    final name = (m['characterName'] as String?)?.trim() ?? characterId;
    final rawCards = m['cards'];
    final cards = <PorchMemoryCard>[];
    if (rawCards is List) {
      for (final c in rawCards) {
        final parsed = PorchMemoryCard.tryParse(c);
        if (parsed != null) cards.add(parsed);
      }
    }
    if (cards.isEmpty) return null;
    return PorchCharacterBlock(
      characterId: characterId,
      characterName: name,
      cards: cards,
    );
  }
}

/// One finished LLMerta game → multi-character multi-card mailbox file.
class PorchMemoryBundle {
  final int schemaVersion;
  final String gameId;
  final DateTime? finishedAt;
  final String? townName;
  final String? difficulty;
  final String userPersonaId;
  final String userPersonaName;
  final List<PorchCharacterBlock> characters;

  /// Absolute path of the JSON file this was loaded from (for delete).
  final String? sourcePath;

  const PorchMemoryBundle({
    required this.schemaVersion,
    required this.gameId,
    required this.userPersonaId,
    required this.userPersonaName,
    required this.characters,
    this.finishedAt,
    this.townName,
    this.difficulty,
    this.sourcePath,
  });

  /// Null when schema unsupported / required fields missing.
  static PorchMemoryBundle? tryParse(
    Object? raw, {
    String? sourcePath,
  }) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final version = (m['schemaVersion'] as num?)?.toInt() ?? 0;
    if (version != 1) return null;

    final gameId = (m['gameId'] as String?)?.trim() ?? '';
    final userPersonaId = (m['userPersonaId'] as String?)?.trim() ?? '';
    if (gameId.isEmpty || userPersonaId.isEmpty) return null;

    final characters = <PorchCharacterBlock>[];
    final rawChars = m['characters'];
    if (rawChars is List) {
      for (final c in rawChars) {
        final block = PorchCharacterBlock.tryParse(c);
        if (block != null) characters.add(block);
      }
    }
    if (characters.isEmpty) return null;

    DateTime? finishedAt;
    final finishedRaw = m['finishedAt'] as String?;
    if (finishedRaw != null && finishedRaw.isNotEmpty) {
      finishedAt = DateTime.tryParse(finishedRaw)?.toUtc();
    }

    return PorchMemoryBundle(
      schemaVersion: version,
      gameId: gameId,
      finishedAt: finishedAt,
      townName: (m['townName'] as String?)?.trim(),
      difficulty: (m['difficulty'] as String?)?.trim(),
      userPersonaId: userPersonaId,
      userPersonaName: (m['userPersonaName'] as String?)?.trim() ?? '',
      characters: characters,
      sourcePath: sourcePath,
    );
  }
}

/// Maps a library identity (LLMerta `characterId`) to the Journal diary owner
/// key used in this session (`_getCharacterIdFromCard` / ChatParticipant.id).
class PorchDiaryTarget {
  /// Match against bundle `character.characterId` (library stableGroupId).
  final String libraryStableGroupId;

  /// Journal `characterId` to plant under.
  final String diaryCharacterId;

  const PorchDiaryTarget({
    required this.libraryStableGroupId,
    required this.diaryCharacterId,
  });
}
