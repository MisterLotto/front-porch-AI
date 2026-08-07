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

part of 'message_bubble.dart';

/// Parses a message's realism/needs metadata into the chip widgets shown
/// under the bubble (bond / trust / mood / lust / time-skip / time-reversal /
/// Chance Time / Director-verifier chips, plus the per-need delta chips),
/// then hands the two chip lists to `_realismChipLayout`
/// (`message_bubble.realism_layout.dart`) for final layout. Split at the
/// one seam in this 639-line method that needs neither hoisting the
/// `maybeTooltip` closure nor threading a dozen parsed scalars — see the
/// split map's H3.
extension _BubbleRealism on _MessageBubbleState {
  Widget _buildRealismIndicator(Map<String, dynamic> metadata) {
    final bondDelta = metadata['bond_delta'] as int? ?? 0;
    final emotionLabel = metadata['emotion_label'] as String? ?? '';
    final arousalDelta = metadata['arousal_delta'] as int? ?? 0;
    final trustDelta = metadata['trust_delta'] as int? ?? 0;
    final bondReason = metadata['bond_reason'] as String? ?? '';
    final trustReason = metadata['trust_reason'] as String? ?? '';
    final timeSkipTo = metadata['time_skip_to'] as String? ?? '';
    final chanceTimeEvent = metadata['chance_time_event'] as String? ?? '';
    final timeReversal = metadata['time_reversal'] as bool? ?? false;
    final needsDeltas = metadata['needs_deltas'] as Map<String, dynamic>?;

    // Verifier result (attached by realism_verification leaf when feature active for the turn).
    // status: 'accepted' | 'corrected'; passes: reprocess count; reason optional for tooltip.
    final verifData =
        metadata[RealismVerification.kMetaKey] as Map<String, dynamic>?;
    final verifStatus = (verifData?['status'] as String? ?? '').trim();
    final verifPasses = (verifData?['passes'] as num?)?.toInt() ?? 0;
    final verifReason = (verifData?['reason'] as String? ?? '').trim();

    if ((needsDeltas == null || needsDeltas.isEmpty) &&
        bondDelta == 0 &&
        emotionLabel.isEmpty &&
        arousalDelta == 0 &&
        trustDelta == 0 &&
        timeSkipTo.isEmpty &&
        chanceTimeEvent.isEmpty &&
        !timeReversal &&
        verifStatus.isEmpty) {
      return const SizedBox.shrink();
    }

    Widget maybeTooltip(Widget child, String tip) {
      if (tip.isEmpty) return child;
      return Tooltip(
        message: tip,
        preferBelow: false,
        textStyle: const TextStyle(fontSize: 12, color: Colors.white),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2937),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white12),
        ),
        child: child,
      );
    }

    final chips = <Widget>[];

    // ── Needs Simulation Chips (deltas + reasons) — built into a separate list
    // so we can render them on their own row underneath the classic realism chips.
    final List<Widget> needsChipList = [];

    if (needsDeltas != null && needsDeltas.isNotEmpty) {
      needsDeltas.forEach((need, data) {
        final delta = (data is Map) ? (data['delta'] as int? ?? 0) : 0;
        if (delta == 0) {
          return; // only show needs that actually changed this turn (avoids "Bladder 0" clutter; mirrors bond/trust/lust skipping 0s)
        }
        final reason = (data is Map) ? (data['reason'] as String? ?? '') : '';

        IconData icon;
        Color color;
        String label = need[0].toUpperCase() + need.substring(1);

        switch (need) {
          case 'hunger':
            icon = Icons.restaurant;
            color = AppColors.resolve(
              context,
              Colors.orangeAccent,
              const Color(0xFFEA580C),
            );
            break;
          case 'bladder':
            icon = Icons.water_drop;
            color = Colors.lightBlueAccent;
            break;
          case 'energy':
            icon = Icons.bolt;
            color = AppColors.resolve(
              context,
              const Color(0xFFD97706),
              const Color(0xFFB45309),
            );
            break;
          case 'social':
            icon = Icons.people;
            color = Colors.pinkAccent;
            break;
          case 'fun':
            icon = Icons.celebration;
            color = AppColors.resolve(
              context,
              AppColors.resolve(
                context,
                Colors.deepPurpleAccent,
                const Color(0xFF7C3AED),
              ),
              const Color(0xFF7C3AED),
            );
            break;
          case 'hygiene':
            icon = Icons.shower;
            color = Colors.cyanAccent;
            break;
          case 'comfort':
            icon = Icons.chair;
            color = Colors.greenAccent;
            break;
          default:
            icon = Icons.circle;
            color = Colors.grey;
        }

        final chip = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
            Text(
              '$label ${delta > 0 ? '+$delta' : '$delta'}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            if (reason.isNotEmpty) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.info_outline,
                size: 10,
                color: AppColors.textTertiary(context),
              ),
            ],
          ],
        );

        needsChipList.add(maybeTooltip(chip, reason));
      });
    }

    if (bondDelta != 0) {
      final chip = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            bondDelta > 0 ? Icons.favorite : Icons.heart_broken,
            size: 11,
            color: bondDelta > 0 ? Colors.pinkAccent : Colors.redAccent,
          ),
          const SizedBox(width: 4),
          Text(
            'Bond: ${bondDelta > 0 ? '+$bondDelta' : '$bondDelta'}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: bondDelta > 0 ? Colors.pinkAccent : Colors.redAccent,
            ),
          ),
          if (bondReason.isNotEmpty) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.info_outline,
              size: 10,
              color: AppColors.textTertiary(context),
            ),
          ],
        ],
      );
      chips.add(maybeTooltip(chip, bondReason));
    }

    if (emotionLabel.isNotEmpty) {
      // The mood chip was the ONLY chip here with no hover reason — bond,
      // trust, every need, the verifier and Chance Time all carry one, and
      // this alone said "Mood: wistful" with nothing behind it. It could not
      // have one: the emotional eval returns a label and an intensity, never a
      // cause.
      //
      // Standing Mood answers the honest half. Not "why she feels this", which
      // nothing knows, but what she walked in carrying — so a user can tell
      // which part of her mood was them and which part was her day. Absent
      // (and the chip unchanged) when the feature is off or the day was
      // unremarkable.
      final moodReason =
          MoodBaseline.fromJson(metadata['mood_context'])?.summary ?? '';
      chips.add(
        maybeTooltip(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.psychology, size: 11, color: Colors.purpleAccent),
              const SizedBox(width: 4),
              Text(
                'Mood: $emotionLabel',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.purpleAccent,
                ),
              ),
            ],
          ),
          moodReason.isEmpty ? '' : 'Came in $moodReason',
        ),
      );
    }

    if (arousalDelta != 0) {
      chips.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              arousalDelta > 0 ? Icons.local_fire_department : Icons.ac_unit,
              size: 11,
              color: arousalDelta > 0
                  ? Colors.deepOrangeAccent
                  : Colors.lightBlueAccent,
            ),
            const SizedBox(width: 4),
            Text(
              'Lust: ${arousalDelta > 0 ? '+$arousalDelta' : '$arousalDelta'}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: arousalDelta > 0
                    ? Colors.deepOrangeAccent
                    : Colors.lightBlueAccent,
              ),
            ),
          ],
        ),
      );
    }

    if (trustDelta != 0) {
      final chip = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            trustDelta > 0 ? Icons.handshake : Icons.gavel,
            size: 11,
            color: trustDelta > 0
                ? Colors.blueAccent
                : AppColors.resolve(
                    context,
                    Colors.deepPurpleAccent,
                    const Color(0xFF7C3AED),
                  ),
          ),
          const SizedBox(width: 4),
          Text(
            'Trust: ${trustDelta > 0 ? '+$trustDelta' : '$trustDelta'}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: trustDelta > 0
                  ? Colors.blueAccent
                  : AppColors.resolve(
                      context,
                      Colors.deepPurpleAccent,
                      const Color(0xFF7C3AED),
                    ),
            ),
          ),
          if (trustReason.isNotEmpty) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.info_outline,
              size: 10,
              color: AppColors.textTertiary(context),
            ),
          ],
        ],
      );
      chips.add(maybeTooltip(chip, trustReason));
    }

    // Time reversal chip
    if (timeReversal) {
      chips.add(
        Tooltip(
          message: 'Time is going backwards?!',
          preferBelow: false,
          textStyle: const TextStyle(fontSize: 12, color: Colors.white),
          decoration: BoxDecoration(
            color: const Color(0xFF1F2937),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '😵‍💫',
                style: TextStyle(fontSize: 11),
              ), // Dizzy face with spirals
              const SizedBox(width: 4),
              const Text(
                'Time Reversal',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.cyanAccent,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (timeSkipTo.isNotEmpty) {
      chips.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.fast_forward,
              size: 11,
              color: AppColors.porchAmberOf(context),
            ),
            const SizedBox(width: 4),
            Text(
              'Time skip: $timeSkipTo',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.porchAmberOf(context),
              ),
            ),
          ],
        ),
      );
    }

    if (chanceTimeEvent.isNotEmpty) {
      chips.add(
        Tooltip(
          message: chanceTimeEvent,
          preferBelow: false,
          textStyle: const TextStyle(fontSize: 12, color: Colors.white),
          decoration: BoxDecoration(
            color: const Color(0xFF1F2937),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎰', style: TextStyle(fontSize: 11)),
              const SizedBox(width: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  'Chance Time: ${chanceTimeEvent.length > 30 ? chanceTimeEvent.substring(0, 30) + '…' : chanceTimeEvent}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFFD166),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Verifier (Director) status chip — only when present (feature was on for this speaker/turn).
    // Reuses the chip row style + maybeTooltip. Data from ChatMessage metadata set by god/leaf after verify.
    // Status + passes; reason in tooltip if provided. Uses AppColors for new/refactored parts.
    if (verifStatus.isNotEmpty) {
      final isAccepted = verifStatus == 'accepted';
      final label = isAccepted
          ? '✓ Director accepted'
          : '🕵️ Director corrected ($verifPasses reprocess${verifPasses == 1 ? '' : 'es'})';
      final icon = isAccepted ? Icons.verified : Icons.fact_check;
      final chipColor = isAccepted
          ? AppColors.resolve(context, Colors.greenAccent, Colors.green)
          : AppColors.resolve(context, Colors.orangeAccent, Colors.deepOrange);
      final chip = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: chipColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: chipColor,
            ),
          ),
        ],
      );
      chips.add(
        maybeTooltip(
          chip,
          verifReason.isNotEmpty ? verifReason : 'Realism Verification result',
        ),
      );
    }
    // Pockets & Wardrobe receipts. Written by the post-generation pass as
    // plain phrases ("picked up: car keys"), so nothing here parses or
    // re-derives anything — the applier already decided what changed, and this
    // shows exactly that. Absent on every turn nothing moved, which is most.
    final pocketChanges = metadata['pocket_changes'];
    if (pocketChanges is List) {
      for (final raw in pocketChanges) {
        final text = raw is String ? raw.trim() : '';
        if (text.isEmpty) continue;
        chips.add(
          maybeTooltip(
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.checkroom_outlined,
                  size: 11,
                  color: AppColors.porchAmberOf(context),
                ),
                const SizedBox(width: 4),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.porchAmberOf(context),
                  ),
                ),
              ],
            ),
            'Pockets & Wardrobe',
          ),
        );
      }
    }

    return _realismChipLayout(chips, needsChipList);
  }
}
