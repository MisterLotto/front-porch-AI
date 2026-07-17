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

import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/services/capability/vision_support_resolver.dart';
import 'package:front_porch_ai/services/character_repository.dart';
import 'package:front_porch_ai/services/expression_pack_service.dart';
import 'package:front_porch_ai/services/image_gen_service.dart';
import 'package:front_porch_ai/services/llm_provider.dart';
import 'package:front_porch_ai/services/storage_service.dart';
import 'package:front_porch_ai/ui/image_studio/vision_gate.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';

import 'avatar_creation_controller.dart';
import 'expressions_section.dart';
import 'portrait_section.dart';

/// The ONE shared "Portrait & Avatars" panel (phase #12), hosted by BOTH
/// creators — the manual wizard's final step and the AI Character Creator's
/// review screen. Portrait section + independent Expressions section + the
/// generate CTA and live progress. All engine controls are views over Image
/// Studio's config; all results land via the existing gallery plumbing.
class AvatarGenerationPanel extends StatefulWidget {
  const AvatarGenerationPanel({
    super.key,
    required this.ensureCardSaved,
    required this.initialPrompt,
    this.card,
  });

  /// Host guarantee: returns a persisted card (dbId set), saving it first if
  /// needed, or null on failure. Called before ANY image lands.
  final Future<CharacterCard?> Function() ensureCardSaved;

  /// Portrait-prompt seed from the host's appearance/description fields.
  final String initialPrompt;

  /// Already-saved card, when the host saved before showing the panel.
  final CharacterCard? card;

  @override
  State<AvatarGenerationPanel> createState() => _AvatarGenerationPanelState();
}

class _AvatarGenerationPanelState extends State<AvatarGenerationPanel> {
  late final AvatarCreationController _c;

  @override
  void initState() {
    super.initState();
    final storage = Provider.of<StorageService>(context, listen: false);
    _c = AvatarCreationController(
      ensureCardSaved: widget.ensureCardSaved,
      repository: Provider.of<CharacterRepository>(context, listen: false),
      storage: storage,
      imageGen: Provider.of<ImageGenService>(context, listen: false),
      resolveVisionFire: () async {
        if (!mounted) return null;
        return resolveVisionFireWithExplainer(context);
      },
      peekVisionSupport: () {
        final llm = Provider.of<LLMProvider>(context, listen: false);
        return VisionSupportResolver.instance.peekForActiveLlm(
          backend: llm.activeBackend,
          storage: storage,
        );
      },
      initialPrompt: widget.initialPrompt,
      card: widget.card,
    );
    _c.init();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Storage is in the merge so gear-dialog edits (backend/model/URL) and
    // slot changes repaint the strip and the edit-model row live.
    final storage = Provider.of<StorageService>(context, listen: false);
    return AnimatedBuilder(
      animation: Listenable.merge([_c, _c.promptController, storage]),
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PortraitSection(controller: _c),
          const SizedBox(height: 16),
          ExpressionsSection(controller: _c),
          const SizedBox(height: 16),
          if (_c.ctaLabel != null && !_c.running) _cta(context),
          if (_c.stage != AvatarRunStage.idle) ...[
            const SizedBox(height: 14),
            _progress(context),
          ],
        ],
      ),
    );
  }

  Widget _cta(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(
          onPressed: _c.canRun ? _c.run : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.formMasterAccent,
            foregroundColor: AppColors.onChaosAccent,
            disabledBackgroundColor: AppColors.surfaceContainerOf(context),
            disabledForegroundColor: AppColors.textTertiary(context),
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            _c.ctaLabel!,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Runs in order, cancel anytime — whatever finished stays in the '
          'gallery.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textTertiary(context),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  // ── Progress ──────────────────────────────────────────────────────────────
  Widget _progress(BuildContext context) {
    final rows = <Widget>[];
    if (_c.stage == AvatarRunStage.failed) {
      rows.add(
        Text(
          _c.statusDetail,
          style: const TextStyle(color: AppColors.logError, fontSize: 12.5),
        ),
      );
      rows.add(const SizedBox(height: 4));
      rows.add(
        Text(
          'Your character is saved — nothing was lost. Fix the engine and '
          'try again, or add images from the Avatar Gallery later.',
          style: TextStyle(
            color: AppColors.textTertiary(context),
            fontSize: 11,
          ),
        ),
      );
    } else {
      if (_c.source == PortraitSource.generate) {
        rows.add(
          _stageRow(
            context,
            at: AvatarRunStage.portrait,
            label: 'Portrait — saved & set as card image (create model)',
            activeLabel: 'Generating portrait…',
          ),
        );
      }
      if (_c.packEnabled && _c.packPossible) {
        if (_c.packEditModeNow) {
          rows.add(
            _stageRow(
              context,
              at: AvatarRunStage.switching,
              label: 'Switched to edit model',
              activeLabel:
                  'Switching to edit model (first use can take a minute)…',
            ),
          );
        }
        rows.add(_packRow(context));
        if (_c.qcEnabled) {
          rows.add(
            _stageRow(
              context,
              at: AvatarRunStage.qc,
              label: _c.flaggedExcluded > 0
                  ? 'Vision QC — ${_c.flaggedExcluded} flagged, held back'
                  : 'Vision QC',
              activeLabel: 'Vision QC — checking each face…',
            ),
          );
        }
      }
      if (_c.stage == AvatarRunStage.done) {
        rows.add(const SizedBox(height: 4));
        rows.add(
          Text(
            _c.importedCount > 0
                ? 'Done — ${_c.importedCount} expression'
                      '${_c.importedCount == 1 ? '' : 's'} in the gallery.'
                : 'Done.',
            style: const TextStyle(
              color: AppColors.logReady,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }
      if (_c.running) {
        rows.add(const SizedBox(height: 8));
        rows.add(
          Row(
            children: [
              Expanded(
                child: Text(
                  'Cancel keeps everything already finished. '
                  '${_c.card?.name ?? 'Your character'} exists either way.',
                  style: TextStyle(
                    color: AppColors.textTertiary(context),
                    fontSize: 11,
                  ),
                ),
              ),
              TextButton(
                onPressed: _c.cancel,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary(context),
                ),
                child: const Text('Cancel', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        );
      }
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
      ),
    );
  }

  /// One progress line for [at]: pending (dim), active (amber + spinner-ish),
  /// or done (green check) based on the controller's current stage order.
  Widget _stageRow(
    BuildContext context, {
    required AvatarRunStage at,
    required String label,
    required String activeLabel,
  }) {
    final done = _c.stage.index > at.index &&
        _c.stage != AvatarRunStage.failed;
    final active = _c.stage == at;
    final color = done
        ? AppColors.logReady
        : active
        ? AppColors.formMasterAccent
        : AppColors.textTertiary(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            done
                ? Icons.check_circle
                : active
                ? Icons.autorenew
                : Icons.circle_outlined,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              active ? activeLabel : label,
              style: TextStyle(color: color, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _packRow(BuildContext context) {
    final s = _c.session;
    final total = s?.slots.length ?? _c.missingEmotions.length;
    final done = s?.doneCount ?? 0;
    String current = '';
    if (s != null) {
      for (final slot in s.slots) {
        if (slot.state == ExpressionSlotState.generating) {
          current = ' — "${slot.emotion}"';
          break;
        }
      }
    }
    final active = _c.stage == AvatarRunStage.pack;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stageRow(
          context,
          at: AvatarRunStage.pack,
          label: 'Expression pack $done / $total (identity pinned to the '
              'portrait)',
          activeLabel: 'Expression pack $done / $total$current',
        ),
        if (active && total > 0)
          Padding(
            padding: const EdgeInsets.only(left: 22, top: 2, bottom: 2),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: done / total,
                minHeight: 5,
                color: AppColors.formMasterAccent,
                backgroundColor: AppColors.surfaceContainerOf(context),
              ),
            ),
          ),
      ],
    );
  }
}
