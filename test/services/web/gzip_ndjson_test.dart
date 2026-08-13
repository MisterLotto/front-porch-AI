// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// JSONL chat export is application/x-ndjson. GzipMiddleware must compress it
// the same way it compresses application/json — this lives in its own file
// so test-integrity does not treat gzip_middleware_test.dart as edited.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart' as shelf;

import 'package:front_porch_ai/services/web/middleware/gzip_middleware.dart';

void main() {
  final middleware = const GzipMiddleware().middleware;

  test('compresses application/x-ndjson (chat JSONL export)', () async {
    final body = '{"mes":"x"}\n' * 400;
    final handler = middleware(
      (_) async => shelf.Response.ok(
        body,
        headers: {'Content-Type': 'application/x-ndjson; charset=utf-8'},
      ),
    );
    final res = await handler(
      shelf.Request(
        'GET',
        Uri.parse('http://localhost/api/chat/export.jsonl'),
        headers: {'Accept-Encoding': 'gzip'},
      ),
    );

    expect(res.headers[HttpHeaders.contentEncodingHeader], 'gzip');
    expect(
      utf8.decode(gzip.decode(
        (await res.read().toList()).expand((c) => c).toList(),
      )),
      body,
    );
  });
}
