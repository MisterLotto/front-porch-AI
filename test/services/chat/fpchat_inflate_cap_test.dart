// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/services/chat/chat.dart';

void main() {
  test('decodeFpchatBytes aborts when unpacked size exceeds the cap', () {
    final zip = encodeFpchatZip(
      chatJson: {
        'format': kFpchatFormatId,
        'messages': [
          {'name': 'U', 'is_user': true, 'mes': 'hi'},
        ],
      },
      images: {
        'pic.png': List<int>.filled(800, 7),
      },
    );
    expect(
      () => decodeFpchatBytes(zip, maxUncompressedBytes: 200),
      throwsA(isA<FormatException>()),
    );
    final ok = decodeFpchatBytes(zip);
    expect(ok.images['pic.png']!.length, 800);
  });
}
