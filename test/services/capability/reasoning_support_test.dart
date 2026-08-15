// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

// Local (KoboldCpp) thinking capability, read from the GGUF chat template
// (2026-08-15).
//
// Why this exists rather than a poke: the remote probe learns a model's menu
// from a provider's "Supported values are: …" 400. KoboldCpp never produces
// one — it forwards enable_thinking / reasoning_effort straight to the chat
// template — so poking it would spend a request to learn nothing AND burn the
// "already probed" flag. The template IS the capability, and it is on disk.
//
// The four template shapes below are the real ones, in the order that
// matters: harmony (gpt-oss) carries reasoning_effort AND channel markers,
// Qwen3 carries enable_thinking AND <think>, so a naive marker-first check
// would call both of them "always thinks" and hide controls that work.
//
// Red-proven (2026-08-15):
//   * checking markers before the switches → the harmony and Qwen3 cases fail
//     (both misread as `always`);
//   * dropping the '<|channel|>analysis' marker → the harmony-without-effort
//     case fails (a thinking model reported as having no thinking mode);
//   * returning a graded set for `toggle` → the "no strength chips" case
//     fails (decorative chips come back).

import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/services/capability/reasoning_support.dart';
import 'package:front_porch_ai/services/reasoning_effort.dart';

/// Qwen3-style: a real on/off kwarg, and the think tags it emits when on.
const _qwen3 = '''
{%- if enable_thinking is defined and enable_thinking is false %}
    {{- '<think>\\n\\n</think>\\n\\n' }}
{%- endif %}
''';

/// gpt-oss / harmony: graded effort, and channels instead of `<think>`.
const _harmony = '''
{{- "Reasoning: " + reasoning_effort + "\\n\\n" }}
{{- "<|channel|>analysis<|message|>" }}
''';

/// A harmony-shaped template with NO effort knob — thinking still happens.
const _harmonyNoEffort = '<|start|>assistant<|channel|>analysis<|message|>';

/// R1-style distill: the think tag is forced open, with no switch at all.
const _r1 = "{{- '<｜Assistant｜>' }}{{- '<think>\\n' }}";

/// Plain instruct model: nothing to do with thinking.
const _llama3 = '''
{% for message in messages %}
{{- '<|start_header_id|>' + message['role'] + '<|end_header_id|>' }}
{% endfor %}
''';

void main() {
  group('detecting what a local template supports', () {
    test('a graded template (gpt-oss) reports graded', () {
      expect(
        detectThinkingFromChatTemplate(_harmony),
        ThinkingSupport.graded,
        reason: 'reasoning_effort is honoured, so the strength chips are real',
      );
    });

    test('a toggle template (Qwen3) reports toggle, not always', () {
      expect(
        detectThinkingFromChatTemplate(_qwen3),
        ThinkingSupport.toggle,
        reason: 'it carries <think> too — but enable_thinking is the more '
            'specific control and it means Off genuinely works',
      );
    });

    test('think markers with no switch report always', () {
      expect(detectThinkingFromChatTemplate(_r1), ThinkingSupport.always);
      expect(
        detectThinkingFromChatTemplate(_harmonyNoEffort),
        ThinkingSupport.always,
        reason: 'harmony reasoners never write <think>; missing the channel '
            'marker would report a thinking model as having no thinking mode',
      );
    });

    test('a plain instruct template reports none', () {
      expect(detectThinkingFromChatTemplate(_llama3), ThinkingSupport.none);
      expect(detectThinkingFromChatTemplate(''), ThinkingSupport.none);
    });
  });

  group('the effort set each verdict implies', () {
    test('only graded offers strength levels', () {
      expect(
        effortsForThinkingSupport(ThinkingSupport.graded),
        containsAll(<String>['low', 'medium', 'high']),
      );
      for (final s in [
        ThinkingSupport.toggle,
        ThinkingSupport.always,
        ThinkingSupport.none,
      ]) {
        expect(
          effortsForThinkingSupport(s),
          {'none'},
          reason: '$s has no strength levels, so it must not advertise any',
        );
      }
    });

    test('the shared chip helper turns those into the right rows', () {
      // The point of reusing the shared vocabulary: chips fall out of the
      // existing helper instead of a second local-only rule.
      rememberReasoningEffortsForModel(
        '/models/graded.gguf',
        effortsForThinkingSupport(ThinkingSupport.graded),
        persist: false,
      );
      rememberReasoningEffortsForModel(
        '/models/toggle.gguf',
        effortsForThinkingSupport(ThinkingSupport.toggle),
        persist: false,
      );
      expect(
        reasoningEffortChipsFor('/models/graded.gguf'),
        ['low', 'medium', 'high'],
      );
      expect(
        reasoningEffortChipsFor('/models/toggle.gguf'),
        isEmpty,
        reason: 'an on/off-only model must show NO strength chips — '
            'decorative chips are exactly what this feature removes',
      );
    });
  });

  group('reading the template off a file', () {
    test('a missing file resolves to null, and null claims nothing', () async {
      ReasoningSupportResolver.instance.clearForTest();
      final verdict = await ReasoningSupportResolver.instance.resolveLocalGguf(
        '/definitely/not/here/model.gguf',
      );
      expect(verdict, isNull);
      expect(
        reasoningEffortSupportedFor('/definitely/not/here/model.gguf'),
        isNull,
        reason: 'an unreadable model must fall back to the generic chips, '
            'never to a guessed capability',
      );
    });

    test('an empty path is not resolved at all', () async {
      ReasoningSupportResolver.instance.clearForTest();
      expect(
        await ReasoningSupportResolver.instance.resolveLocalGguf(''),
        isNull,
      );
      expect(ReasoningSupportResolver.instance.isResolved(''), isFalse);
    });

    test('a miss is cached so a torn file is not re-read every rebuild',
        () async {
      ReasoningSupportResolver.instance.clearForTest();
      const path = '/definitely/not/here/again.gguf';
      await ReasoningSupportResolver.instance.resolveLocalGguf(path);
      expect(
        ReasoningSupportResolver.instance.isResolved(path),
        isTrue,
        reason: 'peek() is called from build — an uncached miss would hit the '
            'filesystem on every frame',
      );
    });

    test('peek never resolves on its own (it is the build-safe read)', () {
      ReasoningSupportResolver.instance.clearForTest();
      expect(ReasoningSupportResolver.instance.peek('/some/model.gguf'), isNull);
      expect(
        ReasoningSupportResolver.instance.isResolved('/some/model.gguf'),
        isFalse,
        reason: 'peek must not populate the cache — it must stay a pure read',
      );
    });
  });
}
