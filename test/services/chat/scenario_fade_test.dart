// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/services/chat/scenario_fade.dart';

void main() {
  group('ScenarioFade.strengthForUserMessageCount', () {
    test('starts at full strength', () {
      expect(ScenarioFade.strengthForUserMessageCount(0), 10);
      expect(ScenarioFade.strengthForUserMessageCount(5), 10);
    });

    test('steps down one strength every kUserMessagesPerStrengthStep', () {
      const step = ScenarioFade.kUserMessagesPerStrengthStep;
      expect(ScenarioFade.strengthForUserMessageCount(step), 9);
      expect(ScenarioFade.strengthForUserMessageCount(step * 2 - 1), 9);
      expect(ScenarioFade.strengthForUserMessageCount(step * 2), 8);
      expect(ScenarioFade.strengthForUserMessageCount(step * 9), 1);
    });

    test('reaches 0 at 60 user messages and stays there', () {
      expect(ScenarioFade.dropAfterUserMessages, 60);
      final dropAt = ScenarioFade.dropAfterUserMessages;
      expect(ScenarioFade.strengthForUserMessageCount(dropAt - 1), 1);
      expect(ScenarioFade.strengthForUserMessageCount(dropAt), 0);
      expect(ScenarioFade.strengthForUserMessageCount(dropAt + 50), 0);
    });

    test('negative counts clamp like zero', () {
      expect(ScenarioFade.strengthForUserMessageCount(-3), 10);
    });
  });

  group('ScenarioFade.wrapScenario', () {
    const body = 'Rain on the docks. She is waiting.';

    test('empty or zero strength yields empty injection', () {
      expect(ScenarioFade.wrapScenario('', 10), isEmpty);
      expect(ScenarioFade.wrapScenario(body, 0), isEmpty);
      expect(ScenarioFade.wrapScenario('  ', 5), isEmpty);
    });

    test('high strength uses plain Scenario: prefix', () {
      expect(ScenarioFade.wrapScenario(body, 10), 'Scenario: $body\n');
      expect(ScenarioFade.wrapScenario(body, 8), startsWith('Scenario: '));
    });

    test('mid strength marks background', () {
      final w = ScenarioFade.wrapScenario(body, 5);
      expect(w, contains('background'));
      expect(w, contains(body));
    });

    test('low strength marks opening premise only', () {
      final w = ScenarioFade.wrapScenario(body, 2);
      expect(w, contains('Opening premise only'));
      expect(w, contains(body));
    });
  });
}
