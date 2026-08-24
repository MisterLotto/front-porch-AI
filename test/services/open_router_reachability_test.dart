// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:front_porch_ai/services/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  OpenRouterService configured() => OpenRouterService(
    apiUrl: 'https://openrouter.ai/api/v1',
    apiKey: 'sk-test',
    modelName: 'test-model',
  );

  test('configured without a ping is provisionally ready, not reachable', () {
    final svc = configured();
    expect(svc.isConfigured, isTrue);
    expect(svc.isReachable, isFalse);
    expect(svc.reachability, RemoteReachability.unknown);
    expect(svc.isReady, isTrue);
    expect(
      remoteBackendStatusLabel(
        configured: svc.isConfigured,
        reachability: svc.reachability,
      ),
      isNot('Ready'),
    );
  });

  test('a successful ping stamps reachable and keeps isReady', () async {
    final svc = configured();
    svc.httpClientFactory = () =>
        MockClient((_) async => http.Response('{"data":[]}', 200));
    await svc.refreshReachability();
    expect(svc.reachability, RemoteReachability.reachable);
    expect(svc.isReachable, isTrue);
    expect(svc.isReady, isTrue);
  });

  test('a failed ping stamps unreachable and isReady is false', () async {
    final svc = configured();
    svc.httpClientFactory = () => MockClient(
      (_) async => http.Response('{"error":{"message":"down"}}', 503),
    );
    await svc.refreshReachability();
    expect(svc.reachability, RemoteReachability.unreachable);
    expect(svc.isReachable, isFalse);
    expect(svc.isReady, isFalse);
  });

  test('testConnection against the live URL stamps reachability', () async {
    final svc = configured();
    svc.httpClientFactory = () =>
        MockClient((_) async => http.Response('nope', 401));
    final msg = await svc.testConnection();
    expect(msg, contains('failed'));
    expect(svc.isReady, isFalse);
    expect(svc.reachability, RemoteReachability.unreachable);
  });

  test('unconfigured stays not ready', () {
    final svc = OpenRouterService();
    expect(svc.isConfigured, isFalse);
    expect(svc.isReady, isFalse);
  });
}
