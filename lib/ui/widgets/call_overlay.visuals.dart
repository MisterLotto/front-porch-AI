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

part of 'call_overlay.dart';

/// The call overlay's visual builders — avatar ring, realism strip, status
/// chip, waveform, live captions, and the control row. Pure presentation
/// over [_CallOverlayState]'s data; the lifecycle (teardown ownership) and
/// the turn loop stay in call_overlay.dart.
extension _CallOverlayVisuals on _CallOverlayState {
  Widget _buildAvatar(
    BuildContext context,
    CallStatus status,
    double amp,
    double size,
  ) {
    final isActive =
        status == CallStatus.listening || status == CallStatus.speaking;
    final ring = _statusColor(context, status);
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulseScale = isActive
            ? 1.0 + (_pulseController.value * 0.04) + (amp * 0.08)
            : 1.0;
        return Transform.scale(
          scale: pulseScale,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: ring.withValues(alpha: isActive ? 0.3 : 0.1),
                  blurRadius: isActive ? 40 + amp * 20 : 20,
                  spreadRadius: isActive ? 4 + amp * 8 : 2,
                ),
              ],
            ),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    ring.withValues(alpha: 0.6),
                    ring.withValues(alpha: 0.2),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: CircleAvatar(
                radius: size / 2 - 4,
                backgroundColor: AppColors.surfaceContainerOf(context),
                backgroundImage: widget.character.imagePath != null
                    ? FileImage(File(widget.character.imagePath!))
                    : null,
                child: widget.character.imagePath == null
                    ? Text(
                        widget.character.name.isNotEmpty
                            ? widget.character.name[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: size * 0.3,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary(context),
                        ),
                      )
                    : null,
              ),
            ),
          ),
        );
      },
    );
  }

  /// The in-call realism window: her current emotion plus the bond/trust
  /// movement of the last scored exchange (read straight off the last
  /// reply's chip metadata — the same numbers the bubbles show after the
  /// call). Renders nothing with the engine off or before the first eval.
  Widget _buildRealismStrip(BuildContext context, ChatService chat) {
    if (!chat.realismEnabled) return const SizedBox(height: 22);
    final chips = <Widget>[];
    final emotion = chat.characterEmotion;
    if (emotion.isNotEmpty) {
      chips.add(
        _stripChip(
          context,
          Icons.mood,
          emotion[0].toUpperCase() + emotion.substring(1),
          AppColors.porchHoneyOf(context),
        ),
      );
    }
    final messages = chat.messages;
    final last = messages.isNotEmpty ? messages.last : null;
    final meta = (last != null && !last.isUser) ? last.activeMetadata : null;
    final bond = meta?['bond_delta'] as int? ?? 0;
    final trust = meta?['trust_delta'] as int? ?? 0;
    if (bond != 0) {
      chips.add(
        _stripChip(
          context,
          Icons.favorite,
          bond > 0 ? '+$bond' : '$bond',
          bond > 0
              ? AppColors.bondHighOf(context)
              : AppColors.bondNegOf(context),
        ),
      );
    }
    if (trust != 0) {
      chips.add(
        _stripChip(
          context,
          Icons.handshake,
          trust > 0 ? '+$trust' : '$trust',
          trust > 0
              ? AppColors.trustHighOf(context)
              : AppColors.bondNegOf(context),
        ),
      );
    }
    if (chips.isEmpty) return const SizedBox(height: 22);
    return Wrap(spacing: 8, runSpacing: 4, children: chips);
  }

  Widget _stripChip(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, CallStatus status) {
    final color = _statusColor(context, status);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey(status),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_statusIcon(status), size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              _statusText(status),
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaveform(BuildContext context, double amp, CallStatus status) {
    final isListening = status == CallStatus.listening;
    final color = _statusColor(context, status);
    const barCount = 9;
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, _) {
        return SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(barCount, (i) {
              final phase =
                  (i / barCount * 2 * pi) + (_waveController.value * 2 * pi);
              final waveHeight = isListening
                  ? 0.3 + (sin(phase) * 0.3 + 0.3) * amp
                  : (status == CallStatus.speaking)
                  ? 0.2 + sin(phase) * 0.3
                  : 0.15;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  width: 4,
                  height: 8 + (waveHeight * 52),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        color.withValues(alpha: 0.8),
                        color.withValues(alpha: 0.3),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  /// Live captions. While she speaks, the EXACT sentence the speaker is
  /// voicing right now ([TtsService.nowSpeaking] — published by the
  /// streaming consumer as it plays, not as text generates, so the caption
  /// never runs ahead of the audio). Otherwise, what the mic last heard
  /// from you — so a bad transcription is visible before the reply lands.
  Widget _buildCaptionArea(
    BuildContext context,
    SttService stt,
    TtsService tts,
  ) {
    final speaking = tts.nowSpeaking;
    final heard = stt.lastTranscription;
    final Widget child;
    if (speaking != null && speaking.isNotEmpty) {
      child = _captionCard(
        context,
        key: const ValueKey('caption_speaking'),
        icon: Icons.graphic_eq,
        color: AppColors.porchTerracottaOf(context),
        text: speaking,
      );
    } else if (heard != null && heard.isNotEmpty) {
      child = _captionCard(
        context,
        key: const ValueKey('caption_heard'),
        icon: Icons.record_voice_over,
        color: AppColors.textTertiary(context),
        text: '"$heard"',
      );
    } else {
      child = const SizedBox(key: ValueKey('caption_none'), height: 40);
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: child,
    );
  }

  Widget _captionCard(
    BuildContext context, {
    required Key key,
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.cardOf(context).withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.borderOf(context).withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textPrimary(context),
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(BuildContext context, SttService stt) {
    final isMuted = stt.call.isMuted;
    final canSend =
        stt.call.status == CallStatus.listening && stt.isRecording;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _controlButton(
          context,
          icon: isMuted ? Icons.mic_off : Icons.mic,
          label: isMuted ? 'Unmute' : 'Mute',
          color: isMuted
              ? AppColors.porchHoneyOf(context)
              : AppColors.textSecondary(context),
          onTap: () => stt.call.toggleMute(),
        ),
        const SizedBox(width: 32),
        if (canSend) ...[
          _controlButton(
            context,
            icon: Icons.send,
            label: 'Send',
            color: AppColors.porchAmberOf(context),
            size: 64,
            onTap: () => stt.call.sendNow(),
          ),
          const SizedBox(width: 32),
        ],
        _controlButton(
          context,
          icon: Icons.call_end,
          label: 'End',
          // End-call red rides the shared AppColors red accent (bondNeg) —
          // universal live-call semantics, not new off-palette chrome.
          color: AppColors.bondNegOf(context),
          onTap: () {
            _teardown(); // snappy: mic + TTS stop NOW, not next frame
            widget.onEndCall();
          },
        ),
      ],
    );
  }

  Widget _controlButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    double size = 56,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.12),
              border: Border.all(
                color: color.withValues(alpha: 0.35),
                width: 1.5,
              ),
            ),
            child: Icon(icon, color: color, size: size * 0.45),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: color.withValues(alpha: 0.8),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
