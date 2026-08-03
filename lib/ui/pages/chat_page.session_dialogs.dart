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
//
// ChatPage session dialogs: group settings, import/export, clear-chat
// confirmation, chat history, and the edit-session sheet. Extracted verbatim
// from chat_page.dart (god-file campaign, Tranche A); same library, all
// privates in scope.

part of 'chat_page.dart';

extension _ChatPageSessionDialogs on _ChatPageState {
  void _showGroupSettingsDialog(ChatService chatService) {
    final groupRepo = Provider.of<GroupChatRepository>(context, listen: false);
    showDialog(
      context: context,
      builder: (dialogContext) =>
          GroupSettingsDialog(chatService: chatService, groupRepo: groupRepo),
    );
  }

  Future<void> _importChat() async {
    try {
      final result = await PickerPrefs.pickFiles(
        category: PickerPrefs.catImport,
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.single.path == null) return;

      final file = File(result.files.single.path!);
      final jsonData = await file.readAsString();

      if (!mounted) return;

      final chatService = Provider.of<ChatService>(context, listen: false);
      await chatService.importFromSillyTavern(jsonData);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chat imported successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surfaceOf(context),
          title: const Text('Import Failed'),
          content: Text('Error importing chat: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _exportChat() async {
    try {
      final chatService = Provider.of<ChatService>(context, listen: false);
      final jsonData = chatService.exportToSillyTavern();

      if (jsonData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No chat to export'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final characterName = chatService.activeCharacter?.name ?? 'chat';
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final fileName = '${characterName}_$timestamp.json';

      final path = await PickerPrefs.saveFile(
        category: PickerPrefs.catExport,
        dialogTitle: 'Export Chat',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (path == null) return;

      final file = File(path);
      await file.writeAsString(jsonData);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chat exported successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surfaceOf(context),
          title: const Text('Export Failed'),
          content: Text('Error exporting chat: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _showClearChatConfirmation(BuildContext context) {
    final chatService = Provider.of<ChatService>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceOf(context),
        title: const Text('New Chat'),
        content: const Text(
          'This will clear the current conversation and start fresh. This can\'t be undone. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              chatService.startNewChat();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text(
              'New Chat',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showHistoryDialog(BuildContext context) async {
    final chatService = Provider.of<ChatService>(context, listen: false);
    var sessions = await chatService.getSessions();

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surfaceOf(context),
          title: const Text('Chat History'),
          content: SizedBox(
            width: 420,
            height: 350,
            child: sessions.isEmpty
                ? const Center(child: Text('No previous chats found.'))
                : ListView.builder(
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final s = sessions[index];
                      final date = s['date'] as DateTime;
                      final dateStr =
                          '${date.year}-${date.month}-${date.day} ${date.hour}:${date.minute.toString().padLeft(2, "0")}';
                      final isCurrent = s['id'] == chatService.currentSessionId;
                      final isBranch = s['parent_session'] != null;
                      final description = s['session_description'] as String?;

                      return ListTile(
                        leading: isBranch
                            ? const Icon(
                                Icons.call_split,
                                size: 18,
                                color: AppColors.formMasterAccent,
                              )
                            : null,
                        title: Text(
                          s['preview'],
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dateStr,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white54,
                              ),
                            ),
                            if (description != null && description.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  description,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white38,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            if (isBranch)
                              Text(
                                '↳ Branched at message #${(s['fork_index'] ?? 0) + 1}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.formMasterAccent,
                                ),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.edit,
                                size: 16,
                                color: Colors.white38,
                              ),
                              tooltip: 'Edit name & description',
                              onPressed: () => _showEditSessionDialog(
                                context,
                                chatService,
                                s,
                                onSaved: () async {
                                  sessions = await chatService.getSessions();
                                  setDialogState(() {});
                                },
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 16,
                                color: Colors.redAccent,
                              ),
                              tooltip: 'Delete chat',
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: AppColors.surfaceOf(
                                      context,
                                    ),
                                    title: const Text('Delete Chat?'),
                                    content: Text(
                                      'This will permanently delete this chat and all its messages.\n\n"${s['preview']}"',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.redAccent,
                                        ),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await chatService.deleteSession(s['id']);
                                  if (isCurrent) {
                                    if (context.mounted) {
                                      Navigator.of(context).pop();
                                    }
                                  } else {
                                    sessions = await chatService.getSessions();
                                    setDialogState(() {});
                                  }
                                }
                              },
                            ),
                            if (isCurrent)
                              const Padding(
                                padding: EdgeInsets.only(left: 4.0),
                                child: Icon(
                                  Icons.check,
                                  size: 16,
                                  color: Colors.greenAccent,
                                ),
                              ),
                          ],
                        ),
                        onTap: () {
                          chatService.loadSession(s['id']);
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditSessionDialog(
    BuildContext context,
    ChatService chatService,
    Map<String, dynamic> session, {
    required VoidCallback onSaved,
  }) {
    final nameController = TextEditingController(
      text: session['session_name'] ?? '',
    );
    final descController = TextEditingController(
      text: session['session_description'] ?? '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceOf(context),
        title: const Text('Edit Chat Session'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Session Name',
                  labelStyle: const TextStyle(color: Colors.white54),
                  hintText: 'e.g. "Adventure in the forest"',
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: const Color(0xFF374151),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: descController,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                minLines: 2,
                decoration: InputDecoration(
                  labelText: 'Description',
                  labelStyle: const TextStyle(color: Colors.white54),
                  hintText: 'Optional — appears under the timestamp',
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: const Color(0xFF374151),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await chatService.renameSession(
                session['id'],
                nameController.text.trim(),
              );
              await chatService.updateSessionDescription(
                session['id'],
                descController.text.trim(),
              );
              Navigator.of(ctx).pop();
              onSaved();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.formMasterAccent,
              foregroundColor: AppColors.onChaosAccent,
            ),
            child: const Text(
              'Save',
              style: TextStyle(color: AppColors.onChaosAccent),
            ),
          ),
        ],
      ),
    );
  }
}
