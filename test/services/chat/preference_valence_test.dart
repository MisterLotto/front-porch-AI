// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// This file is part of Front Porch AI.
//
// Front Porch AI is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Front Porch AI is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with Front Porch AI. If not, see <https://www.gnu.org/licenses/>.

// Authored tastes own the SIGN of bond / emotion / arousal, not only the size.
// Intimate prefs landed after the vanilla "Rejection: −15 to −25" band, so a
// femdom card that warms to struggle still scored lust and bond DOWN on a
// resist. These pins are the prompt contract; the model is the remaining
// half, but without this language the numbered band always wins.

import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/services/chat/chat.dart';

String block({
  List<String> likes = const [],
  List<String> into = const [],
  bool agency = false,
}) => RealismPromptBuilder.preferencesBlock(
  charName: 'Nemu',
  likes: likes,
  intimateInto: into,
  intimateAgency: agency,
);

({String relationship, String emotional, String oneShot}) judges(
  String prefs, {
  bool arousal = true,
}) {
  const common = (
    charName: 'Nemu',
    userName: 'Linus',
    dossier: 'Who Nemu is …\n\n',
    standing: 'Where things stand …\n\n',
    recent: 'Linus: I run\nNemu: …',
  );
  return (
    relationship: RealismPromptBuilder.relationshipEvalPrompt(
      charName: common.charName,
      userName: common.userName,
      dossier: common.dossier,
      standing: common.standing,
      recent: common.recent,
      preferences: prefs,
    ),
    emotional: RealismPromptBuilder.emotionalEvalPrompt(
      charName: common.charName,
      userName: common.userName,
      dossier: common.dossier,
      standing: common.standing,
      recent: common.recent,
      arousalEnabled: arousal,
      arousalLevel: 8,
      preferences: prefs,
    ),
    oneShot: RealismPromptBuilder.oneShotEvalPrompt(
      charName: common.charName,
      userName: common.userName,
      dossier: common.dossier,
      standing: common.standing,
      recent: common.recent,
      arousalEnabled: arousal,
      arousalLevel: 8,
      preferences: prefs,
    ),
  );
}

void main() {
  group('empty card — vanilla physics', () {
    test('costs nothing: no valence invert in the preferences block', () {
      expect(block(), isEmpty);
      expect(block(), isNot(contains('owns the SIGN')));
    });

    test('relationship judge has no invert when prefs are empty', () {
      final p = judges('');
      expect(p.relationship, isNot(contains('owns the SIGN')));
      expect(
        p.relationship,
        isNot(contains('Vanilla rejection physics apply only')),
      );
    });
  });

  group('a listed taste owns the sign', () {
    final prefs = block(
      likes: const ['the feeling of someone struggling under her strength'],
      into: const ['breast smothering — the struggle, the control'],
    );

    test('the block says SIGN not only size, and names the chase class', () {
      expect(prefs, contains('owns the SIGN'));
      expect(prefs, contains('flight, struggle, chase, capture'));
      expect(prefs, contains('not generic hurt'));
      expect(
        prefs,
        contains(
          'Vanilla rejection physics apply only when no listed taste matches',
        ),
      );
    });

    test('trust is not inverted as a blob', () {
      expect(prefs, contains('Trust does not automatically follow'));
      expect(prefs, contains('whether they can rely on this person'));
    });

    test('a genuine out-of-play stop stays negative', () {
      expect(prefs, contains('genuine out-of-play stop'));
      expect(prefs, contains('not play-struggle'));
    });

    test('all three judges carry the SAME invert, byte for byte', () {
      final p = judges(prefs);
      expect(p.relationship, contains(prefs));
      expect(p.emotional, contains(prefs));
      expect(p.oneShot, contains(prefs));
    });
  });

  group('the Rejection band yields', () {
    test('arousal rubric still has the vanilla numbers', () {
      final p = judges('');
      expect(p.emotional, contains('Rejection or humiliation: -15 to -25'));
      expect(p.oneShot, contains('Rejection or humiliation: -15 to -25'));
    });

    test('and then says authored tastes outrank that band', () {
      final p = judges('');
      expect(p.emotional, contains('outrank the Rejection band'));
      expect(p.oneShot, contains('outrank the Rejection band'));
      expect(p.emotional, contains('out-of-play stop is still Rejection'));
    });

    test('relationship judge has no arousal band to outrank', () {
      // Bond invert lives in the preferences block, not a second copy of the
      // lust numbers. Empty prefs must not leak lust language into bond.
      final p = judges('');
      expect(p.relationship, isNot(contains('outrank the Rejection band')));
    });
  });

  group('Acts on desires — refuse is fuel when it is the taste', () {
    test('agency still scores a refusal as a real moment', () {
      final txt = block(into: const ['being held down'], agency: true);
      expect(txt, contains('was refused'));
      expect(txt, contains('anger or cold distance in a dominant character'));
    });

    test('and then yields when the refusal IS the taste', () {
      final txt = block(
        into: const ['the struggle, the control'],
        agency: true,
      );
      expect(txt, contains('fuel, not a wound'));
    });

    test('the fuel clause is absent when the switch is off', () {
      final txt = block(
        into: const ['the struggle, the control'],
        agency: false,
      );
      expect(txt, contains('owns the SIGN'));
      expect(txt, isNot(contains('fuel, not a wound')));
      expect(txt, isNot(contains('was refused')));
    });
  });

  group('vanilla likes are not a blanket chase invert', () {
    test('thunderstorms still get the conditional, not a hard-wired hunt', () {
      final txt = block(likes: const ['thunderstorms']);
      expect(txt, contains('owns the SIGN'));
      expect(txt, contains('only when no listed taste matches'));
      expect(txt, contains('drawn to thunderstorms'));
    });
  });
}
