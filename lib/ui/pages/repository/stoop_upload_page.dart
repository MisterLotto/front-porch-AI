// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// This file is part of Front Porch AI.
//
// Front Porch AI is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// The Drift schema also declares a `World` row class — hide it so `World`
// below always means the model (the same shape .fpworld export uses).
import 'package:front_porch_ai/database/database.dart' hide World;
import 'package:front_porch_ai/models/character_card.dart';
import 'package:front_porch_ai/models/group_chat.dart';
import 'package:front_porch_ai/models/world.dart';
import 'package:front_porch_ai/providers/auth_state.dart';
import 'package:front_porch_ai/services/backporch/backporch.dart';
import 'package:front_porch_ai/services/character_repository.dart';
import 'package:front_porch_ai/services/group_card_exporter.dart';
import 'package:front_porch_ai/services/group_chat_repository.dart';
import 'package:front_porch_ai/services/storage_service.dart';
import 'package:front_porch_ai/services/world_repository.dart';
import 'package:front_porch_ai/ui/pages/repository/stoop_glass.dart';
import 'package:front_porch_ai/ui/pages/repository/stoop_pick_step.dart';
import 'package:front_porch_ai/ui/pages/repository/stoop_standards.dart';
import 'package:front_porch_ai/ui/pages/repository/stoop_tag_selector.dart';
import 'package:front_porch_ai/ui/pages/repository/stoop_world_share.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';
import 'package:front_porch_ai/utils/group_avatar_compositor.dart';
import 'package:front_porch_ai/utils/world_cover.dart';

/// Wizard to share one of the user's local characters to The Stoop. Mirrors the
/// app's create-wizard chrome (step dots + AnimatedSwitcher + nav buttons).
/// Pops `true` once a card has been submitted for review.
class StoopUploadPage extends StatefulWidget {
  /// When set, the wizard runs in UPDATE mode: it is locked to this local
  /// character OR group (the Pick step is skipped) and publishes a new version
  /// of the existing Stoop post [updateStoopId] IN PLACE, instead of creating a
  /// new one. Exactly one of [updateCharacter] / [updateGroup] is set in update
  /// mode.
  final CharacterCard? updateCharacter;
  final GroupChat? updateGroup;
  final String? updateStoopId;

  /// The posted card's current NSFW flag, so update mode preserves it by default.
  final bool initialNsfw;

  /// The posted card's current "Original creator" credit, so update mode
  /// preserves it by default (clearing the field on update removes the credit).
  final String? initialOriginalCreator;

  /// The post's current DISPLAY name + summary, so update mode preserves them
  /// instead of re-seeding from the local card. The display name is the
  /// listing title ("Misty Meadows, Misguided Meteorologist") and may differ
  /// from the card's in-chat name ("Misty", what {{char}} maps to) — without
  /// these, publishing an update would silently revert a custom title.
  final String? initialName;
  final String? initialSummary;

  const StoopUploadPage({
    super.key,
    this.updateCharacter,
    this.updateGroup,
    this.updateStoopId,
    this.initialNsfw = false,
    this.initialOriginalCreator,
    this.initialName,
    this.initialSummary,
  });

  bool get isUpdate =>
      updateStoopId != null &&
      (updateCharacter != null || updateGroup != null);

  @override
  State<StoopUploadPage> createState() => _StoopUploadPageState();
}

class _StoopUploadPageState extends State<StoopUploadPage> {
  static const _steps = ['Pick', 'Details', 'Content', 'Review'];

  /// The Stoop shows at most this many tags per card; cards with more are
  /// trimmed and the creator picks which ones to keep.
  static const _maxTags = 20;

  int _currentStep = 0;
  CharacterCard? _selected;
  GroupChat? _selectedGroup; // set instead of _selected when sharing a group
  World? _selectedWorld; // set when sharing a place (.fpworld) — see below
  final _name = TextEditingController();
  final _summary = TextEditingController();
  final _originalCreator = TextEditingController();
  final _tagInput = TextEditingController();

  /// Every candidate tag (the card's own, plus any the creator types).
  List<String> _tagPool = [];

  /// The subset (≤ [_maxTags]) that will actually be published.
  List<String> _tags = [];
  bool _nsfw = false;
  bool _standardsAck = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _summary.dispose();
    _originalCreator.dispose();
    _tagInput.dispose();
    super.dispose();
  }

  // Prefill the summary from free text, trimming at a word boundary (+ ellipsis)
  // when it's over the 280-char field instead of chopping mid-word.
  void _setSummaryFrom(String text) {
    final desc = text.trim();
    if (desc.length <= 280) {
      _summary.text = desc;
    } else {
      var cut = desc.substring(0, 279);
      final lastSpace = cut.lastIndexOf(' ');
      if (lastSpace > 200) cut = cut.substring(0, lastSpace);
      _summary.text = '${cut.trimRight()}…';
    }
  }

  void _selectGroup(GroupChat group) {
    setState(() => _applyGroupSelection(group));
  }

  // Pre-fills the wizard from a chosen group. No setState — safe to call from
  // initState (update mode) and from _selectGroup (wrapped in setState).
  void _applyGroupSelection(GroupChat group) {
    _selectedGroup = group;
    _selected = null;
    _selectedWorld = null;
    _name.text = group.name;
    _setSummaryFrom(group.scenario); // groups have no description; seed scenario
    _tagPool = [];
    _tags = [];
  }

  @override
  void initState() {
    super.initState();
    // Update mode: lock to the given character OR group and skip the Pick step.
    final uc = widget.updateCharacter;
    final ug = widget.updateGroup;
    if (uc != null) {
      _applySelection(uc);
      _nsfw = widget.initialNsfw;
      _currentStep = 1;
    } else if (ug != null) {
      _applyGroupSelection(ug);
      _nsfw = widget.initialNsfw;
      _currentStep = 1;
    }
    // Update mode: the post's stored display name/summary win over the
    // card-derived seeds the appliers just set (custom titles must survive).
    if (widget.initialName?.trim().isNotEmpty ?? false) {
      _name.text = widget.initialName!.trim();
    }
    if (widget.initialSummary?.trim().isNotEmpty ?? false) {
      _summary.text = widget.initialSummary!.trim();
    }
    _originalCreator.text = widget.initialOriginalCreator ?? '';
  }

  void _select(CharacterCard card) {
    setState(() => _applySelection(card));
  }

  // Pre-fills the wizard from a chosen character. No setState — safe to call from
  // initState (update mode) and from _select (wrapped in setState).
  void _applySelection(CharacterCard card) {
    _selected = card;
    _selectedGroup = null;
    _selectedWorld = null;
    _name.text = card.name;
    _setSummaryFrom(card.description);
    // De-duplicate (preserving order) into the candidate pool, then
    // pre-select the first [_maxTags]; the creator can re-pick on the step.
    final seen = <String>{};
    final pool = <String>[];
    for (final t in card.tags) {
      final tt = t.trim();
      if (tt.isNotEmpty && seen.add(tt)) pool.add(tt);
    }
    _tagPool = pool;
    _tags = pool.take(_maxTags).toList();
  }

  String _mapError(String code) {
    switch (code) {
      case 'policy_not_accepted':
        return 'Please accept the Acceptable Use Policy before sharing.';
      case 'unsupported_image_type':
        return 'That avatar image type isn’t supported (use PNG, JPG, or WebP).';
      case 'file_too_large':
        return 'That avatar image is too large.';
      case 'storage_unavailable':
        return 'The Stoop’s storage is unavailable right now. Try again later.';
      case 'avatar_required':
        return 'This character needs an avatar image to be shared.';
      default:
        return 'Couldn’t share that character. Check your connection and retry.';
    }
  }

  // Pre-fills the wizard from a chosen place. Mirrors the character/group
  // appliers above (each type builds a different payload chain, so unifying
  // the three would just braid unrelated field wiring together).
  void _applyWorldSelection(World world) {
    _selectedWorld = world;
    _selected = null;
    _selectedGroup = null;
    _name.text = world.name;
    _setSummaryFrom(world.description);
    _tagPool = [];
    _tags = [];
  }

  Future<void> _publish() async {
    final world = _selectedWorld;
    if (world != null) {
      await _publishWorld(world);
      return;
    }
    final group = _selectedGroup;
    if (group != null) {
      await _publishGroup(group);
      return;
    }
    final card = _selected;
    if (card == null) return;
    // Cover = the ★ starred avatar (a look/expression) when set, else the
    // library portrait. Gate on the resolved cover (not imagePath) so a
    // portrait-less card that has a starred look can still upload.
    final cover = context.read<CharacterRepository>().coverImageFileFor(card);
    if (cover == null || !cover.existsSync()) {
      setState(() => _error = 'This character has no avatar to upload.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = context.read<AuthState>();
    try {
      final bytes = await cover.readAsBytes();
      final ext = cover.path.split('.').last.toLowerCase();
      // Content is edited in the full character editor before this step (update
      // flow), so the card is already current — publish it as-is.
      final payload = {
        'name': _name.text.trim(),
        'summary': _summary.text.trim(),
        'type': 'SOLO',
        'nsfw': _nsfw,
        'tags': _tags,
        'card': card.toJson(),
        'changelog': widget.isUpdate ? 'Updated' : 'Initial upload',
        // Attribution ('' = own work; on update, '' clears an old credit).
        'originalCreator': _originalCreator.text.trim(),
      };
      if (widget.isUpdate) {
        // In-place new version of the existing post (keeps id/downloads/score).
        await BackporchApi().publishVersion(
          accessToken: auth.accessToken!,
          characterId: widget.updateStoopId!,
          payload: payload,
          avatarBytes: bytes,
          avatarFilename: 'avatar.$ext',
        );
      } else {
        await BackporchApi().uploadCharacter(
          accessToken: auth.accessToken!,
          payload: payload,
          avatarBytes: bytes,
          avatarFilename: 'avatar.$ext',
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on BackporchApiException catch (e) {
      if (mounted) setState(() => _error = _mapError(e.code));
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Couldn’t share that character. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _publishGroup(GroupChat group) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = context.read<AuthState>();
    try {
      final exporter = GroupCardExporter(
        context.read<GroupChatRepository>(),
        context.read<StorageService>(),
        context.read<AppDatabase>(),
      );
      final groupCard = await exporter.buildGroupCard(group);
      if (groupCard == null) {
        if (mounted) {
          setState(() => _error = 'This group has no members to share.');
        }
        return;
      }
      // A member-avatar collage is the Stoop cover; full member avatars still
      // travel inside the card JSON for a faithful download.
      final avatarPaths = groupCard.members
          .map((c) => c.imagePath)
          .whereType<String>()
          .where((p) => p.isNotEmpty)
          .toList();
      if (avatarPaths.isEmpty) {
        if (mounted) {
          setState(
            () => _error =
                'This group’s members need avatars before it can be shared.',
          );
        }
        return;
      }
      final collage = await createGroupAvatarCollage(avatarPaths);
      final payload = {
        'name': _name.text.trim(),
        'summary': _summary.text.trim(),
        'type': 'GROUP',
        'nsfw': _nsfw,
        'tags': _tags,
        'card': groupCard.toJson(),
        'changelog': widget.isUpdate ? 'Updated' : 'Initial upload',
        // Attribution ('' = own work; on update, '' clears an old credit).
        'originalCreator': _originalCreator.text.trim(),
      };
      if (widget.isUpdate) {
        // In-place new version of the existing group post (keeps id/downloads/
        // score). The group card now carries a stable id, so this is the same
        // in-place path solo characters use.
        await BackporchApi().publishVersion(
          accessToken: auth.accessToken!,
          characterId: widget.updateStoopId!,
          payload: payload,
          avatarBytes: collage,
          avatarFilename: 'cover.png',
        );
      } else {
        await BackporchApi().uploadCharacter(
          accessToken: auth.accessToken!,
          payload: payload,
          avatarBytes: collage,
          avatarFilename: 'cover.png',
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on BackporchApiException catch (e) {
      if (mounted) setState(() => _error = _mapError(e.code));
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Couldn’t share that group. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Publish a place as a WORLD card (same moderation queue as characters).
  // The payload/cover work lives in publishStoopWorld (stoop_world_share.dart);
  // this is just the wizard's busy/error scaffolding, mirroring _publishGroup.
  Future<void> _publishWorld(World world) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = context.read<AuthState>();
    try {
      final validation = await publishStoopWorld(
        api: BackporchApi(),
        repo: context.read<WorldRepository>(),
        accessToken: auth.accessToken!,
        world: world,
        name: _name.text.trim(),
        summary: _summary.text.trim(),
        nsfw: _nsfw,
        tags: _tags,
        originalCreator: _originalCreator.text.trim(),
      );
      if (validation != null) {
        if (mounted) setState(() => _error = validation);
        return;
      }
      if (mounted) Navigator.pop(context, true);
    } on BackporchApiException catch (e) {
      if (mounted) setState(() => _error = _mapError(e.code));
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Couldn’t share that place. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _canAdvance {
    switch (_currentStep) {
      case 0:
        return _selected != null ||
            _selectedGroup != null ||
            _selectedWorld != null;
      case 1:
        return _name.text.trim().isNotEmpty && _summary.text.trim().isNotEmpty;
      case 2:
        return _standardsAck;
      default:
        return true;
    }
  }

  void _next() {
    if (!_canAdvance) return;
    if (_currentStep < _steps.length - 1) {
      setState(() => _currentStep++);
    } else {
      _publish();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: stoopBg0(context),
      appBar: AppBar(
        backgroundColor: stoopBg0(context),
        foregroundColor: stoopCream(context),
        elevation: 0,
        shape: Border(bottom: BorderSide(color: stoopBorder(context))),
        title: Text(
          widget.isUpdate ? 'Update character' : 'Share to The Stoop',
          style: stoopDisplay(context, size: 19),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _stepIndicator(),
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _stepBody(),
      ),
      bottomNavigationBar: _navButtons(),
    );
  }

  Widget _stepIndicator() {
    final children = <Widget>[];
    for (var i = 0; i < _steps.length; i++) {
      children.add(_stepDot(i, _steps[i]));
      if (i < _steps.length - 1) children.add(_stepLine());
    }
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: children);
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
            gradient: isActive ? stoopAmberGradient : null,
            color: isActive ? null : stoopBg1(context),
            border: isCurrent
                ? Border.all(color: stoopCream(context), width: 2)
                : isActive
                ? null
                : Border.all(color: stoopBorderHi(context)),
          ),
          child: Center(
            child: isActive && !isCurrent
                ? const Icon(
                    Icons.check,
                    size: 14,
                    color: AppColors.stoopAmberInk,
                  )
                : Text(
                    '${step + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isActive
                          ? AppColors.stoopAmberInk
                          : stoopMute(context),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isCurrent ? stoopAmberText(context) : stoopFaint(context),
          ),
        ),
      ],
    );
  }

  Widget _stepLine() => Container(
    width: 24,
    height: 2,
    margin: const EdgeInsets.only(bottom: 14),
    color: stoopBorder(context),
  );

  Widget _stepBody() {
    switch (_currentStep) {
      case 0:
        return _pickStep();
      case 1:
        return _detailsStep();
      case 2:
        return _contentStep();
      default:
        return _reviewStep();
    }
  }

  // Step 0 — pick a local character, group, or place. Extracted to
  // StoopPickStep (stoop_pick_step.dart), which is folder-aware: the grids
  // follow the home grid's folder hierarchy via the shared
  // buildFolderPickView rules.
  Widget _pickStep() {
    return StoopPickStep(
      selectedCard: _selected,
      selectedGroup: _selectedGroup,
      selectedWorldId: _selectedWorld?.id,
      onSelectCard: _select,
      onSelectGroup: _selectGroup,
      onSelectWorld: (w) => setState(() => _applyWorldSelection(w)),
    );
  }

  // Step 1 — name, summary, tags.
  Widget _detailsStep() {
    return ListView(
      key: const ValueKey('details'),
      padding: const EdgeInsets.all(24),
      children: [
        _label('Display name on The Stoop'),
        TextField(
          controller: _name,
          onChanged: (_) => setState(() {}),
          style: TextStyle(color: stoopCream(context)),
          decoration: _input('Name shown on The Stoop'),
        ),
        const SizedBox(height: 8),
        // Unmissable: this box is the LISTING title, not the chat name.
        // {{char}} keeps mapping to the card's own name, which never changes
        // here — so "Misty Meadows, Misguided Meteorologist" is safe.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: stoopAmberSoft(context),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.stoopAmber.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: stoopAmberText(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selected != null
                      ? 'This is the display name for the listing only — not '
                            'the chat name. In chat, {{char}} still maps to '
                            '“${_selected!.name}”, so replies keep calling '
                            'them “${_selected!.name}” no matter what you '
                            'title the post.'
                      : 'This is the display name for the listing only — in '
                            'chat, everyone keeps their own name no matter '
                            'what you title the post.',
                  style: TextStyle(
                    color: stoopCream2(context),
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _label('Short summary'),
        TextField(
          controller: _summary,
          maxLines: 3,
          maxLength: 280,
          onChanged: (_) => setState(() {}),
          style: TextStyle(color: stoopCream(context)),
          decoration: _input('A one-line hook shown on the card'),
        ),
        const SizedBox(height: 18),
        _label('Original creator (optional)'),
        TextField(
          controller: _originalCreator,
          maxLength: 120,
          onChanged: (_) => setState(() {}),
          style: TextStyle(color: stoopCream(context)),
          decoration: _input('Leave blank if this is your own work').copyWith(
            counterText: '',
            helperText:
                'Sharing someone else’s character? Credit them here — the '
                'card will show “created by …”. The AUP requires this for '
                'reposts; they don’t need a Stoop account.',
            helperMaxLines: 3,
            helperStyle: TextStyle(color: stoopMute(context), fontSize: 12),
          ),
        ),
        const SizedBox(height: 8),
        StoopTagSelector(
          pool: _tagPool,
          selected: _tags,
          max: _maxTags,
          controller: _tagInput,
          decorate: _input,
          onToggle: (t) => setState(() {
            if (_tags.contains(t)) {
              _tags.remove(t);
            } else if (_tags.length < _maxTags) {
              _tags.add(t);
            }
          }),
          onAdd: (raw) => setState(() {
            final tag = raw.trim();
            if (tag.isEmpty) return;
            final lower = tag.toLowerCase();
            // Reuse an existing pool entry that differs only by case so
            // "Potato" and "potato" collapse to one pill (the backend dedupes
            // the same way), then select it.
            var canonical = tag;
            for (final t in _tagPool) {
              if (t.toLowerCase() == lower) {
                canonical = t;
                break;
              }
            }
            if (!_tagPool.contains(canonical)) _tagPool.add(canonical);
            final alreadySelected = _tags.any((t) => t.toLowerCase() == lower);
            if (!alreadySelected && _tags.length < _maxTags) {
              _tags.add(canonical);
            }
          }),
        ),
      ],
    );
  }

  // Step 2 — NSFW flag + the character-agency acknowledgement.
  Widget _contentStep() {
    return ListView(
      key: const ValueKey('content'),
      padding: const EdgeInsets.all(24),
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: stoopCardGradient(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: stoopBorder(context)),
          ),
          // The gradient must stay on the box, so the tile gets its own
          // transparent Material — ink painted on the nearest Material would
          // otherwise be hidden under the DecoratedBox (Flutter assertion).
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: SwitchListTile(
              value: _nsfw,
              onChanged: (v) => setState(() => _nsfw = v),
              activeThumbColor: AppColors.stoopEmber,
              title: Text(
                'This content is NSFW (18+)',
                style: TextStyle(color: stoopCream(context)),
              ),
              subtitle: Text(
                'Mark adult content so it’s hidden from people who haven’t '
                'opted in.',
                style: TextStyle(color: stoopMute(context), fontSize: 12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        StoopStandardsCard(
          footer: CheckboxListTile(
            value: _standardsAck,
            onChanged: (v) => setState(() => _standardsAck = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.stoopAmber,
            checkColor: AppColors.stoopAmberInk,
            title: Text(
              'This card meets the Stoop content standards',
              style: TextStyle(
                color: stoopCream(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'I confirm this card meets every standard above — and complies '
              'with The Stoop Acceptable Use Policy.',
              style: TextStyle(color: stoopCream2(context)),
            ),
          ),
        ),
      ],
    );
  }

  // Step 3 — review + publish.
  Widget _reviewStep() {
    final world = _selectedWorld;
    final isGroup = _selectedGroup != null;
    final preview = world != null
        ? stoopWorldCoverPreview(
            context,
            coverBytes: decodeWorldCoverBytes(world.coverImage),
          )
        : isGroup
        ? Container(
            width: 96,
            height: 96,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: stoopTealSoft(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: StoopGroupMontage(group: _selectedGroup!),
          )
        : ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(_selected!.imagePath!),
              width: 96,
              height: 96,
              fit: BoxFit.cover,
            ),
          );
    return ListView(
      key: const ValueKey('review'),
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            preview,
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _name.text.trim(),
                    style: stoopDisplay(context, size: 21),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _summary.text.trim(),
                    style: TextStyle(color: stoopCream2(context)),
                  ),
                  if (_originalCreator.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'created by ${_originalCreator.text.trim()}',
                      style: TextStyle(
                        color: stoopFaint(context),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  if (_nsfw) ...[
                    const SizedBox(height: 8),
                    const StoopBadge(StoopBadgeKind.nsfw),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (_tags.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in _tags)
                Text(
                  '#$t',
                  style: TextStyle(color: stoopTealText(context)),
                ),
            ],
          ),
        const SizedBox(height: 20),
        Text(
          'Your submission will be reviewed by a moderator before it appears '
          'on The Stoop. You’ll get a message in the app when it’s approved or '
          'if changes are needed.',
          style: TextStyle(color: stoopMute(context), height: 1.5),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(
            _error!,
            style: TextStyle(color: stoopEmberText(context)),
          ),
        ],
      ],
    );
  }

  Widget _navButtons() {
    final isLast = _currentStep == _steps.length - 1;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: stoopBg0(context),
          border: Border(top: BorderSide(color: stoopBorder(context))),
        ),
        child: Row(
          children: [
            // In update mode the Pick step (0) is skipped, so Back stops at 1.
            if (_currentStep > (widget.isUpdate ? 1 : 0))
              TextButton(
                onPressed: _busy ? null : () => setState(() => _currentStep--),
                style: TextButton.styleFrom(
                  foregroundColor: stoopCream2(context),
                ),
                child: const Text('Back'),
              ),
            const Spacer(),
            StoopAmberButton(
              label: isLast ? 'Submit for review' : 'Next',
              busy: _busy,
              onPressed: (_canAdvance && !_busy) ? _next : null,
              padding: const EdgeInsets.symmetric(
                horizontal: 28,
                vertical: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: TextStyle(
        color: stoopCream2(context),
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    ),
  );

  InputDecoration _input(String hint) => stoopInput(context, hint);

}
