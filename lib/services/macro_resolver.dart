// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:math';

import 'package:intl/intl.dart';

/// Context passed to every macro resolver function.
class MacroContext {
  final String? userName;
  final String? characterName;
  final String? chatId;
  final String? characterId;

  const MacroContext({
    this.userName,
    this.characterName,
    this.chatId,
    this.characterId,
  });
}

/// Internal registry entry.
class _MacroEntry {
  final String name;
  final String Function(List<String> args, MacroContext ctx) fn;
  const _MacroEntry({required this.name, required this.fn});
}

/// Central macro engine. Has a name → resolver registry.
/// Replace all known `{{...}}` patterns in text via [resolve].
/// Unknown macros pass through unchanged.
class MacroResolver {
  final Map<String, _MacroEntry> _registry = {};
  bool _defaultsRegistered = false;
  int _pickCounter = 0;

  static final _commentPattern = RegExp(r'\{\{//.*?\}\}');
  static final _escapePattern = RegExp(r'\\\{\{');
  // Accepts both ST separator styles: {{name::a::b}} and {{name:a,b}}.
  static final _macroPattern = RegExp(r'\{\{(\w+)(?:(::?)(.+?))?\}\}');
  // Dedicated roll pass: ST allows {{roll:d6}}, {{roll::1d20+5}}, {{roll d20}}.
  static final _rollMacroPattern =
      RegExp(r'\{\{roll[\s:]+([^}]+)\}\}', caseSensitive: false);
  static final _rollPattern = RegExp(r'^(\d+)d(\d+)([+-]\d+)?$');
  // Comma not preceded by a backslash (the \, escape ST supports in lists).
  static final _unescapedComma = RegExp(r'(?<!\\),');
  static final _rng = Random();

  MacroResolver() {
    _ensureDefaults();
  }

  void _ensureDefaults() {
    if (_defaultsRegistered) return;
    _defaultsRegistered = true;

    register('user', (args, ctx) => ctx.userName ?? '');
    register('char', (args, ctx) => ctx.characterName ?? '');
    // ({{words}} was removed with the old summary-prompt feature — the
    // Journal recap has a fixed length instruction.)

    // Phase 2 P0
    register('newline', (args, ctx) {
      final n = args.isNotEmpty ? int.tryParse(args[0]) ?? 1 : 1;
      return '\n' * n.clamp(1, 100);
    });
    register('space', (args, ctx) {
      final n = args.isNotEmpty ? int.tryParse(args[0]) ?? 1 : 1;
      return ' ' * n.clamp(1, 100);
    });
    register('noop', (args, ctx) => '');
    register('random', (args, ctx) {
      if (args.isEmpty) return '';
      return args[_rng.nextInt(args.length)];
    });
    // roll handled in resolve() for pass-through of invalid notation
    register('time', (args, ctx) => DateFormat('HH:mm').format(DateTime.now()));
    register('date', (args, ctx) => DateFormat('yyyy-MM-dd').format(DateTime.now()));
    register('weekday', (args, ctx) => DateFormat('EEEE').format(DateTime.now()));
    register('isotime', (args, ctx) {
      final iso = DateTime.now().toIso8601String();
      return iso.split('T')[1].split('.').first;
    });
    register('isodate', (args, ctx) {
      return DateTime.now().toIso8601String().split('T')[0];
    });
  }

  void register(
    String name,
    String Function(List<String> args, MacroContext ctx) fn,
  ) {
    _registry[name.toLowerCase()] = _MacroEntry(name: name, fn: fn);
  }

  /// Replaces all known `{{...}}` macros and legacy `<user>`/`<char>` syntax.
  /// Unknown macros pass through unchanged.
  /// Returns empty string for null/empty input.
  /// [section] differentiates [{{pick}}] seeding across prompt sections
  /// (e.g. systemPrompt vs scenario) so the same position in different
  /// sections produces a different result.
  String resolve(String text, MacroContext context, {String section = ''}) {
    if (text.isEmpty) return text;

    _pickCounter = 0;
    var result = text;

    // 1. Escape: \{{ → sentinel (null byte)
    result = result.replaceAll(_escapePattern, '\x00');

    // 2. Strip {{// ...}} comments
    result = result.replaceAll(_commentPattern, '');

    // 3. Legacy angle-bracket syntax (case-insensitive)
    final charName = context.characterName ?? '';
    final userName = context.userName ?? '';
    result = result.replaceAll(
      RegExp(r'<char>', caseSensitive: false),
      charName,
    );
    result = result.replaceAll(
      RegExp(r'<user>', caseSensitive: false),
      userName,
    );

    // 4. {{roll ...}} first — its arg can contain spaces/colons the generic
    // pattern rejects. Handles :, ::, and space separators plus the ST
    // shorthands d6 → 1d6 and 6 → 1d6. Invalid formulas pass through.
    result = result.replaceAllMapped(_rollMacroPattern, (m) {
      var formula = m.group(1)!.trim().toLowerCase();
      if (RegExp(r'^\d+$').hasMatch(formula)) formula = '1d$formula';
      if (formula.startsWith('d')) formula = '1$formula';
      final rm = _rollPattern.firstMatch(formula);
      if (rm == null) return m.group(0)!;
      final count = int.parse(rm.group(1)!);
      final sides = int.parse(rm.group(2)!);
      final mod = int.tryParse(rm.group(3) ?? '') ?? 0;
      if (sides < 1 || count < 1 || count > 1000) return m.group(0)!;
      var total = 0;
      for (var i = 0; i < count; i++) {
        total += _rng.nextInt(sides) + 1;
      }
      return (total + mod).toString();
    });

    // 5. {{macro}} syntax via regex — walk all matches
    result = result.replaceAllMapped(_macroPattern, (m) {
      final name = m.group(1)!.toLowerCase();
      final sep = m.group(2);
      final argsStr = m.group(3);
      final args = _splitArgs(name, sep, argsStr);

      if (name == 'pick') {
        // Deterministic per chatId + characterId + position
        final seedKey = '${context.chatId}_${context.characterId}_${section}_$_pickCounter';
        _pickCounter++;
        final h = seedKey.hashCode.abs();
        return args.isEmpty ? '' : args[h % args.length];
      }

      final entry = _registry[name];
      if (entry != null) return entry.fn(args, context);
      return m.group(0)!; // unknown macro → pass through
    });

    // 6. Unescape sentinel back to {{
    result = result.replaceAll('\x00', '{{');

    return result;
  }

  /// ST arg-splitting: `::` always splits on `::`; the single-colon form
  /// comma-splits for list macros (random/pick) with `\,` escaping, and is a
  /// single argument for everything else.
  static List<String> _splitArgs(String name, String? sep, String? argsStr) {
    if (argsStr == null) return const [];
    if (sep == '::') return argsStr.split('::');
    if (name == 'random' || name == 'pick') {
      return argsStr
          .split(_unescapedComma)
          .map((s) => s.trim().replaceAll(r'\,', ','))
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return [argsStr];
  }
}
