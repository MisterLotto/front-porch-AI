import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:front_porch_ai/models/character_card.dart';
import 'package:front_porch_ai/services/character_gen_service.dart';
import 'package:front_porch_ai/services/character_repository.dart';
import 'package:front_porch_ai/services/image_gen_service.dart';
import 'package:front_porch_ai/services/llm_provider.dart';
import 'package:front_porch_ai/services/llm_service.dart';
import 'package:front_porch_ai/services/open_router_service.dart';
import 'package:front_porch_ai/services/storage_service.dart';
import 'package:front_porch_ai/services/user_persona_service.dart';

/// Full-page AI-powered character creator wizard.
///
/// Step 1: User provides creative input (name, concept, personality, art style).
/// Step 2: LLM generates the full character card + avatar.
/// Step 3: Review and edit the generated card, then save.
class CharacterCreatorPage extends StatefulWidget {
  const CharacterCreatorPage({super.key});

  @override
  State<CharacterCreatorPage> createState() => _CharacterCreatorPageState();
}

class _CharacterCreatorPageState extends State<CharacterCreatorPage> {
  // Step tracking
  int _currentStep = 0; // 0=setup, 1=config, 2=generating, 3=review

  // Step 1 — Input controllers
  final _nameController = TextEditingController();
  final _conceptController = TextEditingController();
  final _keywordsController = TextEditingController();
  final _ageController = TextEditingController();
  final _sexController = TextEditingController();
  final _relationshipController = TextEditingController();
  String _artStyle = 'Anime';
  String _greetingLength = 'Medium (2-4 paragraphs)';
  int _altGreetingCount = 2;
  Set<String> _selectedTones = {'Neutral'};
  bool _generateLorebook = true;
  String _selectedPersonaId = ''; // '' = None (blank slate)

  // Editor pass toggles
  bool _editorAntiPuppet = true;
  bool _editorConsistency = false;
  bool _editorQuality = false;
  String _editorModelId = '';

  // KoboldCpp local model state
  List<FileSystemEntity> _localModels = [];
  String _selectedLocalModelPath = '';
  bool _isReloadingKobold = false;
  String _koboldStatus = '';

  static const _artStyles = [
    'Anime',
    'Realistic',
    'Painterly',
    'Pixel Art',
    'Comic Book',
    'Watercolor',
    'Fantasy Illustration',
  ];

  static const _greetingLengths = [
    'Short (1-2 paragraphs)',
    'Medium (2-4 paragraphs)',
    'Long (4-6 paragraphs)',
  ];

  static const _greetingTones = [
    'Neutral',
    'Romantic',
    'Spicy/NSFW',
    'Flirty/Playful',
    'Wholesome',
    'Slice of Life',
    'Story/Narrative',
    'Adventure',
    'Combat/Action',
    'Comedy/Humor',
    'Suspense/Thriller',
    'Dark/Mystery',
    'Melancholy',
  ];

  // Step 2 — Generation state
  String _generationStatus = '';
  String _generationPreview = '';
  bool _isGenerating = false;
  double _progress = 0.0;

  // Step 3 — Generated results
  CharacterCard? _generatedCard;
  Uint8List? _generatedAvatar;
  String? _imagePrompt;
  bool _isGeneratingAvatar = false;
  bool _imagePromptExpanded = false;

  // Model selector state
  List<RemoteModelInfo> _availableModels = [];
  String _selectedModelId = '';
  bool _isLoadingModels = true;

  // Editable controllers for review step
  final _descController = TextEditingController();
  final _personalityController = TextEditingController();
  final _scenarioController = TextEditingController();
  final _firstMessageController = TextEditingController();
  final _exampleDialogueController = TextEditingController();
  final _systemPromptController = TextEditingController();
  final _imagePromptController = TextEditingController();

  // SharedPreferences keys
  static const _prefName = 'chargen_name';
  static const _prefConcept = 'chargen_concept';
  static const _prefKeywords = 'chargen_keywords';
  static const _prefArtStyle = 'chargen_art_style';
  static const _prefModel = 'chargen_model';
  static const _prefGreetingLength = 'chargen_greeting_length';
  static const _prefAltCount = 'chargen_alt_count';
  static const _prefTone = 'chargen_tone';
  static const _prefLorebook = 'chargen_lorebook';
  static const _prefAge = 'chargen_age';
  static const _prefSex = 'chargen_sex';
  static const _prefRelationship = 'chargen_relationship';
  static const _prefPersona = 'chargen_persona';
  static const _prefEditorAntiPuppet = 'chargen_editor_antipuppet';
  static const _prefEditorConsistency = 'chargen_editor_consistency';
  static const _prefEditorQuality = 'chargen_editor_quality';
  static const _prefEditorModel = 'chargen_editor_model';

  @override
  void initState() {
    super.initState();
    _loadSavedState();
    _loadAvailableModels();
    // Scan local GGUF models for KoboldCpp
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final llmProvider = Provider.of<LLMProvider>(context, listen: false);
      if (llmProvider.activeBackend == BackendType.kobold) {
        _scanLocalModels();
      }
    });
  }

  Future<void> _loadSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _nameController.text = prefs.getString(_prefName) ?? '';
        _conceptController.text = prefs.getString(_prefConcept) ?? '';
        _keywordsController.text = prefs.getString(_prefKeywords) ?? '';
        _artStyle = prefs.getString(_prefArtStyle) ?? 'Anime';
        _selectedModelId = prefs.getString(_prefModel) ?? '';
        _greetingLength = prefs.getString(_prefGreetingLength) ?? 'Medium (2-4 paragraphs)';
        _altGreetingCount = prefs.getInt(_prefAltCount) ?? 2;
        final savedTones = prefs.getString(_prefTone) ?? 'Neutral';
        _selectedTones = savedTones.split(',').where((t) => t.isNotEmpty).toSet();
        if (_selectedTones.isEmpty) _selectedTones = {'Neutral'};
        _generateLorebook = prefs.getBool(_prefLorebook) ?? true;
        _ageController.text = prefs.getString(_prefAge) ?? '';
        _sexController.text = prefs.getString(_prefSex) ?? '';
        _relationshipController.text = prefs.getString(_prefRelationship) ?? '';
        _selectedPersonaId = prefs.getString(_prefPersona) ?? '';
        _editorAntiPuppet = prefs.getBool(_prefEditorAntiPuppet) ?? true;
        _editorConsistency = prefs.getBool(_prefEditorConsistency) ?? false;
        _editorQuality = prefs.getBool(_prefEditorQuality) ?? false;
        _editorModelId = prefs.getString(_prefEditorModel) ?? '';
      });
    }
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefName, _nameController.text);
    await prefs.setString(_prefConcept, _conceptController.text);
    await prefs.setString(_prefKeywords, _keywordsController.text);
    await prefs.setString(_prefArtStyle, _artStyle);
    await prefs.setString(_prefModel, _selectedModelId);
    await prefs.setString(_prefGreetingLength, _greetingLength);
    await prefs.setInt(_prefAltCount, _altGreetingCount);
    await prefs.setString(_prefTone, _selectedTones.join(','));
    await prefs.setBool(_prefLorebook, _generateLorebook);
    await prefs.setString(_prefAge, _ageController.text);
    await prefs.setString(_prefSex, _sexController.text);
    await prefs.setString(_prefRelationship, _relationshipController.text);
    await prefs.setString(_prefPersona, _selectedPersonaId);
    await prefs.setBool(_prefEditorAntiPuppet, _editorAntiPuppet);
    await prefs.setBool(_prefEditorConsistency, _editorConsistency);
    await prefs.setBool(_prefEditorQuality, _editorQuality);
    await prefs.setString(_prefEditorModel, _editorModelId);
  }

  Future<void> _loadAvailableModels() async {
    final llmProvider = Provider.of<LLMProvider>(context, listen: false);

    // If using KoboldCpp backend, no remote model list — just use the local model
    if (llmProvider.activeBackend == BackendType.kobold) {
      if (mounted) {
        setState(() {
          _availableModels = [];
          _isLoadingModels = false;
          _selectedModelId = ''; // Empty = use active service
        });
      }
      return;
    }

    final openRouter = llmProvider.openRouterService;
    try {
      final models = await openRouter.fetchAvailableModels();
      if (mounted) {
        setState(() {
          _availableModels = models;
          _isLoadingModels = false;
          // Default to current model if no saved preference
          if (_selectedModelId.isEmpty) {
            _selectedModelId = openRouter.modelName;
          }
        });
      }
    } catch (e) {
      debugPrint('CharacterCreator: Failed to load models: $e');
      if (mounted) {
        setState(() {
          _isLoadingModels = false;
          _selectedModelId = llmProvider.openRouterService.modelName;
        });
      }
    }
  }

  /// Scan modelsDir for .gguf files (local KoboldCpp models).
  void _scanLocalModels() {
    final storage = Provider.of<StorageService>(context, listen: false);
    final modelsDir = storage.modelsDir;
    if (!modelsDir.existsSync()) {
      setState(() => _localModels = []);
      return;
    }
    try {
      final files = modelsDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.gguf'))
          .toList()
        ..sort((a, b) => p.basename(a.path).toLowerCase().compareTo(p.basename(b.path).toLowerCase()));
      setState(() {
        _localModels = files;
        // Default to last used model if available
        if (_selectedLocalModelPath.isEmpty) {
          _selectedLocalModelPath = storage.lastUsedModelPath ?? '';
        }
      });
    } catch (e) {
      debugPrint('CharacterCreator: Failed to scan models: $e');
      setState(() => _localModels = []);
    }
  }

  /// Stop KoboldCpp and restart with a new model file.
  Future<void> _reloadKoboldWithModel(String modelPath) async {
    if (_isReloadingKobold) return;
    final llmProvider = Provider.of<LLMProvider>(context, listen: false);
    final storage = Provider.of<StorageService>(context, listen: false);
    final kobold = llmProvider.koboldService;

    setState(() {
      _isReloadingKobold = true;
      _koboldStatus = 'Stopping KoboldCpp...';
    });

    try {
      // Stop if running
      if (kobold.isRunning) {
        await kobold.stopKobold();
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Find executable
      final binDir = storage.binDir;
      String? execPath;
      if (binDir.existsSync()) {
        for (final f in binDir.listSync()) {
          if (f is File && (f.path.contains('koboldcpp') || f.path.contains('KoboldCpp'))) {
            execPath = f.path;
            break;
          }
        }
      }

      if (execPath == null) {
        setState(() {
          _isReloadingKobold = false;
          _koboldStatus = 'Error: KoboldCpp executable not found';
        });
        return;
      }

      setState(() => _koboldStatus = 'Starting KoboldCpp with new model...');

      await kobold.startKobold(
        execPath,
        modelPath,
        port: 5001,
        gpuLayers: storage.gpuLayers,
        contextSize: storage.contextSize,
        useVulkan: storage.useVulkan ?? false,
        useCublas: storage.useCublas ?? false,
        useMetal: storage.useMetal ?? false,
        useRocm: storage.useRocm ?? false,
      );

      // Save as last used model
      await storage.setLastUsedModelPath(modelPath);

      // Poll for model readiness
      setState(() => _koboldStatus = 'Loading model...');
      for (int i = 0; i < 120; i++) {
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return;
        if (kobold.modelReady || kobold.consumeModelReady()) {
          setState(() {
            _isReloadingKobold = false;
            _koboldStatus = 'Model loaded successfully!';
            _selectedLocalModelPath = modelPath;
          });
          return;
        }
        if (kobold.modelLoadingStatus.isNotEmpty) {
          setState(() => _koboldStatus = kobold.modelLoadingStatus);
        }
      }

      setState(() {
        _isReloadingKobold = false;
        _koboldStatus = 'Timeout waiting for model to load';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isReloadingKobold = false;
          _koboldStatus = 'Error: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    // Save state before disposing
    _saveState();
    _nameController.dispose();
    _conceptController.dispose();
    _keywordsController.dispose();
    _ageController.dispose();
    _sexController.dispose();
    _relationshipController.dispose();
    _descController.dispose();
    _personalityController.dispose();
    _scenarioController.dispose();
    _firstMessageController.dispose();
    _exampleDialogueController.dispose();
    _systemPromptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _isGenerating ? null : () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 22),
            const SizedBox(width: 8),
            const Text('AI Character Creator'),
            const Spacer(),
            // Step indicator
            _buildStepIndicator(),
          ],
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _currentStep == 0
            ? _buildSetupStep()
            : _currentStep == 1
                ? _buildConfigStep()
                : _currentStep == 2
                    ? _buildGeneratingStep()
                    : _buildReviewStep(),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _stepDot(0, 'Setup'),
        _stepLine(),
        _stepDot(1, 'Configure'),
        _stepLine(),
        _stepDot(2, 'Generate'),
        _stepLine(),
        _stepDot(3, 'Review'),
      ],
    );
  }

  Widget _stepDot(int step, String label) {
    final isActive = _currentStep >= step;
    final isCurrent = _currentStep == step;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? Colors.blueAccent : Colors.white12,
            border: isCurrent ? Border.all(color: Colors.white, width: 2) : null,
          ),
          child: Center(
            child: isActive && !isCurrent
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : Text('${step + 1}', style: TextStyle(fontSize: 11, color: isActive ? Colors.white : Colors.white38)),
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, color: isActive ? Colors.white70 : Colors.white30)),
      ],
    );
  }

  Widget _stepLine() {
    return Container(
      width: 32,
      height: 2,
      margin: const EdgeInsets.only(bottom: 14),
      color: Colors.white12,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  STEP 0: Backend & Model Setup
  // ═══════════════════════════════════════════════════════════════

  Widget _buildSetupStep() {
    final llmProvider = Provider.of<LLMProvider>(context, listen: false);
    final isKobold = llmProvider.activeBackend == BackendType.kobold;

    return Center(
      key: const ValueKey('setup'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'Backend & Model Setup',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose your AI backend and model before configuring your character.',
                style: TextStyle(fontSize: 14, color: Colors.white54, height: 1.5),
              ),
              const SizedBox(height: 32),

              // Backend toggle
              _inputLabel('Backend', required: false),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _backendChip(
                      label: 'KoboldCpp (Local)',
                      icon: Icons.computer,
                      isSelected: isKobold,
                      onTap: () async {
                        if (!isKobold) {
                          await llmProvider.setActiveBackend(BackendType.kobold);
                          _scanLocalModels();
                          setState(() {});
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _backendChip(
                      label: 'API (Remote)',
                      icon: Icons.cloud,
                      isSelected: !isKobold,
                      onTap: () async {
                        if (isKobold) {
                          await llmProvider.setActiveBackend(BackendType.openRouter);
                          _loadAvailableModels();
                          setState(() {});
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Model Selection ──
              if (isKobold) ...[
                _inputLabel('Local Model (.gguf)', required: false),
                const SizedBox(height: 8),
                // KoboldCpp status
                if (llmProvider.koboldService.isRunning)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.green)),
                        const SizedBox(width: 8),
                        Text('KoboldCpp is running', style: TextStyle(color: Colors.green.shade300, fontSize: 12)),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.red)),
                        const SizedBox(width: 8),
                        const Text('KoboldCpp is not running', style: TextStyle(color: Colors.red, fontSize: 12)),
                      ],
                    ),
                  ),
                // Model list
                Container(
                  constraints: const BoxConstraints(maxHeight: 250),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: _localModels.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.folder_open, color: Colors.white24, size: 32),
                                const SizedBox(height: 8),
                                const Text('No .gguf models found', style: TextStyle(color: Colors.white38)),
                                const SizedBox(height: 4),
                                Text('Place models in: ${Provider.of<StorageService>(context, listen: false).modelsDir.path}',
                                    style: const TextStyle(color: Colors.white24, fontSize: 11)),
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: _scanLocalModels,
                                  icon: const Icon(Icons.refresh, size: 14),
                                  label: const Text('Rescan'),
                                  style: TextButton.styleFrom(foregroundColor: Colors.blueAccent),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: _localModels.length,
                          itemBuilder: (context, index) {
                            final file = _localModels[index] as File;
                            final name = p.basename(file.path);
                            final sizeBytes = file.lengthSync();
                            final sizeGB = (sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(1);
                            final isSelected = file.path == _selectedLocalModelPath;
                            return ListTile(
                              dense: true,
                              selected: isSelected,
                              selectedTileColor: Colors.blueAccent.withValues(alpha: 0.15),
                              leading: Icon(
                                isSelected ? Icons.check_circle : Icons.description,
                                size: 18,
                                color: isSelected ? Colors.blueAccent : Colors.white24,
                              ),
                              title: Text(name,
                                  style: TextStyle(color: isSelected ? Colors.blueAccent : Colors.white, fontSize: 13),
                                  overflow: TextOverflow.ellipsis),
                              trailing: Text('${sizeGB}GB', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                              onTap: () => setState(() => _selectedLocalModelPath = file.path),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 12),
                // Reload button + status
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isReloadingKobold || _selectedLocalModelPath.isEmpty
                          ? null
                          : () => _reloadKoboldWithModel(_selectedLocalModelPath),
                      icon: _isReloadingKobold
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.refresh, size: 16),
                      label: Text(_isReloadingKobold ? 'Loading...' : 'Load Model'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.white10,
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: _scanLocalModels,
                      icon: const Icon(Icons.folder_open, size: 14),
                      label: const Text('Rescan'),
                      style: TextButton.styleFrom(foregroundColor: Colors.white38),
                    ),
                    const SizedBox(width: 12),
                    if (_koboldStatus.isNotEmpty)
                      Expanded(
                        child: Text(_koboldStatus,
                          style: TextStyle(
                            color: _koboldStatus.contains('Error') ? Colors.red : Colors.white54,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ] else ...[
                // API model picker
                _inputLabel('Generation Model', required: false),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: _isLoadingModels
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Row(
                            children: [
                              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38)),
                              SizedBox(width: 12),
                              Text('Loading models...', style: TextStyle(color: Colors.white38, fontSize: 13)),
                            ],
                          ),
                        )
                      : InkWell(
                          onTap: () async {
                            final result = await _showModelSearchDialog(
                              title: 'Select Generation Model',
                              currentValue: _selectedModelId,
                            );
                            if (result != null) {
                              setState(() => _selectedModelId = result);
                              _saveState();
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                const Icon(Icons.search, size: 16, color: Colors.white24),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _selectedModelId.isEmpty
                                        ? 'Select a model...'
                                        : (_availableModels.where((m) => m.id == _selectedModelId).firstOrNull?.name ?? _selectedModelId),
                                    style: TextStyle(color: _selectedModelId.isEmpty ? Colors.white38 : Colors.white, fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(Icons.arrow_drop_down, color: Colors.white38),
                              ],
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Tip: Use a non-thinking model (GPT-4o, Claude, Gemini) for best results.',
                  style: TextStyle(color: Colors.white24, fontSize: 11),
                ),
              ],
              const SizedBox(height: 24),

              // ── Editor Pass Section ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF162032),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.edit_note, color: Colors.deepPurpleAccent, size: 20),
                        const SizedBox(width: 8),
                        const Text('Editor Pass',
                          style: TextStyle(color: Colors.deepPurpleAccent, fontSize: 14, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Text(
                          _editorAntiPuppet || _editorConsistency || _editorQuality
                              ? 'Extra API calls will be made'
                              : 'Disabled',
                          style: TextStyle(
                            color: _editorAntiPuppet || _editorConsistency || _editorQuality
                                ? Colors.deepPurple.shade200
                                : Colors.white24,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _editorToggle(
                      'Anti-Puppet Check',
                      'Scans greetings for {{user}} puppeting and rewrites offending lines',
                      Icons.shield_outlined,
                      _editorAntiPuppet,
                      (val) => setState(() { _editorAntiPuppet = val; _saveState(); }),
                    ),
                    _editorToggle(
                      'Consistency Check',
                      'Verifies greetings match the character\'s personality and scenario',
                      Icons.fact_check_outlined,
                      _editorConsistency,
                      (val) => setState(() { _editorConsistency = val; _saveState(); }),
                    ),
                    _editorToggle(
                      'Quality Polish',
                      'Improves prose quality, pacing, and immersiveness',
                      Icons.auto_fix_high,
                      _editorQuality,
                      (val) => setState(() { _editorQuality = val; _saveState(); }),
                    ),
                    // Editor model selector (only if any toggle is on AND using remote backend)
                    if ((_editorAntiPuppet || _editorConsistency || _editorQuality) && !isKobold) ...[
                      const SizedBox(height: 12),
                      const Text('Editor Model', style: TextStyle(color: Colors.deepPurple, fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      const Text('Can be a different model than the generator (e.g. a thinking model)',
                        style: TextStyle(color: Colors.white24, fontSize: 11)),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.3)),
                        ),
                        child: _isLoadingModels
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 14),
                                child: Text('Loading models...', style: TextStyle(color: Colors.white38, fontSize: 13)),
                              )
                            : InkWell(
                                onTap: () async {
                                  final result = await _showModelSearchDialog(
                                    title: 'Select Editor Model',
                                    currentValue: _editorModelId,
                                    showSameAsGenerator: true,
                                  );
                                  if (result != null) {
                                    setState(() => _editorModelId = result);
                                    _saveState();
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.search, size: 16, color: Colors.white24),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _editorModelId.isEmpty
                                              ? 'Same as generator'
                                              : (_availableModels.where((m) => m.id == _editorModelId).firstOrNull?.name ?? _editorModelId),
                                          style: TextStyle(color: _editorModelId.isEmpty ? Colors.white54 : Colors.white, fontSize: 13),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const Icon(Icons.arrow_drop_down, color: Colors.white38),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Next button
              Center(
                child: SizedBox(
                  width: 280,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => setState(() => _currentStep = 1),
                    icon: const Icon(Icons.arrow_forward, size: 20),
                    label: const Text('Next: Configure Character', style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _backendChip({required String label, required IconData icon, required bool isSelected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueAccent.withValues(alpha: 0.15) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? Colors.blueAccent : Colors.white12, width: isSelected ? 2 : 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.blueAccent : Colors.white38),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: isSelected ? Colors.blueAccent : Colors.white54, fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  STEP 1: Character Configuration
  // ═══════════════════════════════════════════════════════════════


  Widget _buildConfigStep() {
    return Center(
      key: const ValueKey('config'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'Bring Your Character to Life',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                'Give us a name and a concept — the AI will do the rest. '
                'It will generate a complete character card with personality, backstory, '
                'dialogue examples, and a custom avatar.',
                style: TextStyle(fontSize: 14, color: Colors.white54, height: 1.5),
              ),
              const SizedBox(height: 32),

              // Name
              _inputLabel('Character Name', required: true),
              const SizedBox(height: 8),
              _styledTextField(
                controller: _nameController,
                hint: 'e.g. Aria Blackwood, Captain Zara, Luna...',
                maxLines: 1,
              ),
              const SizedBox(height: 24),

              // Concept
              _inputLabel('Concept / Description', required: true),
              const SizedBox(height: 8),
              _styledTextField(
                controller: _conceptController,
                hint: 'Describe your character in a few sentences...\n'
                    'e.g. "A sarcastic elven librarian in a steampunk city who secretly fights crime at night"',
                maxLines: 4,
              ),
              const SizedBox(height: 16),

              // Age, Sex, Relationship — compact row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _inputLabel('Age', required: false),
                        const SizedBox(height: 8),
                        _styledTextField(
                          controller: _ageController,
                          hint: 'e.g. 25, Ancient...',
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _inputLabel('Sex', required: false),
                        const SizedBox(height: 8),
                        _styledTextField(
                          controller: _sexController,
                          hint: 'e.g. Female, Male...',
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _inputLabel('Relationship to {{user}}', required: false),
                        const SizedBox(height: 8),
                        _styledTextField(
                          controller: _relationshipController,
                          hint: 'e.g. Childhood friend, Boss, Rival...',
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Personality keywords
              _inputLabel('Personality Keywords', required: false),
              const SizedBox(height: 8),
              _styledTextField(
                controller: _keywordsController,
                hint: 'e.g. witty, secretive, bookish, brave, loyal...',
                maxLines: 1,
              ),
              const SizedBox(height: 24),

              // Art style
              _inputLabel('Avatar Art Style', required: false),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _artStyles.map((style) {
                  final isSelected = _artStyle == style;
                  return ChoiceChip(
                    label: Text(style),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _artStyle = style),
                    selectedColor: Colors.blueAccent,
                    backgroundColor: const Color(0xFF1E293B),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 13,
                    ),
                    side: BorderSide(
                      color: isSelected ? Colors.blueAccent : Colors.white12,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Greeting tone (multi-select, capped to total greeting count)
              _inputLabel('Greeting Tones', required: false),
              const SizedBox(height: 4),
              Text(
                _altGreetingCount == 0
                    ? 'Tone for the first message.'
                    : 'Select up to ${_altGreetingCount + 1} — one per greeting (first message + $_altGreetingCount alternate${_altGreetingCount == 1 ? '' : 's'}).',
                style: const TextStyle(color: Colors.white24, fontSize: 11),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _greetingTones.map((tone) {
                  final isSelected = _selectedTones.contains(tone);
                  final maxTones = _altGreetingCount + 1;
                  final atLimit = _selectedTones.length >= maxTones && !isSelected;
                  return FilterChip(
                    label: Text(tone),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          if (atLimit) {
                            // At limit — swap: remove the last tone and add this one
                            _selectedTones.remove(_selectedTones.last);
                          }
                          _selectedTones.add(tone);
                        } else if (_selectedTones.length > 1) {
                          _selectedTones.remove(tone);
                        }
                      });
                      _saveState();
                    },
                    selectedColor: Colors.blueAccent,
                    backgroundColor: const Color(0xFF1E293B),
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 13,
                    ),
                    side: BorderSide(
                      color: isSelected ? Colors.blueAccent : Colors.white12,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // First message length + Alt greeting count — side by side
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // First message length
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _inputLabel('First Message Length', required: false),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _greetingLength,
                              isExpanded: true,
                              dropdownColor: const Color(0xFF1E293B),
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              items: _greetingLengths.map((len) => DropdownMenuItem(
                                value: len,
                                child: Text(len),
                              )).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _greetingLength = value);
                                  _saveState();
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Number of alternate greetings
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _inputLabel('Alternate Greetings', required: false),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Slider(
                                value: _altGreetingCount.toDouble(),
                                min: 0,
                                max: 5,
                                divisions: 5,
                                activeColor: Colors.blueAccent,
                                inactiveColor: Colors.white12,
                                label: '$_altGreetingCount',
                                onChanged: (val) {
                                  setState(() {
                                    _altGreetingCount = val.round();
                                    // Trim excess tones if count decreased
                                    final maxTones = _altGreetingCount + 1;
                                    while (_selectedTones.length > maxTones) {
                                      _selectedTones.remove(_selectedTones.last);
                                    }
                                  });
                                  _saveState();
                                },
                              ),
                            ),
                            SizedBox(
                              width: 24,
                              child: Text('$_altGreetingCount', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Lorebook toggle
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.menu_book, color: Colors.blueAccent, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Auto-generate Lorebook entries',
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                    ),
                    Switch(
                      value: _generateLorebook,
                      activeColor: Colors.blueAccent,
                      onChanged: (val) {
                        setState(() => _generateLorebook = val);
                        _saveState();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Persona selector
              _inputLabel('{{user}} Persona for Greetings', required: false),
              const SizedBox(height: 4),
              const Text(
                'Select a persona to tailor greetings, or "None" for public cards.',
                style: TextStyle(color: Colors.white24, fontSize: 11),
              ),
              const SizedBox(height: 8),
              Builder(builder: (context) {
                final personaService = Provider.of<UserPersonaService>(context);
                final personas = personaService.personas;
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedPersonaId,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Row(
                            children: [
                              Icon(Icons.person_off, size: 16, color: Colors.white38),
                              SizedBox(width: 8),
                              Text('None (Blank Slate)', style: TextStyle(color: Colors.white54)),
                            ],
                          ),
                        ),
                        ...personas.map((p) => DropdownMenuItem(
                          value: p.id,
                          child: Row(
                            children: [
                              const Icon(Icons.person, size: 16, color: Colors.blueAccent),
                              const SizedBox(width: 8),
                              Flexible(child: Text(p.displayLabel, overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        )),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedPersonaId = value ?? '');
                        _saveState();
                      },
                    ),
                  ),
                );
              }),
              const SizedBox(height: 32),

              // Back + Generate buttons
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() => _currentStep = 0),
                        icon: const Icon(Icons.arrow_back, size: 18),
                        label: const Text('Back', style: TextStyle(fontSize: 14)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white54,
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 240,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _nameController.text.trim().isEmpty || _conceptController.text.trim().isEmpty
                            ? null
                            : _startGeneration,
                        icon: const Icon(Icons.auto_awesome, size: 20),
                        label: const Text('Generate Character', style: TextStyle(fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.white10,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inputLabel(String text, {bool required = false}) {
    return Row(
      children: [
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
        if (required) const Text(' *', style: TextStyle(color: Colors.redAccent)),
      ],
    );
  }

  Widget _editorToggle(String title, String subtitle, IconData icon, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: value ? Colors.deepPurpleAccent : Colors.white24, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: value ? Colors.white : Colors.white54, fontSize: 13, fontWeight: FontWeight.w500)),
                Text(subtitle, style: const TextStyle(color: Colors.white24, fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: Colors.deepPurpleAccent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  /// Show a searchable model picker dialog. Returns the selected model ID or null.
  Future<String?> _showModelSearchDialog({
    required String title,
    required String? currentValue,
    bool showSameAsGenerator = false,
  }) async {
    String searchQuery = '';
    return showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filtered = _availableModels.where((m) {
              if (searchQuery.isEmpty) return true;
              final q = searchQuery.toLowerCase();
              return m.name.toLowerCase().contains(q) || m.id.toLowerCase().contains(q);
            }).toList();

            return Dialog(
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500, maxHeight: 500),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                      child: Row(
                        children: [
                          Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white38, size: 20),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    // Search bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: TextField(
                        autofocus: true,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Search models...',
                          hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                          prefixIcon: const Icon(Icons.search, color: Colors.white24, size: 20),
                          filled: true,
                          fillColor: const Color(0xFF1E293B),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onChanged: (v) => setDialogState(() => searchQuery = v),
                      ),
                    ),
                    const Divider(color: Colors.white12, height: 1),
                    // Model list
                    Flexible(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        children: [
                          if (showSameAsGenerator)
                            _modelListTile(
                              name: 'Same as generator',
                              id: '',
                              isSelected: currentValue == null || currentValue.isEmpty,
                              isThinking: false,
                              onTap: () => Navigator.pop(context, ''),
                            ),
                          ...filtered.map((m) {
                            final isThinking = m.name.toLowerCase().contains('think') ||
                                m.id.toLowerCase().contains('thinking') ||
                                m.id.toLowerCase().contains('reasoner');
                            return _modelListTile(
                              name: m.name.isNotEmpty ? m.name : m.id,
                              id: m.id,
                              isSelected: m.id == currentValue,
                              isThinking: isThinking,
                              onTap: () => Navigator.pop(context, m.id),
                            );
                          }),
                          if (filtered.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(child: Text('No models found', style: TextStyle(color: Colors.white38))),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _modelListTile({
    required String name,
    required String id,
    required bool isSelected,
    required bool isThinking,
    required VoidCallback onTap,
  }) {
    return ListTile(
      dense: true,
      selected: isSelected,
      selectedTileColor: Colors.blueAccent.withValues(alpha: 0.15),
      leading: isThinking
          ? const Icon(Icons.psychology, size: 18, color: Colors.deepPurpleAccent)
          : (id.isEmpty ? const Icon(Icons.link, size: 18, color: Colors.white24) : null),
      title: Text(
        name,
        style: TextStyle(
          color: isSelected ? Colors.blueAccent : (isThinking ? Colors.deepPurple.shade200 : Colors.white),
          fontSize: 13,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      trailing: isSelected ? const Icon(Icons.check, size: 16, color: Colors.blueAccent) : null,
      onTap: onTap,
    );
  }

  Widget _styledTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      onChanged: (_) {
        setState(() {}); // Rebuild to update button state
        _saveState(); // Auto-save on change
      },
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
        filled: true,
        fillColor: const Color(0xFF1E293B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.blueAccent),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  STEP 2: Generation Progress
  // ═══════════════════════════════════════════════════════════════

  Widget _buildGeneratingStep() {
    return Center(
      key: const ValueKey('generating'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            children: [
              const SizedBox(height: 32),
              // Animated icon
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(seconds: 2),
                builder: (_, value, child) => Transform.rotate(
                  angle: value * 6.28,
                  child: child,
                ),
                onEnd: () {}, // Continuous animation via key
                child: const Icon(Icons.auto_awesome, size: 64, color: Colors.amberAccent),
              ),
              const SizedBox(height: 24),
              Text(
                _generationStatus.isEmpty ? 'Generating character...' : _generationStatus,
                style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  backgroundColor: Colors.white10,
                  valueColor: const AlwaysStoppedAnimation(Colors.blueAccent),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 32),
              // Live preview of generation
              if (_generationPreview.isNotEmpty)
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 400),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      _generationPreview,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontFamily: 'monospace',
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  STEP 3: Review & Edit
  // ═══════════════════════════════════════════════════════════════

  Widget _buildReviewStep() {
    if (_generatedCard == null) {
      return Center(
        key: const ValueKey('review-error'),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
            const SizedBox(height: 16),
            const Text(
              'Generation failed. The LLM did not produce valid output.',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => setState(() {
                _currentStep = 1;
                _generationPreview = '';
              }),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      key: const ValueKey('review'),
      padding: const EdgeInsets.all(32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left column — Avatar + quick info
          SizedBox(
            width: 280,
            child: Column(
              children: [
                // Avatar
                Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: const Color(0xFF1E293B),
                    border: Border.all(color: Colors.white12),
                    image: _generatedAvatar != null
                        ? DecorationImage(
                            image: MemoryImage(_generatedAvatar!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _generatedAvatar == null
                      ? Center(
                          child: _isGeneratingAvatar
                              ? const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(color: Colors.blueAccent),
                                    SizedBox(height: 12),
                                    Text('Generating avatar...', style: TextStyle(color: Colors.white38, fontSize: 12)),
                                  ],
                                )
                              : Provider.of<LLMProvider>(context, listen: false).activeBackend == BackendType.kobold
                                  ? Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.content_copy, size: 32, color: Colors.white24),
                                          const SizedBox(height: 8),
                                          const Text('Avatar generation unavailable with KoboldCpp',
                                            style: TextStyle(color: Colors.white38, fontSize: 12),
                                            textAlign: TextAlign.center),
                                          const SizedBox(height: 8),
                                          const Text('Copy the image prompt below to generate locally',
                                            style: TextStyle(color: Colors.white24, fontSize: 11),
                                            textAlign: TextAlign.center),
                                        ],
                                      ),
                                    )
                                  : Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.image_outlined, size: 48, color: Colors.white24),
                                        const SizedBox(height: 8),
                                        TextButton.icon(
                                          onPressed: _generateAvatar,
                                          icon: const Icon(Icons.auto_awesome, size: 16),
                                          label: const Text('Generate Avatar'),
                                        ),
                                      ],
                                    ),
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                if (_generatedAvatar != null)
                  TextButton.icon(
                    onPressed: _isGeneratingAvatar ? null : _generateAvatar,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: Text(_isGeneratingAvatar ? 'Generating...' : 'Regenerate Avatar'),
                    style: TextButton.styleFrom(foregroundColor: Colors.blueAccent),
                  ),
                const SizedBox(height: 12),
                // Editable image prompt — collapsible
                Row(
                  children: [
                    const Text('Image Prompt', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.copy, color: Colors.white38, size: 16),
                      onPressed: () {
                        if (_imagePromptController.text.isNotEmpty) {
                          Clipboard.setData(ClipboardData(text: _imagePromptController.text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Image prompt copied to clipboard'), duration: Duration(seconds: 2)),
                          );
                        }
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Copy prompt to clipboard',
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        _imagePromptExpanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.white38,
                        size: 18,
                      ),
                      onPressed: () => setState(() => _imagePromptExpanded = !_imagePromptExpanded),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: _imagePromptExpanded ? 'Collapse' : 'Expand',
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: _imagePromptController,
                  maxLines: _imagePromptExpanded ? null : 2,
                  minLines: _imagePromptExpanded ? 6 : 2,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Describe the character portrait...',
                    hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white12),
                    ),
                    contentPadding: const EdgeInsets.all(10),
                  ),
                ),
                const SizedBox(height: 16),
                // Character name
                Text(
                  _generatedCard!.name,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                // Tags
                if (_generatedCard!.tags.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: _generatedCard!.tags.map((tag) => Chip(
                      label: Text(tag, style: const TextStyle(fontSize: 11, color: Colors.white70)),
                      backgroundColor: const Color(0xFF374151),
                      side: BorderSide.none,
                      visualDensity: VisualDensity.compact,
                    )).toList(),
                  ),
                const SizedBox(height: 24),
                // Action buttons
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saveCharacter,
                    icon: const Icon(Icons.save),
                    label: const Text('Save Character'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() {
                      _currentStep = 0;
                      _generatedCard = null;
                      _generatedAvatar = null;
                      _generationPreview = '';
                    }),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Start Over'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white54,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 32),

          // Right column — Editable fields
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Review & Edit',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 4),
                const Text(
                  'The AI generated the following character card. Feel free to edit any field before saving.',
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),
                const SizedBox(height: 24),
                _editableField('Description', _descController, maxLines: 6),
                _editableField('Personality', _personalityController, maxLines: 4),
                _editableField('Scenario', _scenarioController, maxLines: 3),
                _editableField('First Message', _firstMessageController, maxLines: 6),
                _editableField('Example Dialogue', _exampleDialogueController, maxLines: 6),
                _editableField('System Prompt', _systemPromptController, maxLines: 3),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _editableField(String label, TextEditingController controller, {int maxLines = 3}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.blueAccent, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            maxLines: maxLines,
            style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.5),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF1E293B),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.blueAccent),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  Logic
  // ═══════════════════════════════════════════════════════════════

  Future<void> _startGeneration() async {
    final name = _nameController.text.trim();
    final concept = _conceptController.text.trim();
    final keywords = _keywordsController.text.trim();

    if (name.isEmpty || concept.isEmpty) return;

    setState(() {
      _currentStep = 2;
      _isGenerating = true;
      _generationStatus = 'Crafting character with AI...';
      _generationPreview = '';
      _progress = 0.0;
    });

    final llmProvider = Provider.of<LLMProvider>(context, listen: false);
    final storage = Provider.of<StorageService>(context, listen: false);

    // Create LLM service based on active backend
    LLMService llmService;
    if (llmProvider.activeBackend == BackendType.kobold) {
      // KoboldCpp — use local backend directly
      final kobold = llmProvider.koboldService;
      if (!kobold.isReady) {
        setState(() {
          _generationStatus = 'Error: KoboldCpp is not running. Start it first.';
          _isGenerating = false;
        });
        return;
      }
      llmService = kobold;
    } else if (_selectedModelId.isNotEmpty && _selectedModelId != llmProvider.openRouterService.modelName) {
      final tempService = OpenRouterService(
        apiUrl: storage.remoteApiUrl,
        apiKey: storage.remoteApiKey,
        modelName: _selectedModelId,
      );
      llmService = tempService;
    } else {
      final active = llmProvider.activeService;
      if (active == null || !active.isReady) {
        setState(() {
          _generationStatus = 'Error: No LLM service available. Configure a model first.';
          _isGenerating = false;
        });
        return;
      }
      llmService = active;
    }

    debugPrint('CharacterGen: Using model: ${_selectedModelId.isNotEmpty ? _selectedModelId : "default"}');

    // Resolve selected persona context
    String userPersonaContext = '';
    if (_selectedPersonaId.isNotEmpty) {
      final personaService = Provider.of<UserPersonaService>(context, listen: false);
      final selectedPersona = personaService.personas
          .where((p) => p.id == _selectedPersonaId)
          .firstOrNull;
      if (selectedPersona != null) {
        final parts = <String>[];
        if (selectedPersona.name.isNotEmpty) parts.add('Name: ${selectedPersona.name}');
        if (selectedPersona.description.isNotEmpty) parts.add('Description: ${selectedPersona.description}');
        if (selectedPersona.persona.isNotEmpty) parts.add('Persona: ${selectedPersona.persona}');
        userPersonaContext = parts.join('\n');
      }
    }

    final genService = CharacterGenService(llmService);

    String lastRawOutput = '';
    String? genError;
    final card = await genService.generateCharacter(
      name: name,
      concept: concept,
      personalityKeywords: keywords,
      artStyle: _artStyle,
      greetingLength: _greetingLength,
      altGreetingCount: _altGreetingCount,
      greetingTones: _selectedTones.toList(),
      generateLorebook: _generateLorebook,
      apiSystemPrompt: storage.systemPrompt,
      age: _ageController.text.trim(),
      sex: _sexController.text.trim(),
      relationship: _relationshipController.text.trim(),
      userPersonaContext: userPersonaContext,
      onProgress: (accumulated) {
        lastRawOutput = accumulated;
        if (mounted) {
          setState(() {
            _generationPreview = accumulated;
            _progress = (accumulated.length / 3000.0).clamp(0.0, 0.95);
          });
        }
      },
      onStatus: (status) {
        if (mounted) {
          setState(() {
            _generationStatus = status;
          });
        }
      },
      onError: (error) {
        genError = error;
        if (mounted) {
          setState(() {
            _generationStatus = 'Error: $error';
          });
        }
      },
    );

    // Extract image prompt before moving to review
    _imagePrompt = genService.extractImagePrompt(lastRawOutput);

    if (card != null) {
      // ── Editor passes ──
      final hasEditorPass = _editorAntiPuppet || _editorConsistency || _editorQuality;
      if (hasEditorPass) {
        // Resolve editor model
        LLMService editorService;
        if (llmProvider.activeBackend == BackendType.kobold) {
          // KoboldCpp — always use local backend for editor too
          editorService = llmService;
        } else {
          final editorModel = _editorModelId.isNotEmpty ? _editorModelId : _selectedModelId;
          if (editorModel.isNotEmpty && editorModel != llmProvider.openRouterService.modelName) {
            editorService = OpenRouterService(
              apiUrl: storage.remoteApiUrl,
              apiKey: storage.remoteApiKey,
              modelName: editorModel,
            );
          } else {
            editorService = llmService;
          }
        }

        final editor = CharacterGenService(editorService);

        void editorProgress(String text) {
          if (mounted) {
            setState(() => _generationPreview = text);
          }
        }

        // Run completion pass first — fix any truncated greetings
        if (mounted) setState(() => _generationStatus = 'Editor: Checking for truncation...');
        final completedFirst = await editor.editorCompletionPass(card.firstMessage, onProgress: editorProgress);
        if (completedFirst != null) card.firstMessage = completedFirst;
        for (int i = 0; i < card.alternateGreetings.length; i++) {
          final completedAlt = await editor.editorCompletionPass(card.alternateGreetings[i], onProgress: editorProgress);
          if (completedAlt != null) card.alternateGreetings[i] = completedAlt;
        }

        // Run anti-puppet check on all greetings
        if (_editorAntiPuppet) {
          if (mounted) setState(() => _generationStatus = 'Editor: Anti-puppet check...');
          card.firstMessage = await editor.editorAntiPuppetCheck(card.firstMessage, onProgress: editorProgress) ?? card.firstMessage;
          for (int i = 0; i < card.alternateGreetings.length; i++) {
            if (mounted) setState(() => _generationStatus = 'Editor: Anti-puppet check (alt ${i + 1})...');
            card.alternateGreetings[i] = await editor.editorAntiPuppetCheck(card.alternateGreetings[i], onProgress: editorProgress) ?? card.alternateGreetings[i];
          }
        }

        // Run consistency check
        if (_editorConsistency) {
          if (mounted) setState(() => _generationStatus = 'Editor: Consistency check...');
          card.firstMessage = await editor.editorConsistencyCheck(
            card.firstMessage, card.description, card.personality, card.scenario,
            onProgress: editorProgress,
          ) ?? card.firstMessage;
          for (int i = 0; i < card.alternateGreetings.length; i++) {
            if (mounted) setState(() => _generationStatus = 'Editor: Consistency check (alt ${i + 1})...');
            card.alternateGreetings[i] = await editor.editorConsistencyCheck(
              card.alternateGreetings[i], card.description, card.personality, card.scenario,
              onProgress: editorProgress,
            ) ?? card.alternateGreetings[i];
          }
        }

        // Run quality polish
        if (_editorQuality) {
          if (mounted) setState(() => _generationStatus = 'Editor: Quality polish...');
          card.firstMessage = await editor.editorQualityPolish(card.firstMessage, onProgress: editorProgress) ?? card.firstMessage;
          for (int i = 0; i < card.alternateGreetings.length; i++) {
            if (mounted) setState(() => _generationStatus = 'Editor: Quality polish (alt ${i + 1})...');
            card.alternateGreetings[i] = await editor.editorQualityPolish(card.alternateGreetings[i], onProgress: editorProgress) ?? card.alternateGreetings[i];
          }
        }
      }

      _generatedCard = card;
      _descController.text = card.description;
      _personalityController.text = card.personality;
      _scenarioController.text = card.scenario;
      _firstMessageController.text = card.firstMessage;
      _exampleDialogueController.text = card.mesExample;
      _systemPromptController.text = card.systemPrompt;

      setState(() {
        _currentStep = 3;
        _isGenerating = false;
        _progress = 1.0;
      });

      // Auto-start avatar generation (API backend only — KoboldCpp has no image API)
      if (llmProvider.activeBackend != BackendType.kobold) {
        _generateAvatar();
      }
    } else {
      setState(() {
        _currentStep = 3; // Show the error state
        _isGenerating = false;
        _generatedCard = null;
      });
    }
  }

  Future<void> _generateAvatar() async {
    if (_isGeneratingAvatar) return;

    final imageGenService = Provider.of<ImageGenService>(context, listen: false);

    // Determine prompt for avatar
    String prompt = _imagePromptController.text.trim();
    if (prompt.isEmpty) {
      if (_imagePrompt != null && _imagePrompt!.isNotEmpty) {
        // Strip character name from the LLM-generated prompt
        String cleanPrompt = _imagePrompt!;
        final charName = _nameController.text.trim();
        if (charName.isNotEmpty) {
          cleanPrompt = cleanPrompt.replaceAll(RegExp(RegExp.escape(charName), caseSensitive: false), '').trim();
          cleanPrompt = cleanPrompt.replaceAll(RegExp(r'\s{2,}'), ' ').replaceAll(RegExp(r'^[,\.\s]+'), '');
        }
        // Append art style as a tag, not a sentence
        prompt = '$cleanPrompt, $_artStyle style';
      } else {
        // Fallback: build from description without name
        final desc = _descController.text;
        prompt = 'character portrait, $_artStyle style, $desc';
        if (prompt.length > 500) prompt = '${prompt.substring(0, 500)}...';
      }
      _imagePromptController.text = prompt;
    }

    setState(() => _isGeneratingAvatar = true);

    try {
      final imageBytes = await imageGenService.generateImage(
        prompt: prompt,
        size: '512x512',
      );

      if (mounted && imageBytes != null) {
        setState(() {
          _generatedAvatar = imageBytes;
          _isGeneratingAvatar = false;
        });
      } else {
        if (mounted) {
          setState(() => _isGeneratingAvatar = false);
        }
      }
    } catch (e) {
      debugPrint('CharacterCreator: Avatar gen failed: $e');
      if (mounted) {
        setState(() => _isGeneratingAvatar = false);
      }
    }
  }

  Future<void> _saveCharacter() async {
    if (_generatedCard == null) return;

    final repo = Provider.of<CharacterRepository>(context, listen: false);
    final storage = Provider.of<StorageService>(context, listen: false);

    // Update card with edited fields
    final card = _generatedCard!;
    card.description = _descController.text;
    card.personality = _personalityController.text;
    card.scenario = _scenarioController.text;
    card.firstMessage = _firstMessageController.text;
    card.mesExample = _exampleDialogueController.text;
    card.systemPrompt = _systemPromptController.text;

    // Save avatar image
    if (_generatedAvatar != null) {
      final rootPath = storage.rootPath ?? '.';
      final charDir = Directory(p.join(rootPath, 'characters'));
      if (!charDir.existsSync()) charDir.createSync(recursive: true);

      final epoch = DateTime.now().millisecondsSinceEpoch;
      final safeName = card.name.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(' ', '_');
      final imagePath = p.join(charDir.path, '${safeName}_$epoch.png');

      // Write the raw image — V2 embedding is handled by the repo
      await File(imagePath).writeAsBytes(_generatedAvatar!);
      card.imagePath = imagePath;
    }

    // Add to repository
    repo.addCharacter(card);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
              const SizedBox(width: 8),
              Text('${card.name} created successfully!'),
            ],
          ),
          backgroundColor: const Color(0xFF2A2A2A),
          behavior: SnackBarBehavior.floating,
        ),
      );
      // Clear saved form data since character was created
      final prefs = await SharedPreferences.getInstance();
      for (final key in [_prefName, _prefConcept, _prefKeywords, _prefArtStyle]) {
        await prefs.remove(key);
      }
      Navigator.of(context).pop();
    }
  }
}
