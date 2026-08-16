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

import 'package:front_porch_ai/models/models.dart';

/// Automatic scenario-injection fade for long chats.
///
/// Card/group scenario text stays stored forever; only the **prompt
/// injection** softens and then drops — Author's Note–style strength
/// (10 → 1 → gone), driven by how many **user** messages the chat already
/// has. No setting, no dial: long RP hands "where we are now" to Journal
/// recap + recent history + RAG once the opening premise has done its job.
///
/// Pure functions + constants only (GrowthPhysics / JournalPhysics style).
class ScenarioFade {
  ScenarioFade._();

  /// Strength scale matches Author's Note: 10 = strongest, 1 = weakest still
  /// present, 0 = omit from the prompt entirely.
  static const int kMaxStrength = 10;

  /// User messages spent at each strength rung (including the opening 10).
  /// Default 6 → full strength for the first 6 user turns, then 9 for the next
  /// 6, …, 1 for six turns, then gone at user-message count ≥ 60.
  static const int kUserMessagesPerStrengthStep = 6;

  /// User-message count at which injection strength first hits 0.
  static int get dropAfterUserMessages =>
      kMaxStrength * kUserMessagesPerStrengthStep;

  /// Injection strength 0–10 for a chat that already has [userMessageCount]
  /// user turns.
  static int strengthForUserMessageCount(int userMessageCount) {
    final n = userMessageCount < 0 ? 0 : userMessageCount;
    final dropped = n ~/ kUserMessagesPerStrengthStep;
    final s = kMaxStrength - dropped;
    if (s <= 0) return 0;
    if (s > kMaxStrength) return kMaxStrength;
    return s;
  }

  /// Wrap resolved scenario prose for the system prompt, or `''` when faded
  /// out / empty. Strength bands mirror Author's Note wording intensity.
  /// One-call form for the generation plan: auto-fades with chat length
  /// (strength 10→0 at 60 user messages). Lives here rather than inline in
  /// chat_service_generation.dart so the fade policy has exactly one home
  /// (and the generation file stays under its god-file ratchet ceiling).
  static String wrapForChat(String scenario, List<ChatMessage> messages) =>
      wrapScenario(
        scenario,
        strengthForUserMessageCount(messages.where((m) => m.isUser).length),
      );

  static String wrapScenario(String scenario, int strength) {
    final text = scenario.trim();
    if (text.isEmpty || strength <= 0) return '';

    if (strength >= 8) {
      // Opening force — same shape the app has always used.
      return 'Scenario: $text\n';
    }
    if (strength >= 4) {
      return 'Scenario (background — the story may already have moved on): '
          '$text\n';
    }
    // 1–3: distant origin only; prefer recap + recent history.
    return 'Opening premise only (no longer current unless the scene still '
        'fits — prefer recent history and Where we are): $text\n';
  }
}
