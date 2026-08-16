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
//
// Manual creator: the Portrait & Avatars step (the final wizard step, entered
// holding the freshly saved card).
// Extracted verbatim from create_character_page.dart (god-file campaign,
// Tranche A); `part of` the same library.

part of 'create_character_page.dart';

extension _CreateCharacterPortraitStep on _CreateCharacterPageState {
  // ═══════════════════════════════════════════════════════════════
  //  STEP 6: PORTRAIT & AVATARS (post-save, the shared panel)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildPortraitAvatarsStep() {
    final card = _savedCard;
    if (card == null) return const SizedBox.shrink(); // unreachable guard
    return Center(
      key: const ValueKey('portrait-avatars'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Portrait & Avatars',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 10),
              // The saved chip — nothing below can lose the writing.
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.logReady.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppColors.logReady.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    '✓ ${card.name} is saved — everything below is optional '
                    'and can\'t lose your writing',
                    style: const TextStyle(
                      color: AppColors.logReady,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              AvatarGenerationPanel(
                key: ValueKey(card.dbId),
                card: card,
                ensureCardSaved: () async => card,
                initialPrompt: _portraitPromptSeed(card.name),
                onBusyChanged: (busy) {
                  if (mounted) rebuildState(() => _panelBusy = busy);
                },
              ),
              const SizedBox(height: 24),
              Center(
                child: SizedBox(
                  width: 280,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _panelBusy ? null : _finishAndClose,
                    icon: const Icon(Icons.check, size: 20),
                    label: const Text('Done', style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.porchAmberOf(context),
                      foregroundColor: AppColors.onChaosAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Portrait-prompt seed from the wizard's own fields: the description (the
  /// manual creator's appearance lives there), macros resolved to the name.
  String _portraitPromptSeed(String name) {
    var seed = _descriptionController.text
        .replaceAll('{{char}}', name)
        .replaceAll('{{user}}', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (seed.length > 400) seed = seed.substring(0, 400);
    if (seed.isEmpty) seed = 'character portrait of $name';
    return seed;
  }
}
