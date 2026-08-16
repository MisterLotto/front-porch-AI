// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// LM Studio's /api/v0/models listing has no file path (verified 2026-08-15
// on 0.4.21). The GGUF still lives under ~/.lmstudio/models, so we match
// the model id onto a filename. Never call from a build path — this walks
// the downloads folder.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Override the `~/.lmstudio/models` root. Tests only.
@visibleForTesting
String? lmStudioModelsRootOverride;

/// LM Studio's downloads folder. Null when HOME/USERPROFILE is missing.
String? lmStudioModelsRoot() {
  if (lmStudioModelsRootOverride != null) return lmStudioModelsRootOverride;
  final home =
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  if (home == null || home.isEmpty) return null;
  return p.join(home, '.lmstudio', 'models');
}

String compactLmStudioId(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

/// Locate the GGUF for an LM Studio model id under [modelsRoot].
/// Skips `mmproj` projector files. Prefers a filename that also carries
/// [quantization] when the listing gave one.
Future<String?> findLmStudioGguf({
  required String modelsRoot,
  required String modelId,
  String? publisher,
  String? quantization,
}) async {
  if (modelsRoot.isEmpty || modelId.isEmpty) return null;
  final root = Directory(modelsRoot);
  if (!await root.exists()) return null;
  final needle = compactLmStudioId(modelId);
  if (needle.isEmpty) return null;
  final pub = (publisher ?? '').toLowerCase();
  final quant = compactLmStudioId(quantization ?? '');

  String? best;
  var bestScore = 0;
  await for (final ent in root.list(recursive: true, followLinks: false)) {
    if (ent is! File) continue;
    final name = p.basename(ent.path);
    if (!name.toLowerCase().endsWith('.gguf')) continue;
    if (name.toLowerCase().contains('mmproj')) continue;
    final compact = compactLmStudioId(p.basenameWithoutExtension(ent.path));
    if (!compact.contains(needle)) continue;
    var score = 10;
    if (pub.isNotEmpty && ent.path.toLowerCase().contains(pub)) score += 2;
    if (quant.isNotEmpty && compact.contains(quant)) score += 3;
    if (score > bestScore) {
      bestScore = score;
      best = ent.path;
    }
  }
  return best;
}
