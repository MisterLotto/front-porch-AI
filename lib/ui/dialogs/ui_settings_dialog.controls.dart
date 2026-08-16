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

part of 'ui_settings_dialog.dart';

/// Ink that stays legible over an arbitrary user-picked swatch color (the
/// color-picker swatches and the current-color chip can be any hue, so no
/// fixed chrome color can guarantee contrast).
Color _swatchInk(Color bg) =>
    ThemeData.estimateBrightnessForColor(bg) == Brightness.dark
    ? Colors.white
    : Colors.black87; // theme-keep: contrast over a user-chosen color

/// Appearance controls (avatar-lock toggle, generic slider) and the Chat
/// Colors row + its "Select Color" picker dialog for [UiSettingsDialog].
/// Extracted verbatim from UiSettingsDialog; direct state access preserves
/// behavior.
extension _UiSettingsControlsSection on _UiSettingsDialogState {
  // ── Appearance controls ──────────────────────────────────────────────────

  Widget _buildAvatarLockedToggle(BuildContext context) {
    final character = _characterNotifier.value!;
    final locked = character.frontPorchExtensions?.avatarLocked ?? false;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lock Avatar Size',
                style: TextStyle(color: AppColors.textSecondary(context)),
              ),
              Text(
                'Avatar won\'t grow past default size when sidebar is wider',
                style: TextStyle(
                  color: AppColors.textTertiary(context),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: locked,
          onChanged: (val) async {
            _updateAvatarLocked(context, val);
          },
          activeTrackColor: AppColors.formMasterAccent,
        ),
      ],
    );
  }

  Widget _buildSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    int? divisions,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(color: AppColors.textSecondary(context)),
            ),
            Text(
              value.toStringAsFixed(2),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context),
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
          activeColor: AppColors.formMasterAccent,
          inactiveColor: AppColors.borderOf(context),
        ),
      ],
    );
  }

  Widget _buildColorRow(
    BuildContext context,
    String label,
    Color color,
    void Function(Color) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.borderOf(context), width: 1),
            ),
            child: IconButton(
              icon: Icon(Icons.color_lens, size: 20, color: _swatchInk(color)),
              onPressed: () => _showColorPicker(context, color, onChanged),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showColorPicker(
    BuildContext context,
    Color initialColor,
    void Function(Color) onChanged,
  ) async {
    // theme-keep: user-pickable swatch palette, not chrome
    const presetColors = [
      Color(0xFF3B82F6),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFFEF4444),
      Color(0xFF8B5CF6),
      Color(0xFFEC4899),
      Color(0xFF14B8A6),
      Color(0xFFF97316),
      Color(0xFF6366F1),
      Color(0xFF06B6D4),
      Color(0xFF10B981),
      Color(0xFF84CC16),
    ];

    Color selectedColor = initialColor;
    void Function(void Function())? setStateCallback;

    final picked = await showDialog<Color>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          setStateCallback = setState;
          return AlertDialog(
            title: const Text('Select Color'),
            content: SizedBox(
              width: 380,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Quick Select',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: presetColors
                          .map(
                            (color) => GestureDetector(
                              onTap: () => Navigator.pop(context, color),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: color == selectedColor
                                        ? AppColors.formMasterAccent
                                        : AppColors.borderOf(context),
                                    width: 2,
                                  ),
                                ),
                                child: color == selectedColor
                                    ? Icon(
                                        Icons.check,
                                        size: 18,
                                        color: _swatchInk(color),
                                      )
                                    : null,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: ColorPicker(
                        color: selectedColor,
                        onColorChanged: (color) {
                          selectedColor = color;
                          setStateCallback?.call(() {});
                        },
                        wheelDiameter: 160,
                        pickersEnabled: const <ColorPickerType, bool>{
                          ColorPickerType.wheel: true,
                        },
                        showColorCode: true,
                        colorCodeHasColor: true,
                        copyPasteBehavior: const ColorPickerCopyPasteBehavior(
                          copyButton: true,
                          pasteButton: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, selectedColor),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.formMasterAccent,
                  foregroundColor: AppColors.onChaosAccent,
                ),
                child: const Text('OK'),
              ),
            ],
          );
        },
      ),
    );
    if (picked != null) {
      onChanged(picked);
    }
  }
}
