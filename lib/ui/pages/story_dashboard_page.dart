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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:front_porch_ai/services/story_repository.dart';
import 'package:front_porch_ai/services/story_pipeline_service.dart';
import 'package:front_porch_ai/models/story_project.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:front_porch_ai/ui/pages/story_structure_page.dart';
import 'package:front_porch_ai/ui/pages/story_reader_page.dart';
import 'package:front_porch_ai/services/audiobook_generator_service.dart';
import 'package:front_porch_ai/ui/widgets/app_text_field.dart';
import 'package:front_porch_ai/services/epub_generator_service.dart';
import 'package:front_porch_ai/services/tts_service.dart';

/// Dashboard page — story bible overview: concept, themes, cast, threads, lore.
class StoryDashboardPage extends StatefulWidget {
  final String projectId;
  final bool autoRunStoryArchitect;

  const StoryDashboardPage({
    super.key,
    required this.projectId,
    this.autoRunStoryArchitect = false,
  });

  @override
  State<StoryDashboardPage> createState() => _StoryDashboardPageState();
}

class _StoryDashboardPageState extends State<StoryDashboardPage> {
  bool _hasAutoRun = false;
  bool _showChatPreview = false;
  List<String> _chatPreviewMessages = [];
  bool _loadingChatPreview = false;

  // Editable act controllers
  final Map<int, TextEditingController> _actTitleControllers = {};
  final Map<int, TextEditingController> _actDescControllers = {};

  static const _bgDark = Color(0xFF0F172A);
  static const _bgCard = Color(0xFF1E293B);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.autoRunStoryArchitect && !_hasAutoRun) {
      _hasAutoRun = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _runStoryArchitect());
    }
  }

  @override
  void dispose() {
    for (final c in _actTitleControllers.values) { c.dispose(); }
    for (final c in _actDescControllers.values) { c.dispose(); }
    super.dispose();
  }

  StoryProject? get _project =>
      Provider.of<StoryRepository>(context, listen: false).getById(widget.projectId);

  Future<void> _runStoryArchitect() async {
    final pipeline = Provider.of<StoryPipelineService>(context, listen: false);
    final project = _project;
    if (project == null) return;

    try {
      // Run Chat Distiller first if chat history is enabled
      if (project.useChatHistory && project.chatHistoryCharacterIds.isNotEmpty && project.distilledTimeline.isEmpty) {
        await pipeline.runChatDistiller(project);
      }
      await pipeline.runStoryArchitect(project);
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red.shade800),
        );
      }
    }
  }

  Future<void> _runActStructurer() async {
    final pipeline = Provider.of<StoryPipelineService>(context, listen: false);
    final project = _project;
    if (project == null) return;

    try {
      await pipeline.runActStructurer(project);
      if (mounted) {
        // Reset act controllers to pick up new data
        _actTitleControllers.clear();
        _actDescControllers.clear();
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red.shade800),
        );
      }
    }
  }

  Future<void> _loadChatPreview(StoryProject project) async {
    if (_loadingChatPreview) return;
    setState(() => _loadingChatPreview = true);

    try {
      final pipeline = Provider.of<StoryPipelineService>(context, listen: false);
      final messages = await pipeline.getChatPreviewMessages(project);

      if (mounted) {
        setState(() {
          _chatPreviewMessages = messages;
          _loadingChatPreview = false;
          _showChatPreview = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingChatPreview = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading chat preview: $e'), backgroundColor: Colors.red.shade800),
        );
      }
    }
  }

  /// Save edited act fields back to the project.
  Future<void> _saveActEdits(StoryProject project) async {
    final repo = Provider.of<StoryRepository>(context, listen: false);
    for (int i = 0; i < project.acts.length; i++) {
      if (_actTitleControllers.containsKey(i)) {
        project.acts[i] = StoryAct(
          number: project.acts[i].number,
          title: _actTitleControllers[i]!.text,
          description: _actDescControllers[i]!.text,
          focusThreadIds: project.acts[i].focusThreadIds,
          knots: project.acts[i].knots,
        );
      }
    }
    await repo.saveProject(project);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Act edits saved!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _startAudiobookGeneration(StoryProject project, AudiobookGeneratorService service) async {
    try {
      final audiobook = await service.generateAudiobook(project);
      if (audiobook != null && mounted) {
        // Save file dialog
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
          SnackBar(content: Text('Audiobook Failed: $e'), backgroundColor: Colors.red.shade800),
        );
      }
    }
  }

  Future<void> _exportEpub(StoryProject project) async {
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
          SnackBar(content: Text('eBook Export Failed: $e'), backgroundColor: Colors.red.shade800),
        );
      }
    }
  }

  Widget _buildAudiobookProgress(AudiobookGeneratorService service) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.amber.shade900.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.headphones, color: Colors.amber),
              const SizedBox(width: 12),
              const Text('Compiling Audiobook...', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton.icon(
                onPressed: service.stop,
                icon: const Icon(Icons.stop, color: Colors.redAccent, size: 16),
                label: const Text('Abort', style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: service.progress,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.amber.shade600),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 8),
          Text(service.status, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<StoryRepository, StoryPipelineService>(
      builder: (context, repo, pipeline, child) {
        final project = repo.getById(widget.projectId);
        if (project == null) {
          return const Scaffold(
            body: Center(child: Text('Project not found', style: TextStyle(color: Colors.white70))),
          );
        }

        return Scaffold(
          backgroundColor: _bgDark,
          appBar: AppBar(
            title: Text(project.title),
            backgroundColor: _bgCard,
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              if (project.acts.isNotEmpty)
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => StoryReaderPage(projectId: widget.projectId),
                    ),
                  ),
                  icon: const Icon(Icons.menu_book, color: Colors.amber),
                  label: const Text('Read', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                ),
              if (project.acts.isNotEmpty)
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => StoryStructurePage(projectId: widget.projectId),
                    ),
                  ),
                  icon: const Icon(Icons.account_tree, color: Colors.white70),
                  label: const Text('Structure', style: TextStyle(color: Colors.white70)),
                ),
            ],
          ),
          body: _buildBody(project, pipeline),
        );
      },
    );
  }

  Widget _buildBody(StoryProject project, StoryPipelineService pipeline) {
    // Show loading state
    if (pipeline.isRunning) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 56, height: 56,
                child: CircularProgressIndicator(strokeWidth: 3, color: Colors.amber),
              ),
              const SizedBox(height: 32),
              Text(
                pipeline.currentStep,
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                pipeline.statusMessage,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
                textAlign: TextAlign.center,
              ),
              if (pipeline.tokenCount > 0) ...[
                const SizedBox(height: 16),
                Text(
                  '${pipeline.tokenCount} tokens generated',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Show story bible
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Audiobook Generator ──
          Consumer<AudiobookGeneratorService>(
            builder: (context, abService, _) {
              if (abService.isGenerating) {
                return _buildAudiobookProgress(abService);
              }
              if (project.prose.isNotEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade800,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.headphones),
                          label: const Text('Export Audiobook (.wav)', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () => _startAudiobookGeneration(project, abService),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade800,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.book),
                          label: const Text('Export eBook (.epub)', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () => _exportEpub(project),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox();
            },
          ),
          
          // ── Chat History Preview ──
          if (project.useChatHistory && project.chatHistoryCharacterIds.isNotEmpty) ...[
            _buildChatHistorySection(project),
            const SizedBox(height: 16),
          ],

          // Concept
          if (project.concept.isNotEmpty) ...[
            _sectionCard('Concept', project.concept, Icons.lightbulb, Colors.amberAccent),
            const SizedBox(height: 16),
          ],
          // Status Quo & Inciting Incident
          if (project.statusQuo.isNotEmpty)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _sectionCard('Status Quo', project.statusQuo, Icons.home, Colors.blueGrey)),
                const SizedBox(width: 16),
                Expanded(child: _sectionCard('Inciting Incident', project.incitingIncident, Icons.bolt, Colors.redAccent)),
              ],
            ),
          if (project.statusQuo.isNotEmpty) const SizedBox(height: 16),

          // Themes & Style
          if (project.themes.isNotEmpty)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _sectionCard('Themes', project.themes, Icons.psychology, Colors.purpleAccent)),
                const SizedBox(width: 16),
                Expanded(child: _sectionCard(
                  'Style',
                  '${project.style.genre} • ${project.style.mood}\n${project.style.writingGuide}',
                  Icons.palette,
                  Colors.tealAccent,
                )),
              ],
            ),
          if (project.themes.isNotEmpty) const SizedBox(height: 16),

          // Cast
          if (project.cast.isNotEmpty) ...[
            _sectionTitle('Cast (${project.cast.length})', Icons.people, Colors.orangeAccent),
            const SizedBox(height: 8),
            ...project.cast.map((c) => _castCard(c)),
            const SizedBox(height: 16),
          ],

          // Threads
          if (project.threads.isNotEmpty) ...[
            _sectionTitle('Narrative Threads (${project.threads.length})', Icons.timeline, Colors.cyanAccent),
            const SizedBox(height: 8),
            ...project.threads.map((t) => _threadCard(t)),
            const SizedBox(height: 16),
          ],

          // Lore
          if (project.lore.isNotEmpty) ...[
            _sectionTitle('World Lore (${project.lore.length})', Icons.public, Colors.greenAccent),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: project.lore.map((l) => _loreChip(l)).toList(),
            ),
            const SizedBox(height: 24),
          ],

          // Acts — Editable
          if (project.acts.isNotEmpty) ...[
            Row(
              children: [
                _sectionTitle('Act Structure (${project.acts.length})', Icons.account_tree, Colors.indigoAccent),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _saveActEdits(project),
                  icon: Icon(Icons.save, size: 16, color: Colors.indigo.shade300),
                  label: Text('Save Edits', style: TextStyle(color: Colors.indigo.shade300, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Edit act titles and descriptions to guide the story, then generate scenes',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12),
            ),
            const SizedBox(height: 8),
            ...project.acts.asMap().entries.map((e) => _editableActCard(e.key, e.value, project)),
            const SizedBox(height: 16),
          ],

          // Action buttons
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (project.concept.isNotEmpty && project.acts.isEmpty)
                ElevatedButton.icon(
                  onPressed: _runActStructurer,
                  icon: const Icon(Icons.account_tree),
                  label: const Text('Generate Act Structure'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                ),
              if (project.acts.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => StoryStructurePage(projectId: widget.projectId),
                    ),
                  ),
                  icon: const Icon(Icons.view_timeline),
                  label: const Text('View Structure & Write'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                ),
              const SizedBox(width: 12),
              if (project.concept.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: _runStoryArchitect,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Regenerate Bible'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white54),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  CHAT HISTORY PREVIEW
  // ═══════════════════════════════════════════════════════════════
  bool _showRawMessages = false;

  Widget _buildChatHistorySection(StoryProject project) {
    final hasTimeline = project.distilledTimeline.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade800.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            onTap: () => setState(() => _showChatPreview = !_showChatPreview),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.history, size: 20, color: Colors.blue.shade300),
                  const SizedBox(width: 8),
                  Text(
                    'Chat History',
                    style: TextStyle(
                      color: Colors.blue.shade200,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (hasTimeline)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade900.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${RegExp(r'\\[EVENT \\d+\\]').allMatches(project.distilledTimeline).length} events distilled',
                        style: TextStyle(color: Colors.green.shade400, fontSize: 11),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade900.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Not distilled yet',
                        style: TextStyle(color: Colors.orange.shade400, fontSize: 11),
                      ),
                    ),
                  const Spacer(),
                  Icon(
                    _showChatPreview ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white38,
                  ),
                ],
              ),
            ),
          ),
          // Expanded content
          if (_showChatPreview) ...[
            Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
            // Tab row: Timeline | Raw Messages | Redistill
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  if (hasTimeline) ...[
                    _tabButton('Timeline', !_showRawMessages, () => setState(() => _showRawMessages = false)),
                    const SizedBox(width: 8),
                  ],
                  _tabButton('Raw Messages', _showRawMessages || !hasTimeline, () {
                    if (_chatPreviewMessages.isEmpty && !_loadingChatPreview) {
                      _loadChatPreview(project);
                    }
                    setState(() => _showRawMessages = true);
                  }),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () async {
                      final pipeline = Provider.of<StoryPipelineService>(context, listen: false);
                      project.distilledTimeline = ''; // Force re-distill
                      await pipeline.runChatDistiller(project);
                      if (mounted) setState(() => _showRawMessages = false);
                    },
                    icon: Icon(Icons.refresh, size: 14, color: Colors.blue.shade400),
                    label: Text(
                      hasTimeline ? 'Redistill' : 'Distill Now',
                      style: TextStyle(color: Colors.blue.shade400, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Content
            if (!_showRawMessages && hasTimeline) ...[
              // Distilled timeline view
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 400),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SelectableText(
                    project.distilledTimeline,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
            ] else if (_loadingChatPreview) ...[
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue)),
              ),
            ] else if (_chatPreviewMessages.isNotEmpty) ...[
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 400),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shrinkWrap: true,
                  itemCount: _chatPreviewMessages.length,
                  itemBuilder: (context, index) {
                    final msg = _chatPreviewMessages[index];
                    if (msg.startsWith('---')) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Divider(color: Colors.white.withValues(alpha: 0.1)),
                      );
                    }
                    final isUser = msg.startsWith('User:') || msg.startsWith('user:') || msg.startsWith('{{user}}:');
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            isUser ? Icons.person : Icons.smart_toy,
                            size: 14,
                            color: isUser ? Colors.green.shade400 : Colors.purple.shade300,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              msg,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Click "Raw Messages" to load the full chat history.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _tabButton(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? Colors.blue.shade900.withValues(alpha: 0.4) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active ? Colors.blue.shade700.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.blue.shade300 : Colors.white38,
            fontSize: 12,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  EDITABLE ACT CARDS
  // ═══════════════════════════════════════════════════════════════

  Widget _editableActCard(int index, StoryAct act, StoryProject project) {
    // Initialize controllers lazily
    if (!_actTitleControllers.containsKey(index)) {
      _actTitleControllers[index] = TextEditingController(text: act.title);
      _actDescControllers[index] = TextEditingController(text: act.description);
    }

    final sceneCount = project.scenes[act.number - 1]?.length ?? 0;

    return Card(
      color: _bgCard,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: CircleAvatar(
          backgroundColor: Colors.indigo.shade900.withValues(alpha: 0.5),
          radius: 18,
          child: Text('${act.number}', style: const TextStyle(color: Colors.white70, fontSize: 14)),
        ),
        title: Text(
          _actTitleControllers[index]?.text ?? act.title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          (act.description.length > 100 ? '${act.description.substring(0, 100)}...' : act.description),
          style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
        ),
        trailing: sceneCount > 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade900.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$sceneCount scenes', style: TextStyle(color: Colors.blue.shade300, fontSize: 11)),
              )
            : null,
        iconColor: Colors.white38,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Title', style: TextStyle(color: Colors.indigo.shade300, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                AppTextField(
                  controller: _actTitleControllers[index],
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: _bgDark,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Description', style: TextStyle(color: Colors.indigo.shade300, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                AppTextField(
                  controller: _actDescControllers[index],
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  maxLines: 8,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: _bgDark,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                // Knots preview
                if (act.knots.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Convergence Points', style: TextStyle(color: Colors.cyan.shade300, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  ...act.knots.map((k) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.merge_type, size: 14, color: Colors.cyan.shade600),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${k.description} — ${k.interaction}',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  EXISTING WIDGETS (unchanged)
  // ═══════════════════════════════════════════════════════════════

  Widget _sectionTitle(String title, IconData icon, Color color) => Row(
    children: [
      Icon(icon, size: 20, color: color),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
    ],
  );

  Widget _sectionCard(String title, String content, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }

  Widget _castCard(StoryCastMember c) {
    return Card(
      color: _bgCard,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        title: Text(c.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        subtitle: Text(c.role, style: const TextStyle(color: Colors.white38, fontSize: 12)),
        leading: CircleAvatar(
          backgroundColor: Colors.orange.shade900.withValues(alpha: 0.4),
          child: Text(c.name.isNotEmpty ? c.name[0] : '?', style: TextStyle(color: Colors.orange.shade300)),
        ),
        iconColor: Colors.white38,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.description, style: const TextStyle(color: Colors.white60, fontSize: 13)),
                if (c.voiceSample != null && c.voiceSample!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Voice: "${c.voiceSample}"', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontStyle: FontStyle.italic, fontSize: 12)),
                ],
                // TTS Voice picker
                const SizedBox(height: 10),
                Consumer<TtsService>(
                  builder: (context, tts, _) {
                    final voices = tts.activeVoices;
                    if (voices.isEmpty) return const SizedBox.shrink();
                    return Row(
                      children: [
                        Icon(Icons.record_voice_over, size: 14, color: Colors.amber.withValues(alpha: 0.6)),
                        const SizedBox(width: 8),
                        Text('TTS Voice:', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButton<String>(
                            value: c.voiceModel,
                            hint: Text('Default narrator', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12)),
                            dropdownColor: const Color(0xFF1E293B),
                            isExpanded: true,
                            underline: Container(height: 1, color: Colors.white12),
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                            items: [
                              DropdownMenuItem<String>(
                                value: null,
                                child: Text('Default narrator', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                              ),
                              ...voices.map((v) => DropdownMenuItem<String>(
                                value: v.id,
                                child: Text(v.name, style: const TextStyle(fontSize: 12)),
                              )),
                            ],
                            onChanged: (value) {
                              c.voiceModel = value;
                              final repo = Provider.of<StoryRepository>(context, listen: false);
                              final project = _project;
                              if (project != null) repo.saveProject(project);
                              setState(() {});
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
                ...c.details.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('${e.key}: ${e.value}', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _threadCard(StoryThread t) {
    return Card(
      color: _bgCard,
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        dense: true,
        leading: Icon(Icons.timeline, size: 18, color: Colors.cyan.shade400),
        title: Text(t.name, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        subtitle: Text(t.description, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
      ),
    );
  }

  Widget _loreChip(StoryLoreEntry l) {
    return Tooltip(
      message: l.detail,
      child: Chip(
        label: Text(l.topic, style: const TextStyle(fontSize: 12, color: Colors.white70)),
        backgroundColor: _bgCard,
        side: BorderSide(color: Colors.green.shade800.withValues(alpha: 0.3)),
      ),
    );
  }
}

/// Auto-scrolling live text view for streaming generation output.
class _DashboardLiveTextView extends StatefulWidget {
  final String text;
  const _DashboardLiveTextView({required this.text});

  @override
  State<_DashboardLiveTextView> createState() => _DashboardLiveTextViewState();
}

class _DashboardLiveTextViewState extends State<_DashboardLiveTextView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant _DashboardLiveTextView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      child: SelectableText(
        widget.text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.7),
          fontSize: 12,
          fontFamily: 'monospace',
          height: 1.5,
        ),
      ),
    );
  }
}
