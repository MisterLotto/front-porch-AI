// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

// Voice-call one-shot upgrade (2026-08-14, safe speed lane).
//
// On a live call, latency IS the product: the pre-generation judges run
// before the character can say a word, so a multi-call turn spends three
// eval round-trips in audible silence. resolveOneShotMode therefore treats
// an active call as an upgrade of Off to AUTO'S OWN RULE — fuse on a remote
// backend with a proven tools verdict, stay multi-call everywhere else.
// The one-shot parity law ("1:1 equivalent outputs") is what makes this a
// pure latency decision rather than a behavior change.
//
// What must NOT move: On and Auto answer exactly as they do outside a call
// (this table pins that), and local backends never fuse — call or no call —
// because small local models struggling with the fused prompt length is the
// reason the old bool defaulted off.
//
// Red-proven: with the `callMode &&` term dropped from the Off arm (making
// Off fuse outside calls too), 'Off stays plain Off outside a call' fails;
// with the whole Off arm reverted to `false`, 'a live call upgrades Off'
// fails. Both restored, the table is green.

import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/services/services.dart';
import 'package:front_porch_ai/services/chat/pass_support.dart';

void main() {
  test('a live call upgrades Off to the fuse-where-safe rule', () {
    expect(
      resolveOneShotMode(
        mode: OneShotMode.off,
        isLocal: false,
        toolSupport: ToolCallSupport.supported,
        callMode: true,
      ),
      isTrue,
      reason: 'remote + proven tools + live call = one eval round-trip '
          'instead of three of audible silence',
    );
  });

  test('Off stays plain Off outside a call', () {
    for (final isLocal in [true, false]) {
      for (final support in ToolCallSupport.values) {
        expect(
          resolveOneShotMode(
            mode: OneShotMode.off,
            isLocal: isLocal,
            toolSupport: support,
          ),
          isFalse,
          reason: 'text chats keep the user\'s explicit Off '
              '(isLocal=$isLocal, support=$support)',
        );
      }
    }
  });

  test('a call never fuses where Auto would not (local / unproven tools)', () {
    expect(
      resolveOneShotMode(
        mode: OneShotMode.off,
        isLocal: true,
        toolSupport: ToolCallSupport.supported,
        callMode: true,
      ),
      isFalse,
      reason: 'local backends stay multi-call, call or no call',
    );
    for (final support in [
      ToolCallSupport.untested,
      ToolCallSupport.unsupported,
    ]) {
      expect(
        resolveOneShotMode(
          mode: OneShotMode.off,
          isLocal: false,
          toolSupport: support,
          callMode: true,
        ),
        isFalse,
        reason: 'no proven tools verdict, no fuse ($support)',
      );
    }
  });

  test('On and Auto are untouched by a live call', () {
    for (final callMode in [true, false]) {
      // On always fuses.
      for (final isLocal in [true, false]) {
        expect(
          resolveOneShotMode(
            mode: OneShotMode.on,
            isLocal: isLocal,
            toolSupport: ToolCallSupport.untested,
            callMode: callMode,
          ),
          isTrue,
        );
      }
      // Auto keeps its own rule bit-for-bit.
      expect(
        resolveOneShotMode(
          mode: OneShotMode.auto,
          isLocal: false,
          toolSupport: ToolCallSupport.supported,
          callMode: callMode,
        ),
        isTrue,
      );
      expect(
        resolveOneShotMode(
          mode: OneShotMode.auto,
          isLocal: true,
          toolSupport: ToolCallSupport.supported,
          callMode: callMode,
        ),
        isFalse,
      );
    }
  });
}
