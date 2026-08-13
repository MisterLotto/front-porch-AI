// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

// AI Enhance's Backend & Model step: it must host the creator wizard's REAL
// SetupStep (the full picker — KoboldCpp/Remote/oMLX — was a maintainer
// requirement; a cut-down row was rejected), gate Continue on an actually
// ready backend, and pop with the selected model id. New route + navigation →
// interaction test per the routes rule.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:front_porch_ai/services/services.dart';
import 'package:front_porch_ai/ui/character_creator/character_creator.dart';
import 'package:front_porch_ai/ui/pages/home/enhance/enhance_setup_page.dart';

import '../../../golden/support/fakes_services.dart';

void _setupPathProviderMock() {
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          final tmp = Directory.systemTemp.createTempSync('fpai_test_');
          return tmp.path;
        }
        return null;
      });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Bounded settle: the REAL SetupStep may run repeating animations (e.g. the
  // blinking backend status dot), which makes pumpAndSettle spin forever.
  // Fixed pumps drive routes + microtasks without depending on quiescence.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets(
      'hosts the creator SetupStep; Continue pops the ready remote model',
      (tester) async {
    _setupPathProviderMock();
    SharedPreferences.setMockInitialValues({});
    // Real-async escape (repo convention, see folder_character_picker_test):
    // service init awaits real I/O futures the widget test's fake-async zone
    // never drives — constructing them inside the zone hangs the test.
    late final StorageService storage;
    late final KoboldService kobold;
    late final BackendManager backendManager;
    late final LLMProvider llm;
    await tester.runAsync(() async {
      storage = StorageService();
      await storage.initialized;
      // Remote backend, configured + keyed → ready without a local process.
      await storage.setBackendType('openRouter');
      await storage.setRemoteModel('current/model');
      await storage.setRemoteApiKey('test-key');
      kobold = KoboldService(storage);
      backendManager = BackendManager(storage);
      llm = LLMProvider(kobold, OpenRouterService(), storage, backendManager);
    });

    String? popped = 'sentinel';
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<StorageService>.value(value: storage),
        ChangeNotifierProvider<KoboldService>.value(value: kobold),
        ChangeNotifierProvider<BackendManager>.value(value: backendManager),
        ChangeNotifierProvider<LLMProvider>.value(value: llm),
        ChangeNotifierProvider<ModelManager>.value(value: FakeModelManager()),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              popped = await Navigator.of(context).push<String>(
                MaterialPageRoute(
                  builder: (_) =>
                      const EnhanceSetupPage(characterName: 'Nina'),
                ),
              );
            },
            child: const Text('go'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await settle(tester);

    // The creator's REAL step — its own header + backend chips are present.
    expect(find.byType(SetupStep), findsOneWidget);
    expect(find.text('Backend & Model Setup'), findsOneWidget);
    expect(find.text('KoboldCpp (Local)'), findsOneWidget);
    expect(find.text('API (Remote)'), findsOneWidget);

    // Remote is configured+keyed → Continue is live and pops the model id.
    // '' (use the active model) and the explicit active id resolve to the
    // same service; which one pops depends on whether the async model-list
    // fallback has landed yet.
    await tester.tap(find.text('Continue'));
    await settle(tester);
    expect(popped, anyOf('', 'current/model'));
    expect(find.byType(EnhanceSetupPage), findsNothing);
    expect(find.text('go'), findsOneWidget);
  });
}
