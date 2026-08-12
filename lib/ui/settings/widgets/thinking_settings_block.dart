// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Request-thinking switch + this model's real strength chips. Off is locked
// when the model cannot disable reasoning. A Nano poke at pick time fills
// the menu when the provider does not advertise it.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:front_porch_ai/services/services.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';
import 'package:front_porch_ai/ui/settings/widgets/thinking_strength_control.dart';

/// Thinking switch + strength chips for Settings and per-chat settings.
class ThinkingSettingsBlock extends StatefulWidget {
  const ThinkingSettingsBlock({
    super.key,
    required this.enabled,
    required this.onEnabledChanged,
    required this.effort,
    required this.onEffortChanged,
    this.modelId = '',
    this.compact = false,
  });

  final bool enabled;
  final ValueChanged<bool> onEnabledChanged;
  final String effort;
  final ValueChanged<String> onEffortChanged;
  final String modelId;
  final bool compact;

  @override
  State<ThinkingSettingsBlock> createState() => _ThinkingSettingsBlockState();
}

class _ThinkingSettingsBlockState extends State<ThinkingSettingsBlock> {
  @override
  void initState() {
    super.initState();
    kReasoningEffortCatalogTick.addListener(_onCatalog);
    WidgetsBinding.instance.addPostFrameCallback((_) => _kickProbe());
  }

  @override
  void didUpdateWidget(ThinkingSettingsBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.modelId != widget.modelId) _kickProbe();
  }

  @override
  void dispose() {
    kReasoningEffortCatalogTick.removeListener(_onCatalog);
    super.dispose();
  }

  void _onCatalog() {
    if (mounted) setState(() {});
  }

  StorageService? get _storage {
    try {
      return Provider.of<StorageService>(context, listen: false);
    } catch (_) {
      return null;
    }
  }

  bool get _isLocal {
    try {
      return Provider.of<LLMProvider>(context, listen: false).isLocal;
    } catch (_) {
      return false;
    }
  }

  void _kickProbe() {
    if (widget.modelId.isEmpty || !mounted || _isLocal) return;
    final storage = _storage;
    if (storage == null) return;
    kickReasoningEffortProbe(
      model: widget.modelId,
      apiUrl: storage.remoteApiUrl,
      apiKey: storage.remoteApiKey,
    );
  }

  @override
  Widget build(BuildContext context) {
    final local = _isLocal;
    final mandatory =
        !local && reasoningEffortIsMandatory(widget.modelId);
    final thinkingOn = local
        ? widget.enabled
        : reasoningEffortThinkingOn(widget.modelId, widget.enabled);
    final pending = !local &&
        reasoningEffortMenuPending(
          widget.modelId,
          apiUrl: _storage?.remoteApiUrl ?? '',
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Request thinking',
                style: TextStyle(
                  color: AppColors.textPrimary(context),
                  fontSize: widget.compact ? 14 : null,
                ),
              ),
            ),
            Switch(
              value: thinkingOn,
              onChanged: mandatory ? null : widget.onEnabledChanged,
              activeTrackColor: AppColors.formMasterAccent,
            ),
          ],
        ),
        if (mandatory)
          Padding(
            padding: EdgeInsets.only(top: widget.compact ? 2 : 4),
            child: Text(
              'This model always thinks — Off is not available.',
              style: TextStyle(
                color: AppColors.textTertiary(context),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        if (pending)
          Padding(
            padding: EdgeInsets.only(top: widget.compact ? 2 : 4),
            child: Text(
              'Asking this provider which thinking levels it accepts…',
              style: TextStyle(
                color: AppColors.textTertiary(context),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        if (thinkingOn)
          Padding(
            padding: EdgeInsets.only(top: widget.compact ? 4 : 12),
            child: ThinkingStrengthControl(
              compact: widget.compact,
              value: widget.effort,
              modelId: local ? '' : widget.modelId,
              onChanged: widget.onEffortChanged,
            ),
          )
        else if (!widget.compact)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Turn on for reasoning models so their think-steps are '
              'captured under each reply. The chips then show this '
              'model\'s real levels.',
              style: TextStyle(
                color: AppColors.textTertiary(context),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Enable to request thinking from compatible models. '
              'Strength maps to the levels the model accepts.',
              style: TextStyle(
                color: AppColors.textTertiary(context),
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}
