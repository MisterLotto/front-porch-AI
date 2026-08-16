// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

part of 'general_tab.dart';

extension _GroupGeneralCards on GroupGeneralTabState {
  Widget _buildTurnStrategyCard(
    TurnOrder order,
    String label,
    String description,
    IconData icon,
  ) {
    final isSelected = _turnOrder == order;
    final amber = AppColors.porchAmberOf(context);
    final borderColor = isSelected ? amber : AppColors.borderOf(context);
    final bgColor = isSelected
        ? amber.withValues(alpha: 0.12)
        : AppColors.surfaceContainerOf(context);
    final iconColor = isSelected ? amber : AppColors.iconSecondary(context);
    final textColor = isSelected
        ? AppColors.textPrimary(context)
        : AppColors.textSecondary(context);

    return GestureDetector(
      onTap: () => _setTurnOrder(order),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: iconColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textTertiary(context),
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Director Mode defaults section (verbatim from the old inline build).
  List<Widget> _directorModeSection() {
    return [
      GroupSectionHeader(
        'Director Mode Defaults',
        Icons.movie_creation_outlined,
        AppColors.porchAmberOf(context),
      ),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerOf(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderOf(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.visibility,
                  size: 18,
                  color: AppColors.iconSecondary(context),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Start this group in Director Mode',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                ),
                Switch(
                  value: _directorModeDefault,
                  activeTrackColor: AppColors.porchAmberOf(context),
                  onChanged: _setDirectorModeDefault,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Text(
                'When enabled, entering the group begins in observer/director mode. You steer via the input box while characters respond autonomously. The live toggle is also available in the group sidebar.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary(context),
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.borderOf(context)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline,
              size: 14,
              color: AppColors.iconSecondary(context),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'These settings are stored with the group definition. Saving here updates the live session immediately. The values are persisted to the database automatically on membership changes (add/remove character) and on session checkpoints.',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textTertiary(context),
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }
}
