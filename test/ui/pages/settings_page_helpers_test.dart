// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Guards for two Settings-page decisions that were wrong in shipped code:
//
//  • the model list was ALWAYS fetched from the Remote API URL, so on the
//    oMLX backend the picker offered OpenRouter's catalogue and tapping one
//    wrote a model oMLX cannot load into the shared remote_model_name pref;
//  • the web-server Port field only committed on Enter. It now commits on
//    focus loss too, which makes "what counts as a usable port" load-bearing:
//    a cleared or half-typed field must never overwrite the saved port (the
//    old Enter handler fell back to 8085 for any unparseable text).

import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/services/services.dart' show BackendType;
import 'package:front_porch_ai/ui/pages/pages.dart'
    show modelListApiUrl, parseWebServerPort;

void main() {
  group('modelListApiUrl', () {
    test('oMLX fetches from its own fixed local server, never the remote', () {
      expect(
        modelListApiUrl(BackendType.omlx, 'https://openrouter.ai/api/v1'),
        'http://localhost:8000/v1',
      );
    });

    test('remote and managed backends keep using the configured URL', () {
      expect(
        modelListApiUrl(BackendType.openRouter, 'https://openrouter.ai/api/v1'),
        'https://openrouter.ai/api/v1',
      );
      expect(modelListApiUrl(BackendType.kobold, ''), '');
    });
  });

  group('parseWebServerPort', () {
    test('accepts a typed port', () {
      expect(parseWebServerPort('9090'), 9090);
      expect(parseWebServerPort(' 8085 '), 8085);
    });

    test('unusable text means "leave the saved port alone"', () {
      expect(parseWebServerPort(''), isNull);
      expect(parseWebServerPort('   '), isNull);
      expect(parseWebServerPort('eighty-eighty-five'), isNull);
      expect(parseWebServerPort('0'), isNull);
      expect(parseWebServerPort('70000'), isNull);
      expect(parseWebServerPort('-1'), isNull);
    });
  });
}
