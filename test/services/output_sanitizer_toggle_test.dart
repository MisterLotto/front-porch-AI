// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Tests for output sanitizer toggle behaviour:
// 1. setOutputSanitizerEnabled(false) implicitly resets sanitiseExistingHistory
// 2. resolveOutputSanitizerEnabled — per-chat override vs global fallback (all 8 combos)
// 3. resolveOutputSanitizerRules — per-chat rules vs global fallback

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:front_porch_ai/models/chat_generation_settings.dart';
import 'package:front_porch_ai/models/output_sanitizer_rule.dart';
import 'package:front_porch_ai/services/storage_service.dart';

void _setupPathProviderMock() {
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          final tmp = Directory.systemTemp.createTempSync('fpai_sanitize_');
          return tmp.path;
        }
        return null;
      });
}

Future<StorageService> _createStorageService([
  Map<String, Object> initialValues = const {},
]) async {
  SharedPreferences.setMockInitialValues(initialValues);
  final service = StorageService();
  await service.initialized;
  return service;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _setupPathProviderMock();

  // ─── GenerationSettings.setOutputSanitizerEnabled ─────────────────

  group('setOutputSanitizerEnabled', () {
    test('turning off implicitly resets sanitiseExistingHistory to false',
        () async {
      final storage = await _createStorageService();

      // Enable both global sanitizer and retroactive history sanitization.
      await storage.generationSettings.setOutputSanitizerEnabled(true);
      await storage.generationSettings.setSanitiseExistingHistory(true);
      expect(storage.generationSettings.outputSanitizerEnabled, isTrue);
      expect(storage.generationSettings.sanitiseExistingHistory, isTrue);

      // Turning global sanitizer off should reset retroactive flag.
      await storage.generationSettings.setOutputSanitizerEnabled(false);
      expect(storage.generationSettings.outputSanitizerEnabled, isFalse);
      expect(storage.generationSettings.sanitiseExistingHistory, isFalse);
    });

    test('turning on does NOT change sanitiseExistingHistory', () async {
      final storage = await _createStorageService();

      // Retroactive starts off.
      expect(storage.generationSettings.sanitiseExistingHistory, isFalse);

      // Turn global on — retroactive should stay off.
      await storage.generationSettings.setOutputSanitizerEnabled(true);
      expect(storage.generationSettings.outputSanitizerEnabled, isTrue);
      expect(storage.generationSettings.sanitiseExistingHistory, isFalse);

      // Manually enable retroactive, then toggle global off and on.
      await storage.generationSettings.setSanitiseExistingHistory(true);
      expect(storage.generationSettings.sanitiseExistingHistory, isTrue);

      await storage.generationSettings.setOutputSanitizerEnabled(false);
      expect(storage.generationSettings.sanitiseExistingHistory, isFalse);

      await storage.generationSettings.setOutputSanitizerEnabled(true);
      // Retroactive was reset to false when global was turned off;
      // turning global back on should NOT resurrect it.
      expect(storage.generationSettings.sanitiseExistingHistory, isFalse);
    });
  });

  // ─── ChatGenerationSettings.resolveOutputSanitizerEnabled ────────

  group('resolveOutputSanitizerEnabled', () {
    late StorageService storage;

    setUp(() async {
      storage = await _createStorageService();
    });

    // ── Global ON ────────────────────────────────────────────────────

    test('global ON, chat override null → true (inherits global)', () {
      // Global defaults to OFF; enable it.
      storage.generationSettings.setOutputSanitizerEnabled(true);

      final chat = ChatGenerationSettings(); // all null
      expect(chat.resolveOutputSanitizerEnabled(storage), isTrue);
    });

    test('global ON, chat override ON → true', () async {
      await storage.generationSettings.setOutputSanitizerEnabled(true);
      final chat = ChatGenerationSettings(outputSanitizerEnabled: true);
      expect(chat.resolveOutputSanitizerEnabled(storage), isTrue);
    });

    test('global ON, chat override OFF → false', () async {
      await storage.generationSettings.setOutputSanitizerEnabled(true);
      final chat = ChatGenerationSettings(outputSanitizerEnabled: false);
      expect(chat.resolveOutputSanitizerEnabled(storage), isFalse);
    });

    // ── Global OFF ───────────────────────────────────────────────────

    test('global OFF, chat override null → false (inherits global)', () {
      // Global defaults to OFF; don't touch it.
      expect(storage.generationSettings.outputSanitizerEnabled, isFalse);

      final chat = ChatGenerationSettings(); // all null
      expect(chat.resolveOutputSanitizerEnabled(storage), isFalse);
    });

    test('global OFF, chat override ON → true (chat overrides global)', () {
      final chat = ChatGenerationSettings(outputSanitizerEnabled: true);
      expect(chat.resolveOutputSanitizerEnabled(storage), isTrue);
    });

    test('global OFF, chat override OFF → false', () {
      final chat = ChatGenerationSettings(outputSanitizerEnabled: false);
      expect(chat.resolveOutputSanitizerEnabled(storage), isFalse);
    });
  });

  // ─── ChatGenerationSettings.resolveOutputSanitizerRules ───────────

  group('resolveOutputSanitizerRules', () {
    late StorageService storage;
    final globalRule = OutputSanitizerRule(id: 0, find: 'alpha', replace: 'ALPHA');
    final chatRule = OutputSanitizerRule(id: 1, find: 'beta', replace: 'BETA');

    setUp(() async {
      storage = await _createStorageService();
    });

    test('chat override null → inherits global rules', () async {
      await storage.generationSettings.setOutputSanitizerRules([globalRule]);
      final chat = ChatGenerationSettings(); // no rules override
      final rules = chat.resolveOutputSanitizerRules(storage);
      expect(rules, hasLength(1));
      expect(rules.first.find, 'alpha');
    });

    test('chat override set → uses chat rules, not global', () async {
      await storage.generationSettings.setOutputSanitizerRules([globalRule]);
      final chat = ChatGenerationSettings(outputSanitizerRules: [chatRule]);
      final rules = chat.resolveOutputSanitizerRules(storage);
      expect(rules, hasLength(1));
      expect(rules.first.find, 'beta');
    });

    test('chat override empty list → returns empty list', () async {
      await storage.generationSettings.setOutputSanitizerRules([globalRule]);
      final chat = ChatGenerationSettings(outputSanitizerRules: []);
      final rules = chat.resolveOutputSanitizerRules(storage);
      expect(rules, isEmpty);
    });
  });

  // ─── Retroactive gate: combined scenarios ─────────────────────────

  group('retroactive gate (combined enable flags)', () {
    late StorageService storage;

    setUp(() async {
      storage = await _createStorageService();
    });

    test('retroactive cannot activate when global sanitizer is off', () async {
      // Even with retroactive manually set on, global off blocks it.
      await storage.generationSettings.setOutputSanitizerEnabled(false);
      await storage.generationSettings.setSanitiseExistingHistory(true);

      // The retroactive condition requires BOTH flags:
      final retroActiveBlocked =
          !storage.generationSettings.outputSanitizerEnabled ||
          !storage.generationSettings.sanitiseExistingHistory;
      expect(retroActiveBlocked, isTrue);
    });

    test(
        'per-chat OFF blocks retroactive even when global + retroactive are on',
        () async {
      await storage.generationSettings.setOutputSanitizerEnabled(true);
      await storage.generationSettings.setSanitiseExistingHistory(true);

      final chat = ChatGenerationSettings(outputSanitizerEnabled: false);
      final freshWouldSanitize =
          chat.resolveOutputSanitizerEnabled(storage);
      // Fresh output: NOT sanitized (per-chat override wins).
      expect(freshWouldSanitize, isFalse);
      // Retroactive gate: the resolved enable is false, so retroactive
      // should also NOT apply to this chat.
      final retroactiveWouldApply = freshWouldSanitize &&
          storage.generationSettings.sanitiseExistingHistory;
      expect(retroactiveWouldApply, isFalse);
    });

    test(
        'per-chat ON + global ON + retroactive ON → both fresh and retroactive apply',
        () async {
      await storage.generationSettings.setOutputSanitizerEnabled(true);
      await storage.generationSettings.setSanitiseExistingHistory(true);

      final chat = ChatGenerationSettings(outputSanitizerEnabled: true);
      final freshWouldSanitize =
          chat.resolveOutputSanitizerEnabled(storage);
      expect(freshWouldSanitize, isTrue);
      final retroactiveWouldApply = freshWouldSanitize &&
          storage.generationSettings.sanitiseExistingHistory;
      expect(retroactiveWouldApply, isTrue);
    });

    test(
        'per-chat ON + global OFF → fresh applies but retroactive does not',
        () async {
      await storage.generationSettings.setOutputSanitizerEnabled(false);

      final chat = ChatGenerationSettings(outputSanitizerEnabled: true);
      final freshWouldSanitize =
          chat.resolveOutputSanitizerEnabled(storage);
      expect(freshWouldSanitize, isTrue);
      // Retroactive blocked because global is off.
      final retroactiveWouldApply =
          storage.generationSettings.outputSanitizerEnabled &&
              storage.generationSettings.sanitiseExistingHistory;
      expect(retroactiveWouldApply, isFalse);
    });
  });
}
