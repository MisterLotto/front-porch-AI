// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/services/reasoning_effort.dart';

void main() {
  setUp(clearReasoningEffortCatalog);

  test('app levels have titles and blurbs', () {
    for (final id in kAppReasoningEfforts) {
      expect(reasoningEffortTitle(id), isNotEmpty);
      expect(reasoningEffortBlurb(id), isNotEmpty);
    }
    expect(reasoningEffortTitle('xhigh'), 'Extra high');
    expect(reasoningEffortTitle('max'), 'Max');
  });

  test(':thinking models map low/medium to high on the wire', () {
    const model = 'deepseek/deepseek-v4-flash:thinking';
    expect(wireReasoningEffort(model, 'low'), 'high');
    expect(wireReasoningEffort(model, 'medium'), 'high');
    expect(wireReasoningEffort(model, 'high'), 'high');
    expect(wireReasoningEffort(model, 'max'), 'max');
    expect(wireReasoningEffort(model, 'low'), isNot('low'));
    expect(wireReasoningEffort(model, 'high'), 'high');
  });

  test(':thinking chips are High and Max — not Low or Medium', () {
    const model = 'deepseek/deepseek-v4-flash:thinking';
    expect(reasoningEffortChipsFor(model), ['high', 'max']);
    expect(reasoningEffortDisplayedSelection(model, 'low'), 'high');
    expect(reasoningEffortDisplayedSelection(model, 'medium'), 'high');
    expect(reasoningEffortDisplayedSelection(model, 'high'), 'high');
    expect(reasoningEffortDisplayedSelection(model, 'max'), 'max');
  });

  test('catalog DeepSeek V4 chips are Low / High / Max', () {
    rememberReasoningProfileFromCatalog('deepseek/deepseek-v4-flash-0731', {
      'supported_efforts': ['max', 'high', 'low'],
      'mandatory': false,
    });
    expect(reasoningEffortChipsFor('deepseek/deepseek-v4-flash-0731'), [
      'low',
      'high',
      'max',
    ]);
    expect(
      reasoningEffortIsMandatory('deepseek/deepseek-v4-flash-0731'),
      isFalse,
    );
  });

  test('mandatory catalog models lock Off and still show chips', () {
    rememberReasoningProfileFromCatalog('x-ai/grok-4.6', {
      'supported_efforts': ['xhigh', 'high', 'medium', 'low'],
      'mandatory': true,
    });
    expect(reasoningEffortIsMandatory('x-ai/grok-4.6'), isTrue);
    expect(reasoningEffortThinkingOn('x-ai/grok-4.6', false), isTrue);
    expect(reasoningEffortChipsFor('x-ai/grok-4.6'), [
      'low',
      'medium',
      'high',
      'xhigh',
    ]);
    final cap = reasoningEffortMappingCaption('x-ai/grok-4.6', 'high');
    expect(cap.toLowerCase(), contains('always thinks'));
    expect(cap, contains('Extra high'));
  });

  test('mapping caption names this model\'s real menu', () {
    const model = 'deepseek/deepseek-v4-flash:thinking';
    final cap = reasoningEffortMappingCaption(model, 'low');
    expect(cap, contains('High'));
    expect(cap, contains('Max'));
    expect(cap, isNot(contains('Low')));
  });

  test('only-max models show a Max chip and snap the saved pick to it', () {
    rememberReasoningEffortsForModel('acme/max-only', {'none', 'max'});
    expect(reasoningEffortChipsFor('acme/max-only'), ['max']);
    expect(reasoningEffortDisplayedSelection('acme/max-only', 'medium'), 'max');
  });

  test('GLM-5.2 chips are High / Max (thinking can still be Off)', () {
    expect(reasoningEffortChipsFor('z-ai/glm-5.2:thinking'), ['high', 'max']);
    expect(reasoningEffortIsMandatory('z-ai/glm-5.2:thinking'), isFalse);
  });

  test('Kimi K2.6 keeps Low — :thinking is not DeepSeek\'s menu', () {
    const model = 'moonshotai/kimi-k2.6:thinking';
    expect(reasoningEffortChipsFor(model), ['low', 'high', 'max']);
    expect(wireReasoningEffort(model, 'low'), 'low');
    expect(reasoningEffortIsMandatory(model), isFalse);
  });

  test('a random :thinking id is not guessed as High/Max', () {
    expect(reasoningEffortChipsFor('acme/mystery-reasoner:thinking'), [
      'low',
      'medium',
      'high',
    ]);
    expect(
      wireReasoningEffort('acme/mystery-reasoner:thinking', 'medium'),
      'medium',
    );
  });

  test('plain models pass the user pick through until a 400 teaches them', () {
    expect(wireReasoningEffort('acme/gpt-lite', 'low'), 'low');
    rememberReasoningEffortsForModel('acme/gpt-lite', {'none', 'high', 'max'});
    expect(wireReasoningEffort('acme/gpt-lite', 'low'), 'high');
    expect(reasoningEffortChipsFor('acme/gpt-lite'), ['high', 'max']);
  });

  test('the LMS/OpenAI server enum is not a per-model menu', () {
    const lms =
        "Invalid 'reasoning_effort' value: 'fpai_probe'. "
        'Supported values: none, minimal, low, medium, high, xhigh.';
    final listing = supportedReasoningEffortsFromError(lms)!;
    expect(isGenericProviderEffortSchema(listing), isTrue);
    expect(
      isGenericProviderEffortSchema({'none', 'high', 'max'}),
      isFalse,
      reason: 'DeepSeek-on-Nano is a real short menu',
    );
    expect(
      isGenericProviderEffortSchema({'none', 'low', 'high', 'max'}),
      isFalse,
      reason: 'Kimi is a real short menu',
    );
  });

  test('toggle-only has no chips and does not wire effort none', () {
    rememberReasoningEffortsForModel('google/gemma-4-26b-a4b', const {'none'});
    expect(reasoningEffortIsToggleOnly('google/gemma-4-26b-a4b'), isTrue);
    expect(reasoningEffortChipsFor('google/gemma-4-26b-a4b'), isEmpty);
    expect(
      wireReasoningEffort('google/gemma-4-26b-a4b', 'minimal'),
      'minimal',
      reason: 'rewriting to none would turn thinking off on Nano/OpenRouter',
    );
  });
}
