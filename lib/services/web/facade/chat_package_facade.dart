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

import 'dart:typed_data';

import 'package:front_porch_ai/services/services.dart';

/// Thrown when a `.fpchat` full-restore would land on the wrong 1:1 card
/// and the client has not yet chosen Full restore vs Dialogue only.
class ChatPackageMismatch implements Exception {
  ChatPackageMismatch(this.packageName, this.activeName);
  final String packageName;
  final String activeName;
}

/// Thin relay of desktop [ChatService] package I/O for the PWA.
///
/// Bytes in / bytes out — the browser never decodes `.fpchat` or JSONL.
class ChatPackageFacade {
  ChatPackageFacade(this._chat);
  final ChatService _chat;

  Future<Uint8List?> exportFpchat() => _chat.exportToFpchat();

  String? exportJsonl() => _chat.exportToSillyTavern();

  /// [mismatch] is `full` or `dialogue` after the 409 prompt. Omitted on
  /// the first try — a 1:1 card clash then throws [ChatPackageMismatch].
  Future<({bool fullRestore, String? warning})> importBytes(
    List<int> bytes, {
    String? mismatch,
  }) {
    final raw = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    return _chat.importChatPackage(
      raw,
      onCharacterMismatch: (pkg, active) async {
        if (mismatch == 'full') return true;
        if (mismatch == 'dialogue') return false;
        throw ChatPackageMismatch(pkg, active);
      },
    );
  }
}
