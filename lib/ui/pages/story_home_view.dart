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
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:front_porch_ai/services/story_repository.dart';
import 'package:front_porch_ai/services/audiobook_generator_service.dart';
import 'package:front_porch_ai/services/epub_generator_service.dart';
import 'package:front_porch_ai/models/story_project.dart';
import 'package:front_porch_ai/ui/pages/story_setup_page.dart';
import 'package:front_porch_ai/ui/pages/story_dashboard_page.dart';
import 'package:front_porch_ai/ui/pages/story_reader_page.dart';

/// The "Porch Stories" home view — shows all story projects with create/delete.
class StoryHomeView extends StatefulWidget {
  const StoryHomeView({super.key});

  @override
  State<StoryHomeView> createState() => _StoryHomeViewState();
}

class _StoryHomeViewState extends State<StoryHomeView> {
  @override
  Widget build(BuildContext context) {
    return Consumer<StoryRepository>(
      builder: (context, repo, child) {
        if (repo.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (repo.projects.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_stories, size: 72, color: Colors.amber.withValues(alpha: 0.3)),
                const SizedBox(height: 24),
                Text(
                  'No stories yet',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create your first AI-generated story!',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white38,
                  ),
                ),
                const SizedBox(height: 24),
                _buildCreateButton(context, repo),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Row(
                children: [
                  Icon(Icons.auto_stories, color: Colors.amber.shade600, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'Porch Stories',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade900.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${repo.projects.length}',
                      style: TextStyle(color: Colors.amber.shade400, fontSize: 13),
                    ),
                  ),
                  const Spacer(),
                  _buildCreateButton(context, repo),
                ],
              ),
            ),

            // Audiobook generation progress banner
            Consumer<AudiobookGeneratorService>(
              builder: (context, abService, _) {
                if (!abService.isGenerating) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade900.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(color: Colors.amber, strokeWidth: 2),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text('Generating Audiobook...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                          TextButton(
                            onPressed: abService.stop,
                            child: const Text('Abort', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: abService.progress,
                        backgroundColor: Colors.white12,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.amber.shade600),
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      const SizedBox(height: 6),
                      Text(abService.status, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                    ],
                  ),
                );
              },
            ),

            // Project list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: repo.projects.length,
                itemBuilder: (context, index) {
                  final project = repo.projects[index];
                  return _buildProjectCard(context, project, repo);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCreateButton(BuildContext context, StoryRepository repo) {
    return ElevatedButton.icon(
      onPressed: () async {
        final project = await repo.createProject();
        if (context.mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => StorySetupPage(projectId: project.dbId!),
            ),
          );
        }
      },
      icon: const Icon(Icons.add),
      label: const Text('New Story'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.amber.shade800,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    );
  }

  Widget _buildProjectCard(BuildContext context, StoryProject project, StoryRepository repo) {
    final hasActs = project.acts.isNotEmpty;
    final totalScenes = project.scenes.values.fold<int>(0, (sum, s) => sum + s.length);
    final totalProse = project.prose.values.where((p) => p.final_ != null).length;

    String statusLabel;
    Color statusColor;
    IconData statusIcon;

    if (totalProse > 0) {
      statusLabel = '$totalProse beats written';
      statusColor = Colors.greenAccent;
      statusIcon = Icons.edit_note;
    } else if (totalScenes > 0) {
      statusLabel = '$totalScenes scenes planned';
      statusColor = Colors.blueAccent;
      statusIcon = Icons.view_timeline;
    } else if (hasActs) {
      statusLabel = '${project.acts.length} acts structured';
      statusColor = Colors.purpleAccent;
      statusIcon = Icons.account_tree;
    } else if (project.concept.isNotEmpty) {
      statusLabel = 'Bible created';
      statusColor = Colors.orangeAccent;
      statusIcon = Icons.menu_book;
    } else {
      statusLabel = 'New — needs concept';
      statusColor = Colors.white38;
      statusIcon = Icons.lightbulb_outline;
    }

    return Card(
      color: const Color(0xFF1E293B),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => project.concept.isEmpty
                  ? StorySetupPage(projectId: project.dbId!)
                  : StoryDashboardPage(projectId: project.dbId!),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Story icon
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: Colors.amber.shade900.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.auto_stories, color: Colors.amber.shade600, size: 28),
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (project.style.genre.isNotEmpty)
                      Text(
                        '${project.style.genre} • ${project.style.mood}',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(statusIcon, size: 14, color: statusColor),
                        const SizedBox(width: 6),
                        Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              // Tier badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _tierColor(project.promptTier).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _tierLabel(project.promptTier),
                  style: TextStyle(color: _tierColor(project.promptTier), fontSize: 11),
                ),
              ),
              const SizedBox(width: 8),
              // Read Button
              if (hasActs)
                IconButton(
                  icon: const Icon(Icons.menu_book, color: Colors.amber, size: 20),
                  tooltip: 'Read Story',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => StoryReaderPage(projectId: project.dbId!)),
                  ),
                ),
              // Export menu (only for stories with prose)
              if (totalProse > 0)
                PopupMenuButton<String>(
                  icon: Icon(Icons.download, color: Colors.white.withValues(alpha: 0.6), size: 20),
                  tooltip: 'Export',
                  color: const Color(0xFF1E293B),
                  onSelected: (value) {
                    if (value == 'audiobook') _startAudiobookExport(project);
                    if (value == 'epub') _startEpubExport(project);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'audiobook',
                      child: Row(children: [
                        Icon(Icons.headphones, color: Colors.amber, size: 18),
                        SizedBox(width: 10),
                        Text('Export Audiobook (.wav)', style: TextStyle(color: Colors.white)),
                      ]),
                    ),
                    const PopupMenuItem(
                      value: 'epub',
                      child: Row(children: [
                        Icon(Icons.book, color: Colors.blue, size: 18),
                        SizedBox(width: 10),
                        Text('Export eBook (.epub)', style: TextStyle(color: Colors.white)),
                      ]),
                    ),
                  ],
                ),
              // Delete
              IconButton(
                icon: Icon(Icons.delete_outline, color: Colors.red.withValues(alpha: 0.5), size: 20),
                tooltip: 'Delete story',
                onPressed: () => _confirmDelete(context, project, repo),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startAudiobookExport(StoryProject project) async {
    final service = Provider.of<AudiobookGeneratorService>(context, listen: false);
    try {
      final audiobook = await service.generateAudiobook(project);
      if (audiobook != null && mounted) {
        final String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Audiobook',
          fileName: 'audiobook_${project.title.replaceAll(' ', '_')}.wav',
          type: FileType.custom,
          allowedExtensions: ['wav'],
        );
        if (outputFile != null) {
          await audiobook.file.copy(outputFile);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Audiobook saved to $outputFile'), backgroundColor: Colors.green),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Audiobook failed: $e'), backgroundColor: Colors.red.shade800),
        );
      }
    }
  }

  Future<void> _startEpubExport(StoryProject project) async {
    try {
      final epub = await EpubGeneratorService.generateEpub(project);
      if (epub != null && mounted) {
        final String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Save eBook',
          fileName: '${project.title.replaceAll(' ', '_')}.epub',
          type: FileType.custom,
          allowedExtensions: ['epub'],
        );
        if (outputFile != null) {
          await File(outputFile).writeAsBytes(epub.bytes);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('eBook saved to $outputFile'), backgroundColor: Colors.green),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('eBook export failed: $e'), backgroundColor: Colors.red.shade800),
        );
      }
    }
  }

  String _tierLabel(PromptTier tier) {
    switch (tier) {
      case PromptTier.frontier: return 'Frontier';
      case PromptTier.largLocal: return '70B+';
      case PromptTier.smallLocal: return '7-34B';
    }
  }

  Color _tierColor(PromptTier tier) {
    switch (tier) {
      case PromptTier.frontier: return Colors.cyanAccent;
      case PromptTier.largLocal: return Colors.greenAccent;
      case PromptTier.smallLocal: return Colors.orangeAccent;
    }
  }

  void _confirmDelete(BuildContext context, StoryProject project, StoryRepository repo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Delete Story?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Delete "${project.title}" and all its content? This cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              repo.deleteProject(project.dbId!);
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
