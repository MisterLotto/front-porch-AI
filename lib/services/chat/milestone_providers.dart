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

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:front_porch_ai/models/chat_message.dart';
import 'package:front_porch_ai/services/chat/milestone_feed.dart';

/// Riverpod surface for the "Our Story" timeline (Living Time §7).
///
/// FutureProvider (not AsyncNotifier) is the deliberate choice: this is a
/// pure read-model with no mutations, and family-memoized async reads are
/// exactly what FutureProvider models. The inputs record carries the stable
/// MilestoneFeed instance (identity ==) and a `revision` the host widget
/// bumps (message count) so the feed refetches when the chat moves — the
/// same widget-boundary bridge pattern as weather.
typedef MilestoneFeedInputs = ({
  MilestoneFeed feed,
  String sessionId,
  String characterId,
  int revision,
  List<ChatMessage> messages,
});

final milestoneFeedProvider = FutureProvider.autoDispose
    .family<List<MilestoneEntry>, MilestoneFeedInputs>((ref, i) {
      return i.feed.entriesFor(
        sessionId: i.sessionId,
        characterId: i.characterId,
        messages: i.messages,
      );
    });
