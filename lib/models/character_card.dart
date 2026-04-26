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

import 'package:front_porch_ai/database/database.dart' show AvatarImage;
import 'package:front_porch_ai/models/lorebook.dart';

/// Front Porch AI V2.5 extensions — stored inside V2 `extensions.front_porch`.
///
/// These values seed the Realism Engine's initial state when a new
/// conversation is started with a character. Existing sessions use their
/// own DB-persisted state and are not affected.
class FrontPorchExtensions {
  bool realismEnabled;
  int shortTermBond; // -150 to 150
  int longTermBond; // -150 to 150
  int trustLevel; // -100 to 100
  int dayCount; // starts at 1
  String timeOfDay; // dawn/morning/late_morning/afternoon/evening/night
  String characterEmotion; // e.g. "curious"
  String emotionIntensity; // mild/moderate/strong
  bool nsfwCooldownEnabled;
  bool passageOfTimeEnabled; // sub-toggle for automatic time advancement
  bool chaosModeEnabled;
  String currentTask; // initial quest/task for the character

  FrontPorchExtensions({
    this.realismEnabled = false,
    this.shortTermBond = 0,
    this.longTermBond = 0,
    this.trustLevel = 0,
    this.dayCount = 1,
    this.timeOfDay = 'morning',
    this.characterEmotion = '',
    this.emotionIntensity = 'mild',
    this.nsfwCooldownEnabled = false,
    this.passageOfTimeEnabled = true, // defaults to on when realism is enabled
    this.chaosModeEnabled = false,
    this.currentTask = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'version': '2.5',
      'realism_engine': {
        'enabled': realismEnabled,
        'short_term_bond': shortTermBond,
        'long_term_bond': longTermBond,
        'trust_level': trustLevel,
        'day_count': dayCount,
        'time_of_day': timeOfDay,
        'character_emotion': characterEmotion,
        'emotion_intensity': emotionIntensity,
        'nsfw_cooldown_enabled': nsfwCooldownEnabled,
        'passage_of_time_enabled': passageOfTimeEnabled,
        'chaos_mode_enabled': chaosModeEnabled,
        'current_task': currentTask,
      },
    };
  }

  factory FrontPorchExtensions.fromJson(Map<String, dynamic> json) {
    final realism = json['realism_engine'] as Map<String, dynamic>? ?? {};
    return FrontPorchExtensions(
      realismEnabled: realism['enabled'] as bool? ?? false,
      shortTermBond: realism['short_term_bond'] as int? ?? 0,
      longTermBond: realism['long_term_bond'] as int? ?? 0,
      trustLevel: realism['trust_level'] as int? ?? 0,
      dayCount: realism['day_count'] as int? ?? 1,
      timeOfDay: realism['time_of_day'] as String? ?? 'morning',
      characterEmotion: realism['character_emotion'] as String? ?? '',
      emotionIntensity: realism['emotion_intensity'] as String? ?? 'mild',
      nsfwCooldownEnabled: realism['nsfw_cooldown_enabled'] as bool? ?? false,
      passageOfTimeEnabled: realism['passage_of_time_enabled'] as bool? ?? true,
      chaosModeEnabled: realism['chaos_mode_enabled'] as bool? ?? false,
      currentTask: realism['current_task'] as String? ?? '',
    );
  }

  /// Create a deep copy of this extensions object
  FrontPorchExtensions copyWith({
    bool? realismEnabled,
    int? shortTermBond,
    int? longTermBond,
    int? trustLevel,
    int? dayCount,
    String? timeOfDay,
    String? characterEmotion,
    String? emotionIntensity,
    bool? nsfwCooldownEnabled,
    bool? passageOfTimeEnabled,
    bool? chaosModeEnabled,
    String? currentTask,
  }) {
    return FrontPorchExtensions(
      realismEnabled: realismEnabled ?? this.realismEnabled,
      shortTermBond: shortTermBond ?? this.shortTermBond,
      longTermBond: longTermBond ?? this.longTermBond,
      trustLevel: trustLevel ?? this.trustLevel,
      dayCount: dayCount ?? this.dayCount,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      characterEmotion: characterEmotion ?? this.characterEmotion,
      emotionIntensity: emotionIntensity ?? this.emotionIntensity,
      nsfwCooldownEnabled: nsfwCooldownEnabled ?? this.nsfwCooldownEnabled,
      passageOfTimeEnabled: passageOfTimeEnabled ?? this.passageOfTimeEnabled,
      chaosModeEnabled: chaosModeEnabled ?? this.chaosModeEnabled,
      currentTask: currentTask ?? this.currentTask,
    );
  }
}

class CharacterCard {
  String name;
  String description;
  String personality;
  String scenario;
  String firstMessage;
  String mesExample;
  String systemPrompt;
  String postHistoryInstructions;
  List<String> alternateGreetings;
  List<String> tags;
  String? imagePath;
  String? folderId;
  Lorebook? lorebook;
  List<String> worldNames;
  String? ttsVoice; // Piper voice key for per-character TTS
  String? dbId; // UUID primary key (runtime only, not serialized)
  FrontPorchExtensions? frontPorchExtensions; // V2.5 Realism Engine defaults
  Map<String, dynamic>?
      rawExtensions; // Preserve unknown third-party extension keys
  List<AvatarImage>? avatarImages; // Multiple avatar images for the character
  int primeAvatarIndex = 1; // 1-based index of the prime (default) avatar

  CharacterCard({
    required this.name,
    this.description = '',
    this.personality = '',
    this.scenario = '',
    this.firstMessage = '',
    this.mesExample = '',
    this.systemPrompt = '',
    this.postHistoryInstructions = '',
    this.alternateGreetings = const [],
    this.tags = const [],
    this.imagePath,
    this.folderId,
    this.lorebook,
    this.worldNames = const [],
    this.ttsVoice,
    this.frontPorchExtensions,
    this.rawExtensions,
    this.avatarImages,
    int? primeAvatarIndex,
  }) : primeAvatarIndex = primeAvatarIndex ?? 1;

  /// All greetings: primary first message + alternates
  List<String> get allGreetings {
    final greetings = <String>[firstMessage];
    greetings.addAll(alternateGreetings);
    return greetings.where((g) => g.isNotEmpty).toList();
  }

  Map<String, dynamic> toJson() {
    // Build extensions map: merge raw (third-party) keys with our namespace
    Map<String, dynamic>? extensions;
    if (frontPorchExtensions != null ||
        (rawExtensions != null && rawExtensions!.isNotEmpty)) {
      extensions = <String, dynamic>{};
      // Preserve any third-party extension keys first
      if (rawExtensions != null) extensions.addAll(rawExtensions!);
      // Add/overwrite our namespace
      if (frontPorchExtensions != null) {
        extensions['front_porch'] = frontPorchExtensions!.toJson();
      }
    }

    return {
      'name': name,
      'description': description,
      'personality': personality,
      'scenario': scenario,
      'first_mes': firstMessage,
      'mes_example': mesExample,
      'system_prompt': systemPrompt,
      'post_history_instructions': postHistoryInstructions,
      'alternate_greetings': alternateGreetings,
      'tags': tags,
      'character_book': lorebook?.toJson(),
      'world_names': worldNames,
      if (ttsVoice != null) 'tts_voice': ttsVoice,
      if (extensions != null) 'extensions': extensions,
    };
  }

  String replacePlaceholders(String text, {String userName = 'You'}) {
    return text
        .replaceAll(RegExp(r'\{\{char\}\}', caseSensitive: false), name)
        .replaceAll(RegExp(r'<char>', caseSensitive: false), name)
        .replaceAll(RegExp(r'\{\{user\}\}', caseSensitive: false), userName)
        .replaceAll(RegExp(r'<user>', caseSensitive: false), userName);
  }

  String get formattedDescription => replacePlaceholders(description);

  /// Whether this card has any Front Porch extensions configured.
  bool get hasFrontPorchExtensions => frontPorchExtensions != null;
}
