// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/utils/path_exists_memo.dart';

void main() {
  test('PathExistsMemo stats once per path and reuses the answer', () async {
    final dir = await Directory.systemTemp.createTemp('fpai_exists_');
    final file = File('${dir.path}${Platform.pathSeparator}model.gguf');
    await file.writeAsBytes([1, 2, 3]);
    addTearDown(() => dir.delete(recursive: true));

    final memo = PathExistsMemo();
    expect(memo.of(file.path), isTrue);

    await file.delete();
    expect(
      memo.of(file.path),
      isTrue,
      reason: 'same path must not re-stat — that is the Kobold-log-line bug',
    );

    expect(memo.of('${file.path}.other'), isFalse);
    expect(memo.of(null), isFalse);
    expect(memo.of(''), isFalse);
  });
}
