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

/// Lays out the two realism chip lists built by `_buildRealismIndicator`
/// (`message_bubble.realism.dart`): the classic-chips-only single row, or
/// the two-row layout (classic row above a needs-chips `Wrap`), followed
/// by the Manual Reprocess / Revert-reprocess pills. The local `_spaced`
/// helper (the RangeError fix for an empty chip list) and its only call
/// site move here together, unchanged.
extension _BubbleRealismLayout on _MessageBubbleState {
  Widget _realismChipLayout(
    List<Widget> chips,
    List<Widget> needsChipList,
  ) {
    // Safely build a list of children with spacers between them.
    // The old expand(...).toList()..removeLast() pattern would throw
    // "RangeError (length): Invalid value: Valid value range is empty: -1"
    // whenever the source list was empty (chips or needsChipList after 0-delta filtering).
    // This happened for messages whose realism metadata only contained needs_deltas
    // (or a needs_deltas map whose deltas all filtered to 0) with no bond/trust/verif/etc.,
    // or for older messages in history when the indicator was re-built after new realism
    // metadata started being attached. The crash surfaced in the chat ListView item builder.
    List<Widget> _spaced(List<Widget> items, double gap) {
      if (items.isEmpty) return const <Widget>[];
      final out = <Widget>[];
      for (int i = 0; i < items.length; i++) {
        out.add(items[i]);
        if (i < items.length - 1) out.add(SizedBox(width: gap));
      }
      return out;
    }

    final classicSpaced = _spaced(chips, 10);
    final classicRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: classicSpaced,
    );
    final classicBox = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.resolve(
          context,
          AppColors.resolve(
            context,
            Colors.black12,
            Colors.black.withValues(alpha: 0.06),
          ),
          Colors.black.withValues(alpha: 0.06),
        ),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white10),
      ),
      child: classicRow,
    );

    // Built once so BOTH layouts below can render them — see _reprocessPills.
    final pills = _reprocessPills();

    if (needsChipList.isEmpty) {
      // Nothing classic and no needs chips → nothing to show (guard should have caught most,
      // but be defensive after 0-delta filtering in needs).
      if (classicSpaced.isEmpty && pills.isEmpty) return const SizedBox.shrink();
      if (pills.isEmpty) {
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: classicBox,
        );
      }
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (classicSpaced.isNotEmpty) classicBox,
            ...pills,
          ],
        ),
      );
    }

    // Two-row layout: Classic Realism chips on top, Needs chips on a dedicated second row below.
    // This prevents the single-row clutter the user was worried about.
    // Only render the classic container if we actually have classic chips (bond/trust/verif/etc.);
    // otherwise just show the needs row without an empty bordered box on top.
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Classic Realism (Bond, Trust, Lust, Mood, Time, Chance Time, Director status, etc.)
          if (classicSpaced.isNotEmpty) classicBox,

          if (classicSpaced.isNotEmpty) const SizedBox(height: 4),

          // Row 2: Needs Simulation deltas (Energy, Hunger, Bladder, etc.)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white10),
            ),
            // Wrap, not Row: all seven needs can carry a delta at once (a
            // manual reprocess routinely returns a full set) and seven chips
            // overflow the bubble — Windows hit it first, by 0.668px.
            child: Wrap(spacing: 8, runSpacing: 4, children: needsChipList),
          ),

          // Row 3: Manual Reprocess / Revert buttons (only for last non-user msg with usable needs state)
          ...pills,
        ],
      ),
    );
  }

  /// The Manual Reprocess / Revert-reprocess pills, or an empty list when this
  /// message cannot be reprocessed.
  ///
  /// They used to be nested inside the needs-chip branch of the layout above,
  /// so they only existed on a turn that produced at least one NON-ZERO need
  /// delta. A reprocess whose correction nets to zero writes an empty
  /// `needs_deltas` while keeping `needs_deltas_pre_reprocess` — which drew no
  /// needs chip and therefore stranded Revert, the one control whose whole job
  /// is undoing what the user just did. The web twin (ChipsRow.tsx) already
  /// renders them as a sibling of both chip rows; this matches it.
  List<Widget> _reprocessPills() {
    final chat = widget.chatService;
    if (chat == null ||
        index != chat.messages.length - 1 ||
        message.isUser ||
        chat.isGenerating) {
      return const <Widget>[];
    }
    final meta = message.activeMetadata;
    // Only show the reprocess affordance if this msg carries realism_state['needs']
    final rs = meta?['realism_state'];
    final canReprocess = rs is Map && rs['needs'] != null;
    // Revert is offered only when a pre-reprocess stash exists on this (last) msg
    final canRevert = meta != null && meta['needs_deltas_pre_reprocess'] is Map;
    if (!canReprocess && !canRevert) return const <Widget>[];

    return [
      if (canReprocess) ...[
        const SizedBox(height: 6),
        Tooltip(
          message: 'Reprocess Needs with critique',
          preferBelow: false,
          textStyle: const TextStyle(fontSize: 12, color: Colors.white),
          decoration: BoxDecoration(
            color: const Color(0xFF1F2937),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white12),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => showReprocessNeedsDialog(context, index),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.resolve(
                    context,
                    AppColors.optionalAccent.withValues(alpha: 0.15),
                    AppColors.optionalAccent.withValues(alpha: 0.15),
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.resolve(
                      context,
                      AppColors.optionalAccent.withValues(alpha: 0.4),
                      AppColors.optionalAccent.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.rate_review,
                      size: 12,
                      color: AppColors.optionalAccent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Manual Reprocess',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.optionalAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
      if (canRevert) ...[
        const SizedBox(height: 4),
        Tooltip(
          message:
              'Restore previous Needs deltas and live state before the last reprocess',
          preferBelow: false,
          textStyle: const TextStyle(fontSize: 12, color: Colors.white),
          decoration: BoxDecoration(
            color: const Color(0xFF1F2937),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white12),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                try {
                  await chat.revertNeedsReprocess(index);
                } catch (e) {
                  debugPrint('[Realism:Needs] revert error: $e');
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.resolve(
                    context,
                    AppColors.optionalAccent.withValues(alpha: 0.12),
                    AppColors.optionalAccent.withValues(alpha: 0.12),
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.resolve(
                      context,
                      AppColors.optionalAccent.withValues(alpha: 0.35),
                      AppColors.optionalAccent.withValues(alpha: 0.35),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.undo,
                      size: 11,
                      color: AppColors.optionalAccent,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Revert reprocess',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: AppColors.optionalAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ];
  }
}
