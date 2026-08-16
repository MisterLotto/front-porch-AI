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

import 'package:front_porch_ai/services/chat/chat.dart';
import 'package:front_porch_ai/services/services.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';

/// The Journal's "Promises" tab (maintainer request 2026-08-04: promise cards
/// were buried among the memory cards). One row per commitment — open first —
/// with manual "Kept / Broken" resolution for the ones the post-turn eval
/// missed. Resolution routes through ChatService.resolvePromiseManually →
/// the SAME applier as automatic detection, trust/bond effects included.
class JournalPromisesTab extends StatefulWidget {
  final ChatService chat;
  final String ownerId;
  final String ownerName;

  const JournalPromisesTab({
    super.key,
    required this.chat,
    required this.ownerId,
    required this.ownerName,
  });

  @override
  State<JournalPromisesTab> createState() => _JournalPromisesTabState();
}

class _PromiseRow {
  final String cardId;
  final String text;
  final String party; // user | char
  final String status; // open | kept | broken
  const _PromiseRow(this.cardId, this.text, this.party, this.status);
}

class _JournalPromisesTabState extends State<JournalPromisesTab> {
  List<_PromiseRow> _rows = const [];
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant JournalPromisesTab old) {
    super.didUpdateWidget(old);
    if (old.ownerId != widget.ownerId) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final sessionId = widget.chat.currentSessionId;
    final rows = <_PromiseRow>[];
    if (sessionId != null) {
      final cards = await widget.chat.journalStore.cardsFor(
        sessionId,
        widget.ownerId,
      );
      for (final card in cards) {
        final meta = PromiseDebtService.metaOf(card.metadata);
        if (meta['kind'] != 'promise') continue;
        final desc = meta['description'];
        rows.add(
          _PromiseRow(
            card.id,
            desc is String && desc.isNotEmpty ? desc : card.content,
            (meta['party'] as String?) == 'char' ? 'char' : 'user',
            (meta['status'] as String?) ?? 'open',
          ),
        );
      }
      // Open commitments first, then the kept/broken history.
      rows.sort((a, b) => (a.status == 'open' ? 0 : 1)
          .compareTo(b.status == 'open' ? 0 : 1));
    }
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  Future<void> _resolve(_PromiseRow row, {required bool kept}) async {
    setState(() => _busy = true);
    final ok = await widget.chat.resolvePromiseManually(
      characterId: widget.ownerId,
      cardId: row.cardId,
      kept: kept,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (kept
                    ? 'Marked kept — trust and bond updated, and a milestone '
                          'was written.'
                    : 'Marked broken — trust and bond updated.')
              : 'Couldn’t resolve it right now — wait for the current reply '
                    'to finish settling, then try again.',
        ),
        duration: const Duration(seconds: 4),
      ),
    );
    if (ok) await _load();
  }

  (String, Color) _statusChip(BuildContext context, String status) =>
      switch (status) {
        'kept' => ('✅ Kept', AppColors.bondHighOf(context)),
        'broken' => ('💔 Broken', AppColors.negativeAccentOf(context)),
        _ => ('⏳ Open', AppColors.porchAmberOf(context)),
      };

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(
          color: AppColors.porchAmberOf(context),
        ),
      );
    }
    if (_rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No promises yet.\nWhen someone gives their word in this chat, '
            'it lands here — and you can mark it kept or broken yourself if '
            'the app misses the moment.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textTertiary(context),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _rows.length,
      separatorBuilder: (_, _) =>
          Divider(height: 16, color: AppColors.borderOf(context)),
      itemBuilder: (context, i) {
        final row = _rows[i];
        final (chipText, chipColor) = _statusChip(context, row.status);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: chipColor.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Text(
                    chipText,
                    style: TextStyle(fontSize: 11, color: chipColor),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  row.party == 'user'
                      ? 'Your word'
                      : '${widget.ownerName}’s word',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              row.text,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.textPrimary(context),
              ),
            ),
            if (row.status == 'open') ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _resolve(row, kept: true),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.bondHighOf(context),
                      side: BorderSide(
                        color: AppColors.bondHighOf(context)
                            .withValues(alpha: 0.6),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text(
                      'Mark kept',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _resolve(row, kept: false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.negativeAccentOf(context),
                      side: BorderSide(
                        color: AppColors.negativeAccentOf(context)
                            .withValues(alpha: 0.6),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text(
                      'Mark broken',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}
