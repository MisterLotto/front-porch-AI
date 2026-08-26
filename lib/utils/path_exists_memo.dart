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

import 'dart:io';

/// Memoizes [File.existsSync] per path so a widget that rebuilds on every
/// Kobold log line does not stat a multi-GB GGUF (or projector) each time.
///
/// Same contract as the Advanced Launch `_launchModelExists` cache: one disk
/// trip when the path changes, reuse after that. A missing file that later
/// appears at the same path stays cached-absent until [of] is called with a
/// different path (or a new memo is created).
class PathExistsMemo {
  String? _path;
  bool _exists = false;

  bool of(String? path) {
    if (path == null || path.isEmpty) {
      _path = path;
      _exists = false;
      return false;
    }
    if (_path == path) return _exists;
    _path = path;
    _exists = File(path).existsSync();
    return _exists;
  }
}
