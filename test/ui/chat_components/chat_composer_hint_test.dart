// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/ui/chat_components/chat_components.dart';

void main() {
  group('chatComposerHint', () {
    test('shows No API connection when the backend is down', () {
      expect(
        chatComposerHint(apiReady: false, observerMode: false),
        kNoApiConnectionHint,
      );
    });

    test('connection-down wins over observer mode', () {
      expect(
        chatComposerHint(apiReady: false, observerMode: true),
        kNoApiConnectionHint,
      );
    });

    test('restores the normal hint when the connection recovers', () {
      expect(
        chatComposerHint(apiReady: true, observerMode: false),
        kTypeAMessageHint,
      );
    });

    test('observer hint only when connected', () {
      expect(
        chatComposerHint(apiReady: true, observerMode: true),
        kDirectTheSceneHint,
      );
    });
  });
}
