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
// Manual creator: the Review step and the Portrait & Avatars step.
// Extracted verbatim from create_character_page.dart (god-file campaign,
// Tranche A); `part of` the same library, so privates and the mandatory
// step-indicator wizard flow are unchanged.

part of 'create_character_page.dart';

extension _CreateCharacterReviewStep on _CreateCharacterPageState {
  Widget _buildReviewStep() {
    return SingleChildScrollView(
      key: const ValueKey('review'),
      padding: const EdgeInsets.all(32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left column — quick info (the portrait is made in the NEXT step,
          // after the card is safely saved).
          SizedBox(
            width: 280,
            child: Column(
              children: [
                Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: AppColors.cardOf(context),
                    border: Border.all(color: AppColors.borderOf(context)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person,
                        size: 64,
                        color: AppColors.textTertiary(context),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Portrait comes next,\nonce the card is saved',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textTertiary(context),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Name
                Text(
                  _nameController.text.isEmpty
                      ? 'Unnamed'
                      : _nameController.text,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                // Tags
                if (_tags.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: _tags
                        .map(
                          (tag) => Chip(
                            label: Text(
                              tag,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                            backgroundColor: AppColors.surfaceContainerOf(
                              context,
                            ),
                            side: BorderSide.none,
                            visualDensity: VisualDensity.compact,
                          ),
                        )
                        .toList(),
                  ),
                const SizedBox(height: 16),
                // Realism Engine summary
                if (_realismEnabled)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.formMasterAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.formMasterAccent.withValues(
                          alpha: 0.3,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.psychology,
                              size: 14,
                              color: AppColors.formMasterAccent,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Realism Engine',
                              style: TextStyle(
                                color: AppColors.formMasterAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Day $_realismDayCount · ${_realismTimeOfDay.split('_').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ')}',
                          style: TextStyle(
                            color: AppColors.textTertiary(context),
                            fontSize: 11,
                          ),
                        ),
                        if (_realismEmotion.isNotEmpty)
                          Text(
                            'Emotion: $_realismEmotion ($_realismEmotionIntensity)',
                            style: TextStyle(
                              color: AppColors.textTertiary(context),
                              fontSize: 11,
                            ),
                          ),
                        Text(
                          'Bond: $_realismShortTermBond / $_realismLongTermBond · Trust: $_realismTrustLevel',
                          style: TextStyle(
                            color: AppColors.textTertiary(context),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                // Create button — saves the card, then advances into the
                // Portrait & Avatars step (generation is post-save by design).
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _createAndAdvance,
                    icon: const Icon(Icons.check),
                    label: const Text('Create Character'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.formMasterAccent,
                      foregroundColor: AppColors.onChaosAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => rebuildState(() => _currentStep = 0),
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('Back to Edit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary(context),
                      side: BorderSide(color: AppColors.borderOf(context)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 32),

          // Right column — editable fields review
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Review & Edit',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Review your character card. All fields are still editable before saving.',
                  style: TextStyle(
                    color: AppColors.textTertiary(context),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 24),
                _reviewField(
                  'Description',
                  _descriptionController,
                  maxLines: 4,
                ),
                _reviewField(
                  'Personality',
                  _personalityController,
                  maxLines: 3,
                ),
                _reviewField('Scenario', _scenarioController, maxLines: 3),
                _reviewField(
                  'First Message',
                  _firstMessageController,
                  maxLines: 5,
                ),
                if (_exampleDialogueController.text.isNotEmpty)
                  _reviewField(
                    'Example Dialogue',
                    _exampleDialogueController,
                    maxLines: 4,
                  ),
                if (_systemPromptController.text.isNotEmpty)
                  _reviewField(
                    'System Prompt',
                    _systemPromptController,
                    maxLines: 3,
                  ),
                if (_postHistoryController.text.isNotEmpty)
                  _reviewField(
                    'Post-History Instructions',
                    _postHistoryController,
                    maxLines: 3,
                  ),

                // Alt greetings
                ..._altGreetingControllers.asMap().entries.map((entry) {
                  return _reviewField(
                    'Alt Greeting ${entry.key + 1}',
                    entry.value,
                    maxLines: 3,
                  );
                }),

                // Lorebook
                if (_lorebookEntries.isNotEmpty) ...[
                  Divider(color: AppColors.borderOf(context), height: 32),
                  Row(
                    children: [
                      const Icon(
                        Icons.menu_book,
                        color: AppColors.formMasterAccent,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Lorebook Entries',
                        style: TextStyle(
                          color: AppColors.formMasterAccent,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_lorebookEntries.length} entries',
                        style: TextStyle(
                          color: AppColors.textTertiary(context),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._lorebookEntries.map(
                    (entry) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.cardOf(context),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.formMasterAccent.withValues(
                            alpha: 0.2,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.displayName,
                            style: TextStyle(
                              color: AppColors.textPrimary(context),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (entry.key.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Keys: ${entry.key}',
                              style: const TextStyle(
                                color: AppColors.formMasterAccent,
                                fontSize: 11,
                              ),
                            ),
                          ],
                          if (entry.content.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              entry.content,
                              style: TextStyle(
                                color: AppColors.textSecondary(context),
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewField(
    String label,
    TextEditingController controller, {
    int maxLines = 3,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.formMasterAccent,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          AppTextField(
            controller: controller,
            maxLines: maxLines,
            style: TextStyle(
              color: AppColors.textPrimary(context),
              fontSize: 13,
              height: 1.5,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surfaceContainerOf(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.borderOf(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.borderOf(context)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.formMasterAccent),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
        ],
      ),
    );
  }
}
