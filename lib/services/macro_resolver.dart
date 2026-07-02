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
  static final _macroPattern = RegExp(r'\{\{(\w+)(?:::(.+?))?\}\}');
  static final _rollPattern = RegExp(r'^(\d+)d(\d+)([+-]\d+)?$');
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

    // 4. {{macro}} syntax via regex — walk all matches
    result = result.replaceAllMapped(_macroPattern, (m) {
      final name = m.group(1)!.toLowerCase();
      final argsStr = m.group(2);
      final args = argsStr != null ? argsStr.split('::') : <String>[];

      if (name == 'pick') {
        // Deterministic per chatId + characterId + position
        final seedKey = '${context.chatId}_${context.characterId}_${section}_$_pickCounter';
        _pickCounter++;
        final h = seedKey.hashCode.abs();
        return args.isEmpty ? '' : args[h % args.length];
      }

      if (name == 'roll') {
        if (args.isEmpty) return '';
        final rm = _rollPattern.firstMatch(args[0]);
        if (rm == null) return m.group(0)!;
        final count = int.parse(rm.group(1)!);
        final sides = int.parse(rm.group(2)!);
        final mod = int.tryParse(rm.group(3) ?? '') ?? 0;
        var total = 0;
        for (var i = 0; i < count; i++) {
          total += _rng.nextInt(sides) + 1;
        }
        return (total + mod).toString();
      }

      final entry = _registry[name];
      if (entry != null) return entry.fn(args, context);
      return m.group(0)!; // unknown macro → pass through
    });

    // 5. Unescape sentinel back to {{
    result = result.replaceAll('\x00', '{{');

    return result;
  }
}
