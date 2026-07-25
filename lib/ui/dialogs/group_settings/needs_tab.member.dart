// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

part of 'needs_tab.dart';

extension _GroupNeedsMemberCard on _GroupNeedsTabState {
  /// One member's needs card (verbatim from the old inline map closure).
  Widget _buildMemberNeedsCard(MapEntry<int, CharacterCard> entry) {
                final index = entry.key;
                final char = entry.value;
                final id = _getCharId(char);
                final baselines = _needsBaselines[id] ?? {};

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar + name + reset
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: groupCharAccentColor(index),
                            backgroundImage: char.imagePath != null
                                ? FileImage(File(char.imagePath!))
                                : null,
                            child: char.imagePath == null
                                ? Text(
                                    char.name.isNotEmpty
                                        ? char.name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              char.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton(
                            onPressed: () => _resetCharacterNeeds(char),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              minimumSize: const Size(0, 32),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Reset',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.tealAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // 7 baseline sliders, each with its own per-turn decay.
                      _needsSlider(
                        'Hunger',
                        baselines[_kHunger] ?? 80,
                        (v) => _updateNeedsBaseline(id, _kHunger, v),
                        decayValue: _decayRates[id]?[_kHunger] ?? 4,
                        onDecayChanged: (v) =>
                            _updateMemberDecay(id, _kHunger, v),
                        onDecayChangeEnd: (v) => widget.chatService
                            .setGroupNeedsDecayRate(_kHunger, v, memberId: id),
                      ),
                      _needsSlider(
                        'Bladder',
                        baselines[_kBladder] ?? 80,
                        (v) => _updateNeedsBaseline(id, _kBladder, v),
                        decayValue: _decayRates[id]?[_kBladder] ?? 6,
                        onDecayChanged: (v) =>
                            _updateMemberDecay(id, _kBladder, v),
                        onDecayChangeEnd: (v) => widget.chatService
                            .setGroupNeedsDecayRate(_kBladder, v, memberId: id),
                      ),
                      _needsSlider(
                        'Energy',
                        baselines[_kEnergy] ?? 80,
                        (v) => _updateNeedsBaseline(id, _kEnergy, v),
                        decayValue: _decayRates[id]?[_kEnergy] ?? 3,
                        onDecayChanged: (v) =>
                            _updateMemberDecay(id, _kEnergy, v),
                        onDecayChangeEnd: (v) => widget.chatService
                            .setGroupNeedsDecayRate(_kEnergy, v, memberId: id),
                      ),
                      _needsSlider(
                        'Social',
                        baselines[_kSocial] ?? 80,
                        (v) => _updateNeedsBaseline(id, _kSocial, v),
                        decayValue: _decayRates[id]?[_kSocial] ?? 2,
                        onDecayChanged: (v) =>
                            _updateMemberDecay(id, _kSocial, v),
                        onDecayChangeEnd: (v) => widget.chatService
                            .setGroupNeedsDecayRate(_kSocial, v, memberId: id),
                      ),
                      _needsSlider(
                        'Fun',
                        baselines[_kFun] ?? 80,
                        (v) => _updateNeedsBaseline(id, _kFun, v),
                        decayValue: _decayRates[id]?[_kFun] ?? 2,
                        onDecayChanged: (v) => _updateMemberDecay(id, _kFun, v),
                        onDecayChangeEnd: (v) => widget.chatService
                            .setGroupNeedsDecayRate(_kFun, v, memberId: id),
                      ),
                      _needsSlider(
                        'Hygiene',
                        baselines[_kHygiene] ?? 80,
                        (v) => _updateNeedsBaseline(id, _kHygiene, v),
                        decayValue: _decayRates[id]?[_kHygiene] ?? 1,
                        onDecayChanged: (v) =>
                            _updateMemberDecay(id, _kHygiene, v),
                        onDecayChangeEnd: (v) => widget.chatService
                            .setGroupNeedsDecayRate(_kHygiene, v, memberId: id),
                      ),
                      _needsSlider(
                        'Comfort',
                        baselines[_kComfort] ?? 80,
                        (v) => _updateNeedsBaseline(id, _kComfort, v),
                        decayValue: _decayRates[id]?[_kComfort] ?? 2,
                        onDecayChanged: (v) =>
                            _updateMemberDecay(id, _kComfort, v),
                        onDecayChangeEnd: (v) => widget.chatService
                            .setGroupNeedsDecayRate(_kComfort, v, memberId: id),
                      ),

                      const SizedBox(height: 8),
                      Divider(color: Colors.white12, height: 1),
                      const SizedBox(height: 8),

                      // Enjoys low hygiene
                      Row(
                        children: [
                          const Icon(
                            Icons.water_drop_outlined,
                            size: 14,
                            color: Colors.tealAccent,
                          ),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              'Enjoys low hygiene',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 20,
                            width: 20,
                            child: Checkbox(
                              value: _enjoysLowHygiene[id] ?? false,
                              onChanged: (v) {
                                if (v != null) {
                                  _updateMemberEnjoysLowHygiene(char, v);
                                }
                              },
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
  }

  Widget _needsSlider(
    String label,
    int value,
    ValueChanged<int> onChanged, {
    int? decayValue,
    ValueChanged<int>? onDecayChanged,
    ValueChanged<int>? onDecayChangeEnd,
  }) {
    final baseline = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              '$value',
              style: const TextStyle(fontSize: 10, color: Colors.white54),
            ),
          ],
        ),
        const SizedBox(height: 2),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.tealAccent,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
            thumbColor: Colors.tealAccent,
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
          ),
          child: Slider(
            value: value.toDouble(),
            min: 0,
            max: 100,
            divisions: 100,
            onChanged: (d) => onChanged(d.round()),
          ),
        ),
      ],
    );

    // No decay wiring → plain baseline slider (keeps the method reusable).
    if (decayValue == null || onDecayChanged == null) return baseline;

    String decayLabel;
    if (decayValue == 0) {
      decayLabel = 'Static (0)';
    } else if (decayValue <= 2) {
      decayLabel = 'Very Slow ($decayValue)';
    } else if (decayValue <= 4) {
      decayLabel = 'Slow ($decayValue)';
    } else if (decayValue <= 7) {
      decayLabel = 'Normal ($decayValue)';
    } else if (decayValue <= 12) {
      decayLabel = 'Fast ($decayValue)';
    } else {
      decayLabel = 'Very Fast ($decayValue)';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        baseline,
        Padding(
          padding: const EdgeInsets.only(left: 10, right: 4, bottom: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Decay / Turn',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.white.withValues(alpha: 0.45),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    decayLabel,
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Colors.tealAccent.withValues(alpha: 0.45),
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                  thumbColor: Colors.tealAccent.withValues(alpha: 0.6),
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
                ),
                child: Slider(
                  value: decayValue.toDouble(),
                  min: 0,
                  max: 20,
                  divisions: 20,
                  // Smooth local update while dragging; the (expensive) persist
                  // to the member PNG + DB row happens once, on release.
                  onChanged: (d) => onDecayChanged(d.round()),
                  onChangeEnd: onDecayChangeEnd == null
                      ? null
                      : (d) => onDecayChangeEnd(d.round()),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
