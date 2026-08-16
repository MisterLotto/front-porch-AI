// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// -1 is the app-wide "random seed" sentinel (image_gen_settings defaults to it
// and the Image Studio field literally hints "-1=random"). Draw Things mapped
// it to the CONSTANT 0, and dt_config_fb writes seed as a uint32 whose schema
// default is 0 — so the field was omitted and the server rendered the same
// image for every generation. ComfyUI's sibling path does
// `seed == -1 ? Random().nextInt(1 << 31) : seed`; this is that behaviour.
//
// The transport itself needs a live Draw Things server, so this guards the
// resolver the config map calls, not the gRPC round-trip.

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/services/grpc/draw_things_grpc_service.dart';

void main() {
  group('DrawThingsGrpcService.effectiveSeed', () {
    test('-1 is randomised, never the fixed 0', () {
      final draws = List.generate(
        40,
        (_) => DrawThingsGrpcService.effectiveSeed(-1),
      );
      expect(
        draws.toSet().length,
        greaterThan(1),
        reason: 'the random sentinel must vary between generations',
      );
      expect(
        draws.where((s) => s == 0).length,
        lessThan(draws.length),
        reason: '-1 must not collapse to the constant 0',
      );
      for (final s in draws) {
        expect(s, inInclusiveRange(0, 1 << 31));
      }
    });

    test('an explicit seed is passed through untouched', () {
      expect(DrawThingsGrpcService.effectiveSeed(12345), 12345);
      expect(DrawThingsGrpcService.effectiveSeed(0), 0);
    });
  });
}
