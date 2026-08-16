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

part of 'enhance_wizard_page.dart';

/// Wizard chrome for [EnhanceWizardPage]: the creator-pattern step
/// indicator + per-step nav buttons, and the shared step scaffolding
/// (scroll frame, headings, callouts) the step bodies compose.
extension _EnhanceWizardChrome on _EnhanceWizardPageState {
  // ── Shared bits ─────────────────────────────────────────────────────────

  Widget _stepScroll(BuildContext context, List<Widget> children) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ),
    );
  }

  Widget _stepHeading(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary(context),
        ),
      ),
    );
  }

  Widget _stepBody(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          height: 1.5,
          color: AppColors.textSecondary(context),
        ),
      ),
    );
  }

  Widget _callout(
    BuildContext context, {
    required IconData icon,
    required String text,
    Color? accent,
  }) {
    final color = accent ?? AppColors.porchAmberOf(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.textPrimary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Step indicator — exact pattern from character_creator_page.dart
  // (horizontal dots + labels + connecting lines in the AppBar, driven by
  // the _currentStep int; the mandated wizard chrome).
  Widget _buildStepIndicator(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < _EnhanceWizardPageState._stepLabels.length; i++) ...[
          if (i > 0) _stepLine(context),
          _stepDot(context, i, _EnhanceWizardPageState._stepLabels[i]),
        ],
      ],
    );
  }

  Widget _stepDot(BuildContext context, int step, String label) {
    final isActive = _currentStep >= step;
    final isCurrent = _currentStep == step;
    final dotColor = isActive
        ? AppColors.porchAmberOf(context)
        : AppColors.surfaceContainerOf(context);
    final numberOrCheckColor = isActive
        ? AppColors.onChaosAccent
        : AppColors.textTertiary(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dotColor,
            border: isCurrent
                ? Border.all(color: AppColors.textPrimary(context), width: 2)
                : Border.all(
                    color: AppColors.borderOf(context).withValues(alpha: 0.3),
                  ),
          ),
          child: Center(
            child: isActive && !isCurrent
                ? Icon(Icons.check, size: 14, color: numberOrCheckColor)
                : Text(
                    '${step + 1}',
                    style: TextStyle(fontSize: 11, color: numberOrCheckColor),
                  ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isActive
                ? AppColors.textSecondary(context)
                : AppColors.textTertiary(context),
          ),
        ),
      ],
    );
  }

  Widget _stepLine(BuildContext context) {
    return Container(
      width: 24,
      height: 2,
      margin: const EdgeInsets.only(bottom: 14),
      color: AppColors.borderOf(context).withValues(alpha: 0.35),
    );
  }

  // Bottom nav — modeled exactly on character_creator_page.dart, with
  // per-step labels/gating. While the interview runs, the only control is
  // Cancel; after the Review save there is no way back (the copy exists).
  Widget _buildNavButtons(BuildContext context, bool backendReady) {
    if (_running) {
      return Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 16),
        child: Center(
          child: SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _cancelInterview,
              icon: const Icon(Icons.close, size: 18),
              label: const Text('Cancel', style: TextStyle(fontSize: 14)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary(context),
                side: BorderSide(color: AppColors.borderOf(context)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final (String nextLabel, IconData nextIcon, VoidCallback? onNext) =
        switch (_currentStep) {
          0 => (
            'Next: Model',
            Icons.arrow_forward,
            (_sessions?.isNotEmpty ?? false)
                ? () => rebuildState(() => _currentStep = 1)
                : null,
          ),
          1 => (
            backendReady ? 'Next: Chat' : 'Waiting for a ready backend...',
            Icons.arrow_forward,
            backendReady
                ? () => rebuildState(() {
                    _modelId = creatorState.selectedModelId;
                    _currentStep = 2;
                  })
                : null,
          ),
          2 => (
            'Next: Interview',
            Icons.arrow_forward,
            _sessionId != null ? _loadChatContextAndAdvance : null,
          ),
          3 => (
            'Start the Interview',
            Icons.auto_awesome,
            _selection.anySelected ? _runInterview : null,
          ),
          4 => (
            'Save as New Character',
            Icons.save_alt,
            _saving ? null : _saveReview,
          ),
          _ => ('Finish', Icons.check, _copying ? null : _finish),
        };
    final showBack = _currentStep > 0 && _currentStep < 5 && !_saving;

    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 16),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showBack)
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => rebuildState(() => _currentStep--),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Back', style: TextStyle(fontSize: 14)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary(context),
                    side: BorderSide(color: AppColors.borderOf(context)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            if (showBack) const SizedBox(width: 16),
            SizedBox(
              width: 280,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: onNext,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(nextIcon, size: 20),
                label: Text(nextLabel, style: const TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.porchAmberOf(context),
                  foregroundColor: AppColors.onChaosAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
