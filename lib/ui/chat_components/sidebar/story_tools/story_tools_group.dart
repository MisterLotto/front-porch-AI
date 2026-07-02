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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/services/services.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';
import '../porch_accordion.dart';
import 'author_note_section.dart';
import 'chaos_panel.dart';
import 'lorebook_panel.dart';
import 'objective_panel.dart';
import 'static_text_panel.dart';

/// 🎲 Story Tools accordion — author's note, objectives (1:1 full chats
/// only), chaos mode, lorebook triggers, and the read-only Scenario /
/// Description panels.
///
/// [scenarioText] and [descriptionText] arrive already macro-resolved;
/// [hideScenario] is computed by the caller (SidebarBody) — chat_page hides
/// Scenario when an evolved scenario exists. [character] is the active 1:1
/// card the LorebookSection needs (unused in group mode).
class StoryToolsGroup extends StatelessWidget {
  final ChatService chatService;
  final bool isGroup;
  final bool isLite;
  final bool initiallyExpanded;
  final ValueChanged<bool>? onExpansionChanged;
  final VoidCallback onSpinRequested;
  final String scenarioText;
  final String descriptionText;
  final bool hideScenario;
  final CharacterCard? character;

  const StoryToolsGroup({
    super.key,
    required this.chatService,
    required this.isGroup,
    required this.isLite,
    required this.initiallyExpanded,
    this.onExpansionChanged,
    required this.onSpinRequested,
    required this.scenarioText,
    required this.descriptionText,
    required this.hideScenario,
    this.character,
  });

  @override
  Widget build(BuildContext context) {
    return PorchAccordion(
      id: 'story_tools',
      emoji: '🎲',
      title: 'Story Tools',
      accent: AppColors.porchHoneyOf(context),
      initiallyExpanded: initiallyExpanded,
      onExpansionChanged: onExpansionChanged,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuthorNoteSection(chatService: chatService),
          const SizedBox(height: 12),
          if (!isGroup && !isLite) ...[
            ObjectivePanel(chatService: chatService),
            const SizedBox(height: 12),
          ],
          Consumer<ChatService>(
            builder: (context, chat, _) =>
                ChaosPanel(chat: chat, onSpinRequested: onSpinRequested),
          ),
          const SizedBox(height: 12),
          if (isGroup)
            GroupLorebookSection(chatService: chatService)
          else if (character != null)
            LorebookSection(character: character!),
          if (scenarioText.isNotEmpty && !hideScenario) ...[
            const SizedBox(height: 12),
            StaticTextPanel(title: 'Scenario', content: scenarioText),
          ],
          if (descriptionText.isNotEmpty) ...[
            const SizedBox(height: 12),
            StaticTextPanel(title: 'Description', content: descriptionText),
          ],
        ],
      ),
    );
  }
}
