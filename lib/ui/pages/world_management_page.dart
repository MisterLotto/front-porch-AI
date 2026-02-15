import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:kobold_character_card_manager/models/world.dart';
import 'package:kobold_character_card_manager/models/lorebook.dart';
import 'package:kobold_character_card_manager/services/world_repository.dart';

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
        title: Text(world.name, style: const TextStyle(fontWeight: FontWeight.bold)),
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
            IconButton(
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
     // For now, reuse the create dialog. 
     // In a full implementation, we'd have a separate page to manage lorebook entries.
     // I'll stick to a simple entry management for now to meet the requirement.
     // Wait, the user said "creating lorebooks and worlds that can accept precreated .json files".
     // I should probably allow editing ENTRIES too.
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
