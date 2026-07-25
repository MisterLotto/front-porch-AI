// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

part of 'general_tab.dart';

extension _GroupGeneralCards on _GroupGeneralTabState {
  Widget _buildTurnStrategyCard(
    TurnOrder order,
    String label,
    String description,
    IconData icon,
  ) {
    final isSelected = _turnOrder == order;
    final borderColor = isSelected ? Colors.purpleAccent : Colors.white12;
    final bgColor = isSelected
        ? const Color(0xFF1F2937)
        : const Color(0xFF111827);
    final iconColor = isSelected ? Colors.purpleAccent : Colors.white54;
    final textColor = isSelected ? Colors.purpleAccent : Colors.white;

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
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white54,
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
                // ── Director Mode ──────────────────────────────────────────
                GroupSectionHeader(
                  'Director Mode Defaults',
                  Icons.movie_creation_outlined,
                  Colors.amberAccent,
                ),
                const SizedBox(height: 8),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.visibility,
                            size: 18,
                            color: Colors.white54,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Start this group in Director Mode',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Switch(
                            value: _directorModeDefault,
                            activeTrackColor: Colors.amberAccent,
                            onChanged: _setDirectorModeDefault,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Padding(
                        padding: EdgeInsets.only(left: 26),
                        child: Text(
                          'When enabled, entering the group begins in observer/director mode. You steer via the input box while characters respond autonomously. The live toggle is also available in the group sidebar.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white38,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Persistence note
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 14, color: Colors.white38),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'These settings are stored with the group definition. Saving here updates the live session immediately. The values are persisted to the database automatically on membership changes (add/remove character) and on session checkpoints.',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white38,
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
