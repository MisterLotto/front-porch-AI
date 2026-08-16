// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

/// Thrown when [ChatService.importChatPackage] is called while a turn
/// is still streaming or settling, or while another import is running.
/// Import clears `_messages` and mints a new session — doing that under
/// a live writer would drop the reply onto the wrong chat (or into the void).
class ChatImportBusy implements Exception {
  @override
  String toString() =>
      'Wait until the current reply finishes, then import.';
}
