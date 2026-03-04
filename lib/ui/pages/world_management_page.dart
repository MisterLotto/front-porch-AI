import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:front_porch_ai/models/world.dart';
import 'package:front_porch_ai/models/lorebook.dart';
import 'package:front_porch_ai/services/world_repository.dart';

class WorldManagementPage extends StatelessWidget {
  const WorldManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WorldRepository>(
      builder: (context, repo, child) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text('World Management', style: TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              IconButton(
                icon: const Icon(Icons.download),
                tooltip: 'Import World JSON',
                onPressed: () => _importWorld(context, repo),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('New World'),
                onPressed: () => _showWorldDialog(context, repo),
              ),
              const SizedBox(width: 16),
            ],
          ),
          body: repo.isLoading
              ? const Center(child: CircularProgressIndicator())
              : repo.worlds.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.public, size: 64, color: Colors.white24),
                          const SizedBox(height: 16),
                          const Text('No worlds found. Create or import one!',
                              style: TextStyle(color: Colors.white54)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(24),
                      itemCount: repo.worlds.length,
                      itemBuilder: (context, index) {
                        final world = repo.worlds[index];
                        return _WorldCard(world: world, repo: repo);
                      },
                    ),
        );
      },
    );
  }

  Future<void> _importWorld(BuildContext context, WorldRepository repo) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result != null && result.files.single.path != null) {
      try {
        await repo.importWorld(File(result.files.single.path!));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('World imported successfully!')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Import failed: $e')));
        }
      }
    }
  }

  void _showWorldDialog(BuildContext context, WorldRepository repo, [World? world]) {
    final nameController = TextEditingController(text: world?.name ?? '');
    final descController = TextEditingController(text: world?.description ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(world == null ? 'Create World' : 'Edit World'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final newWorld = world ?? World(name: '', lorebook: Lorebook(entries: []));
              newWorld.name = nameController.text;
              newWorld.description = descController.text;
              repo.saveWorld(newWorld);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _WorldCard extends StatelessWidget {
  final World world;
  final WorldRepository repo;

  const _WorldCard({required this.world, required this.repo});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        title: Row(
          children: [
            Expanded(
              child: Text(world.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            if (world.linkedCharacterName != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.link, size: 14, color: Colors.blueAccent),
                    const SizedBox(width: 4),
                    Text(
                      world.linkedCharacterName!,
                      style: const TextStyle(color: Colors.blueAccent, fontSize: 12),
                    ),
                  ],
                ),
              ),
          ],
        ),
        subtitle: Text(
          '${world.lorebook.entries.length} Entries • ${world.description.isEmpty ? "No description" : world.description}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.upload, size: 20),
              tooltip: 'Export World JSON',
              onPressed: () => _exportWorld(context),
            ),
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () => _editWorld(context),
            ),
            world.linkedCharacterName != null
              ? Tooltip(
                  message: 'Cannot delete: linked to ${world.linkedCharacterName}',
                  child: IconButton(
                    icon: Icon(Icons.delete, size: 20, color: Colors.grey.shade600),
                    onPressed: null,
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.delete, size: 20, color: Colors.redAccent),
                  onPressed: () => _confirmDelete(context),
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportWorld(BuildContext context) async {
    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Export World JSON',
      fileName: '${world.name}.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (outputFile != null) {
      if (!outputFile.endsWith('.json')) outputFile += '.json';
      try {
        await repo.exportWorld(world, outputFile);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Exported to $outputFile')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Export failed: $e')));
        }
      }
    }
  }

  void _editWorld(BuildContext context) {
    final nameController = TextEditingController(text: world.name);
    final descController = TextEditingController(text: world.description);

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 600,
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Edit World: ${world.name}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 16),

                // Name & Description
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'World Name',
                    labelStyle: TextStyle(color: Colors.white54),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    labelStyle: TextStyle(color: Colors.white54),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
                  ),
                ),
                const SizedBox(height: 20),

                // Lorebook entries header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Lorebook Entries (${world.lorebook.entries.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.blueAccent),
                      tooltip: 'Add Entry',
                      onPressed: () {
                        setDialogState(() {
                          world.lorebook.entries.add(LorebookEntry(key: '', content: ''));
                        });
                      },
                    ),
                  ],
                ),
                const Divider(color: Colors.white10),

                // Entries list
                Flexible(
                  child: world.lorebook.entries.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                              child: Text('No entries. Tap + to add one.',
                                  style: TextStyle(color: Colors.white38))),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: world.lorebook.entries.length,
                          itemBuilder: (_, i) {
                            final entry = world.lorebook.entries[i];
                            return _buildEntryEditor(entry, i, setDialogState);
                          },
                        ),
                ),
                const SizedBox(height: 16),

                // Save / Cancel
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.save, size: 18),
                      label: const Text('Save'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                      onPressed: () {
                        world.name = nameController.text;
                        world.description = descController.text;
                        repo.saveWorld(world);
                        Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEntryEditor(LorebookEntry entry, int index, void Function(void Function()) setDialogState) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF374151),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: entry.enabled ? Colors.white10 : Colors.redAccent.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: name/key display + controls
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.displayName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: entry.enabled ? Colors.white : Colors.white38,
                  ),
                ),
              ),
              // Constant toggle
              Tooltip(
                message: 'Always active (no keyword trigger needed)',
                child: FilterChip(
                  label: const Text('Constant', style: TextStyle(fontSize: 10)),
                  selected: entry.constant,
                  onSelected: (val) => setDialogState(() => entry.constant = val),
                  selectedColor: Colors.amber.withValues(alpha: 0.3),
                  labelStyle: TextStyle(color: entry.constant ? Colors.amber : Colors.white54),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              // Enabled toggle
              Switch(
                value: entry.enabled,
                onChanged: (val) => setDialogState(() => entry.enabled = val),
                activeTrackColor: Colors.blueAccent,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              // Delete
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                onPressed: () => setDialogState(() => world.lorebook.entries.removeAt(index)),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Name field
          TextField(
            controller: TextEditingController(text: entry.name),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'Name',
              labelStyle: TextStyle(color: Colors.white38, fontSize: 12),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 8),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
            ),
            onChanged: (val) => entry.name = val,
          ),
          const SizedBox(height: 6),

          // Key field
          TextField(
            controller: TextEditingController(text: entry.key),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'Keywords (comma-separated)',
              labelStyle: TextStyle(color: Colors.white38, fontSize: 12),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 8),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
            ),
            onChanged: (val) => entry.key = val,
          ),
          const SizedBox(height: 6),

          // Content field
          TextField(
            controller: TextEditingController(text: entry.content),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            maxLines: 3,
            minLines: 2,
            decoration: const InputDecoration(
              labelText: 'Content',
              labelStyle: TextStyle(color: Colors.white38, fontSize: 12),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 8),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
            ),
            onChanged: (val) => entry.content = val,
          ),
          const SizedBox(height: 8),

          // Sticky depth
          Row(
            children: [
              const Text('Sticky Depth: ', style: TextStyle(color: Colors.white54, fontSize: 12)),
              SizedBox(
                width: 50,
                child: TextField(
                  controller: TextEditingController(text: entry.stickyDepth.toString()),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
                  ),
                  onChanged: (val) => entry.stickyDepth = int.tryParse(val) ?? 1,
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'How many messages this entry stays active after triggering',
                child: const Icon(Icons.info_outline, size: 14, color: Colors.white24),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete World?'),
        content: Text('Are you sure you want to delete "${world.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              repo.deleteWorld(world);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
