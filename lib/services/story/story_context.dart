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

/// Pure context-string builders and export renderers for the Porch Stories
/// pipeline. Extracted verbatim from `story_pipeline_service.dart` (Clusters
/// F/H's pure context builders + Cluster I's export functions) as part of
/// the god-file split — all four take only [StoryProject] data and touch no
/// pipeline state.
abstract final class StoryContext {
  /// Build character card context from snapshotted character definitions.
  static String characterCards(StoryProject project) {
    if (project.characterCardSnapshots.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln(
      '\n\n## Character Definitions (from imported character cards)',
    );
    buffer.writeln(
      'These are the CORE characters of the story. Use their names, personalities, ',
    );
    buffer.writeln(
      'descriptions, and relationships faithfully. You MAY create additional supporting ',
    );
    buffer.writeln(
      'NPCs, antagonists, and side characters to enrich the story, but the characters ',
    );
    buffer.writeln('below should be the central figures.\n');

    for (int i = 0; i < project.characterCardSnapshots.length; i++) {
      final snap = project.characterCardSnapshots[i];
      final role = snap['role'] ?? 'Supporting';
      final isSelfInsert = snap['self_insert'] == 'true';
      final roleLabel = isSelfInsert ? '$role — User Self-Insert' : role;
      buffer.writeln(
        '### Character ${i + 1}: ${snap['name'] ?? 'Unknown'} ($roleLabel)',
      );
      if (snap['description']?.isNotEmpty == true) {
        buffer.writeln('Description: ${snap['description']}');
      }
      if (snap['personality']?.isNotEmpty == true) {
        buffer.writeln('Personality: ${snap['personality']}');
      }
      if (snap['scenario']?.isNotEmpty == true) {
        buffer.writeln('Scenario: ${snap['scenario']}');
      }
      if (snap['first_message']?.isNotEmpty == true) {
        buffer.writeln('Opening: ${snap['first_message']}');
      }
      if (snap['system_prompt']?.isNotEmpty == true) {
        buffer.writeln('System context: ${snap['system_prompt']}');
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  static String previousActs(StoryProject project, int currentActIndex) {
    if (currentActIndex == 0) return '';

    final buffer = StringBuffer();
    buffer.writeln(
      '\n\n## STORY SO FAR (Events from previous acts — maintain continuity!)',
    );
    buffer.writeln(
      'The following is a summary of everything that has happened in the story ',
    );
    buffer.writeln(
      'up to this point. You MUST maintain consistency with these established ',
    );
    buffer.writeln('events, character developments, and plot threads.\n');

    for (int prevAct = 0; prevAct < currentActIndex; prevAct++) {
      final act = project.acts[prevAct];
      final scenes = project.scenes[prevAct] ?? [];

      buffer.writeln('### Act ${act.number}: ${act.title}');
      buffer.writeln(act.description);

      if (scenes.isNotEmpty) {
        buffer.writeln('\nScenes:');
        for (int s = 0; s < scenes.length; s++) {
          final scene = scenes[s];
          buffer.writeln(
            '  ${s + 1}. ${scene.title} (${scene.location}) — ${scene.description}',
          );
          buffer.writeln('     Characters: ${scene.castNames.join(", ")}');

          // Include prose excerpts for rich context
          final sId = '$prevAct-$s';
          final beats = project.beats[sId] ?? [];
          final proseExcerpts = <String>[];
          for (int b = 0; b < beats.length; b++) {
            final bId = '$sId-$b';
            final prose = project.prose[bId]?.final_;
            if (prose != null && prose.isNotEmpty) {
              // Include a meaningful excerpt
              final excerpt = prose.length > 300
                  ? '${prose.substring(0, 300)}...'
                  : prose;
              proseExcerpts.add(excerpt);
            }
          }
          if (proseExcerpts.isNotEmpty) {
            buffer.writeln('     What happened: ${proseExcerpts.join(" ")}');
          }
        }
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// Export the full story as plain text.
  static String exportText(StoryProject project) {
    final buffer = StringBuffer();
    buffer.writeln(project.title.toUpperCase());
    buffer.writeln('=' * project.title.length);
    buffer.writeln();

    for (int actIdx = 0; actIdx < project.acts.length; actIdx++) {
      final act = project.acts[actIdx];
      buffer.writeln('\n${'─' * 40}');
      buffer.writeln('ACT ${act.number}: ${act.title.toUpperCase()}');
      buffer.writeln('${'─' * 40}\n');

      final scenes = project.scenes[actIdx] ?? [];
      for (int sceneIdx = 0; sceneIdx < scenes.length; sceneIdx++) {
        final scene = scenes[sceneIdx];
        buffer.writeln('\nChapter ${scene.number}: ${scene.title}\n');

        final sId = '$actIdx-$sceneIdx';
        final beats = project.beats[sId] ?? [];
        for (int beatIdx = 0; beatIdx < beats.length; beatIdx++) {
          final bId = '$sId-$beatIdx';
          final prose = project.prose[bId];
          if (prose?.final_ != null) {
            buffer.writeln(prose!.final_);
            buffer.writeln();
          }
        }
      }
    }

    return buffer.toString();
  }

  /// Export the full story as Markdown.
  static String exportMarkdown(StoryProject project) {
    final buffer = StringBuffer();
    buffer.writeln('# ${project.title}\n');

    for (int actIdx = 0; actIdx < project.acts.length; actIdx++) {
      final act = project.acts[actIdx];
      buffer.writeln('## Act ${act.number}: ${act.title}\n');

      final scenes = project.scenes[actIdx] ?? [];
      for (int sceneIdx = 0; sceneIdx < scenes.length; sceneIdx++) {
        final scene = scenes[sceneIdx];
        buffer.writeln('### Chapter ${scene.number}: ${scene.title}\n');

        final sId = '$actIdx-$sceneIdx';
        final beats = project.beats[sId] ?? [];
        for (int beatIdx = 0; beatIdx < beats.length; beatIdx++) {
          final bId = '$sId-$beatIdx';
          final prose = project.prose[bId];
          if (prose?.final_ != null) {
            buffer.writeln(prose!.final_);
            buffer.writeln();
          }
        }
      }
    }

    return buffer.toString();
  }
}
