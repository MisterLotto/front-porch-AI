// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/services/chat/with_user_eval.dart';
import 'package:front_porch_ai/services/llm_service.dart' show LlmToolCall;
import 'package:front_porch_ai/services/chat/realism_tools.dart';

void main() {
  test('parse true / false / missing', () {
    expect(WithUserEval.parseWithUser('{"with_user": true}'), isTrue);
    expect(WithUserEval.parseWithUser('{"with_user": false}'), isFalse);
    expect(WithUserEval.parseWithUser('{"with_user": "true"}'), isTrue);
    expect(WithUserEval.parseWithUser('{"posture": "on the couch"}'), isNull);
    expect(WithUserEval.parseWithUser(null), isNull);
    expect(WithUserEval.parseWithUser(''), isNull);
  });

  test('prompt never asks the model to move them', () {
    final p = WithUserEval.buildPrompt(
      charName: 'Misty',
      userName: 'Ben',
      reply: 'She sits on her own couch.',
      recentExchange: '',
      stance: 'sitting on her couch at home',
      toolsMode: false,
    );
    expect(p, contains('Do not move anyone'));
    expect(p, contains('Last known position of Misty'));
    expect(p, contains('sitting on her couch at home'));
    expect(p.toLowerCase(), isNot(contains('update to the new context')));
    expect(p.toLowerCase(), isNot(contains("don't jump locations")));
  });

  test('tools transport round-trips the verdict', () {
    expect(toolIsRegistered(kWithUserToolName), isTrue);
    final json = realismToolCallToJson(WithUserEval.kWithUserTool, [
      const LlmToolCall(
        name: 'report_with_user',
        arguments: {'with_user': false},
      ),
    ]);
    expect(WithUserEval.parseWithUser(json), isFalse);
  });

  test('failed detect leaves null (fail closed)', () async {
    final eval = WithUserEval(
      fire:
          ({required debugLabel, required tools, required buildPrompt}) async {
            throw StateError('backend down');
          },
    );
    expect(
      await eval.detect(
        charName: 'Misty',
        userName: 'Ben',
        reply: 'She is home.',
      ),
      isNull,
    );
  });
}
