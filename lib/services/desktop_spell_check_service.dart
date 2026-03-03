import 'dart:ui' show Locale;
import 'package:flutter/services.dart';
import 'package:simple_spell_checker/simple_spell_checker.dart';
import 'package:simple_spell_checker_en_lan/simple_spell_checker_en_lan.dart';

/// Custom [SpellCheckService] for Linux and Windows desktop,
/// powered by [SimpleSpellChecker] with a bundled English dictionary.
class DesktopSpellCheckService extends SpellCheckService {
  static bool _registered = false;
  late final _SpellCheckerHelper _checker;

  DesktopSpellCheckService() {
    if (!_registered) {
      SimpleSpellCheckerEnRegister.registerLan();
      _registered = true;
    }
    _checker = _SpellCheckerHelper(language: 'en', caseSensitive: false);
  }

  // Simple word boundary regex — matches alphabetical words and contractions
  static final _wordPattern = RegExp(r"[a-zA-Z']+");

  @override
  Future<List<SuggestionSpan>?> fetchSpellCheckSuggestions(
    Locale locale,
    String text,
  ) async {
    if (text.trim().isEmpty) return null;

    final suggestions = <SuggestionSpan>[];

    for (final match in _wordPattern.allMatches(text)) {
      final word = match.group(0)!;
      // Skip very short words (1-2 chars) to reduce false positives
      if (word.length <= 2) continue;
      // Skip words that are all apostrophes
      if (word.replaceAll("'", '').isEmpty) continue;

      if (!_checker.checkWord(word)) {
        suggestions.add(
          SuggestionSpan(
            TextRange(start: match.start, end: match.end),
            <String>[], // No suggestions — just highlighting
          ),
        );
      }
    }

    return suggestions.isEmpty ? null : suggestions;
  }

  void dispose() {
    _checker.dispose();
  }
}

/// Subclass to expose the @protected [isWordValid] method.
class _SpellCheckerHelper extends SimpleSpellChecker {
  _SpellCheckerHelper({required super.language, super.caseSensitive});

  bool checkWord(String word) => isWordValid(word);
}
