// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Web Settings now round-trips Top-P/K, DRY, dynatemp range, stops, bans,
// sanitise-history, and the global system prompt (audit P2.12).

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:front_porch_ai/services/open_router_service.dart';
import 'package:front_porch_ai/services/storage_service.dart';
import 'package:front_porch_ai/services/web/facade/settings_facade.dart';

import '../../golden/support/fakes.dart';

class _Llm extends FakeLLMProvider {
  final OpenRouterService remote = OpenRouterService();
  @override
  OpenRouterService get openRouterService => remote;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return Directory.systemTemp.createTempSync('fpai_samp_').path;
        }
        return null;
      });

  test(
    'read/apply expose sampling extras the Generation tab already had',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.initialized;
      final facade = SettingsFacade(storage, _Llm());

      await facade.update({
        'systemPrompt': 'Stay on the porch.',
        'bannedPhrases': ['nope'],
        'generation': {
          'topP': 0.8,
          'topK': 40,
          'dryMultiplier': 0.5,
          'dynamicTempRange': 0.3,
          'stopSequences': ['END'],
          'outputSanitizerEnabled': true,
          'sanitiseExistingHistory': true,
        },
      });

      final out = facade.read();
      expect(out['systemPrompt'], 'Stay on the porch.');
      expect(out['bannedPhrases'], ['nope']);
      final gen = out['generation'] as Map;
      expect(gen['topP'], closeTo(0.8, 0.001));
      expect(gen['topK'], 40);
      expect(gen['dryMultiplier'], closeTo(0.5, 0.001));
      expect(gen['dynamicTempRange'], closeTo(0.3, 0.001));
      expect(gen['stopSequences'], ['END']);
      expect(gen['sanitiseExistingHistory'], isTrue);
    },
  );

  test('sanitise-history cannot re-arm when the sanitizer is off', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.initialized;
    final facade = SettingsFacade(storage, _Llm());
    await facade.update({
      'generation': {
        'outputSanitizerEnabled': true,
        'sanitiseExistingHistory': true,
      },
    });
    expect(storage.generationSettings.sanitiseExistingHistory, isTrue);

    await facade.update({
      'generation': {
        'outputSanitizerEnabled': false,
        'sanitiseExistingHistory': true,
      },
    });
    expect(storage.generationSettings.outputSanitizerEnabled, isFalse);
    expect(
      storage.generationSettings.sanitiseExistingHistory,
      isFalse,
      reason: 'stale PWA true must not re-arm a history rewrite',
    );
  });
}
