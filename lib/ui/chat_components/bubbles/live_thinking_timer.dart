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
import 'package:front_porch_ai/ui/theme/app_colors.dart';

/// The live "Thinking Ns..." spinner shown on a streaming bubble while the
/// model is inside its think block — extracted verbatim from message_bubble
/// (god-file ratchet). Renders nothing once generation stops.
class LiveThinkingTimer extends StatelessWidget {
  const LiveThinkingTimer({super.key, required this.startMs});

  /// [ChatMessage.thinkingStartTime] — epoch millis the think block opened.
  final int startMs;

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatService>(
      builder: (context, chatService, _) {
        if (!chatService.isGenerating) {
          return const SizedBox.shrink();
        }
        final elapsed = DateTime.now().millisecondsSinceEpoch - startMs;
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: Colors.tealAccent,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Thinking ${(elapsed / 1000).toStringAsFixed(0)}s...',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary(context),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
