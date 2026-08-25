// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Bytes-only think-wrapper sniff. No model names. Proven against the
// NanoGPT Gemma dump (leading `thought`, no <think>) and the wrappers
// the industry actually emits.

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/models/chat_message.dart';
import 'package:front_porch_ai/services/reasoning_stream_wrapper.dart';
import 'package:front_porch_ai/utils/reasoning_markers.dart';
import 'package:front_porch_ai/utils/think_tags.dart';

void main() {
  group('canonicalizeReasoning', () {
    test('plain prose is untouched', () {
      expect(canonicalizeReasoning('Hello there.'), 'Hello there.');
    });

    test('<think> identity is unchanged', () {
      const raw = '<think>plan</think>\n"Hi."';
      expect(canonicalizeReasoning(raw), raw);
    });

    test('Gemma 4 channel becomes <think>', () {
      const raw = '<|channel>thought\nThe user ran.\n<channel|>"Stay."';
      final out = canonicalizeReasoning(raw);
      expect(out, startsWith('<think>'));
      expect(out, contains('</think>'));
      expect(out, contains('"Stay."'));
      expect(out, isNot(contains('<|channel>')));
    });

    test('stripped Gemma leftover thought\\n still parses when closed', () {
      const raw = 'thought\nlong essay\n<channel|>"Spoken."';
      final out = canonicalizeReasoning(raw);
      expect(out, contains('<think>long essay\n</think>'));
      expect(out, contains('"Spoken."'));
    });

    test('harmony analysis channel becomes <think>', () {
      const raw = '<|channel|>analysis\nstep one\n<|channel|>final\nAnswer.';
      final out = canonicalizeReasoning(raw);
      expect(out, contains('<think>'));
      expect(out, contains('step one'));
      expect(out, contains('</think>'));
      expect(out, contains('Answer.'));
    });

    test('Kimi triangle think tags', () {
      expect(
        canonicalizeReasoning('◁think▷secret◁/think▷Hi.'),
        '<think>secret</think>\nHi.',
      );
    });

    test('<reasoning> and <thinking> both convert', () {
      expect(
        canonicalizeReasoning('<reasoning>a</reasoning>B'),
        '<think>a</think>\nB',
      );
      expect(
        canonicalizeReasoning('<thinking>a</thinking>B'),
        '<think>a</think>\nB',
      );
    });

    test('"I thought about it" is not a think block', () {
      const raw = 'I thought about it on the porch.';
      expect(canonicalizeReasoning(raw), raw);
      expect(stripThinkTags(raw), raw);
    });
  });

  group('ReasoningMarkerRewriter streaming', () {
    test('split Gemma open across tokens', () {
      final r = ReasoningMarkerRewriter();
      expect(r.push('<|chan'), '');
      final mid = r.push('nel>thought\nfoo');
      expect(mid, contains('<think>'));
      expect(mid, contains('foo'));
      final end = r.push('bar<channel|>hi');
      expect(end, contains('</think>'));
      expect(end, contains('hi'));
      expect(r.finish(), '');
    });

    test('ordinary prose is not delayed', () {
      final r = ReasoningMarkerRewriter();
      expect(r.push('Hel'), 'Hel');
      expect(r.push('lo'), 'lo');
    });

    test('keep:false drops the think body', () {
      final r = ReasoningMarkerRewriter(keep: false);
      expect(r.push('<|channel>thought\nessay<channel|>"Hi."'), '"Hi."');
    });
  });

  group('ReasoningIngest', () {
    test('content-side Gemma becomes a Thought chip + spoken body', () {
      final i = ReasoningIngest(wrap: true);
      final a = i.onContent('<|channel>thought\nessay\n');
      final b = i.onContent('<channel|>"Stay."');
      final c = i.finish();
      final all = '$a$b$c';
      expect(all, contains('<think>'));
      expect(all, contains('</think>'));
      expect(all, contains('"Stay."'));
      final msg = ChatMessage(text: all, sender: 'Nemu', isUser: false);
      expect(msg.thinkingContent, contains('essay'));
      expect(msg.displayText, '"Stay."');
    });

    test('reasoning_content still wraps as before', () {
      final i = ReasoningIngest(wrap: true);
      expect(i.onReasoning('abc'), '<think>abc');
      expect(i.onContent('ans'), '</think>\nans');
    });
  });

  group('ChatMessage + strip floor', () {
    test('stored Gemma dump: Thought chip, spoken body, history-safe', () {
      final msg = ChatMessage(
        text:
            '<|channel>thought\nThe user resisted.\n<channel|>"You declined."',
        sender: 'Nemu',
        isUser: false,
      );
      expect(msg.hasThinking, isTrue);
      expect(msg.thinkingContent, contains('resisted'));
      expect(msg.displayText, '"You declined."');
      expect(msg.toPromptHistoryLine(), contains('You declined'));
      expect(msg.toPromptHistoryLine(), isNot(contains('resisted')));
    });

    test('stripThinkTags peels Gemma for TTS', () {
      expect(stripThinkTags('<|channel>thought\nnope<channel|>hello'), 'hello');
    });
  });
}
