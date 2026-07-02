// standard
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;

import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/services/services.dart';
import 'package:front_porch_ai/services/embedding_sidecar.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';
import 'package:front_porch_ai/ui/widgets/widgets.dart';
import 'package:front_porch_ai/ui/dialogs/data_bank_dialog.dart';
import 'package:front_porch_ai/ui/chat_components/overlays/rag_setup_dialog.dart';

/// Memory (RAG) sidebar section — shows enable toggle, config,
/// embedding status, and per-character memory source picker.
class MemorySection extends StatefulWidget {
  final ChatService chatService;
  const MemorySection({super.key, required this.chatService});

  @override
  State<MemorySection> createState() => MemorySectionState();
}

class MemorySectionState extends State<MemorySection> {
  bool _showSettings = false;
  bool _showSources = false;
  Set<String> _selectedSources = {};
  bool _sourcesLoaded = false;
  double? _dragRagRetrievalCount;
  double? _dragRagWindowSize;
  double? _dragEvolutionInterval;

  /// Derive the embedding ID for a character card (must match ChatService._getCharacterIdFromCard)
  String _embeddingId(CharacterCard card) {
    if (card.imagePath != null) {
      return p.basenameWithoutExtension(card.imagePath!);
    }
    return card.name.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(' ', '_');
  }

  /// Load current memorySources from DB
  Future<void> _loadSources() async {
    final activeChar = widget.chatService.activeCharacter;
    if (activeChar == null || activeChar.dbId == null) return;
    try {
      final repo = Provider.of<CharacterRepository>(context, listen: false);
      final sources = await repo.getMemorySources(activeChar.dbId!);
      setState(() {
        _selectedSources = sources.toSet();
        _sourcesLoaded = true;
      });
    } catch (_) {
      setState(() => _sourcesLoaded = true);
    }
  }

  /// Save selected sources to DB
  Future<void> _saveSources() async {
    final activeChar = widget.chatService.activeCharacter;
    if (activeChar == null || activeChar.dbId == null) return;
    try {
      final repo = Provider.of<CharacterRepository>(context, listen: false);
      await repo.setMemorySources(activeChar.dbId!, _selectedSources.toList());
    } catch (e) {
      debugPrint('[RAG:UI] Failed to save memorySources: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final storage = Provider.of<StorageService>(context);
    final enabled = storage.ragEnabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with enable toggle
        Row(
          children: [
            const Icon(Icons.psychology, size: 16, color: Colors.purpleAccent),
            const SizedBox(width: 6),
            const Text(
              'Memory (RAG)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
            const Spacer(),
            SizedBox(
              height: 28,
              child: FittedBox(
                child: Switch(
                  value: enabled,
                  onChanged: (val) async {
                    if (!val) {
                      // Turning OFF — no consent needed
                      storage.setRagEnabled(false);
                      return;
                    }
                    // Turning ON — check if consent was given before
                    final prefs = await SharedPreferences.getInstance();
                    final consented =
                        prefs.getBool('rag_setup_consented') ?? false;
                    if (consented) {
                      // Already consented — just enable
                      storage.setRagEnabled(true);
                      Provider.of<EmbeddingSidecar>(
                        context,
                        listen: false,
                      ).ensureRunning();
                      return;
                    }
                    // First time — show consent + setup dialog
                    if (!context.mounted) return;
                    final result = await showDialog<bool>(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => const RagSetupDialog(),
                    );
                    if (result == true) {
                      await prefs.setBool('rag_setup_consented', true);
                      storage.setRagEnabled(true);
                      if (context.mounted) {
                        Provider.of<EmbeddingSidecar>(
                          context,
                          listen: false,
                        ).ensureRunning();
                      }
                    }
                  },
                  activeTrackColor: Colors.purpleAccent,
                ),
              ),
            ),
          ],
        ),

        if (!enabled)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Retrieve relevant past messages that have fallen out of context, including from other characters\' conversations.',
              style: TextStyle(fontSize: 11, color: Colors.white30),
            ),
          ),

        if (enabled) ...[
          const SizedBox(height: 6),
          // Status indicator
          Builder(
            builder: (context) {
              final sidecar = Provider.of<EmbeddingSidecar>(context);
              final statusColor = sidecar.modelReady
                  ? Colors.greenAccent
                  : Colors.amber;
              final statusText = sidecar.modelReady
                  ? 'Embedding engine ready'
                  : sidecar.isRunning
                  ? 'Starting...'
                  : 'Engine not running';
              return Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    statusText,
                    style: const TextStyle(fontSize: 10, color: Colors.white38),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 6),
          // Controls row
          Row(
            children: [
              // Settings gear toggle
              InkWell(
                onTap: () => setState(() => _showSettings = !_showSettings),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.tune,
                        size: 14,
                        color: _showSettings
                            ? Colors.purpleAccent
                            : Colors.white38,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Settings',
                        style: TextStyle(
                          fontSize: 10,
                          color: _showSettings
                              ? Colors.purpleAccent
                              : Colors.white38,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Sources toggle
              InkWell(
                onTap: () {
                  setState(() => _showSources = !_showSources);
                  if (_showSources && !_sourcesLoaded) _loadSources();
                },
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.people,
                        size: 14,
                        color: _showSources
                            ? Colors.purpleAccent
                            : Colors.white38,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Sources${_selectedSources.isNotEmpty ? ' (${_selectedSources.length})' : ''}',
                        style: TextStyle(
                          fontSize: 10,
                          color: _showSources
                              ? Colors.purpleAccent
                              : Colors.white38,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Data Bank button
              InkWell(
                onTap: () {
                  final activeChar = widget.chatService.activeCharacter;
                  if (activeChar == null) return;
                  showDialog(
                    context: context,
                    builder: (_) => DataBankDialog(
                      characterId: _embeddingId(activeChar),
                      characterName: activeChar.name,
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.library_books,
                        size: 14,
                        color: Colors.white38,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Data Bank',
                        style: TextStyle(fontSize: 10, color: Colors.white38),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Expandable settings
          if (_showSettings) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerOf(context),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderOf(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Memories per turn
                  Row(
                    children: [
                      Text(
                        'Memories per turn',
                        style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontSize: 11,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        (_dragRagRetrievalCount ??
                                        storage.ragRetrievalCount.toDouble())
                                    .round() ==
                                0
                            ? 'All'
                            : '${(_dragRagRetrievalCount ?? storage.ragRetrievalCount.toDouble()).round()}',
                        style: const TextStyle(
                          color: Colors.purpleAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                    ),
                    child: Slider(
                      value:
                          _dragRagRetrievalCount ??
                          storage.ragRetrievalCount.toDouble(),
                      min: 0,
                      max: 50,
                      divisions: 50,
                      activeColor: Colors.purpleAccent,
                      inactiveColor: Colors.white12,
                      onChanged: (val) =>
                          setState(() => _dragRagRetrievalCount = val),
                      onChangeEnd: (val) {
                        _dragRagRetrievalCount = null;
                        storage.setRagRetrievalCount(val.round());
                      },
                    ),
                  ),
                  // Window size
                  Row(
                    children: [
                      const Text(
                        'Window size',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                      const Spacer(),
                      Text(
                        '${(_dragRagWindowSize ?? storage.ragWindowSize.toDouble()).round()}',
                        style: const TextStyle(
                          color: Colors.purpleAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                    ),
                    child: Slider(
                      value:
                          _dragRagWindowSize ??
                          storage.ragWindowSize.toDouble(),
                      min: 3,
                      max: 10,
                      divisions: 7,
                      activeColor: Colors.purpleAccent,
                      inactiveColor: Colors.white12,
                      onChanged: (val) =>
                          setState(() => _dragRagWindowSize = val),
                      onChangeEnd: (val) {
                        _dragRagWindowSize = null;
                        storage.setRagWindowSize(val.round());
                      },
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 12,
                        color: Colors.purpleAccent,
                      ),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Uses local nomic-embed-text model — no data leaves your machine.',
                          style: TextStyle(fontSize: 10, color: Colors.white38),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 10),
                  const SizedBox(height: 10),
                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 10),
                  // Character evolution toggle
                  Row(
                    children: [
                      const Icon(
                        Icons.psychology_alt,
                        size: 14,
                        color: Colors.tealAccent,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Character Evolution',
                        style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontSize: 11,
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        height: 24,
                        child: FittedBox(
                          child: Switch(
                            value: storage.characterEvolutionEnabled,
                            onChanged: (val) =>
                                storage.setCharacterEvolutionEnabled(val),
                            activeTrackColor: Colors.tealAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (storage.characterEvolutionEnabled) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text(
                          'Evolve every',
                          style: TextStyle(color: Colors.white38, fontSize: 10),
                        ),
                        const Spacer(),
                        Text(
                          '${(_dragEvolutionInterval ?? storage.evolutionInterval.toDouble()).round()} messages',
                          style: const TextStyle(
                            color: Colors.tealAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value:
                          _dragEvolutionInterval ??
                          storage.evolutionInterval.toDouble(),
                      min: 10,
                      max: 50,
                      divisions: 8,
                      activeColor: Colors.tealAccent,
                      onChanged: (val) =>
                          setState(() => _dragEvolutionInterval = val),
                      onChangeEnd: (val) {
                        _dragEvolutionInterval = null;
                        storage.setEvolutionInterval(val.round());
                      },
                    ),
                    Consumer<ChatService>(
                      builder: (context, chat, _) {
                        final count = chat.characterEvolutionCount;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  count > 0
                                      ? 'Evolved $count time${count > 1 ? 's' : ''}'
                                      : 'Not yet evolved',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: count > 0
                                        ? Colors.tealAccent
                                        : Colors.white24,
                                    fontWeight: count > 0
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                                const Spacer(),
                                if (count > 0) ...[
                                  GestureDetector(
                                    onTap: () =>
                                        _showEvolutionReview(context, chat),
                                    child: const Text(
                                      'View',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.tealAccent,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => _showResetEvolutionConfirm(
                                      context,
                                      chat,
                                    ),
                                    child: const Text(
                                      'Reset',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.redAccent,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Personality & scenario evolve based on conversations. Original card is always preserved.',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white24,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Expandable memory sources (cross-character picker)
          if (_showSources) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Include memories from other characters:',
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  const SizedBox(height: 6),
                  _buildCharacterSourceList(),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildCharacterSourceList() {
    final charRepo = Provider.of<CharacterRepository>(context, listen: false);
    final activeChar = widget.chatService.activeCharacter;
    final activeEmbedId = activeChar != null ? _embeddingId(activeChar) : '';

    // Get all characters except the current one
    final otherChars = charRepo.characters
        .where((c) => _embeddingId(c) != activeEmbedId)
        .toList();

    if (otherChars.isEmpty) {
      return const Text(
        'No other characters available.',
        style: TextStyle(
          fontSize: 10,
          color: Colors.white30,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Column(
      children: otherChars.map((char) {
        final embedId = _embeddingId(char);
        final isSelected = _selectedSources.contains(embedId);
        return InkWell(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedSources.remove(embedId);
              } else {
                _selectedSources.add(embedId);
              }
            });
            _saveSources();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Icon(
                  isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                  size: 16,
                  color: isSelected ? Colors.purpleAccent : Colors.white30,
                ),
                const SizedBox(width: 8),
                if (char.imagePath != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      Provider.of<StorageService>(
                        context,
                        listen: false,
                      ).resolveCharacterImage(char.imagePath!),
                      width: 20,
                      height: 20,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.person,
                        size: 16,
                        color: Colors.white30,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    char.name,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? Colors.white70 : Colors.white38,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showEvolutionReview(BuildContext context, ChatService chat) {
    final character = chat.activeCharacter;
    if (character == null) return;
    final charName = character.name;

    // Get evolved versions from chat service cache
    final evolvedPersonality = chat.getEffectivePersonality ?? '';
    final evolvedScenario = chat.getEffectiveScenario ?? '';

    final personalityController = TextEditingController(
      text: evolvedPersonality,
    );
    final scenarioController = TextEditingController(text: evolvedScenario);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceOf(context),
        title: Row(
          children: [
            const Icon(
              Icons.psychology_alt,
              size: 18,
              color: Colors.tealAccent,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$charName — Evolution',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Evolved ${chat.characterEvolutionCount} time${chat.characterEvolutionCount > 1 ? "s" : ""}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.tealAccent,
                  ),
                ),
                const SizedBox(height: 12),
                // Original personality (read-only)
                const Text(
                  'Original Personality',
                  style: TextStyle(fontSize: 11, color: Colors.white38),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1117),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white10),
                  ),
                  constraints: const BoxConstraints(maxHeight: 80),
                  child: SingleChildScrollView(
                    child: Text(
                      character.personality,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white30,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Evolved personality (editable)
                const Text(
                  'Evolved Personality',
                  style: TextStyle(fontSize: 11, color: Colors.tealAccent),
                ),
                const SizedBox(height: 4),
                AppTextField(
                  controller: personalityController,
                  maxLines: 4,
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF111827),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Colors.tealAccent),
                    ),
                    contentPadding: const EdgeInsets.all(8),
                  ),
                ),
                const SizedBox(height: 12),
                // Original scenario (read-only)
                const Text(
                  'Original Scenario',
                  style: TextStyle(fontSize: 11, color: Colors.white38),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1117),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white10),
                  ),
                  constraints: const BoxConstraints(maxHeight: 80),
                  child: SingleChildScrollView(
                    child: Text(
                      character.scenario,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white30,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Evolved scenario (editable)
                const Text(
                  'Evolved Scenario',
                  style: TextStyle(fontSize: 11, color: Colors.tealAccent),
                ),
                const SizedBox(height: 4),
                AppTextField(
                  controller: scenarioController,
                  maxLines: 4,
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF111827),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Colors.tealAccent),
                    ),
                    contentPadding: const EdgeInsets.all(8),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              chat.updateEvolvedPersonality(personalityController.text);
              chat.updateEvolvedScenario(scenarioController.text);
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.tealAccent.shade700,
            ),
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  void _showResetEvolutionConfirm(BuildContext context, ChatService chat) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceOf(context),
        title: const Text('Reset Character Evolution?'),
        content: const Text(
          'This will reset the character\'s personality and scenario back to the original card values. '
          'The evolution count will also reset to 0. This cannot be undone.',
          style: TextStyle(fontSize: 12, color: Colors.white54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              chat.resetCharacterEvolution();
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}
