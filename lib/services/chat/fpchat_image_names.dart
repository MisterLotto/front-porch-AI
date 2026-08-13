// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:path/path.dart' as path;

/// Strip stacked `fpchat_<sid>_<seq>_` prefixes (sid may be digits or `import`).
final RegExp fpchatImagePrefixRe = RegExp(r'^fpchat_[A-Za-z0-9]+_\d+_');

String stripFpchatImagePrefixes(String base) {
  var b = path.basename(base);
  for (var i = 0; i < 32 && fpchatImagePrefixRe.hasMatch(b); i++) {
    b = b.replaceFirst(fpchatImagePrefixRe, '');
  }
  if (b.isEmpty) b = 'image.png';
  return b;
}

/// `fpchat_<sid>_<seq>[_n]_<stem><ext>` with stem capped so total ≤ 120.
String cappedFpchatImageName(
  String sid,
  int seq,
  String cleanBase, {
  int? collision,
}) {
  var ext = path.extension(cleanBase);
  if (ext.length > 12) ext = '.png';
  var stem = path.basenameWithoutExtension(cleanBase);
  if (stem.isEmpty) stem = 'image';
  final mid = collision == null ? '${seq}_' : '${seq}_${collision}_';
  // Keep sid so two imports cannot collide on fpchat_3_0.png.
  final safeSid = sid.length > 24 ? sid.substring(sid.length - 24) : sid;
  final prefix = 'fpchat_${safeSid}_$mid';
  final budget = 120 - prefix.length - ext.length;
  if (budget < 4) {
    return 'fpchat_${safeSid}_${seq}_${collision ?? 0}$ext';
  }
  if (stem.length > budget) stem = stem.substring(0, budget);
  return '$prefix$stem$ext';
}
