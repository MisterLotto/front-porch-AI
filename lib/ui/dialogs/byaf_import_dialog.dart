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
import 'package:flutter/material.dart';
import 'package:front_porch_ai/services/byaf_service.dart';

/// Result from the BYAF import dialog.
class ByafImportResult {
  final bool confirmed;
  final bool importChatHistory;
  ByafImportResult({required this.confirmed, required this.importChatHistory});
}

/// Dialog to preview and confirm import of a .byaf character file.
class ByafImportDialog extends StatefulWidget {
  final ByafImportPreview preview;

  const ByafImportDialog({super.key, required this.preview});

  @override
  State<ByafImportDialog> createState() => _ByafImportDialogState();
}

class _ByafImportDialogState extends State<ByafImportDialog> {
  bool _importChat = true;

  @override
  Widget build(BuildContext context) {
    final preview = widget.preview;

    return Dialog(
      backgroundColor: const Color(0xFF1F2937),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.archive_outlined, color: Colors.blueAccent, size: 24),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Import Backyard AI Character',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context, ByafImportResult(confirmed: false, importChatHistory: false)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 16),

            // Content - scrollable
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Character info row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 100,
                            height: 100,
                            color: const Color(0xFF374151),
                            child: preview.extractedImagePath != null
                                ? Image.file(
                                    File(preview.extractedImagePath!),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.person, color: Colors.white38, size: 48,
                                    ),
                                  )
                                : const Icon(Icons.person, color: Colors.white38, size: 48),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Name + stats
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                preview.name,
                                style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildInfoChip(Icons.auto_stories, '${preview.persona.length} chars persona'),
                              if (preview.loreItems.isNotEmpty)
                                _buildInfoChip(Icons.book, '${preview.loreItems.length} lore items'),
                              if (preview.messages.isNotEmpty)
                                _buildInfoChip(Icons.chat, '${preview.messages.length} chat messages'),
                              if (preview.firstMessage != null && preview.firstMessage!.isNotEmpty)
                                _buildInfoChip(Icons.chat_bubble_outline, 'Has greeting'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Persona preview
                    if (preview.persona.isNotEmpty) ...[
                      const Text('Persona', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent, fontSize: 13)),
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111827),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          preview.persona.length > 400
                              ? '${preview.persona.substring(0, 400)}…'
                              : preview.persona,
                          style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // First message preview
                    if (preview.firstMessage != null && preview.firstMessage!.isNotEmpty) ...[
                      const Text('First Message', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent, fontSize: 13)),
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111827),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          preview.firstMessage!.length > 300
                              ? '${preview.firstMessage!.substring(0, 300)}…'
                              : preview.firstMessage!,
                          style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Model settings (read-only)
                    if (preview.modelSettings.isNotEmpty) ...[
                      const Text('Model Settings (preview only)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white38, fontSize: 13)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: preview.modelSettings.entries.map((e) =>
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF374151),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${e.key}: ${e.value.toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                          ),
                        ).toList(),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Chat history import toggle
                    if (preview.messages.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                        ),
                        child: CheckboxListTile(
                          value: _importChat,
                          onChanged: (v) => setState(() => _importChat = v ?? true),
                          title: Text(
                            'Import chat history (${preview.messages.length} messages)',
                            style: const TextStyle(color: Colors.blueAccent, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                          subtitle: const Text(
                            'Creates a chat session with the imported messages',
                            style: TextStyle(color: Colors.white38, fontSize: 11),
                          ),
                          activeColor: Colors.blueAccent,
                          checkColor: Colors.white,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, ByafImportResult(confirmed: false, importChatHistory: false)),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, ByafImportResult(confirmed: true, importChatHistory: _importChat)),
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Import Character'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white38),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }
}
