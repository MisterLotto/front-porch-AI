// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:front_porch_ai/services/storage_service.dart';
import 'package:front_porch_ai/services/web/facade/chat_tools_facade.dart';

import '../../golden/support/fakes.dart';

void _setupPathProviderMock() {
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall call) async {
    if (call.method == 'getApplicationDocumentsDirectory') {
      return Directory.systemTemp.createTempSync('fpai_test_').path;
    }
    return null;
  });
}

class _ObjectivesOffChat extends FakeChatService {
  @override
  bool get objectivesActive => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _setupPathProviderMock();

  late StorageService storage;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
  });

  test('objectives block reports enabled from objectivesActive', () {
    final on = ChatToolsFacade(FakeChatService(), storage, null);
    expect((on.state()['objectives'] as Map)['enabled'], isTrue);
    final off = ChatToolsFacade(_ObjectivesOffChat(), storage, null);
    expect((off.state()['objectives'] as Map)['enabled'], isFalse);
  });

  test('generate/set refuse when objectives are off', () async {
    final off = ChatToolsFacade(_ObjectivesOffChat(), storage, null);
    expect(await off.generateTasks('any'), isFalse);
    // setObjective must not reach ChatService (the off fake has no impl).
    await off.setObjective('win the prize');
  });
}
