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

import 'package:front_porch_ai/services/services.dart';
import 'package:front_porch_ai/ui/settings/widgets/widgets.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';

/// **Porch Life** — every "what makes characters feel alive" switch in one
/// place, grouped by what it is, each saying plainly what it needs.
///
/// Why this tab exists (docs/design/feature-independence.md, maintainer
/// 2026-08-07): these toggles used to live nested inside General's "Realism
/// Mode" card, which meant switching the Realism Engine OFF also HID the
/// switches for features that work fine without it — the welcome-back recap
/// and Story Weather among them. A three-agent code audit established which
/// features genuinely depend on the engine and which were merely filed under
/// it; the chips on each row report that finding rather than a guess.
///
/// Scope note: this tab holds the GLOBAL defaults. Chaos Mode and Growth Rings
/// remain per-chat switches in the chat sidebar — the closing card points there
/// instead of pretending otherwise.
///
/// Needs got its global switch here (`needsSimDefault`, 2026-08-07): it had
/// none at all, so the tab had nothing to show for the app's most visible
/// simulation. It AND-gates the card's own setting — default true, so nothing
/// changes until a user deliberately turns it off.
///
/// Dependency truths per the maintainer: Needs and Afterglow genuinely REQUIRE
/// the engine.
///
/// Passage of Time no longer does (2026-08-06). What the clock needs is a model
/// call sizing each exchange, not bond and trust — so it now runs on its own
/// eval when the engine is off, behind the opt-in sub-switch on that row. The
/// deterministic drift underneath remains what it always was: the cushion for
/// one failed call, never a mode and never offered as one. Weather and Dreams
/// follow the CLOCK rather than the engine, which is what this tab already
/// told users they did.
class PorchLifeTab extends StatelessWidget {
  const PorchLifeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = context.watch<StorageService>();
    final chat = context.read<ChatService>();
    final realism = storage.realismSettings;

    // The engine gates everything in "needs Realism" rows; passage of time
    // additionally gates weather and dreams, and weather gates the °F display.
    final engineOn = storage.realismDefault;
    final timeOn = storage.passageOfTimeDefault;
    final weatherOn = storage.weatherEnabled;
    final journalOn = storage.journalEnabled;
    // Objectives depend on nothing but their own eval cost (maintainer,
    // 2026-08-07), and Ambitions hang off them: finishing a quest is the only
    // thing that moves ambition progress.
    final objectivesOn = storage.objectivesEnabled;

    // Weather and dreams gate on the Passage of Time FLAG, deliberately not on
    // whether the clock is currently moving (ChatService._clockRunning). An
    // earlier draft used the latter, on the theory that it was more honest —
    // it is not, it is the old bug wearing a new hat. With the engine off and
    // the standalone opt-in off, gating on it greys out Story Weather again,
    // which is precisely the dead-switch problem this tab was built to end.
    // This tab sets DEFAULTS: a user must be able to record what they want now
    // and have it apply the moment the clock starts moving. The one fact that
    // subtlety depends on — "left off, the clock simply holds still" — is
    // stated on the row that owns it, one row above.

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Everything that makes a character feel like they live somewhere. '
          'Each switch says plainly what it needs — many need nothing at all.',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary(context),
          ),
        ),
        const SizedBox(height: 16),

        FeatureGroupCard(
          title: 'The Engine',
          subtitle: 'feelings about what you do',
          rows: [
            FeatureRow(
              icon: Icons.theater_comedy,
              label: 'Realism Engine',
              need: FeatureNeed.core,
              blurb:
                  'Bond and trust, moods that carry between turns, physical '
                  'state — how the character feels about what you just did. '
                  'Needs, the story clock and desire all read from it; the '
                  'rest of Porch Life runs with or without it, and every row '
                  'says which it is.',
              value: engineOn,
              onChanged: (v) {
                storage.setRealismDefault(v);
                chat.setRealismEnabled(v);
              },
            ),
            FeatureRow(
              icon: Icons.favorite_outline,
              label: 'Needs',
              need: FeatureNeed.needs,
              dependsOn: 'the Realism Engine',
              satisfied: engineOn,
              blurb:
                  'Hunger, energy, comfort and the rest, Sims-style — they '
                  'drift through a scene and colour how the character feels. '
                  'The engine is what turns a need into a mood, so needs run '
                  'with it or not at all. Individual chats can still switch '
                  'them off in the sidebar.',
              value: storage.needsSimDefault,
              onChanged: (v) {
                storage.realismSettings.setNeedsSimDefault(v);
                chat.setNeedsSimEnabled(v);
              },
            ),
            FeatureRow(
              icon: Icons.local_fire_department,
              label: 'Afterglow',
              need: FeatureNeed.needs,
              dependsOn: 'the Realism Engine',
              satisfied: engineOn,
              blurb:
                  'Desire builds through a scene and settles afterwards '
                  'instead of resetting — so intimacy keeps a believable '
                  'rhythm and a character is not instantly ready to go again. '
                  'The engine is what scores desire, so this cannot run '
                  'without it. (18+ themes only.)',
              value: storage.nsfwCooldownDefault,
              onChanged: (v) {
                storage.setNsfwCooldownDefault(v);
                chat.setNsfwCooldownEnabled(v);
              },
            ),
          ],
        ),

        FeatureGroupCard(
          title: 'Time & World',
          subtitle: "the story's clock and sky",
          rows: [
            FeatureRow(
              icon: Icons.schedule,
              label: 'Passage of Time',
              need: FeatureNeed.alone,
              blurb:
                  'The story keeps its own clock — dawn to morning to evening '
                  'to night, day after day. The AI judges how long each '
                  'exchange actually took, so a shared meal moves the clock '
                  'further than a passing hello.',
              value: timeOn,
              onChanged: (v) {
                storage.setPassageOfTimeDefault(v);
                chat.setPassageOfTimeEnabled(v);
              },
              // Shown only with the engine off. With it on, the clock already
              // rides the engine's own reading of the scene and costs nothing
              // extra, so offering a switch there would be a choice about
              // nothing.
              child: engineOn
                  ? null
                  : _StandaloneClockSwitch(
                      value: realism.standaloneClockEnabled,
                      onChanged: storage.setStandaloneClockEnabled,
                    ),
            ),
            FeatureRow(
              icon: Icons.cloud_outlined,
              label: 'Story Weather',
              need: FeatureNeed.needs,
              dependsOn: 'Passage of Time',
              satisfied: timeOn,
              blurb:
                  'Weather rolls through the story\'s days and is felt in mood '
                  'and comfort. Characters can see fronts coming ("looks like '
                  'rain tomorrow"). It costs no extra AI call — the sky is '
                  'worked out from the date — but it needs days to pass.',
              value: weatherOn,
              onChanged: storage.setWeatherEnabled,
            ),
            FeatureRow(
              icon: Icons.thermostat,
              label: 'Temperatures in °F',
              need: FeatureNeed.needs,
              dependsOn: 'Story Weather',
              satisfied: weatherOn,
              blurb:
                  'Display only — characters always experience weather in '
                  'words ("coat-and-gloves cold"), never numbers.',
              value: storage.weatherFahrenheit,
              onChanged: storage.setWeatherFahrenheit,
            ),
          ],
        ),

        FeatureGroupCard(
          title: 'Memory & Heart',
          subtitle: 'what they keep and carry',
          rows: [
            FeatureRow(
              icon: Icons.menu_book_outlined,
              label: 'The Journal',
              need: FeatureNeed.alone,
              blurb:
                  'Memory cards and the "where we are" recap, kept per chat and '
                  'never shared between chats. With the Realism Engine on, '
                  'cards also carry the feeling of the moment; without it they '
                  'are simply remembered.',
              value: journalOn,
              onChanged: storage.setJournalEnabled,
            ),
            FeatureRow(
              icon: Icons.nightlight_outlined,
              label: 'Dreams',
              need: FeatureNeed.needs,
              dependsOn: 'the Journal and Passage of Time',
              satisfied: journalOn && timeOn,
              blurb:
                  'When a story night passes, the character dreams — a short, '
                  'hazy scene woven from their memories, mood and the weather.',
              value: storage.dreamsEnabled,
              onChanged: storage.setDreamsEnabled,
            ),
            FeatureRow(
              icon: Icons.handshake_outlined,
              label: 'Promises',
              need: FeatureNeed.needs,
              dependsOn: 'the Journal',
              satisfied: journalOn,
              blurb:
                  'Commitments either of you make are remembered, and kept or '
                  'broken ones come back later. Uses one extra AI request per '
                  'reply to spot them, so it is slower and costs more on a paid '
                  'API. You can settle one yourself in the Journal\'s Promises '
                  'tab.',
              value: realism.promiseLedgerEnabled,
              onChanged: realism.setPromiseLedgerEnabled,
            ),
            FeatureRow(
              icon: Icons.track_changes,
              label: 'Objectives',
              need: FeatureNeed.alone,
              blurb:
                  'Short-lived quests a character works toward — set your own, '
                  'or let them decide what they want. Needs nothing else to '
                  'run, but it does check in with the AI to see whether a task '
                  'got done: every turn while the Realism Engine is on, and '
                  'every few messages while it is off. Switching this off is '
                  'the way to stop that cost — your quests are kept either way.',
              value: objectivesOn,
              onChanged: (v) {
                storage.setObjectivesEnabled(v);
                chat.setObjectivesEnabled(v);
              },
            ),
            FeatureRow(
              icon: Icons.flag_outlined,
              label: 'Ambitions',
              need: FeatureNeed.needs,
              dependsOn: 'Objectives',
              satisfied: objectivesOn,
              blurb:
                  'Long-term goals written on the character\'s card colour how '
                  'they steer a scene, and finishing an objective moves them a '
                  'little closer. Costs nothing extra — the goals are already '
                  'on the card — but finishing a quest is the only thing that '
                  'moves them, so they need Objectives running.',
              value: realism.ambitionsEnabled,
              onChanged: realism.setAmbitionsEnabled,
            ),
          ],
        ),

        FeatureGroupCard(
          title: 'Presence',
          subtitle: 'noticing you, nothing more',
          rows: [
            FeatureRow(
              icon: Icons.history,
              label: 'Welcome-back recap',
              need: FeatureNeed.alone,
              blurb:
                  'After you have been away a while, opening a chat shows a '
                  'small "where we left off" banner. Uses the time of your last '
                  'message, already saved with your chat. Nothing new is '
                  'collected and nothing leaves your device.',
              value: storage.absenceBannerEnabled,
              onChanged: storage.setAbsenceBannerEnabled,
            ),
            FeatureRow(
              icon: Icons.waving_hand_outlined,
              label: 'Character notices your absence',
              need: FeatureNeed.alone,
              blurb:
                  'The character briefly acknowledges a long gap ("it\'s been a '
                  'few days") — once, in coarse words, never guessing what you '
                  'were doing. Same local-only timestamp as the recap banner.',
              value: storage.absenceAckEnabled,
              onChanged: storage.setAbsenceAckEnabled,
              child: _AwayThreshold(storage: storage),
            ),
          ],
        ),

        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerOf(context),
            border: Border(
              left: BorderSide(
                color: AppColors.porchAmberOf(context),
                width: 3,
              ),
            ),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(10),
              bottomRight: Radius.circular(10),
            ),
          ),
          child: Text(
            'Chaos Mode and Growth Rings are set per chat rather than globally '
            '— open a chat and use the sidebar to switch them for that story. '
            'Needs can be switched off per chat there too.',
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary(context),
            ),
          ),
        ),
      ],
    );
  }
}

/// The opt-in that keeps the clock running with the Realism Engine off.
///
/// It exists as its own switch, rather than reading the Passage of Time row
/// above, because that row already defaults ON — for years it meant nothing
/// while the engine was off, so nobody chose it in a world where it cost a
/// model call. Treating it as consent would hand every engine-off user a new
/// per-turn call without asking. Hence a separate, deliberate yes, and copy
/// that states the cost in the same breath as the benefit.
class _StandaloneClockSwitch extends StatelessWidget {
  const _StandaloneClockSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Keep the clock running without the engine',
                style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'The engine normally judges how long each exchange took as '
                'part of work it is already doing. With it off, the clock '
                'needs one short AI call of its own each turn — so this costs '
                'a little speed. Left off, the clock simply holds still.',
                style: TextStyle(
                  color: AppColors.textTertiary(context),
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

/// The "away for at least" dropdown that rides the absence-acknowledgement
/// row. Values are clamped to a known item so a hand-edited preference cannot
/// assert the dropdown (carried over verbatim from the old General tab).
class _AwayThreshold extends StatelessWidget {
  const _AwayThreshold({required this.storage});

  final StorageService storage;

  @override
  Widget build(BuildContext context) {
    const known = [12, 24, 72, 168];
    return Row(
      children: [
        Text(
          'Away for at least',
          style: TextStyle(
            color: AppColors.textSecondary(context),
            fontSize: 12,
          ),
        ),
        const Spacer(),
        DropdownButton<int>(
          value: known.contains(storage.absenceThresholdHours)
              ? storage.absenceThresholdHours
              : 24,
          dropdownColor: AppColors.cardOf(context),
          style: TextStyle(
            color: AppColors.textPrimary(context),
            fontSize: 12,
          ),
          items: const [
            DropdownMenuItem(value: 12, child: Text('12 hours')),
            DropdownMenuItem(value: 24, child: Text('a day')),
            DropdownMenuItem(value: 72, child: Text('3 days')),
            DropdownMenuItem(value: 168, child: Text('a week')),
          ],
          onChanged: (v) {
            if (v != null) storage.setAbsenceThresholdHours(v);
          },
        ),
      ],
    );
  }
}
