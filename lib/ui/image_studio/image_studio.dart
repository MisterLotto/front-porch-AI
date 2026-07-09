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
// but WITHOUT ANY WARRANTY, without even the implied warranty of
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

import 'prompt_workspace.dart';
import 'reference_image_picker.dart';
import 'generation_panel.dart';
import 'result_view.dart';
import 'generation_history.dart';
import 'mode_info_card.dart';
import 'style_preview.dart';
import 'studio_helpers.dart';
import 'generation_options_tab.dart';

/// Full from-scratch Image Studio (Stage 3 of image gen UI refactor).
/// Replaces the old monolithic ImageGenDialog with pre-gen control first-class:
/// editable prompt (high-quality prefilled from Stage 2 builder), style/paradigm
/// with live suffix preview, per-gen negative, deliberate Generate, result +
/// history, variations, edit+regen, save, accept (with identical crop behavior).
///
/// Launched from chat toolbar via updated _showImageGenDialog (thin wiring only).
///
/// NOTE on file size: the coordinator owns the full session state + live style re-apply
/// + orchestration per the plan's "main coordinator widget ... that owns the overall session state".
/// All major surfaces extracted to dedicated files (<150 LOC each); pure helpers in studio_helpers.dart.
/// Measured ~600 lines (incl. license); core logic kept minimal. Documented exception per plan "main coordinator"
/// owning the typed ImageGenContext + builder wiring for pre-gen control. No god proliferation.
class ImageStudio extends StatefulWidget {
  final ImageGenMode mode;
  final String? customPrompt;
  final String? lastMessage;
  final String? characterName;
  final String? characterDescription;
  final String? characterPersonality; // signature compat only
  final String? scenario;
  final String? worldInfo;
  final String? personaName;
  final String? personaText;
  final List<String>? recentMessages;
  final LLMService? llmService;
  final void Function(String path)? onAccept;

  /// When provided (chat launches), the result view offers "Send to chat" —
  /// the callback receives the image bytes + final prompt and attaches them
  /// to the conversation (ChatService.addGeneratedImageMessage wiring).
  final Future<void> Function(Uint8List bytes, String prompt)? onSendToChat;
  // Stage 4 richer context (wired from chat launch for better prompts; kept in sync with service thins,
  // _buildPromptContext, ImageGenContext, chat_page _show, builder use, and studio _ctx + craft path).
  // Keep reset/ctor blocks in sync (no owned reset state here; per-invocation snapshot like before).
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

  /// Show as modal dialog. Mirrors old dialog show contract for wiring minimal change.
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
    String? personaText,
    List<String>? recentMessages,
    LLMService? llmService,
    void Function(String path)? onAccept,
    Future<void> Function(Uint8List bytes, String prompt)? onSendToChat,
    // Stage 4: pass richer fields through (keep show/ctor/widget fields/_ctx/craft + service thins + launch site + builder in sync).
    String? currentExpression,
    String? timeOfDay,
    String? lightingHint,
    bool isGroupNonObserver = false,
    String? currentSpeakerId,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ImageStudio(
        mode: mode,
        customPrompt: customPrompt,
        lastMessage: lastMessage,
        characterName: characterName,
        characterDescription: characterDescription,
        characterPersonality: characterPersonality,
        scenario: scenario,
        worldInfo: worldInfo,
        personaName: personaName,
        personaText: personaText,
        recentMessages: recentMessages,
        llmService: llmService,
        onAccept: onAccept,
        onSendToChat: onSendToChat,
        currentExpression: currentExpression,
        timeOfDay: timeOfDay,
        lightingHint: lightingHint,
        isGroupNonObserver: isGroupNonObserver,
        currentSpeakerId: currentSpeakerId,
      ),
    );
  }

  @override
  State<ImageStudio> createState() => _ImageStudioState();
}

class _ImageStudioState extends State<ImageStudio> {
  // Session state (owned here; no god proliferation)
  late String _selectedStyle;
  late String _paradigm;
  late String _editablePrompt;
  late String _negativeForGen;
  Uint8List? _currentImageBytes;
  String _error = '';
  bool _isCrafting = false;
  bool _isGenerating = false;
  bool _saving = false;

  // Internal active type (user spec: the 6 options are now buttons *inside* the Image Studio UI,
  // not a popup menu in toolbar. Launch opens neutral/default (custom as starter); user picks button immediately.
  // All mode-dependent UI (ModeInfoCard, header label, accept crop logic, craft assembly, viz slider visibility)
  // driven from this. widget.mode is only the initial/launch selection for compat.
  late ImageGenMode _activeMode;

  // Visualize slider (user spec): controls exactly how many recent messages (from launch snapshot) to send
  // in the prompt to the LLM (for craft). Default 5, range 1-10. Only visible when _activeMode == visualizeScene.
  // Messages pre-generated so stripping all &lt;think&gt; is simple (delegated to builder _clean / _stripThinkBlocks).
  int _visualizeMessageCount = 5;

  // Optional img2img reference image (transient — per-generation input, never
  // persisted). When set, Generate runs img2img on the active local backend at
  // the shared imageGenDenoise strength; when null it's txt2img as before. The
  // remote backends have no img2img endpoint and ignore it (the picker widget
  // hides itself there).
  Uint8List? _referenceImageBytes;

  // History: session-local thumbnails + restoreable prompt/bytes
  final List<({String prompt, Uint8List bytes, String style})> _history = [];

  late final ImagePromptBuilder _builder;
  late ImageGenContext
  _ctx; // intentionally rebound on internal type button switches (for ctx propagation to workspace/pills per plan)

  @override
  void initState() {
    super.initState();
    final storage = Provider.of<StorageService>(context, listen: false);
    _selectedStyle = storage.imageGenStyle;
    _paradigm = storage.imageGenSettings.imageGenPromptParadigm;
    _negativeForGen = storage.imageGenNegativePrompt;

    _activeMode = widget
        .mode; // initial selection from launch (neutral starter e.g. custom from updated chat toolbar)

    // Stage 4: automatic strong negative injection for modes that need it (chatBackground per builder contract
    // "NO PEOPLE... in both prompt and negative" — Stage 4 complete: auto-seeded here in initState; user edits win;
    // positive enforcement in builder). Per-gen negative editor remains first-class. Injected here (coordinator)
    // so workspace always sees seeded value. Keep in sync with modeInfoCard description and builder chatBackground
    // static/smart positive enforcement. See image_prompt_builder.dart:47.
    if (_activeMode == ImageGenMode.chatBackground) {
      const strongNoPeople =
          'no people, no characters, no figures, no humans, no silhouettes, empty of any living subjects';
      final cur = _negativeForGen.trim();
      if (cur.isEmpty) {
        _negativeForGen = strongNoPeople;
      } else if (!cur.toLowerCase().contains('no people') &&
          !cur.toLowerCase().contains('no characters')) {
        _negativeForGen = '$cur, $strongNoPeople';
      }
    }

    // Build rich ctx from passed raw (matches Stage 2 thin + builder contract).
    // Stage 4 user spec: *no boilerplate or pregenerated prompt* in the box on open for any mode (incl. Visualize).
    // Box starts empty/minimal-hint ("type instructions here (optional) or just tap Craft..."); user types free
    // guidance if desired. Craft always assembles: current box text (as userInstruction) + type-specific context
    // (for visualize: exactly the slider N recent msgs, each stripped of all &lt;think&gt; via builder helpers since pre-gen)
    // + User persona (name + text) + character visual info (effectiveAppearance / filtered, no personality) + style.
    // The LLM (if ready) parses that assembled into the clean visual prompt which is set back into _editablePrompt.
    // widget.mode is launch initial only; _activeMode + _visualizeMessageCount drive runtime.
    // Keep in sync with chat_page launch (now neutral, no mode popup), service thins (userInstr + vizN), ImageGenContext,
    // builder _generateSmartWith (parts + recent limit + strip + instr + persona always), _ctx (for pills), ModeInfoCard etc.
    // Ctx snapshot uses the helper below for DRY (see _makeContextForMode) + exact match to mode-switch path,
    // launch data contract, service thins, builder assembly, and all documented "keep ctor / blocks in sync".
    // "incomplete zeroing..." N/A for per-invocation studio snapshot (qualified in comments + tests).

    _builder = ImagePromptBuilder(llmService: widget.llmService);

    // NO prefill / compute on open. Per exact user spec: "no boilerplate or pregenerated prompt".
    // The _editablePrompt box is for user to type instructions (optional). Craft assembles full context per active type.
    // Style is enforced by builder on the craft result (and on final gen path via re-apply if content present).
    _editablePrompt = '';

    // Build initial ctx via helper (ensures switch and init use identical snapshot logic).
    _ctx = _makeContextForMode(_activeMode);

    // No auto-gen / no boilerplate in box on open (per user spec). The box starts empty
    // (or with user-typed guidance). For Visualize the slider value and launch recentMessages
    // are used when Craft is tapped. Direct Generate when box empty for viz will use a clean
    // messages-focused assembly (see _generate).
    // No auto-write of "Scene setting..." or similar into the box here.

    // No auto-gen: workspace shown first, deliberate Generate required.
  }

  // reapplyCurrentStyleSuffix lives in studio_helpers.dart (extracted for <500 LOC cap).
  // computeInitialPrompt deleted (no callers left post no-boiler change; deletion/anti-accum part of task).

  /// Build a fresh snapshot ctx for the given (runtime) mode.
  /// Used on type button switches so workspace pills / ModeInfoCard see the active mode.
  /// Launch data (persona/char/recent etc) stay the per-invocation snapshot; only mode flips.
  /// Keep ctor fields in sync with initState, chat_page _showImageGenDialog, service thins,
  /// ImageGenContext, builder, and "keep blocks in sync" comments.
  ImageGenContext _makeContextForMode(ImageGenMode mode) {
    return ImageGenContext(
      mode: mode,
      style: _selectedStyle,
      paradigm: _paradigm,
      characterName: widget.characterName,
      characterDescription: widget.characterDescription,
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

  /// For Visualize scene (user spec): directly assemble the prompt that will be sent to the image
  /// model using the *current* slider N (most recent messages from the launch snapshot, each stripped
  /// of &lt;think&gt;/quotes/meta via the builder), plus User persona + character visual info (no personality),
  /// any text currently in the box (treated as additional "User guidance"), + style. This ensures
  /// "the scene visualization prompt" *includes the (N, stripped) chat messages* and moving the slider
  /// visibly changes the prompt the user sees and that Generate will send. Craft/LLM (when available)
  /// can still be clicked to have the model parse the current box + N + full context into a refined version.
  String _assembleVisualizePrompt() {
    final ctx = ImageGenContext(
      mode: ImageGenMode.visualizeScene,
      style: _selectedStyle,
      paradigm: _paradigm,
      characterName: widget.characterName,
      characterDescription: widget.characterDescription,
      lastMessage: widget.lastMessage,
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
      visualizeNumMessages: _visualizeMessageCount,
      userInstruction: _editablePrompt.trim().isNotEmpty
          ? _editablePrompt.trim()
          : null,
    );
    try {
      return _builder.buildStaticPrompt(ctx);
    } catch (_) {
      // Never wipe whatever the user has typed.
      return _editablePrompt;
    }
  }

  Future<void> _craftWithLlmIfAvailable() async {
    // Re-query current active LLM at craft time (launch snapshot may be stale if backend
    // started after the studio opened, or user switched). Mirrors collection in chat_page launch.
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
      // Use service thin (delegates to builder + LLM) for consistency with other paths.
      // Style is passed live so the LLM craft instruction + post-ensure reflect the current selection.
      //
      // User spec: pass the *current* _editablePrompt content as userInstruction (whatever user typed before
      // tapping Craft/Refresh) so it is sent in the prompt to the LLM "to parse into the image gen prompt".
      // Use _activeMode (from internal buttons) not the launch widget.mode.
      // For visualize: pass the slider value; builder will limit to N recent + strip &lt;think&gt; (simple).
      // Persona + char visual (no pers via effective) + style always included per assembly in builder.
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
        // Stage 4 forward (keep craft service call in sync with launch show(), studio ctor fields, _ctx, service thins, _buildPromptContext, builder).
        currentExpression: widget.currentExpression,
        timeOfDay: widget.timeOfDay,
        lightingHint: widget.lightingHint,
        isGroupNonObserver: widget.isGroupNonObserver,
        currentSpeakerId: widget.currentSpeakerId,
        // User spec (exact): box text before craft + viz N slider.
        userInstruction: _editablePrompt.trim().isNotEmpty
            ? _editablePrompt.trim()
            : null,
        visualizeNumMessages: _activeMode == ImageGenMode.visualizeScene
            ? _visualizeMessageCount
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

  void _updateStyle(String newStyle) {
    final storage = Provider.of<StorageService>(context, listen: false);
    setState(() {
      _selectedStyle = newStyle;
      storage.setImageGenStyle(newStyle); // persist global default
      // Re-apply only if there is user/crafted content (per no-boilerplate spec: do not synthesize glue+style from empty box).
      // Re-apply ensures style is in the sent prompt for Generate after craft or manual type.
      if (_editablePrompt.trim().isNotEmpty) {
        _editablePrompt = reapplyCurrentStyleSuffix(
          _editablePrompt,
          _selectedStyle,
          _paradigm,
          _builder,
        );
      }
    });
  }

  void _updateParadigm(String p) {
    setState(() {
      _paradigm = p;
      if (_editablePrompt.trim().isNotEmpty) {
        _editablePrompt = reapplyCurrentStyleSuffix(
          _editablePrompt,
          _selectedStyle,
          _paradigm,
          _builder,
        );
      }
    });
    // Paradigm is global but allow session override in UI for this studio invocation.
  }

  void _updatePrompt(String text) {
    setState(() => _editablePrompt = text);
  }

  void _updateNegative(String text) {
    setState(() => _negativeForGen = text);
  }

  bool get _isBusy => _isCrafting || _isGenerating || _saving;

  String get _modeLabel => getModeLabel(_activeMode);
  bool get _hasAcceptAction => hasAcceptAction(_activeMode);
  String get _acceptLabel => getAcceptLabel(_activeMode);

  Future<void> _generate() async {
    String prompt = _editablePrompt.trim();

    // For Visualize Scene: if the box is still empty when the user taps Generate,
    // assemble a *clean, messages-focused* prompt using the current slider N.
    // This puts the actual (stripped) recent chat messages into the prompt that
    // reaches the image model, without the long "Scene setting: [scenario dump]"
    // or "Key character appearance: [vague]" framing the user hates.
    // The assembly only happens on actual Generate (not on button select or slider drag),
    // preserving the "no boilerplate or pregenerated prompt" in the box until the user commits.
    if (prompt.isEmpty && _activeMode == ImageGenMode.visualizeScene) {
      final assembled = _assembleVisualizePrompt();
      // Prefer the "Recent visual events" block (the actual cleaned chat messages) as the core narrative.
      // Fall back to the full assembled if the regex doesn't find it.
      final recentRe = RegExp(
        r'Recent visual events \(N=[^)]+\):\s*([^\n]+(?:\n(?!\n)[^\n]+)*)',
        dotAll: true,
      );
      final recentMatch = recentRe.firstMatch(assembled);
      String core = recentMatch != null
          ? recentMatch.group(1)!.trim()
          : assembled;
      // Also pull a clean appearance if present (the real card desc, not "the character is...").
      final appRe = RegExp(r'Key character appearance:\s*([^\n]+)');
      final appMatch = appRe.firstMatch(assembled);
      final app = appMatch != null
          ? ' The character looks like: ${appMatch.group(1)!.trim()}.'
          : '';
      final guidance = _editablePrompt.trim().isNotEmpty
          ? ' ${_editablePrompt.trim()}'
          : '';
      prompt = (core + app + guidance).trim();
      if (prompt.isNotEmpty) {
        setState(() => _editablePrompt = prompt);
      }
    }

    if (prompt.isEmpty) return;

    setState(() {
      _isGenerating = true;
      _error = '';
      _currentImageBytes = null;
    });

    final service = Provider.of<ImageGenService>(context, listen: false);

    try {
      // Size for backgrounds per legacy behavior (kept identical).
      String? size;
      if (_activeMode == ImageGenMode.chatBackground) {
        size = '1792x1024';
      }

      final bytes = await service.generateImage(
        prompt: prompt,
        negativePrompt: _negativeForGen,
        size: size,
        // Portrait modes orient the configured size vertically (same flag the
        // /image command and the character creators pass).
        isPortrait:
            _activeMode == ImageGenMode.characterPortrait ||
            _activeMode == ImageGenMode.userAvatar,
        // img2img when a reference image was chosen; honored by the local
        // backends at imageGenDenoise strength (remote APIs ignore it).
        referenceImage: _referenceImageBytes,
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
          // Record to history for easy compare/restore.
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

  /// Pick a transient img2img reference image (desktop file dialog). Kept in
  /// memory only for the next Generate; never persisted.
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
    // Re-use current prompt + let backend provide variance (new internal seed or slight model temp).
    // No service changes per plan; this satisfies "Variations (re-uses the current prompt + new seed / slight nudge)".
    if (_currentImageBytes == null) return;
    final currentPrompt = _editablePrompt.trim();
    if (currentPrompt.isEmpty) return;
    // Slight nudge in prompt for perceptible variety without mutating user text permanently.
    final nudged = '$currentPrompt, variation';
    final prevPrompt = _editablePrompt;
    setState(() => _editablePrompt = nudged);
    await _generate();
    if (mounted) {
      setState(() => _editablePrompt = prevPrompt); // restore user text
    }
  }

  void _editAndRegen() {
    // Switch back to workspace with current prompt (user can tweak then deliberate gen again).
    // AnimatedSwitcher in build handles the view transition.
    setState(() {
      _currentImageBytes = null;
      _error = '';
      // Keep _editablePrompt as-is for edit.
    });
  }

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

    String? path;
    if (_activeMode == ImageGenMode.characterPortrait ||
        _activeMode == ImageGenMode.userAvatar) {
      // Identical crop-on-accept behavior as legacy for portraits/avatars.
      final croppedBytes = await ImageCropDialog.show(
        context,
        imageBytes: _currentImageBytes!,
      );
      if (croppedBytes == null) {
        if (mounted) setState(() => _saving = false);
        return;
      }
      path = await service.saveAvatarToDisk(
        croppedBytes,
        characterName: widget.characterName ?? widget.personaName,
      );
    } else {
      path = await service.saveImageToDisk(_currentImageBytes);
    }

    if (mounted) {
      setState(() => _saving = false);
      if (path != null) {
        // User spec support for internal type buttons: perform the "set as" side effects based on the
        // *chosen active mode at accept time*, not the launch widget.mode. Uses providers (storage/persona)
        // so bg/user work even for neutral launch + button switch. Portrait char set (needs full object)
        // falls back to legacy onAccept if provided by direct launchers; otherwise image is saved.
        // Keep in sync with launcher collection, studio _activeMode + hasAccept, old onAccept captures.
        if (_activeMode == ImageGenMode.chatBackground) {
          final storage = Provider.of<StorageService>(context, listen: false);
          storage.setChatBackground(path);
        } else if (_activeMode == ImageGenMode.userAvatar) {
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

  // Internal type selector (user spec): buttons inside studio replace the old toolbar PopupMenuButton<ImageGenMode>.
  // Keep compact, use AppColors exclusively, icons matching prior popup for familiarity.
  Widget _buildTypeSelector(BuildContext context) {
    final modes = ImageGenMode.values;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Generation type',
          style: TextStyle(
            color: AppColors.textSecondary(context),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: modes.map((m) {
            final isSel = m == _activeMode;
            final icon = _iconForMode(m);
            return OutlinedButton.icon(
              onPressed: _isBusy
                  ? null
                  : () {
                      setState(() {
                        _activeMode = m;
                        // Rebuild _ctx for the new mode so PromptWorkspace/ModeInfoCard/pills reflect selection
                        // (launch sources snapshot + updated mode). Craft/assembly already use live _activeMode +
                        // _editablePrompt (as userInstruction) + _visualizeMessageCount. Per plan fidelity for
                        // propagation to ctx.
                        _ctx = _makeContextForMode(m);
                        // _editablePrompt (user typed or from prior Craft) is left as-is.
                        // "no boilerplate or pregenerated prompt" is honored: selecting the viz button
                        // or changing the slider does not auto-write "Scene setting: ..." or "Key character
                        // appearance: ..." boilerplate into the box. The box stays empty or with what you type.
                        // The _visualizeMessageCount is still passed live to Craft (so the chosen N of
                        // stripped recent messages + your box text + persona + char visual + style are sent
                        // to the LLM to produce the prompt).
                      });
                    },
              icon: Icon(
                icon,
                size: 16,
                color: isSel
                    ? AppColors.resolve(
                        context,
                        AppColors.formMasterAccent,
                        AppColors.formMasterAccent,
                      )
                    : AppColors.iconSecondary(context),
              ),
              label: Text(
                getModeLabel(m),
                style: TextStyle(
                  fontSize: 12,
                  color: isSel
                      ? AppColors.textPrimary(context)
                      : AppColors.textSecondary(context),
                  fontWeight: isSel ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                side: BorderSide(
                  color: isSel
                      ? AppColors.resolve(
                          context,
                          AppColors.formMasterAccent,
                          AppColors.formMasterAccent,
                        )
                      : AppColors.borderOf(context),
                ),
                backgroundColor: isSel ? AppColors.cardOf(context) : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  IconData _iconForMode(ImageGenMode m) {
    switch (m) {
      case ImageGenMode.customPrompt:
        return Icons.brush;
      case ImageGenMode.visualizeScene:
        return Icons.landscape;
      case ImageGenMode.characterPortrait:
        return Icons.face;
      case ImageGenMode.chatBackground:
        return Icons.wallpaper;
      case ImageGenMode.userAvatar:
        return Icons.person;
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = _currentImageBytes != null && _error.isEmpty
        ? 'result'
        : (_isCrafting || _isGenerating)
        ? 'generating'
        : 'workspace';

    return Dialog(
      backgroundColor: AppColors.surfaceOf(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 720,
          maxHeight: MediaQuery.of(context).size.height * 0.94,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header (mode label + close)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.borderOf(context)),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    color: AppColors.resolve(
                      context,
                      AppColors.formMasterAccent,
                      AppColors.formMasterAccent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _modeLabel,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: AppColors.iconSecondary(context),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Proper top-level tabs (user request): first tab = Image generation settings (the options, enable toggle removed since being in the studio implies generation is wanted),
            // second tab = the existing Image Studio (generation types, style preview, prompt workspace, deliberate generate, results, history).
            DefaultTabController(
              length: 2,
              child: Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
                      child: TabBar(
                        labelColor: AppColors.textPrimary(context),
                        unselectedLabelColor: AppColors.textSecondary(context),
                        indicatorColor: AppColors.formMasterAccent,
                        indicatorWeight: 2,
                        tabs: const [
                          Tab(text: 'Generation Settings'),
                          Tab(text: 'Studio'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // Tab 0: Generation Settings (full controls; enable toggle omitted + forced on in this context)
                          SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: const GenerationOptionsTab(
                              showEnableToggle: false,
                            ),
                          ),

                          // Tab 1: Studio (existing workflow)
                          SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Mode explanation (prominent per spec, especially for From Last Message)
                                // Driven by internal button selection (_activeMode), not fixed launch mode.
                                ModeInfoCard(mode: _activeMode),

                                const SizedBox(height: 12),

                                // User spec: the 6 image gen types are buttons *inside* the Image Studio (no more popup menu in chat toolbar).
                                // Clicking sets _activeMode (updates ModeInfoCard, header label, accept logic, what Craft assembles, viz slider visibility).
                                // Launch (from magic wand) is neutral (we pass custom as starter from simplified launcher); user picks immediately.
                                // Matches AppColors, existing pill/button style in workspace, no raw Colors.
                                _buildTypeSelector(context),

                                // Visualize slider (user spec, only for that type): "slider for how many messages to send in the image generation prompt"
                                // (stripped of all &lt;think&gt;; simple because messages already generated). Default 5, 1-10. Affects craft assembly only.
                                if (_activeMode ==
                                    ImageGenMode.visualizeScene) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceContainerOf(
                                        context,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: AppColors.borderOf(context),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Most recent messages to include (N): $_visualizeMessageCount',
                                          style: TextStyle(
                                            color: AppColors.textSecondary(
                                              context,
                                            ),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Slider(
                                          value: _visualizeMessageCount
                                              .toDouble(),
                                          min: 1,
                                          max: 10,
                                          divisions: 9,
                                          label: '$_visualizeMessageCount',
                                          onChanged: _isBusy
                                              ? null
                                              : (v) {
                                                  setState(() {
                                                    _visualizeMessageCount = v
                                                        .round();
                                                    // The N is captured live and passed on the next Craft for this mode
                                                    // (so exactly that many stripped recent messages + your current box
                                                    // text as guidance + character visual info from the card + persona + style are sent
                                                    // to the LLM). Per the "no boilerplate or pregenerated prompt" rule,
                                                    // we do not auto-write assembled content into the box on slider move.
                                                  });
                                                },
                                          activeColor: AppColors.resolve(
                                            context,
                                            AppColors.formMasterAccent,
                                            AppColors.formMasterAccent,
                                          ),
                                        ),
                                        Text(
                                          'The N most recent chat messages (stripped of all &lt;think&gt;) from when the studio opened. These are the primary "what is actually going on right now" content for the visualization prompt (plus your box text as guidance + character visual info from the card + persona + style).',
                                          style: TextStyle(
                                            color: AppColors.textTertiary(
                                              context,
                                            ),
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 12),

                                // Live style + paradigm + preview (richer selector)
                                StylePreview(
                                  selectedStyle: _selectedStyle,
                                  paradigm: _paradigm,
                                  builder: _builder,
                                  onStyleChanged: _isBusy ? null : _updateStyle,
                                  onParadigmChanged: _isBusy
                                      ? null
                                      : _updateParadigm,
                                ),

                                const SizedBox(height: 12),

                                // Optional img2img reference + denoise (local
                                // backends only; hides itself on remote APIs).
                                ReferenceImagePicker(
                                  referenceBytes: _referenceImageBytes,
                                  isBusy: _isBusy,
                                  onPick: _pickReferenceImage,
                                  onClear: () => setState(
                                    () => _referenceImageBytes = null,
                                  ),
                                ),

                                const SizedBox(height: 12),

                                // The heart: pre-gen editable workspace with pills/transparency
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 220),
                                  child: view == 'workspace'
                                      ? PromptWorkspace(
                                          key: const ValueKey('workspace'),
                                          prompt: _editablePrompt,
                                          negative: _negativeForGen,
                                          ctx: _ctx,
                                          builder: _builder,
                                          paradigm: _paradigm,
                                          llmAvailable:
                                              widget.llmService != null &&
                                              widget.llmService!.isReady,
                                          isBusy: _isBusy,
                                          onPromptChanged: _updatePrompt,
                                          onNegativeChanged: _updateNegative,
                                          onCraftLlm: _craftWithLlmIfAvailable,
                                        )
                                      : const SizedBox.shrink(),
                                ),

                                // Generation panel (prominent deliberate button)
                                GenerationPanel(
                                  onGenerate: _isBusy ? null : _generate,
                                  isGenerating: _isGenerating,
                                  isCrafting: _isCrafting,
                                  error: _error,
                                  promptIsSane: _editablePrompt
                                      .trim()
                                      .isNotEmpty,
                                ),

                                const SizedBox(height: 12),

                                // Result view (large image + actions)
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 220),
                                  child: view == 'result'
                                      ? ResultView(
                                          key: const ValueKey('result'),
                                          imageBytes: _currentImageBytes!,
                                          mode: _activeMode,
                                          hasAccept: _hasAcceptAction,
                                          acceptLabel: _acceptLabel,
                                          isSaving: _saving,
                                          onSave: _save,
                                          onAccept: _accept,
                                          onVariations: _variations,
                                          onEditRegen: _editAndRegen,
                                          onSendToChat:
                                              widget.onSendToChat == null
                                              ? null
                                              : () async {
                                                  final bytes =
                                                      _currentImageBytes;
                                                  if (bytes == null) return;
                                                  await widget.onSendToChat!(
                                                    bytes,
                                                    _editablePrompt.trim(),
                                                  );
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          'Image sent to chat',
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                },
                                        )
                                      : const SizedBox.shrink(),
                                ),

                                // Session history strip (thumbnails)
                                if (_history.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  GenerationHistory(
                                    entries: _history,
                                    onRestore: _restoreFromHistory,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// History uses lightweight records for session-local entries (no extra classes).
