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

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:front_porch_ai/services/services.dart';
import 'package:front_porch_ai/services/image_prompt/image_gen_context.dart';
import 'package:front_porch_ai/services/image_prompt/image_prompt_builder.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';
import 'package:front_porch_ai/ui/dialogs/image_crop_dialog.dart';
import 'package:front_porch_ai/utils/picker_prefs.dart';

import 'studio_helpers.dart';
import 'studio_view.dart';

/// The Image Studio: one shared canvas driven by a **Subject** selector
/// (Freeform / Character / Your persona). Backend/model/size/steps/CFG/sampler/
/// scheduler/seed/LoRA controls live in the collapsible [StudioSettingsPanel].
/// Picking Character/Persona auto-fills the prompt from their appearance (via
/// the [ImagePromptBuilder]); Freeform is yours (blank + Craft distills the
/// current chat scene). Layout lives in [StudioView]; this owns the session
/// state + handlers.
class ImageStudio extends StatefulWidget {
  final ImageGenMode mode;
  final String? customPrompt;
  final String? lastMessage;
  final String? characterName;
  final String? characterDescription;
  final String? characterPersonality; // signature compat only

  /// Group-chat cast (name + appearance). Empty for 1:1 chats. When non-empty,
  /// the Subject picker offers a per-member portrait picker plus a caveated
  /// whole-cast "Group shot".
  final List<({String name, String description})> groupCharacters;
  final String? scenario;
  final String? worldInfo;
  final String? personaName;
  final String? personaText;
  final List<String>? recentMessages;
  final LLMService? llmService;
  final void Function(String path)? onAccept;

  /// When provided (chat launches), the result view offers "Send to chat":
  /// the callback attaches the image bytes + final prompt to the conversation.
  final Future<void> Function(Uint8List bytes, String prompt)? onSendToChat;

  // Richer context wired from the chat launch for better prompts.
  final String? currentExpression;
  final String? timeOfDay;
  final String? lightingHint;
  final bool isGroupNonObserver;
  final String? currentSpeakerId;

  const ImageStudio({
    super.key,
    required this.mode,
    this.customPrompt,
    this.lastMessage,
    this.characterName,
    this.characterDescription,
    this.characterPersonality,
    this.groupCharacters = const [],
    this.scenario,
    this.worldInfo,
    this.personaName,
    this.personaText,
    this.recentMessages,
    this.llmService,
    this.onAccept,
    this.onSendToChat,
    this.currentExpression,
    this.timeOfDay,
    this.lightingHint,
    this.isGroupNonObserver = false,
    this.currentSpeakerId,
  });

  @override
  State<ImageStudio> createState() => _ImageStudioState();
}

class _ImageStudioState extends State<ImageStudio> {
  // Session state (owned here; no god proliferation).
  late String _selectedStyle;
  late String _paradigm;

  // Group-chat subject: the picked cast member, or a whole-cast "group shot".
  // Both null/false → fall back to the 1:1 character passed on the widget.
  String? _pickedGroupName;
  String? _pickedGroupDesc;
  bool _groupShot = false;
  late String _editablePrompt;
  late String _negativeForGen;
  Uint8List? _currentImageBytes;
  String _error = '';
  bool _isCrafting = false;
  bool _isGenerating = false;
  bool _saving = false;

  /// The active subject; `widget.mode` is only the initial selection.
  late ImageGenMode _activeMode;

  /// Optional img2img reference (transient, never persisted). When set, Generate
  /// runs img2img at the shared imageGenDenoise strength on the local backends;
  /// remote APIs ignore it (the picker hides itself there).
  Uint8List? _referenceImageBytes;

  // History: session-local thumbnails + restoreable prompt/bytes.
  final List<({String prompt, Uint8List bytes, String style})> _history = [];

  late final ImagePromptBuilder _builder;
  late ImageGenContext _ctx;

  @override
  void initState() {
    super.initState();
    final storage = Provider.of<StorageService>(context, listen: false);
    _selectedStyle = storage.imageGenStyle;
    _paradigm = storage.imageGenSettings.imageGenPromptParadigm;
    _negativeForGen = storage.imageGenNegativePrompt;
    _activeMode = widget.mode;
    _builder = ImagePromptBuilder(llmService: widget.llmService);
    // No boilerplate prefill for ANY subject: an empty box (with a guiding
    // hint) until the user types or taps "Write it for me". Dumping the raw
    // character description made both a poor prompt and poor UX.
    _editablePrompt = '';
    _ctx = _makeContextForMode(_activeMode);
  }

  /// Build a fresh snapshot ctx for the given subject.
  ImageGenContext _makeContextForMode(ImageGenMode mode) {
    return ImageGenContext(
      mode: mode,
      style: _selectedStyle,
      paradigm: _paradigm,
      characterName: _activeCharName,
      characterDescription: _activeCharDesc,
      lastMessage: (mode == ImageGenMode.customPrompt
          ? widget.customPrompt
          : widget.lastMessage),
      scenario: widget.scenario,
      worldInfo: widget.worldInfo,
      personaName: widget.personaName,
      personaText: widget.personaText,
      recentMessages: widget.recentMessages,
      currentExpression: widget.currentExpression,
      timeOfDay: widget.timeOfDay,
      lightingHint: widget.lightingHint,
      isGroupNonObserver: widget.isGroupNonObserver,
      currentSpeakerId: widget.currentSpeakerId,
    );
  }

  /// Switch subject: rebuild the ctx snapshot and clear the prompt box — no
  /// bleed between subjects, and no raw-description prefill (the user types or
  /// taps "Write it for me").
  void _selectSubject(ImageGenMode mode) {
    setState(() {
      _activeMode = mode;
      // Leaving the Character subject clears any group pick/shot.
      if (mode != ImageGenMode.characterPortrait) {
        _pickedGroupName = null;
        _pickedGroupDesc = null;
        _groupShot = false;
      }
      _ctx = _makeContextForMode(mode);
      _editablePrompt = '';
    });
  }

  /// Name for the portrait context: a whole-cast label, a picked group member,
  /// else the 1:1 chat character.
  String? get _activeCharName {
    if (_groupShot) {
      return 'the group (${widget.groupCharacters.map((c) => c.name).join(', ')})';
    }
    return _pickedGroupName ?? widget.characterName;
  }

  /// Appearance for the portrait context: all members' appearances for a group
  /// shot, a picked member's, else the 1:1 character's.
  String? get _activeCharDesc {
    if (_groupShot) {
      return widget.groupCharacters
          .map((c) => '${c.name}: ${c.description}')
          .join('\n\n');
    }
    return _pickedGroupDesc ?? widget.characterDescription;
  }

  /// Portrait one chosen group member (reliable — a single subject).
  void _pickGroupMember(int index) {
    if (index < 0 || index >= widget.groupCharacters.length) return;
    setState(() {
      final m = widget.groupCharacters[index];
      _pickedGroupName = m.name;
      _pickedGroupDesc = m.description;
      _groupShot = false;
      _activeMode = ImageGenMode.characterPortrait;
      _ctx = _makeContextForMode(_activeMode);
      _editablePrompt = '';
    });
  }

  /// Attempt the whole cast in one image. Honestly caveated in the UI — vanilla
  /// diffusion renders multiple specific characters unreliably.
  void _pickGroupShot() {
    setState(() {
      _pickedGroupName = null;
      _pickedGroupDesc = null;
      _groupShot = true;
      _activeMode = ImageGenMode.characterPortrait;
      _ctx = _makeContextForMode(_activeMode);
      _editablePrompt = '';
    });
  }

  Future<void> _craftWithLlmIfAvailable() async {
    // Re-query the live LLM at craft time (the launch snapshot may be stale).
    final llmProvider = Provider.of<LLMProvider>(context, listen: false);
    final liveLlm = llmProvider.activeService.isReady
        ? llmProvider.activeService
        : widget.llmService;

    if (liveLlm == null || !liveLlm.isReady) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'LLM not ready for smart crafting (using static quality)',
            ),
            backgroundColor: AppColors.surfaceContainerOf(context),
          ),
        );
      }
      return;
    }
    setState(() {
      _isCrafting = true;
      _error = '';
    });

    try {
      final service = Provider.of<ImageGenService>(context, listen: false);
      final crafted = await service.generateSmartPrompt(
        mode: _activeMode,
        style: _selectedStyle,
        llmService: liveLlm,
        customPrompt: widget.customPrompt,
        lastMessage: widget.lastMessage,
        characterName: widget.characterName,
        characterDescription: widget.characterDescription,
        characterPersonality: widget.characterPersonality,
        scenario: widget.scenario,
        worldInfo: widget.worldInfo,
        personaName: widget.personaName,
        personaText: widget.personaText,
        recentMessages: widget.recentMessages,
        currentExpression: widget.currentExpression,
        timeOfDay: widget.timeOfDay,
        lightingHint: widget.lightingHint,
        isGroupNonObserver: widget.isGroupNonObserver,
        currentSpeakerId: widget.currentSpeakerId,
        // Box content → guidance the LLM parses in (blank Freeform → scene).
        userInstruction: _editablePrompt.trim().isNotEmpty
            ? _editablePrompt.trim()
            : null,
      );
      if (mounted) {
        setState(() {
          _editablePrompt = crafted;
          _isCrafting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCrafting = false;
          _error =
              'Craft failed: ${e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '')}';
        });
      }
    }
  }

  /// Re-apply the live style suffix to a non-empty prompt so Generate sends the
  /// currently chosen style. No-op on an empty box (avoids glue+style synthesis).
  void _reapplyStyle() {
    if (_editablePrompt.trim().isEmpty) return;
    _editablePrompt = reapplyCurrentStyleSuffix(
      _editablePrompt,
      _selectedStyle,
      _paradigm,
      _builder,
    );
  }

  void _updateStyle(String newStyle) {
    Provider.of<StorageService>(
      context,
      listen: false,
    ).setImageGenStyle(newStyle); // persist global default
    setState(() {
      _selectedStyle = newStyle;
      _reapplyStyle();
    });
  }

  void _updateParadigm(String p) => setState(() {
    _paradigm = p;
    _reapplyStyle();
  });

  void _updatePrompt(String text) => setState(() => _editablePrompt = text);
  void _updateNegative(String text) => setState(() => _negativeForGen = text);

  bool get _isBusy => _isCrafting || _isGenerating || _saving;
  bool get _isPortraitSubject =>
      _activeMode == ImageGenMode.characterPortrait ||
      _activeMode == ImageGenMode.userAvatar;

  Future<void> _generate() async {
    final prompt = _editablePrompt.trim();
    if (prompt.isEmpty) return;

    setState(() {
      _isGenerating = true;
      _error = '';
      _currentImageBytes = null;
    });

    final service = Provider.of<ImageGenService>(context, listen: false);
    try {
      final bytes = await service.generateImage(
        prompt: prompt,
        negativePrompt: _negativeForGen,
        isPortrait: _isPortraitSubject, // portraits orient vertically
        referenceImage: _referenceImageBytes, // img2img on local backends
      );

      if (!mounted) return;
      setState(() {
        _isGenerating = false;
        _currentImageBytes = bytes;
        if (bytes == null) {
          _error = service.statusMessage.isNotEmpty
              ? service.statusMessage
              : 'Generation returned no image';
        } else {
          _history.insert(0, (
            prompt: prompt,
            bytes: bytes,
            style: _selectedStyle,
          ));
          if (_history.length > 8) _history.removeLast();
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _error = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
        });
      }
    }
  }

  /// Pick a transient img2img reference (desktop file dialog; not persisted).
  Future<void> _pickReferenceImage() async {
    final result = await PickerPrefs.pickFiles(
      category: PickerPrefs.catImage,
      dialogTitle: 'Select a reference image',
      type: FileType.image,
      withData: true,
    );
    final bytes = (result != null && result.files.isNotEmpty)
        ? result.files.first.bytes
        : null;
    if (bytes != null && mounted) {
      setState(() => _referenceImageBytes = bytes);
    }
  }

  Future<void> _variations() async {
    if (_currentImageBytes == null) return;
    final currentPrompt = _editablePrompt.trim();
    if (currentPrompt.isEmpty) return;
    // Nudge the prompt for variety without permanently mutating user text.
    final prevPrompt = _editablePrompt;
    setState(() => _editablePrompt = '$currentPrompt, variation');
    await _generate();
    if (mounted) setState(() => _editablePrompt = prevPrompt);
  }

  /// Return to the workspace with the current prompt for tweaking.
  void _editAndRegen() => setState(() {
    _currentImageBytes = null;
    _error = '';
  });

  Future<void> _save() async {
    if (_currentImageBytes == null) return;
    setState(() => _saving = true);
    final service = Provider.of<ImageGenService>(context, listen: false);
    final path = await service.saveImageToDisk(_currentImageBytes);
    if (mounted) {
      setState(() => _saving = false);
      if (path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image saved to $path'),
            backgroundColor: AppColors.resolve(
              context,
              AppColors.logReady,
              AppColors.lightBorder,
            ),
          ),
        );
      }
    }
  }

  Future<void> _accept() async {
    if (_currentImageBytes == null) return;
    setState(() => _saving = true);
    final service = Provider.of<ImageGenService>(context, listen: false);

    // Accept only applies to portrait subjects → crop then save as an avatar.
    final croppedBytes = await ImageCropDialog.show(
      context,
      imageBytes: _currentImageBytes!,
    );
    if (croppedBytes == null) {
      if (mounted) setState(() => _saving = false);
      return;
    }
    final path = await service.saveAvatarToDisk(
      croppedBytes,
      characterName: widget.characterName ?? widget.personaName,
    );

    if (mounted) {
      setState(() => _saving = false);
      if (path != null) {
        if (_activeMode == ImageGenMode.userAvatar) {
          final personaService = Provider.of<UserPersonaService>(
            context,
            listen: false,
          );
          final updated = personaService.persona.copyWith(avatarPath: path);
          personaService.updatePersona(updated);
        }
        widget.onAccept?.call(path);
        Navigator.pop(context);
      }
    }
  }

  void _restoreFromHistory(
    ({String prompt, Uint8List bytes, String style}) entry,
  ) {
    setState(() {
      _editablePrompt = entry.prompt;
      _selectedStyle = entry.style;
      _currentImageBytes = entry.bytes;
      _error = '';
    });
  }

  /// The "Send to chat" action, or null when not launched from a conversation.
  VoidCallback? get _sendToChat {
    if (widget.onSendToChat == null) return null;
    return () async {
      final bytes = _currentImageBytes;
      if (bytes == null) return;
      await widget.onSendToChat!(bytes, _editablePrompt.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image sent to chat')),
        );
      }
    };
  }

  @override
  Widget build(BuildContext context) {
    final configured = Provider.of<ImageGenService>(
      context,
      listen: false,
    ).isConfigured;

    return StudioView(
      activeMode: _activeMode,
      characterName: _activeCharName,
      groupCharacters: widget.groupCharacters,
      groupShotActive: _groupShot,
      onPickGroupMember: _pickGroupMember,
      onPickGroupShot: _pickGroupShot,
      selectedStyle: _selectedStyle,
      paradigm: _paradigm,
      prompt: _editablePrompt,
      negative: _negativeForGen,
      referenceBytes: _referenceImageBytes,
      currentImageBytes: _currentImageBytes,
      error: _error,
      isCrafting: _isCrafting,
      isGenerating: _isGenerating,
      saving: _saving,
      isBusy: _isBusy,
      llmAvailable: widget.llmService != null && widget.llmService!.isReady,
      configured: configured,
      builder: _builder,
      ctx: _ctx,
      history: _history,
      onClose: () => Navigator.pop(context),
      onSelectSubject: _selectSubject,
      onStyleChanged: _updateStyle,
      onParadigmChanged: _updateParadigm,
      onPickReference: _pickReferenceImage,
      onClearReference: () => setState(() => _referenceImageBytes = null),
      onPromptChanged: _updatePrompt,
      onNegativeChanged: _updateNegative,
      onCraftLlm: _craftWithLlmIfAvailable,
      onGenerate: _generate,
      onSave: _save,
      onAccept: _accept,
      onVariations: _variations,
      onEditRegen: _editAndRegen,
      onSendToChat: _sendToChat,
      onRestore: _restoreFromHistory,
    );
  }
}

// History uses lightweight records for session-local entries (no extra classes).
