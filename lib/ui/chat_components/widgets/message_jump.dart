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

import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';

/// Scroll the chat's reverse `ListView.builder` to [target] (Journal
/// receipts tap-to-jump).
///
/// A builder list only materializes elements near the viewport, so a distant
/// message can't be located directly. The chat page keys each bubble with a
/// GlobalKey it OWNS and resolves through [keyOf]; this seeks in two moves:
/// 1. one rough hop to the target's proportional offset (reverse list:
///    offset 0 = newest, maxScrollExtent = oldest), then
/// 2. viewport-sized pages toward the target — comparing its position
///    against the currently built range — until its key materializes,
///    finishing with an animated `ensureVisible` that centers it.
///
/// [keyOf] returns null for a message whose bubble the page has never built
/// — indistinguishable, on purpose, from "built but currently unmounted":
/// both mean "keep paging". The keys were previously `GlobalObjectKey(msg)`
/// minted HERE from the message alone, which made a message's key app-global
/// — and two chat routes alive in the same frame (push over a live page, or
/// a route transition) both built the same ChatService messages, one
/// duplicate-GlobalKey crash per bubble (maintainer repro, 2026-08-10).
///
/// Safe on any history length (steps are viewport-sized and hard-bounded),
/// resilient to the estimated extents a builder list reports, and a no-op if
/// the target isn't in [messages] or the list has no clients.
Future<void> jumpToMessage({
  required ScrollController controller,
  required List<ChatMessage> messages,
  required ChatMessage target,
  required GlobalKey? Function(ChatMessage) keyOf,
}) async {
  if (!controller.hasClients) return;
  final index = messages.indexWhere((m) => identical(m, target));
  if (index < 0) return;

  if (keyOf(target)?.currentContext == null && messages.length > 1) {
    final position = controller.position;
    final fractionOlder = 1 - index / (messages.length - 1);
    controller.jumpTo(
      (position.maxScrollExtent * fractionOlder).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
    );
    await WidgetsBinding.instance.endOfFrame;
  }

  for (var step = 0; step < 500; step++) {
    final ctx = keyOf(target)?.currentContext;
    if (ctx != null) {
      await Scrollable.ensureVisible(
        ctx,
        alignment: 0.5,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    // Which side of the currently built window is the target on?
    int? lowest, highest;
    for (var p = 0; p < messages.length; p++) {
      if (keyOf(messages[p])?.currentContext != null) {
        lowest ??= p;
        highest = p;
      }
    }
    if (lowest == null || highest == null) return; // nothing built — bail

    final pos = controller.position;
    // Reverse list: older messages (smaller position) live at LARGER offsets.
    final older = index < lowest;
    final next = (older
            ? pos.pixels + pos.viewportDimension * 0.9
            : pos.pixels - pos.viewportDimension * 0.9)
        .clamp(pos.minScrollExtent, pos.maxScrollExtent);
    if ((next - pos.pixels).abs() < 0.5) return; // pinned at an edge — bail
    controller.jumpTo(next);
    await WidgetsBinding.instance.endOfFrame;
  }
}

/// Wraps one chat bubble; briefly tints it after a Journal jump lands so the
/// eye finds the message the memory came from. Carries the bubble's
/// page-owned GlobalKey (assigned by the chat page's itemBuilder).
class JumpFlash extends StatelessWidget {
  final bool flashed;
  final Widget child;

  const JumpFlash({super.key, required this.flashed, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: flashed
            ? AppColors.porchHoneyOf(context).withValues(alpha: 0.16)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}
