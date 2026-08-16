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

part of 'image_crop_dialog.dart';

/// Chrome for [ImageCropDialog] (a `part`, settings_page convention): the
/// aspect-preset chips, the Face circle-guide chip, and the fill swatches.
/// The aspect presets. Free is null; the circle guide rides 1:1.
const _presets = <(String, double?)>[
  ('Free', null),
  ('1:1', 1.0),
  ('2:3', 2 / 3),
  ('16:9', 16 / 9),
];

extension _ImageCropChrome on _ImageCropDialogState {
  Widget _buildPresetRow(BuildContext context) {
    final amber = AppColors.porchAmberOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final (label, aspect) in _presets)
            ChoiceChip(
              label: Text(label),
              selected: !_circle && _aspect == aspect,
              selectedColor: amber.withValues(alpha: 0.25),
              labelStyle: TextStyle(
                fontSize: 12,
                color: (!_circle && _aspect == aspect)
                    ? AppColors.textPrimary(context)
                    : AppColors.textSecondary(context),
              ),
              visualDensity: VisualDensity.compact,
              onSelected: (_) => _selectPreset(aspect),
            ),
          ChoiceChip(
            avatar: Icon(
              Icons.circle_outlined,
              size: 14,
              color: _circle ? amber : AppColors.iconSecondary(context),
            ),
            label: const Text('Face'),
            selected: _circle,
            selectedColor: amber.withValues(alpha: 0.25),
            labelStyle: TextStyle(
              fontSize: 12,
              color: _circle
                  ? AppColors.textPrimary(context)
                  : AppColors.textSecondary(context),
            ),
            visualDensity: VisualDensity.compact,
            tooltip: 'Square crop with a circle guide — avatars render round '
                'in chat',
            onSelected: (_) => _selectPreset(1.0, circle: true),
          ),
          const SizedBox(width: 8),
          for (final fill in CropFill.values) _fillSwatch(context, fill),
        ],
      ),
    );
  }

  Widget _fillSwatch(BuildContext context, CropFill fill) {
    final selected = _fill == fill;
    return Tooltip(
      message: switch (fill) {
        CropFill.dark => 'Fill past the edges with dark',
        CropFill.white => 'Fill past the edges with white',
        CropFill.transparent => 'Transparent past the edges',
      },
      child: InkWell(
        onTap: () => rebuildState(() => _fill = fill),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: fill == CropFill.transparent
                ? null
                : Color.fromARGB(255, fill.r, fill.g, fill.b),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selected
                  ? AppColors.porchAmberOf(context)
                  : AppColors.borderOf(context),
              width: selected ? 2 : 1,
            ),
          ),
          child: fill == CropFill.transparent
              ? Icon(
                  Icons.grid_on,
                  size: 14,
                  color: AppColors.iconSecondary(context),
                )
              : null,
        ),
      ),
    );
  }
}
