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

import 'package:front_porch_ai/services/chat/chat.dart';

/// Scene-time fragment for the words-only state block
/// (docs/design/prompt-state-injection.md §3). One line; clock digits and
/// dates are normal fiction, unlike meters (design: story-calendar.md §7).
/// The year appears only when the story isn't set in the current real-world
/// year. State stays in TimeService.
class TimeInjection {
  final TimeService timeService;

  TimeInjection({required this.timeService});

  /// The real-absence note used to ride this fragment. It was lifted out on
  /// 2026-08-07 (docs/design/feature-independence.md, "Notices your absence"):
  /// the note is computed from your last message's WALL-CLOCK timestamp and
  /// its own opt-in, and has nothing to do with story time — but riding here
  /// meant it inherited the scene-facts gate, so with the story clock frozen
  /// the feature was silently dead. It is now its own fragment in
  /// RealismStateInjection, emitted in this same position.
  String buildTimeInjection() =>
      'It is currently ${StoryClock.clockPhrase(timeService.clock)} on '
      '${timeService.displayDate} '
      '(day ${timeService.dayCount} of the story).';
}
