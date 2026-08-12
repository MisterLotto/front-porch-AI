// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A Nano-style host that does not list supported_efforts must still teach
// the chip row at model-pick time via the same "Supported values are:"
// 400 the live send path already learns from.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/services/reasoning_effort.dart';
import 'package:front_porch_ai/services/reasoning_effort_probe.dart';

void main() {
  // Flutter's test binding stubs HttpClient to 400 everything.
  setUp(() => HttpOverrides.global = null);
  setUp(() {
    clearReasoningEffortCatalog();
    clearReasoningEffortProbes();
  });

  test('probe learns High/Max from a Nano 400 and updates chips', () async {
    final seen = <String?>[];
    final server = await _startFakeNano(seen: seen);
    addTearDown(server.close);

    const model = 'moonshotai/kimi-k2.6:thinking';
    expect(reasoningEffortChipsFor(model), ['low', 'high', 'max']);

    final learned = await probeReasoningEfforts(
      model: model,
      apiUrl: 'http://${server.address.host}:${server.port}',
      apiKey: 'test',
      allowLocal: true,
    );
    expect(learned, isTrue);
    expect(seen.single, 'fpai_probe');
    expect(reasoningEffortChipsFor(model), ['high', 'max']);
    expect(reasoningEffortMenuPending(model), isFalse);
  });

  test('probe is skipped once the menu is known', () async {
    rememberReasoningEffortsForModel('already/known', {'low', 'high'});
    final hits = <int>[];
    final server = await _startFakeNano(seen: [], onHit: () => hits.add(1));
    addTearDown(server.close);

    final learned = await probeReasoningEfforts(
      model: 'already/known',
      apiUrl: 'http://${server.address.host}:${server.port}',
      apiKey: 'test',
      allowLocal: true,
    );
    expect(learned, isFalse);
    expect(hits, isEmpty);
  });

  test('local URLs are not poked', () async {
    expect(
      await probeReasoningEfforts(
        model: 'local-model',
        apiUrl: 'http://127.0.0.1:1234/v1',
        apiKey: '',
      ),
      isFalse,
    );
  });

  test('a listing-less 400 is not poked again', () async {
    final hits = <int>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((req) async {
      hits.add(1);
      req.response
        ..statusCode = 400
        ..write('nope')
        ..close();
    });
    final url = 'http://${server.address.host}:${server.port}';
    await probeReasoningEfforts(
      model: 'acme/silent',
      apiUrl: url,
      apiKey: 't',
      allowLocal: true,
    );
    await probeReasoningEfforts(
      model: 'acme/silent',
      apiUrl: url,
      apiKey: 't',
      allowLocal: true,
    );
    expect(hits, [1]);
  });
}

Future<HttpServer> _startFakeNano({
  required List<String?> seen,
  void Function()? onHit,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((req) async {
    onHit?.call();
    final body = jsonDecode(await utf8.decoder.bind(req).join()) as Map;
    final reasoning = (body['reasoning'] as Map?)?.cast<String, dynamic>();
    seen.add(reasoning?['effort']?.toString() ??
        body['reasoning_effort']?.toString());
    req.response
      ..statusCode = 400
      ..headers.contentType = ContentType.json
      ..write(jsonEncode({
        'error': {
          'message':
              'Invalid value for reasoning.effort: "fpai_probe". '
              'Supported values are: none, high, max.',
        },
      }));
    await req.response.close();
  });
  return server;
}
