// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart';

import 'package:front_porch_ai/services/chat/chat.dart';
import 'package:front_porch_ai/ui/pages/worlds/climate_editor_widgets.dart';

class ClimateSeasonStrip extends StatelessWidget {
  const ClimateSeasonStrip({
    super.key,
    required this.ids,
    required this.band,
    required this.anchorCtls,
    required this.labelCtls,
    required this.startMonth,
    required this.startDay,
    required this.unit,
    required this.needsAnchor,
    required this.clash,
    required this.onBand,
    required this.onAnchorChanged,
    required this.onLabelChanged,
    required this.onStart,
    required this.onRemove,
    required this.onAdd,
  });

  final List<String> ids;
  final Map<String, TempBand> band;
  final Map<String, TextEditingController> anchorCtls;
  final Map<String, TextEditingController> labelCtls;
  final Map<String, int> startMonth;
  final Map<String, int> startDay;
  final String unit;
  final bool Function(String id) needsAnchor;
  final bool Function(String id) clash;
  final void Function(String id, TempBand band) onBand;
  final VoidCallback onAnchorChanged;
  final VoidCallback onLabelChanged;
  final void Function(String id, int month, int day) onStart;
  final void Function(String id) onRemove;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final season in ids)
          SizedBox(
            width: 200,
            child: SeasonCard(
              season: season,
              band: band[season]!,
              anchorController: anchorCtls[season]!,
              needsAnchor: needsAnchor(season),
              unit: unit,
              onBand: (b) => onBand(season, b),
              onAnchorChanged: onAnchorChanged,
              labelController: labelCtls[season]!,
              onLabelChanged: onLabelChanged,
              startMonth: startMonth[season]!,
              startDay: startDay[season]!,
              clash: clash(season),
              onStart: (m, d) => onStart(season, m, d),
              onRemove: ids.length > kMinSeasons
                  ? () => onRemove(season)
                  : null,
            ),
          ),
        if (ids.length < kMaxSeasons)
          SizedBox(
            width: 120,
            height: 88,
            child: OutlinedButton(
              onPressed: onAdd,
              child: const Text('+ Season'),
            ),
          ),
      ],
    );
  }
}
