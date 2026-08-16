// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/services/llm_service.dart';
import 'package:front_porch_ai/services/openai_completions_fallback.dart';

void main() {
  setUp(debugResetCompletionsOnlyModels);

  test('recognises the oMLX chat-completions rejection', () {
    expect(
      isChatCompletionsUnsupportedError(
        'Model Qwen3.8-27B-MLX-8bit is not supported on /v1/chat/completions.',
      ),
      isTrue,
    );
    expect(
      isChatCompletionsUnsupportedError('HTTP 400: invalid max_tokens'),
      isFalse,
    );
  });

  test('completions payload is a prompt, not messages', () {
    final p = openAiCompletionsPayload(
      GenerationParams(
        prompt: 'Write a greeting',
        systemPrompt: 'You are a writer',
        maxLength: 128,
      ),
      modelName: 'Qwen3.8-27B-MLX-8bit',
      stream: true,
    );
    expect(p.containsKey('messages'), isFalse);
    expect(p['prompt'], contains('You are a writer'));
    expect(p['prompt'], contains('Write a greeting'));
    expect(p['model'], 'Qwen3.8-27B-MLX-8bit');
  });

  test('SSE parser yields choices[0].text', () async {
    final bytes = Stream<List<int>>.fromIterable([
      utf8.encode(
        'data: {"choices":[{"text":"Hel"}]}\n'
        'data: {"choices":[{"text":"lo"}]}\n'
        'data: [DONE]\n',
      ),
    ]);
    expect(await parseCompletionsSse(bytes).toList(), ['Hel', 'lo']);
  });
}
