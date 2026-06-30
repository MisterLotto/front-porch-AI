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

import 'package:front_porch_ai/database/database.dart';
import 'package:front_porch_ai/models/character_card.dart';
import 'package:front_porch_ai/models/group_chat.dart';
import 'package:front_porch_ai/providers/auth_state.dart';
import 'package:front_porch_ai/services/backporch/backporch.dart';
import 'package:front_porch_ai/services/character_repository.dart';
import 'package:front_porch_ai/services/group_card_exporter.dart';
import 'package:front_porch_ai/services/group_chat_repository.dart';
import 'package:front_porch_ai/services/storage_service.dart';
import 'package:front_porch_ai/ui/pages/repository/stoop_standards.dart';
import 'package:front_porch_ai/ui/pages/repository/stoop_tag_selector.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';
import 'package:front_porch_ai/ui/widgets/group_avatar_montage.dart';
import 'package:front_porch_ai/utils/group_avatar_compositor.dart';

/// Wizard to share one of the user's local characters to The Stoop. Mirrors the
/// app's create-wizard chrome (step dots + AnimatedSwitcher + nav buttons).
/// Pops `true` once a card has been submitted for review.
class StoopUploadPage extends StatefulWidget {
  const StoopUploadPage({super.key});

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
  final _name = TextEditingController();
  final _summary = TextEditingController();
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
    setState(() {
      _selectedGroup = group;
      _selected = null;
      _name.text = group.name;
      _setSummaryFrom(group.scenario); // groups have no description; seed scenario
      _tagPool = [];
      _tags = [];
    });
  }

  void _select(CharacterCard card) {
    setState(() {
      _selected = card;
      _selectedGroup = null;
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
    });
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

  Future<void> _publish() async {
    final group = _selectedGroup;
    if (group != null) {
      await _publishGroup(group);
      return;
    }
    final card = _selected;
    if (card == null || card.imagePath == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = context.read<AuthState>();
    try {
      final bytes = await File(card.imagePath!).readAsBytes();
      final ext = card.imagePath!.split('.').last.toLowerCase();
      await BackporchApi().uploadCharacter(
        accessToken: auth.accessToken!,
        payload: {
          'name': _name.text.trim(),
          'summary': _summary.text.trim(),
          'type': 'SOLO',
          'nsfw': _nsfw,
          'tags': _tags,
          'card': card.toJson(),
          'changelog': 'Initial upload',
        },
        avatarBytes: bytes,
        avatarFilename: 'avatar.$ext',
      );
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
      await BackporchApi().uploadCharacter(
        accessToken: auth.accessToken!,
        payload: {
          'name': _name.text.trim(),
          'summary': _summary.text.trim(),
          'type': 'GROUP',
          'nsfw': _nsfw,
          'tags': _tags,
          'card': groupCard.toJson(),
          'changelog': 'Initial upload',
        },
        avatarBytes: collage,
        avatarFilename: 'cover.png',
      );
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

  bool get _canAdvance {
    switch (_currentStep) {
      case 0:
        return _selected != null || _selectedGroup != null;
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
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppBar(
        backgroundColor: AppColors.surfaceOf(context),
        foregroundColor: AppColors.textPrimary(context),
        title: const Text('Share a character'),
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
    final accent = AppColors.resolve(context, Colors.tealAccent, Colors.teal);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? accent : AppColors.surfaceContainerOf(context),
            border: isCurrent
                ? Border.all(color: AppColors.textPrimary(context), width: 2)
                : null,
          ),
          child: Center(
            child: isActive && !isCurrent
                ? Icon(Icons.check, size: 14, color: AppColors.background)
                : Text(
                    '${step + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isActive
                          ? AppColors.background
                          : AppColors.textSecondary(context),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isCurrent
                ? AppColors.textPrimary(context)
                : AppColors.textTertiary(context),
          ),
        ),
      ],
    );
  }

  Widget _stepLine() => Container(
    width: 24,
    height: 2,
    margin: const EdgeInsets.only(bottom: 14),
    color: AppColors.borderOf(context).withValues(alpha: 0.35),
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

  // Step 0 — pick a local character or a group (only those with an avatar /
  // members-with-avatars can be shared).
  Widget _pickStep() {
    final cards = context
        .read<CharacterRepository>()
        .characters
        .where((c) => c.imagePath != null && c.imagePath!.isNotEmpty)
        .toList();
    final groups = context.read<GroupChatRepository>().groups;
    if (cards.isEmpty && groups.isEmpty) {
      return _centeredHint(
        Icons.person_off_outlined,
        'Nothing to share yet',
        'Characters need an avatar image, and groups need members, before they '
            'can be shared.',
      );
    }
    const grid = SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 150,
      childAspectRatio: 0.78,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
    );
    return ListView(
      key: const ValueKey('pick'),
      padding: const EdgeInsets.all(16),
      children: [
        // Groups first — they're the marquee thing to share and shouldn't be
        // buried under a long character list.
        if (groups.isNotEmpty) ...[
          _label('Groups'),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: grid,
            itemCount: groups.length,
            itemBuilder: (context, i) => _groupPickTile(groups[i]),
          ),
        ],
        if (cards.isNotEmpty) ...[
          if (groups.isNotEmpty) const SizedBox(height: 16),
          _label('Characters'),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: grid,
            itemCount: cards.length,
            itemBuilder: (context, i) => _pickTile(cards[i]),
          ),
        ],
      ],
    );
  }

  Widget _groupPickTile(GroupChat group) {
    final selected = _selectedGroup?.id == group.id;
    final accent = AppColors.resolve(context, Colors.tealAccent, Colors.teal);
    return GestureDetector(
      onTap: () => _selectGroup(group),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardOf(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? accent : AppColors.borderOf(context),
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ColoredBox(
                color: AppColors.resolve(
                  context,
                  Colors.purple.shade900.withValues(alpha: 0.35),
                  Colors.purple.shade50,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: _groupMontage(group),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(
                group.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textPrimary(context),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // A folder-style montage of a group's member avatars, sized to fill its slot.
  // Shared by the picker tile and the review-step preview. Falls back to a
  // groups glyph while members load or if none have an avatar.
  Widget _groupMontage(GroupChat group) {
    return FutureBuilder<List<File>>(
      future: context.read<GroupChatRepository>().getMemberAvatarFiles(group.id),
      builder: (context, snap) {
        final files = snap.data ?? const <File>[];
        if (files.isEmpty) {
          return const Center(
            child: Icon(
              Icons.groups_rounded,
              size: 44,
              color: Colors.purpleAccent,
            ),
          );
        }
        return LayoutBuilder(
          builder: (context, c) {
            final side = c.maxWidth < c.maxHeight ? c.maxWidth : c.maxHeight;
            return Center(
              child: GroupAvatarMontage(
                images: files.take(4).toList(),
                side: side,
              ),
            );
          },
        );
      },
    );
  }

  Widget _pickTile(CharacterCard card) {
    final selected = _selected?.dbId == card.dbId && _selected != null;
    final accent = AppColors.resolve(context, Colors.tealAccent, Colors.teal);
    return GestureDetector(
      onTap: () => _select(card),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardOf(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? accent : AppColors.borderOf(context),
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Image.file(File(card.imagePath!), fit: BoxFit.cover),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(
                card.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textPrimary(context),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Step 1 — name, summary, tags.
  Widget _detailsStep() {
    return ListView(
      key: const ValueKey('details'),
      padding: const EdgeInsets.all(24),
      children: [
        _label('Name'),
        TextField(
          controller: _name,
          onChanged: (_) => setState(() {}),
          style: TextStyle(color: AppColors.textPrimary(context)),
          decoration: _input('Character name'),
        ),
        const SizedBox(height: 18),
        _label('Short summary'),
        TextField(
          controller: _summary,
          maxLines: 3,
          maxLength: 280,
          onChanged: (_) => setState(() {}),
          style: TextStyle(color: AppColors.textPrimary(context)),
          decoration: _input('A one-line hook shown on the card'),
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
            color: AppColors.surfaceContainerOf(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: SwitchListTile(
            value: _nsfw,
            onChanged: (v) => setState(() => _nsfw = v),
            title: Text(
              'This character is NSFW (18+)',
              style: TextStyle(color: AppColors.textPrimary(context)),
            ),
            subtitle: Text(
              'Mark adult content so it’s hidden from people who haven’t opted in.',
              style: TextStyle(
                color: AppColors.textTertiary(context),
                fontSize: 12,
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
            title: Text(
              'This card meets the Stoop content standards',
              style: TextStyle(
                color: AppColors.textPrimary(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'I confirm this card meets every standard above — and complies '
              'with The Stoop Acceptable Use Policy.',
              style: TextStyle(color: AppColors.textSecondary(context)),
            ),
          ),
        ),
      ],
    );
  }

  // Step 3 — review + publish.
  Widget _reviewStep() {
    final isGroup = _selectedGroup != null;
    final preview = isGroup
        ? Container(
            width: 96,
            height: 96,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.resolve(
                context,
                Colors.purple.shade900.withValues(alpha: 0.35),
                Colors.purple.shade50,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _groupMontage(_selectedGroup!),
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
                    style: TextStyle(
                      color: AppColors.textPrimary(context),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _summary.text.trim(),
                    style: TextStyle(color: AppColors.textSecondary(context)),
                  ),
                  if (_nsfw) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.resolve(
                          context,
                          Colors.pinkAccent,
                          Colors.pink,
                        ).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'NSFW',
                        style: TextStyle(
                          color: AppColors.resolve(
                            context,
                            Colors.pinkAccent,
                            Colors.pink,
                          ),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
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
                  style: TextStyle(color: AppColors.textTertiary(context)),
                ),
            ],
          ),
        const SizedBox(height: 20),
        Text(
          'Your character will be reviewed by a moderator before it appears on '
          'The Stoop. You’ll get a message in the app when it’s approved or if '
          'changes are needed.',
          style: TextStyle(color: AppColors.textTertiary(context), height: 1.5),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(
            _error!,
            style: TextStyle(
              color: AppColors.resolve(
                context,
                Colors.redAccent,
                Colors.red.shade700,
              ),
            ),
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
          color: AppColors.surfaceOf(context),
          border: Border(top: BorderSide(color: AppColors.borderOf(context))),
        ),
        child: Row(
          children: [
            if (_currentStep > 0)
              TextButton(
                onPressed: _busy ? null : () => setState(() => _currentStep--),
                child: const Text('Back'),
              ),
            const Spacer(),
            FilledButton(
              onPressed: (_canAdvance && !_busy) ? _next : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isLast ? 'Submit for review' : 'Next'),
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
        color: AppColors.textSecondary(context),
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    ),
  );

  InputDecoration _input(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: AppColors.textTertiary(context)),
    filled: true,
    fillColor: AppColors.surfaceContainerOf(context),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AppColors.borderOf(context)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AppColors.borderOf(context)),
    ),
  );

  Widget _centeredHint(IconData icon, String title, String body) {
    return Center(
      key: const ValueKey('hint'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.iconSecondary(context)),
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                color: AppColors.textPrimary(context),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textTertiary(context)),
            ),
          ],
        ),
      ),
    );
  }
}
