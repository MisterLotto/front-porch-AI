// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

// StoryJson.stripThinkTags handled an UNTERMINATED <think> block by hunting
// for a '{' after it — fine for the JSON stages, useless for the prose and
// timeline calls, which have no JSON at all. When a reasoning model's
// </think> was cut off (the beat call hitting maxLength), the function
// returned the raw chain-of-thought, and the pipeline stored it as the beat's
// finished prose (reader / ePub / audiobook) or as project.distilledTimeline,
// which is injected into every later stage prompt as "CANON EVENT TIMELINE".

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/services/story/story_json.dart';

void main() {
  group('StoryJson.stripThinkTags', () {
    test('drops an unterminated think block in prose output', () {
      const truncated =
          'The gulls cried over the water.\n'
          '<think>Now I need a beat where she notices the dock is empty, and';
      expect(
        StoryJson.stripThinkTags(truncated),
        'The gulls cried over the water.',
      );
    });

    test('an unterminated block with no prose before it leaves nothing', () {
      const allReasoning =
          '<think>Okay. The beat is about arriving. Let me set the scene and';
      expect(StoryJson.stripThinkTags(allReasoning), '');
    });

    test('still anchors on JSON after an unterminated block', () {
      // The behaviour the JSON stages depend on: a model that forgets the
      // closing tag but does emit the object must still parse.
      const raw = '<think>planning the acts\n{"concept": "c", "acts": []}';
      expect(
        StoryJson.stripThinkTags(raw),
        '{"concept": "c", "acts": []}',
      );
      expect(StoryJson.parseJson(raw), {'concept': 'c', 'acts': []});
    });

    test('complete blocks are still removed, prose around them kept', () {
      expect(
        StoryJson.stripThinkTags(
          '<think>plan</think>\nShe pushed the door open.',
        ),
        'She pushed the door open.',
      );
      expect(
        StoryJson.stripThinkTags('<reasoning>plan</reasoning>Kept.'),
        'Kept.',
      );
    });

    test('untagged prose is returned untouched', () {
      expect(
        StoryJson.stripThinkTags('  A quiet start on the harbor.  '),
        'A quiet start on the harbor.',
      );
    });
  });
}
