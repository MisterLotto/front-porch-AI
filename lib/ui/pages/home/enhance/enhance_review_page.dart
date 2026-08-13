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

import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/services/services.dart';
import 'package:front_porch_ai/services/chargen/chargen.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';

/// Old-vs-new review of an AI Enhance run. Every rewritten field is shown
/// beside the original, editable, with a per-field "use this" switch.
/// Saving creates a NEW `<Name> (Enhanced)` character (via the same
/// duplicate machinery as the context menu's Duplicate action) — the original
/// is never written, and Discard writes nothing at all.
class EnhanceReviewPage extends StatefulWidget {
  const EnhanceReviewPage({
    super.key,
    required this.original,
    required this.enhanced,
    required this.selection,
  });

  final CharacterCard original;
  final CharacterCard enhanced;
  final EnhanceSelection selection;

  @override
  State<EnhanceReviewPage> createState() => _EnhanceReviewPageState();
}

class _EnhanceReviewPageState extends State<EnhanceReviewPage> {
  final _controllers = <String, TextEditingController>{};
  final _use = <String, bool>{};
  late final List<bool> _useLoreEntry;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    void field(String key, bool selected, String newValue) {
      if (!selected) return;
      _controllers[key] = TextEditingController(text: newValue);
      _use[key] = true;
    }

    field('description', widget.selection.description,
        widget.enhanced.description);
    field('personality', widget.selection.personality,
        widget.enhanced.personality);
    field('exampleDialogue', widget.selection.exampleDialogue,
        widget.enhanced.mesExample);
    field('scenario', widget.selection.scenario, widget.enhanced.scenario);
    if (widget.selection.greetings) {
      field('firstMessage', true, widget.enhanced.firstMessage);
      for (var i = 0; i < widget.enhanced.alternateGreetings.length; i++) {
        field('alt$i', true, widget.enhanced.alternateGreetings[i]);
      }
      _use['greetings'] = true;
    }
    _useLoreEntry = List.filled(
      widget.enhanced.lorebook?.entries.length ?? 0,
      true,
    );
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final repo = Provider.of<CharacterRepository>(context, listen: false);
      final folders = Provider.of<FolderService>(context, listen: false);
      final copy = await repo.duplicateCharacter(
        widget.original,
        newNameOverride: '${widget.original.name} (Enhanced)',
      );
      if (copy == null) {
        throw Exception('could not create the new character');
      }
      // The enhanced copy belongs wherever the original lives (same rule as
      // the plain Duplicate action).
      await folders.inheritFolder(widget.original.imagePath, copy.imagePath);

      String accepted(String key, String fallback) =>
          (_use[key] ?? false) ? _controllers[key]!.text.trim() : fallback;

      copy.description = accepted('description', copy.description);
      copy.personality = accepted('personality', copy.personality);
      copy.mesExample = accepted('exampleDialogue', copy.mesExample);
      copy.scenario = accepted('scenario', copy.scenario);
      if (widget.selection.greetings && (_use['greetings'] ?? false)) {
        copy.firstMessage = _controllers['firstMessage']!.text.trim();
        copy.alternateGreetings = [
          for (var i = 0;
              i < widget.enhanced.alternateGreetings.length;
              i++)
            _controllers['alt$i']!.text.trim(),
        ]..removeWhere((g) => g.isEmpty);
      }
      final loreEntries = widget.enhanced.lorebook?.entries ?? [];
      final keptLore = [
        for (var i = 0; i < loreEntries.length; i++)
          if (_useLoreEntry[i]) loreEntries[i],
      ];
      if (keptLore.isNotEmpty) {
        copy.lorebook = Lorebook(entries: keptLore);
      }

      await repo.updateCharacter(copy);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${copy.name}" added to your library.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save the enhanced character: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sections = <Widget>[
      if (widget.selection.description)
        _fieldSection('Description', 'description',
            widget.original.description),
      if (widget.selection.personality)
        _fieldSection('Personality', 'personality',
            widget.original.personality),
      if (widget.selection.exampleDialogue)
        _fieldSection('Example dialogue', 'exampleDialogue',
            widget.original.mesExample),
      if (widget.selection.scenario)
        _fieldSection('Scenario', 'scenario', widget.original.scenario),
      if (widget.selection.greetings) _greetingsSection(),
      if (widget.selection.lorebook &&
          (widget.enhanced.lorebook?.entries.isNotEmpty ?? false))
        _lorebookSection(),
    ];

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppBar(
        backgroundColor: AppColors.surfaceOf(context),
        foregroundColor: AppColors.textPrimary(context),
        title: Row(
          children: [
            Icon(Icons.auto_awesome,
                color: AppColors.porchAmberOf(context), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Review: ${widget.original.name} (Enhanced)',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Nothing is saved yet. Edit anything below, untick what you don\'t '
            'want, then Save to add the enhanced copy to your library. Your '
            'original ${widget.original.name} stays exactly as-is either way.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 12),
          ...sections,
          const SizedBox(height: 80),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            border: Border(top: BorderSide(color: AppColors.borderOf(context))),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving
                      ? null
                      : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary(context),
                    side: BorderSide(color: AppColors.borderOf(context)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Discard'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.porchAmberOf(context),
                    foregroundColor: AppColors.onChaosAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_alt, size: 18),
                  label: const Text('Save as New Character'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: child,
    );
  }

  Widget _sectionHeader(String title, String useKey) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(context),
            ),
          ),
        ),
        Text(
          'Use this',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textTertiary(context),
          ),
        ),
        Switch(
          value: _use[useKey] ?? false,
          activeThumbColor: AppColors.porchAmberOf(context),
          onChanged: (v) => setState(() => _use[useKey] = v),
        ),
      ],
    );
  }

  Widget _oldText(String label, String text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textTertiary(context),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 140),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerOf(context),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            child: Text(
              text.isEmpty ? '(empty)' : text,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary(context),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _newField(String label, TextEditingController controller,
      {bool enabled = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.porchAmberOf(context),
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          enabled: enabled,
          maxLines: null,
          minLines: 2,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textPrimary(context),
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surfaceContainerOf(context),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.borderOf(context)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.borderOf(context)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  BorderSide(color: AppColors.porchAmberOf(context)),
            ),
            contentPadding: const EdgeInsets.all(8),
          ),
        ),
      ],
    );
  }

  Widget _fieldSection(String title, String key, String oldValue) {
    final use = _use[key] ?? false;
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(title, key),
          const SizedBox(height: 8),
          _oldText('Before', oldValue),
          const SizedBox(height: 8),
          _newField('After (editable)', _controllers[key]!, enabled: use),
        ],
      ),
    );
  }

  Widget _greetingsSection() {
    final use = _use['greetings'] ?? false;
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('First message + alternates', 'greetings'),
          const SizedBox(height: 8),
          _oldText('Before (first message)', widget.original.firstMessage),
          const SizedBox(height: 8),
          _newField('After (editable)', _controllers['firstMessage']!,
              enabled: use),
          for (var i = 0;
              i < widget.enhanced.alternateGreetings.length;
              i++) ...[
            const SizedBox(height: 8),
            _newField('Alternate ${i + 1} (editable)', _controllers['alt$i']!,
                enabled: use),
          ],
        ],
      ),
    );
  }

  Widget _lorebookSection() {
    final entries = widget.enhanced.lorebook!.entries;
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'New lorebook entries',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < entries.length; i++)
            CheckboxListTile(
              value: _useLoreEntry[i],
              onChanged: (v) =>
                  setState(() => _useLoreEntry[i] = v ?? false),
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: AppColors.porchAmberOf(context),
              checkColor: AppColors.onChaosAccent,
              contentPadding: EdgeInsets.zero,
              title: Text(
                entries[i].name,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary(context),
                ),
              ),
              subtitle: Text(
                entries[i].content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary(context),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
