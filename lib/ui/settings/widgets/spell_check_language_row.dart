// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:front_porch_ai/services/services.dart'
    show DesktopSpellCheckService, StorageService, kSpellCheckOff;
import 'package:front_porch_ai/ui/theme/app_colors.dart';
import 'package:front_porch_ai/ui/widgets/widgets.dart' show StyledDropdown;
import 'package:front_porch_ai/utils/utils.dart';

/// Picks the language prose fields are spell checked against.
///
/// This exists because the language someone *types* has nothing to do with the
/// language their operating system is set to. A user running a German desktop
/// and role-playing in English was getting every English word underlined,
/// because both spell check paths resolved the OS locale. Defaulting to
/// English and letting people say otherwise is the fix; this is where they say
/// it.
///
/// The menu lists what the platform can actually check — hunspell dictionaries
/// found on disk (Linux), `NSSpellChecker.availableLanguages` (macOS),
/// `ISpellCheckerFactory` supported languages (Windows) — so it can never
/// offer a language that would silently do nothing.
class SpellCheckLanguageRow extends StatefulWidget {
  const SpellCheckLanguageRow({super.key});

  @override
  State<SpellCheckLanguageRow> createState() => _SpellCheckLanguageRowState();
}

class _SpellCheckLanguageRowState extends State<SpellCheckLanguageRow> {
  List<String> _languages = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final found = await DesktopSpellCheckService.availableLanguages();
    if (!mounted) return;
    setState(() {
      // Always include the current selection even if the platform did not
      // report it — otherwise a dictionary uninstalled since the setting was
      // saved would leave the dropdown with a value that is not in its own
      // item list, which throws.
      _languages = sortedByLabel([
        ...found,
        if (DesktopSpellCheckService.activeLanguage != kSpellCheckOff)
          DesktopSpellCheckService.activeLanguage,
      ]);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final storage = context.watch<StorageService>();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Spell Check Language',
                  style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'The language you write in — not your system language. '
                  'Set this to the language you chat with characters in.',
                  style: TextStyle(
                    color: AppColors.textTertiary(context),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (_loading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            StyledDropdown<String>(
              width: 220,
              value: storage.spellCheckLanguage,
              items: [
                const DropdownMenuItem(
                  value: kSpellCheckOff,
                  child: Text('Off'),
                ),
                for (final tag in _languages)
                  DropdownMenuItem(
                    value: tag,
                    child: Text(spellCheckLanguageLabel(tag)),
                  ),
              ],
              onChanged: (value) {
                if (value != null) storage.setSpellCheckLanguage(value);
              },
            ),
        ],
      ),
    );
  }
}
