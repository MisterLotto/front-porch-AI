import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:front_porch_ai/services/image_gen_service.dart';
import 'package:front_porch_ai/services/storage_service.dart';
import 'package:front_porch_ai/services/llm_service.dart';

/// Dialog that shows the image generation result with action buttons.
///
/// Displayed as a modal overlay — never injected into chat messages.
class ImageGenDialog extends StatefulWidget {
  final ImageGenMode mode;

  /// Raw context fields — the dialog will use the LLM to craft the prompt.
  final String? customPrompt;
  final String? lastMessage;
  final String? characterName;
  final String? characterDescription;
  final String? characterPersonality;
  final String? scenario;
  final String? worldInfo;
  final String? personaName;
  final String? personaDescription;
  final List<String>? recentMessages;

  /// The active LLM service for smart prompt generation (nullable for fallback).
  final LLMService? llmService;

  /// Callback when user accepts the image for use (avatar/background).
  final void Function(String path)? onAccept;

  const ImageGenDialog({
    super.key,
    required this.mode,
    this.customPrompt,
    this.lastMessage,
    this.characterName,
    this.characterDescription,
    this.characterPersonality,
    this.scenario,
    this.worldInfo,
    this.personaName,
    this.personaDescription,
    this.recentMessages,
    this.llmService,
    this.onAccept,
  });

  /// Show the dialog with raw context — the LLM will craft the prompt.
  static Future<void> show(
    BuildContext context, {
    required ImageGenMode mode,
    String? customPrompt,
    String? lastMessage,
    String? characterName,
    String? characterDescription,
    String? characterPersonality,
    String? scenario,
    String? worldInfo,
    String? personaName,
    String? personaDescription,
    List<String>? recentMessages,
    LLMService? llmService,
    void Function(String path)? onAccept,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ImageGenDialog(
        mode: mode,
        customPrompt: customPrompt,
        lastMessage: lastMessage,
        characterName: characterName,
        characterDescription: characterDescription,
        characterPersonality: characterPersonality,
        scenario: scenario,
        worldInfo: worldInfo,
        personaName: personaName,
        personaDescription: personaDescription,
        recentMessages: recentMessages,
        llmService: llmService,
        onAccept: onAccept,
      ),
    );
  }

  @override
  State<ImageGenDialog> createState() => _ImageGenDialogState();
}

class _ImageGenDialogState extends State<ImageGenDialog> {
  Uint8List? _imageBytes;
  bool _craftingPrompt = false;
  bool _generatingImage = false;
  String _error = '';
  String _currentPrompt = '';
  bool _saving = false;
  late String _selectedStyle;

  @override
  void initState() {
    super.initState();
    final storage = Provider.of<StorageService>(context, listen: false);
    _selectedStyle = storage.imageGenStyle;
    // Pre-set custom prompt text if available
    if (widget.mode == ImageGenMode.customPrompt && widget.customPrompt != null) {
      _currentPrompt = widget.customPrompt!;
    }
    // Don't auto-generate — let user pick style first
  }

  Future<void> _generate() async {
    setState(() {
      _craftingPrompt = true;
      _generatingImage = false;
      _error = '';
      _imageBytes = null;
    });

    final service = Provider.of<ImageGenService>(context, listen: false);
    final storage = Provider.of<StorageService>(context, listen: false);

    try {
      // Phase 1: Craft the prompt via LLM
      final prompt = await service.generateSmartPrompt(
        mode: widget.mode,
        style: _selectedStyle,
        llmService: widget.llmService,
        customPrompt: widget.customPrompt,
        lastMessage: widget.lastMessage,
        characterName: widget.characterName,
        characterDescription: widget.characterDescription,
        characterPersonality: widget.characterPersonality,
        scenario: widget.scenario,
        worldInfo: widget.worldInfo,
        personaName: widget.personaName,
        personaDescription: widget.personaDescription,
        recentMessages: widget.recentMessages,
      );

      if (!mounted) return;
      setState(() {
        _currentPrompt = prompt;
        _craftingPrompt = false;
        _generatingImage = true;
      });

      // Phase 2: Generate the image
      // Use landscape size for backgrounds
      String? size;
      if (widget.mode == ImageGenMode.chatBackground) {
        size = '1792x1024';
      }

      final bytes = await service.generateImage(
        prompt: prompt,
        negativePrompt: storage.imageGenNegativePrompt,
        size: size,
      );

      if (mounted) {
        setState(() {
          _generatingImage = false;
          _imageBytes = bytes;
          if (bytes == null) {
            _error = service.statusMessage;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _craftingPrompt = false;
          _generatingImage = false;
          _error = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
        });
      }
    }
  }

  Future<void> _save() async {
    if (_imageBytes == null) return;
    setState(() => _saving = true);

    final service = Provider.of<ImageGenService>(context, listen: false);
    final path = await service.saveImageToDisk(_imageBytes);

    if (mounted) {
      setState(() => _saving = false);
      if (path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image saved to $path'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _accept() async {
    if (_imageBytes == null) return;
    setState(() => _saving = true);

    final service = Provider.of<ImageGenService>(context, listen: false);
    final path = await service.saveImageToDisk(_imageBytes);

    if (mounted) {
      setState(() => _saving = false);
      if (path != null) {
        widget.onAccept?.call(path);
        Navigator.pop(context);
      }
    }
  }

  String get _modeLabel {
    switch (widget.mode) {
      case ImageGenMode.customPrompt:
        return 'Custom Image';
      case ImageGenMode.visualizeScene:
        return 'Scene Visualization';
      case ImageGenMode.fromLastMessage:
        return 'Message Illustration';
      case ImageGenMode.characterPortrait:
        return 'Character Portrait';
      case ImageGenMode.chatBackground:
        return 'Chat Background';
      case ImageGenMode.userAvatar:
        return 'User Avatar';
    }
  }

  String get _acceptLabel {
    switch (widget.mode) {
      case ImageGenMode.characterPortrait:
        return 'Set as Avatar';
      case ImageGenMode.chatBackground:
        return 'Set as Background';
      case ImageGenMode.userAvatar:
        return 'Set as Avatar';
      default:
        return '';
    }
  }

  bool get _hasAcceptAction =>
      widget.mode == ImageGenMode.characterPortrait ||
      widget.mode == ImageGenMode.chatBackground ||
      widget.mode == ImageGenMode.userAvatar;

  bool get _isBusy => _craftingPrompt || _generatingImage;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1F2937),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 560,
        constraints: const BoxConstraints(maxHeight: 750),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white10)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.purpleAccent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(_modeLabel,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Style selector chips
                    _buildStyleSelector(),

                    const SizedBox(height: 16),

                    // Image display area
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(
                          minHeight: 200, maxHeight: 400),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(12),
                        border: _imageBytes != null
                            ? Border.all(
                                color:
                                    Colors.purpleAccent.withValues(alpha: 0.3),
                                width: 2)
                            : null,
                      ),
                      child: _buildImageArea(),
                    ),

                    const SizedBox(height: 16),

                    // Prompt display
                    if (_currentPrompt.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text('Prompt',
                                    style: TextStyle(
                                        color: Colors.white38,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600)),
                                if (widget.llmService != null)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 6),
                                    child: Icon(Icons.auto_fix_high,
                                        size: 10, color: Colors.purpleAccent),
                                  ),
                                if (widget.llmService != null)
                                  const Text(' AI-crafted',
                                      style: TextStyle(
                                          color: Colors.purpleAccent,
                                          fontSize: 9)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _currentPrompt.length > 300
                                  ? '${_currentPrompt.substring(0, 300)}...'
                                  : _currentPrompt,
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 11),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Action buttons
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStyleSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: ImageGenService.styleLabels.entries.map((entry) {
        final isSelected = _selectedStyle == entry.key;
        return ChoiceChip(
          label: Text(entry.value,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white : Colors.white60,
              )),
          selected: isSelected,
          selectedColor: Colors.purpleAccent,
          backgroundColor: const Color(0xFF374151),
          side: BorderSide(
            color: isSelected ? Colors.purpleAccent : Colors.white12,
          ),
          onSelected: _isBusy
              ? null
              : (selected) {
                  if (selected) {
                    setState(() => _selectedStyle = entry.key);
                    // Persist the style choice
                    final storage =
                        Provider.of<StorageService>(context, listen: false);
                    storage.setImageGenStyle(entry.key);
                  }
                },
        );
      }).toList(),
    );
  }

  Widget _buildImageArea() {
    if (_craftingPrompt) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Colors.purpleAccent.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Crafting prompt...',
                style: TextStyle(color: Colors.purpleAccent, fontSize: 13)),
            const SizedBox(height: 4),
            const Text('Using AI to describe the scene',
                style: TextStyle(color: Colors.white24, fontSize: 11)),
          ],
        ),
      );
    }

    if (_generatingImage) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Colors.blueAccent.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Generating image...',
                style: TextStyle(color: Colors.white38, fontSize: 13)),
            const SizedBox(height: 4),
            const Text('This may take 10-30 seconds',
                style: TextStyle(color: Colors.white24, fontSize: 11)),
          ],
        ),
      );
    }

    if (_error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  color: Colors.redAccent, size: 40),
              const SizedBox(height: 12),
              Text(_error,
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(color: Colors.redAccent, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    if (_imageBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          _imageBytes!,
          fit: BoxFit.contain,
        ),
      );
    }

    // Idle state — show Generate button
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome, color: Colors.purpleAccent, size: 48),
          const SizedBox(height: 16),
          const Text('Choose a style above, then generate',
              style: TextStyle(color: Colors.white38, fontSize: 13)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _generate,
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('Generate'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purpleAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: [
        // Regenerate
        ElevatedButton.icon(
          onPressed: _isBusy ? null : _generate,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Regenerate'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white10,
            foregroundColor: Colors.white70,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),

        // Save
        ElevatedButton.icon(
          onPressed: (_imageBytes == null || _saving) ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.save_alt, size: 16),
          label: const Text('Save'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),

        // Accept (for avatar/background modes)
        if (_hasAcceptAction)
          ElevatedButton.icon(
            onPressed: (_imageBytes == null || _saving) ? null : _accept,
            icon: Icon(
              widget.mode == ImageGenMode.chatBackground
                  ? Icons.wallpaper
                  : Icons.person,
              size: 16,
            ),
            label: Text(_acceptLabel),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purpleAccent,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
      ],
    );
  }
}
