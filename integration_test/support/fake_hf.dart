// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// In-process stand-in for the HuggingFace API surface the Model Manager's
// search/download journey actually touches (ModelManager.hfBaseUrl points
// here in the E2E suite):
//
//   GET /api/models?search=...                the model search
//   GET /api/models/{owner}/{repo}/tree/main  the GGUF file listing
//   GET /{owner}/{repo}/resolve/main/{file}   the download itself
//
// One repo, two GGUF files: a small one that fits the suite's overridden
// VRAM and a 16 GB one that exceeds it (sizes are CLAIMED in the tree
// listing — the download always serves [downloadBytes], so even the
// "oversize" file completes in milliseconds once confirmed). Unmodeled
// paths land in [unexpectedPaths], asserted empty by the suite.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class FakeHuggingFace {
  FakeHuggingFace._(this._server);

  final HttpServer _server;

  static const String repoId = 'porch/Tiny-Porch-GGUF';
  static const String fitFilename = 'tiny-porch.Q4_K_M.gguf';
  static const String oversizeFilename = 'giant-porch-70B.Q8_0.gguf';

  /// Claimed sizes (bytes) in the tree listing — these drive the VRAM fit
  /// math, not the actual transfer.
  static const int fitClaimedBytes = 96 * 1024 * 1024;
  static const int oversizeClaimedBytes = 16 * 1024 * 1024 * 1024;

  /// What every download actually transfers.
  final Uint8List downloadBytes = Uint8List.fromList(
    List<int>.filled(64 * 1024, 0x50),
  );

  int searchRequests = 0;
  int treeRequests = 0;

  /// Filenames served through /resolve/main/, in order.
  final List<String> downloadsServed = [];

  final List<String> unexpectedPaths = [];

  /// Handler crashes — asserted empty by the suite for the same reason as
  /// [FakeStoopServer.handlerErrors]: a silently-broken fake presents as an
  /// anonymous timeout in whatever the app was waiting for.
  final List<String> handlerErrors = [];

  String get baseUrl => 'http://127.0.0.1:${_server.port}';

  static Future<FakeHuggingFace> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fake = FakeHuggingFace._(server);
    server.listen(fake._handle);
    return fake;
  }

  Future<void> _handle(HttpRequest req) async {
    final path = req.uri.path;
    try {
      if (path == '/api/models') {
        searchRequests++;
        req.response.headers.contentType = ContentType.json;
        req.response.write(
          jsonEncode([
            {
              'id': repoId,
              'author': 'porch',
              'likes': 12,
              'downloads': 3400,
              'tags': ['gguf', 'text-generation'],
              'description': 'A tiny porch-flavored test model.',
            },
          ]),
        );
      } else if (path == '/api/models/$repoId/tree/main') {
        treeRequests++;
        req.response.headers.contentType = ContentType.json;
        req.response.write(
          jsonEncode([
            {'path': fitFilename, 'size': fitClaimedBytes},
            {'path': oversizeFilename, 'size': oversizeClaimedBytes},
            {'path': 'README.md', 'size': 1024}, // must be filtered out
          ]),
        );
      } else if (path.startsWith('/$repoId/resolve/main/')) {
        final filename = path.split('/').last;
        downloadsServed.add(filename);
        req.response.headers.contentType = ContentType.binary;
        req.response.contentLength = downloadBytes.length;
        req.response.add(downloadBytes);
      } else {
        unexpectedPaths.add(path);
        req.response.statusCode = HttpStatus.notFound;
      }
    } catch (e) {
      handlerErrors.add('${req.method} $path: $e');
      // ignore: avoid_print — test support; print reaches the suite log.
      print('[FakeHuggingFace] handler error on $path: $e');
    } finally {
      try {
        await req.response.close();
      } catch (_) {}
    }
  }

  Future<void> close() => _server.close(force: true);
}
