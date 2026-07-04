import 'package:flutter/material.dart';

import 'package:front_porch_ai/models/lorebook.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';
import 'package:front_porch_ai/ui/widgets/app_text_field.dart';
import 'package:front_porch_ai/ui/widgets/expanded_editor_dialog.dart';
import 'package:front_porch_ai/ui/widgets/styled_text_controller.dart';

Future<LorebookEntry?> showLorebookEntryDialog({
  required BuildContext context,
  LorebookEntry? existing,
  bool showEnabled = false,
}) {
  return showDialog<LorebookEntry>(
    context: context,
    builder: (_) => _LorebookEntryDialog(
      existing: existing,
      showEnabled: showEnabled,
    ),
  );
}

class _LorebookEntryDialog extends StatefulWidget {
  final LorebookEntry? existing;
  final bool showEnabled;

  const _LorebookEntryDialog({
    this.existing,
    this.showEnabled = false,
  });

  @override
  State<_LorebookEntryDialog> createState() => _LorebookEntryDialogState();
}

class _LorebookEntryDialogState extends State<_LorebookEntryDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _keyCtrl;
  late final StyledTextController _contentCtrl;
  late bool _constant;
  late int _stickyDepth;
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _keyCtrl = TextEditingController(text: e?.key ?? '');
    _contentCtrl = StyledTextController(
      text: e?.content ?? '',
      preset: StyledTextPreset.macros,
    );
    _constant = e?.constant ?? false;
    _stickyDepth = e?.stickyDepth ?? 1;
    _enabled = e?.enabled ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _keyCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cardOf(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Text(
        widget.existing == null ? 'Add Lorebook Entry' : 'Edit Lorebook Entry',
        style: TextStyle(color: AppColors.textPrimary(context)),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _fieldLabel(context, 'Name (optional)'),
            const SizedBox(height: 6),
            AppTextField(
              controller: _nameCtrl,
              decoration: _fieldDecoration(context),
            ),
            const SizedBox(height: 12),
            _fieldLabel(context,
                _constant ? 'Keywords (Disabled — Always Active)' : 'Keywords (comma separated)'),
            const SizedBox(height: 6),
            AppTextField(
              controller: _keyCtrl,
              enabled: !_constant,
              decoration: _fieldDecoration(context).copyWith(
                fillColor: _constant
                    ? AppColors.surfaceContainerOf(context).withValues(alpha: 0.5)
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _fieldLabel(context, 'Content'),
                const Spacer(),
                InkWell(
                  onTap: () => showExpandedEditorDialog(
                    context: context,
                    title: 'Content',
                    controller: _contentCtrl,
                    hintText: 'Enter lore content...',
                  ),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.open_in_full,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            AppTextField(
              controller: _contentCtrl,
              maxLines: 5,
              decoration: _fieldDecoration(context),
            ),
            const SizedBox(height: 16),
            if (widget.showEnabled) ...[
              _toggleCard(
                context,
                icon: Icons.visibility,
                label: 'Enabled',
                subtitle: 'This entry can be injected when its keys match',
                value: _enabled,
                activeColor: Colors.blueAccent,
                onChanged: (v) => setState(() => _enabled = v),
              ),
              const SizedBox(height: 12),
            ],
            _toggleCard(
              context,
              icon: Icons.push_pin,
              label: 'Always Active',
              subtitle: 'Always considered active (ignores trigger keys)',
              value: _constant,
              activeColor: Colors.amberAccent,
              onChanged: (v) => setState(() => _constant = v),
            ),
            if (!_constant) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.layers, size: 14, color: Colors.white38),
                  const SizedBox(width: 6),
                  Text(
                    'Sticky Depth',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(context),
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerOf(context),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$_stickyDepth',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'How many turns the entry stays active after triggering',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary(context),
                ),
              ),
              const SizedBox(height: 6),
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor:
                      AppColors.resolve(context, Colors.tealAccent, Colors.teal.shade700),
                  inactiveTrackColor:
                      AppColors.borderOf(context).withValues(alpha: 0.4),
                  thumbColor:
                      AppColors.resolve(context, Colors.tealAccent, Colors.teal.shade700),
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 7,
                  ),
                ),
                child: Slider(
                  value: _stickyDepth.toDouble().clamp(1, 50),
                  min: 1,
                  max: 50,
                  divisions: 49,
                  label: _stickyDepth.toString(),
                  onChanged: (v) => setState(() => _stickyDepth = v.round()),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: Colors.white38),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            // Clone-then-overwrite: editing only the simple fields must not
            // strip the advanced/imported ST metadata an entry carries.
            final entry = widget.existing?.clone() ?? LorebookEntry();
            entry.name = _nameCtrl.text.trim();
            entry.keys = LorebookEntry.parseKeyList(_keyCtrl.text.trim());
            entry.content = _contentCtrl.text.trim();
            entry.constant = _constant;
            entry.stickyDepth = _stickyDepth;
            entry.enabled = _enabled;
            Navigator.pop(context, entry);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(widget.existing == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }

  Widget _fieldLabel(BuildContext context, String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.textSecondary(context),
          fontSize: 13,
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(BuildContext context) {
    return InputDecoration(
      filled: true,
      fillColor: AppColors.surfaceContainerOf(context),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  Widget _toggleCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required bool value,
    required Color activeColor,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: value
              ? activeColor.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 14, color: value ? activeColor : Colors.white38),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: activeColor.withValues(alpha: 0.5),
            activeThumbColor: activeColor,
          ),
        ],
      ),
    );
  }
}
