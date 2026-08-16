// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The RAG dialog's Cancel calls EmbeddingService.cancelSetup() →
// NativeEmbeddingEngine.shutdown(). Loading the ~550MB nomic session takes
// SECONDS, and for all of it the engine's `_worker` field is still null — so
// a shutdown that lands inside that window used to send its stop message to
// nothing, and the spawn that finished a moment later published the session
// anyway. The user's Cancel silently kept ~550MB resident for the rest of
// the process.
//
// Model-gated exactly like nomic_embedding_test.dart: runs where the real
// model + FP_ORT_LIB exist (the dev Mac), skips in CI.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/services/embedding/native_embedding_engine.dart';

void main() {
  final files = NativeEmbeddingEngine.resolveModelFiles(null);
  final ortLib = Platform.environment['FP_ORT_LIB'] ?? '';
  final runnable = files != null && ortLib.isNotEmpty;

  test(
    'shutdown during model load aborts the embed instead of publishing the session',
    () async {
      final engine = NativeEmbeddingEngine();
      final pending = engine.embed(
        modelPath: files!.model,
        vocabPath: files.vocab,
        text: 'test',
      );
      // Well inside the load window (the session takes seconds), well after
      // the spawn has started.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      engine.shutdown();

      await expectLater(
        pending,
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('shut down during model load'),
          ),
        ),
      );

      // And the engine is genuinely released, not left half-wired: the next
      // embed must spawn a fresh worker and succeed.
      final after = await engine.embed(
        modelPath: files.model,
        vocabPath: files.vocab,
        text: 'test',
      );
      expect(after, hasLength(768));
      engine.shutdown();
    },
    skip: runnable
        ? false
        : 'needs the nomic model on disk AND FP_ORT_LIB pointing at '
              'libonnxruntime — skipping',
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
