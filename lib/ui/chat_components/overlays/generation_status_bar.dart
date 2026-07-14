// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// This file is part of Front Porch AI.
//
// ... full standard header ...
//
// You should have received a copy of the GNU Affero General Public License
// along with Front Porch AI. If not, see <https://www.gnu.org/licenses/>.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/services/services.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';

/// Rich, phase-aware generation status bar. (extracted)
class GenerationStatusBar extends StatefulWidget {
  final ChatService chatService;
  const GenerationStatusBar({super.key, required this.chatService});

  @override
  State<GenerationStatusBar> createState() => _GenerationStatusBarState();
}

class _GenerationStatusBarState extends State<GenerationStatusBar> {
  Timer? _elapsedTimer;

  @override
  void initState() {
    super.initState();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.chatService;
    final phase = cs.generationPhase;
    // Live per-request progress straight from the managed backend's console
    // (null / stale for remote backends — the label falls back gracefully).
    // The Provider is optional by design: widget tests (and any embedding
    // without the app-level tree) render the estimate-based fallback instead
    // of crashing.
    KoboldService? kobold;
    try {
      kobold = context.watch<KoboldService>();
    } on ProviderNotFoundException {
      kobold = null;
    }

    final (
      String label,
      Color accentColor,
      IconData icon,
      bool showMetrics,
    ) = switch (phase) {
      GenerationPhase.preparing => (
        'Assembling prompt...',
        AppColors.resolve(
          context,
          const Color(0xFFF59E0B),
          const Color(0xFFB45309),
        ),
        Icons.build_rounded,
        false,
      ),
      GenerationPhase.prefilling => _prefillLabel(cs, kobold),
      GenerationPhase.thinking => _thinkingLabel(cs),
      GenerationPhase.buffering => (
        'Buffering tokens...',
        AppColors.resolve(
          context,
          const Color(0xFF3B82F6),
          const Color(0xFF1D4ED8),
        ),
        Icons.hourglass_top_rounded,
        true,
      ),
      GenerationPhase.generating => (
        'Generating response...',
        AppColors.resolve(
          context,
          const Color(0xFF10B981),
          const Color(0xFF059669),
        ),
        Icons.bolt_rounded,
        true,
      ),
      GenerationPhase.idle => (
        'Idle',
        AppColors.textTertiary(context),
        Icons.check_rounded,
        false,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        border: Border(
          top: BorderSide(
            color: AppColors.borderOf(context).withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child:
                    phase == GenerationPhase.prefilling ||
                        phase == GenerationPhase.preparing
                    ? PulsingIcon(icon: icon, color: accentColor)
                    : Icon(icon, size: 16, color: accentColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: accentColor.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (showMetrics) ...[
                Text(
                  '${cs.tokensPerSecond.toStringAsFixed(1)} t/s',
                  style: TextStyle(
                    color: AppColors.resolve(
                      context,
                      Colors.amberAccent,
                      const Color(0xFFB45309),
                    ),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${cs.tokensGenerated} / ${cs.maxTokens}',
                  style: TextStyle(
                    color: AppColors.textTertiary(context),
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${(cs.generationProgress * 100).toInt()}%',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: _buildProgressBar(cs, phase, accentColor),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(
    ChatService cs,
    GenerationPhase phase,
    Color accentColor,
  ) {
    if (phase == GenerationPhase.generating ||
        phase == GenerationPhase.buffering) {
      return LinearProgressIndicator(
        value: cs.generationProgress,
        minHeight: 4,
        backgroundColor: AppColors.borderOf(context).withValues(alpha: 0.08),
        valueColor: AlwaysStoppedAnimation<Color>(
          Color.lerp(
            accentColor,
            AppColors.resolve(
              context,
              AppColors.resolve(
                context,
                const Color(0xFF10B981),
                const Color(0xFF059669),
              ),
              const Color(0xFF059669),
            ),
            cs.generationProgress,
          )!,
        ),
      );
    }
    if (phase == GenerationPhase.prefilling) {
      // Determinate whenever the managed backend's console gave us real
      // numbers — the prompt pass stops being a black box.
      KoboldService? kobold;
      try {
        kobold = context.read<KoboldService>();
      } on ProviderNotFoundException {
        kobold = null;
      }
      final fraction = kobold?.liveProgress.promptFraction();
      if (fraction != null) {
        return LinearProgressIndicator(
          value: fraction,
          minHeight: 4,
          backgroundColor: AppColors.borderOf(context).withValues(alpha: 0.08),
          valueColor: AlwaysStoppedAnimation<Color>(accentColor),
        );
      }
    }
    return LinearProgressIndicator(
      minHeight: 4,
      backgroundColor: Colors.white.withValues(alpha: 0.08),
      valueColor: AlwaysStoppedAnimation<Color>(
        accentColor.withValues(alpha: 0.7),
      ),
    );
  }

  (String, Color, IconData, bool) _prefillLabel(
    ChatService cs,
    KoboldService? kobold,
  ) {
    final elapsed = cs.prefillElapsedSeconds;
    final elapsedStr = elapsed >= 1 ? ' (${elapsed.toInt()}s)' : '';
    const color = Color(0xFFF97316);

    // The single-slot local backend serializes requests, so our reply can be
    // stuck behind a background pass. Name the wait truthfully.
    final String? busyWith = cs.isSummaryGenerating
        ? 'journal pass'
        : (cs.isGrowthPassRunning ? 'growth pass' : null);

    final live = kobold?.liveProgress;
    if (live != null && live.isFresh && live.promptTotal > 0) {
      final pct = ((live.promptFraction() ?? 0) * 100).toInt();
      final counts =
          '${_fmtTokens(live.promptCurrent)} / ${_fmtTokens(live.promptTotal)} tokens';
      if (busyWith != null) {
        // Whatever Kobold is chewing on right now is the BACKGROUND call;
        // our reply is queued behind it.
        final stage = live.genTotal > 0
            ? 'writing (${live.genCurrent} tokens)'
            : 'reading $counts ($pct%)';
        return (
          'Waiting — $busyWith is using the model: $stage$elapsedStr',
          color,
          Icons.hourglass_top_rounded,
          false,
        );
      }
      if (live.genTotal == 0 || (live.promptFraction() ?? 0) < 1.0) {
        return (
          'Reading prompt — $counts ($pct%)$elapsedStr',
          color,
          Icons.memory_rounded,
          false,
        );
      }
      // Prompt done, decode running, but no token has reached us yet — on
      // the solo path that decode IS our own reply warming up (buffering /
      // suppressed thinking / first-token latency), so say so. Only a
      // busyWith flag above marks the slot as genuinely someone else's
      // (review finding: "earlier call" here mislabeled every normal reply).
      return (
        'Starting the reply — ${live.genCurrent} tokens written$elapsedStr',
        color,
        Icons.bolt_rounded,
        false,
      );
    }

    // No live console data (remote backend, or nothing printed yet): keep the
    // estimate-based label.
    final promptTokens = cs.prefillPromptTokens;
    String tokenStr = '';
    if (promptTokens > 0) {
      tokenStr = '~${_fmtTokens(promptTokens)} tokens';
    }
    final perf = cs.lastPerfData;
    String speedStr = '';
    if (perf != null) {
      final idle = perf['idle'];
      if (idle == 0) {
        final speed = perf['last_process_speed'];
        if (speed != null && speed is num && speed > 0) {
          speedStr = '~${speed.toStringAsFixed(0)} t/s';
        }
      }
    }
    final parts = <String>[
      if (tokenStr.isNotEmpty) tokenStr,
      if (speedStr.isNotEmpty) speedStr,
    ];
    final detail = parts.isNotEmpty ? ' — ${parts.join(', ')}' : '';
    final label = busyWith != null
        ? 'Waiting — $busyWith is using the model$elapsedStr'
        : 'Processing prompt$elapsedStr$detail';
    return (label, color, Icons.memory_rounded, false);
  }

  String _fmtTokens(int n) {
    if (n >= 10000) return '${(n / 1000).toStringAsFixed(0)}K';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  (String, Color, IconData, bool) _thinkingLabel(ChatService cs) {
    final tokens = cs.tokensGenerated;
    final tps = cs.tokensPerSecond;
    String detail = '';
    if (tokens > 0 && tps > 0) {
      detail = ' — ${tps.toStringAsFixed(1)} t/s, $tokens tokens';
    } else if (tokens > 0) {
      detail = ' — $tokens tokens';
    }
    return (
      'Model is thinking...$detail',
      const Color(0xFFA855F7),
      Icons.psychology_rounded,
      false,
    );
  }
}

/// Pulsing icon (extracted).
class PulsingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  const PulsingIcon({super.key, required this.icon, required this.color});

  @override
  State<PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<PulsingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: 0.4 + (_controller.value * 0.6),
          child: Icon(widget.icon, size: 16, color: widget.color),
        );
      },
    );
  }
}
