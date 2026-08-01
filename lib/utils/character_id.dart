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

import 'package:path/path.dart' as p;
import 'package:front_porch_ai/models/models.dart';

extension StableGroupId on CharacterCard {
  /// The canonical stable identifier for *singular/library* CharacterCards only.
  ///
  /// Used for library lookups, 1:1 chat keys, and (for backward compat in some
  /// cross-cutting utilities) certain non-group paths.
  ///
  /// **Group members are fully decoupled** — they use their own UUID (GroupMember.id)
  /// for all per-member realism, prompts, objectives, RAG, etc. Never derive group
  /// membership or keys from stableGroupId or characterIds.
  ///
  /// This value is **always** derived from the character's image filename
  /// (basename without extension). It is the portable, round-trippable ID
  /// that survives export, import, and duplication for library characters.
  ///
  /// Do **not** use `dbId` for any of the above — it is an internal
  /// database surrogate key and is not stable across devices or imports.
  String get stableGroupId {
    if (imagePath != null && imagePath!.isNotEmpty) {
      return p.basenameWithoutExtension(imagePath!);
    }

    // Rare fallback for characters that have never had an image file.
    return name.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(' ', '_');
  }
}
