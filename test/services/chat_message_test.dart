// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Tests for ChatMessage - the core data structure for chat history.
// Covers serialization, swipe handling, thinking tag stripping, and metadata.

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/models/chat_message.dart';

/// Helper to build text with thinking tags (tags rendered invisibly in terminal).
String _thinkingText({required String content, bool inProgress = false}) {
  final open = '<think>';
  final close = '</think>';
  if (inProgress) {
    return open + content;
  }
  return open + content + close;
}

void main() {
  group('text and swipes', () {
    test('text returns swipes[swipeIndex]', () {
      final msg = ChatMessage(
        text: 'Swipe 1',
        sender: 'Luna',
        isUser: false,
        swipes: ['Original', 'Swipe 1', 'Swipe 2'],
        swipeIndex: 1,
      );

      expect(msg.text, 'Swipe 1');
    });

    test('text returns single item when no swipes provided', () {
      final msg = ChatMessage(text: 'Hello', sender: 'Luna', isUser: false);

      expect(msg.text, 'Hello');
      expect(msg.swipes, ['Hello']);
    });

    test('setText updates swipes[swipeIndex]', () {
      final msg = ChatMessage(
        text: 'Original',
        sender: 'Luna',
        isUser: false,
        swipes: ['Original', 'Swipe 1', 'Swipe 2'],
        swipeIndex: 1,
      );

      msg.text = 'New Swipe 1';
      expect(msg.swipes[1], 'New Swipe 1');
      expect(msg.text, 'New Swipe 1');
    });

    test('setText does nothing when swipes is empty', () {
      final msg = ChatMessage(
        text: '',
        sender: 'Luna',
        isUser: false,
        swipes: [],
      );

      msg.text = 'New text';
      expect(msg.swipes, isEmpty);
    });

    test('swipeIndex out of range is clamped (no RangeError on access)', () {
      final msg = ChatMessage(
        text: 'Hello',
        sender: 'Luna',
        isUser: false,
        swipes: ['Hello'],
        swipeIndex: 99,
      );

      expect(msg.swipeIndex, 0);
      expect(msg.text, 'Hello'); // does not throw thanks to ctor clamping
    });
  });

  group('promptText (photo-aware eval/context text)', () {
    test('non-photo message returns displayText unchanged', () {
      final msg = ChatMessage(text: 'Hello!', sender: 'You', isUser: true);
      expect(msg.promptText, 'Hello!');
    });

    test('photo-only message (empty text) shows the marker, not blank', () {
      final msg = ChatMessage(
        text: '',
        sender: 'You',
        isUser: true,
        metadata: {'is_user_image': true, 'image_path': '/x/y.png'},
      );
      // The bug: realism evals saw a bare "You: " for this turn.
      expect(msg.promptText, '[shared a photo]');
    });

    test('photo + text keeps both, marker appended', () {
      final msg = ChatMessage(
        text: 'do you like it?',
        sender: 'You',
        isUser: true,
        metadata: {'is_user_image': true, 'image_path': '/x/y.png'},
      );
      expect(msg.promptText, 'do you like it? [shared a photo]');
    });

    test('once captioned, the marker carries the description', () {
      final msg = ChatMessage(
        text: '',
        sender: 'You',
        isUser: true,
        metadata: {
          'is_user_image': true,
          'image_path': '/x/y.png',
          'image_caption': 'a sunset over the porch',
        },
      );
      expect(msg.promptText, '[shared a photo: a sunset over the porch]');
    });
  });

  group('toPromptHistoryLine (generation history — think stripped)', () {
    // THE BUG (Nina chat, 2026-08-11): history used raw m.text, so every
    // prior <think> plan re-entered the next generation prompt. Rerolls
    // re-executed the previous scene. Guard: line must be think-free and
    // must equal the promptText form evals already use.
    test('strips completed think blocks from character turns', () {
      final msg = ChatMessage(
        text: '<think>\nplan the massage scene again\n</think>\n*She settles into the hot tub.*',
        sender: 'Nina',
        isUser: false,
      );
      final line = msg.toPromptHistoryLine();
      expect(line, 'Nina: *She settles into the hot tub.*');
      expect(line.contains('<think>'), isFalse);
      expect(line.contains('massage scene'), isFalse);
    });

    test('strips unclosed (streaming) think blocks', () {
      final msg = ChatMessage(
        text: '<think>\nstill planning the entryway\n',
        sender: 'Nina',
        isUser: false,
      );
      expect(msg.toPromptHistoryLine(), 'Nina: ');
      expect(msg.toPromptHistoryLine().contains('<think>'), isFalse);
    });

    test('photo turns carry the same shared-a-photo marker as promptText', () {
      final msg = ChatMessage(
        text: '',
        sender: 'You',
        isUser: true,
        metadata: {
          'is_user_image': true,
          'image_caption': 'a red kite over the bay',
        },
      );
      expect(
        msg.toPromptHistoryLine(),
        'You: [shared a photo: a red kite over the bay]',
      );
    });

    test('director notes stay bracketed', () {
      final msg = ChatMessage(
        text: 'nudge: lean into the quiet',
        sender: 'Director',
        isUser: false,
        characterId: '__director__',
      );
      expect(msg.toPromptHistoryLine(), '[Director: nudge: lean into the quiet]');
    });

    test('generated-image shares describe the prompt when prose is empty', () {
      final msg = ChatMessage(
        text: '',
        sender: 'Studio',
        isUser: false,
        metadata: {
          'is_generated_image': true,
          'image_prompt': 'Nina by a lantern stall',
        },
      );
      expect(
        msg.toPromptHistoryLine(),
        'Studio: [shares a generated image: Nina by a lantern stall]',
      );
    });
  });

  group('displayText', () {
    test('preserves text without thinking tags', () {
      final msg = ChatMessage(text: 'Hello!', sender: 'Luna', isUser: false);

      expect(msg.displayText, 'Hello!');
    });

    test('strips completed thinking block with surrounding text', () {
      final msg = ChatMessage(
        text:
            _thinkingText(content: 'Let me think about this carefully') +
            'Hello!',
        sender: 'Luna',
        isUser: false,
      );

      expect(msg.displayText, 'Hello!');
    });

    test('strips in-progress thinking block', () {
      final msg = ChatMessage(
        text: _thinkingText(content: 'partial', inProgress: true),
        sender: 'Luna',
        isUser: false,
      );

      expect(msg.displayText, '');
    });

    test('strips multiple thinking blocks', () {
      final msg = ChatMessage(
        text:
            _thinkingText(content: 'first') +
            'Between' +
            _thinkingText(content: 'second'),
        sender: 'Luna',
        isUser: false,
      );

      expect(msg.displayText, 'Between');
    });

    test('preserves text after thinking block', () {
      final msg = ChatMessage(
        text: _thinkingText(content: 'reasoning') + 'Hello there!',
        sender: 'Luna',
        isUser: false,
      );

      expect(msg.displayText, 'Hello there!');
    });

    test('displayText trims result', () {
      final msg = ChatMessage(
        text: '  Hello  \n',
        sender: 'Luna',
        isUser: false,
      );

      expect(msg.displayText, 'Hello');
    });

    test('message with only thinking tags has empty displayText', () {
      final msg = ChatMessage(
        text: _thinkingText(content: 'only thinking'),
        sender: 'Luna',
        isUser: false,
      );

      expect(msg.displayText, '');
    });

    test('case-insensitive tag matching', () {
      final msg = ChatMessage(
        text: '<THINK>upper</THINK>Hello',
        sender: 'Luna',
        isUser: false,
      );

      expect(msg.displayText, 'Hello');
    });
  });

  group('thinkingContent', () {
    test('returns null when no thinking tags', () {
      final msg = ChatMessage(
        text: 'Hello world',
        sender: 'Luna',
        isUser: false,
      );

      expect(msg.thinkingContent, isNull);
    });

    test('extracts completed thinking content', () {
      final msg = ChatMessage(
        text:
            _thinkingText(content: 'Let me think about this carefully') +
            'Hello!',
        sender: 'Luna',
        isUser: false,
      );

      expect(msg.thinkingContent, 'Let me think about this carefully');
    });

    test('extracts in-progress thinking content', () {
      final msg = ChatMessage(
        text: _thinkingText(
          content: 'I am still working on this...',
          inProgress: true,
        ),
        sender: 'Luna',
        isUser: false,
      );

      expect(msg.thinkingContent, 'I am still working on this...');
    });

    test('returns null for text without thinking tags', () {
      final msg = ChatMessage(text: 'texthello', sender: 'Luna', isUser: false);

      expect(msg.thinkingContent, isNull);
    });

    test('thinkingContent trims whitespace', () {
      final msg = ChatMessage(
        text: _thinkingText(content: '  spaced content  '),
        sender: 'Luna',
        isUser: false,
      );

      expect(msg.thinkingContent, 'spaced content');
    });

    test('prefers completed block over in-progress', () {
      final msg = ChatMessage(
        text:
            _thinkingText(content: 'Closed block') +
            _thinkingText(content: 'Open block', inProgress: true),
        sender: 'Luna',
        isUser: false,
      );

      expect(
        msg.thinkingContent,
        'Closed block',
        reason: 'completed block takes priority',
      );
    });
  });

  group('hasThinking', () {
    test('true when thinking tags present', () {
      final msg = ChatMessage(
        text: _thinkingText(content: 'reasoning'),
        sender: 'Luna',
        isUser: false,
      );

      expect(msg.hasThinking, isTrue);
    });

    test('false when no thinking tags and no duration', () {
      final msg = ChatMessage(text: 'Hello', sender: 'Luna', isUser: false);

      expect(msg.hasThinking, isFalse);
    });

    test('true when thinkingDurationMs > 0', () {
      final msg = ChatMessage(text: 'Hello', sender: 'Luna', isUser: false);

      msg.thinkingDurationMs = 500;
      expect(msg.hasThinking, isTrue);
    });

    test('false when thinkingDurationMs is 0', () {
      final msg = ChatMessage(text: 'Hello', sender: 'Luna', isUser: false);

      expect(msg.hasThinking, isFalse);
    });
  });

  group('metadata', () {
    test('activeMetadata returns metadata when no swipe metadata', () {
      final msg = ChatMessage(
        text: 'Hello',
        sender: 'Luna',
        isUser: false,
        metadata: {'key': 'value'},
      );

      expect(msg.activeMetadata, {'key': 'value'});
    });

    test('activeMetadata returns swipe metadata at current index', () {
      final msg = ChatMessage(
        text: 'Hello',
        sender: 'Luna',
        isUser: false,
        swipes: ['Hello', 'Hello2'],
        swipeMetadata: [
          null,
          {'swipeKey': 'swipeValue'},
        ],
        swipeIndex: 1,
      );

      expect(msg.activeMetadata, {'swipeKey': 'swipeValue'});
    });

    test('activeMetadata falls back to metadata when swipe is null', () {
      final msg = ChatMessage(
        text: 'Hello',
        sender: 'Luna',
        isUser: false,
        metadata: {'fallback': true},
        swipeMetadata: [null, null],
        swipeIndex: 1,
      );

      expect(msg.activeMetadata, {'fallback': true});
    });

    test('setting activeMetadata creates swipe metadata entry', () {
      final msg = ChatMessage(text: 'Hello', sender: 'Luna', isUser: false);

      msg.activeMetadata = {'new': 'data'};
      expect(msg.swipeMetadata.length, 1);
      expect(msg.swipeMetadata[0], {'new': 'data'});
    });

    test('setting activeMetadata at higher index pads with nulls', () {
      final msg = ChatMessage(
        text: 'Hello',
        sender: 'Luna',
        isUser: false,
        swipes: ['Hello', 'H1', 'H2'],
        swipeMetadata: [null, null, null],
        swipeIndex: 2,
      );

      msg.activeMetadata = {'at': 'index2'};
      expect(msg.swipeMetadata[2], {'at': 'index2'});
    });
  });

  group('toJson / fromJson round-trip', () {
    test('round-trip basic message', () {
      final original = ChatMessage(
        text: 'Hello world',
        sender: 'Luna',
        isUser: false,
      );

      final json = original.toJson();
      final restored = ChatMessage.fromJson(json);

      expect(restored.text, 'Hello world');
      expect(restored.sender, 'Luna');
      expect(restored.isUser, false);
      expect(restored.swipes, ['Hello world']);
      expect(restored.swipeIndex, 0);
    });

    test('round-trip with swipes', () {
      final original = ChatMessage(
        text: 'Swipe 1',
        sender: 'Luna',
        isUser: false,
        swipes: ['Original', 'Swipe 1', 'Swipe 2'],
        swipeIndex: 1,
        swipeDurations: [100, 200, 300],
      );

      final json = original.toJson();
      final restored = ChatMessage.fromJson(json);

      expect(restored.swipes, ['Original', 'Swipe 1', 'Swipe 2']);
      expect(restored.swipeIndex, 1);
      expect(restored.text, 'Swipe 1');
      expect(restored.swipeDurations, [100, 200, 300]);
    });

    test('round-trip with metadata', () {
      final original = ChatMessage(
        text: 'Hello',
        sender: 'Luna',
        isUser: false,
        metadata: {'emotion': 'happy', 'bond_delta': 5},
      );

      final json = original.toJson();
      final restored = ChatMessage.fromJson(json);

      expect(restored.metadata, {'emotion': 'happy', 'bond_delta': 5});
    });

    test('round-trip with swipe metadata', () {
      final original = ChatMessage(
        text: 'Hello',
        sender: 'Luna',
        isUser: false,
        swipes: ['Hello', 'Swipe 1'],
        swipeMetadata: [
          null,
          {'swipeKey': 'swipeValue'},
          null,
        ],
        swipeIndex: 1,
      );

      final json = original.toJson();
      final restored = ChatMessage.fromJson(json);

      expect(restored.swipeMetadata[1], {'swipeKey': 'swipeValue'});
    });

    test('round-trip with characterId', () {
      final original = ChatMessage(
        text: 'Hello',
        sender: 'Luna',
        isUser: false,
        characterId: 'char_luna',
      );

      final json = original.toJson();
      final restored = ChatMessage.fromJson(json);

      expect(restored.characterId, 'char_luna');
    });

    test('characterId omitted from JSON when null', () {
      final original = ChatMessage(text: 'Hello', sender: 'User', isUser: true);

      final json = original.toJson();
      expect(json.containsKey('character_id'), isFalse);
    });

    test('fromJson handles missing fields with defaults', () {
      final json = {'text': 'Hello', 'sender': 'Luna', 'is_user': false};
      final msg = ChatMessage.fromJson(json);

      expect(msg.text, 'Hello');
      expect(msg.sender, 'Luna');
      expect(msg.isUser, false);
      expect(msg.swipes, ['Hello']);
      expect(msg.swipeIndex, 0);
      expect(msg.swipeDurations, [0]);
    });

    test('fromJson handles empty text gracefully', () {
      final json = {'text': '', 'sender': 'Luna', 'is_user': false};
      final msg = ChatMessage.fromJson(json);

      expect(msg.text, '');
    });

    test('fromJson handles missing sender with empty default', () {
      final json = {'text': 'Hello', 'is_user': false};
      final msg = ChatMessage.fromJson(json);

      expect(msg.sender, '');
    });

    test('fromJson handles missing is_user with false default', () {
      final json = {'text': 'Hello', 'sender': 'Luna'};
      final msg = ChatMessage.fromJson(json);

      expect(msg.isUser, false);
    });

    test('toJson excludes null swipe_metadata entries', () {
      final original = ChatMessage(
        text: 'Hello',
        sender: 'Luna',
        isUser: false,
        swipeMetadata: [null, null, null],
      );

      final json = original.toJson();
      expect(json.containsKey('swipe_metadata'), isFalse);
    });

    test('toJson includes swipe_metadata when any entry is non-null', () {
      final original = ChatMessage(
        text: 'Hello',
        sender: 'Luna',
        isUser: false,
        swipeMetadata: [
          null,
          {'key': 'val'},
          null,
        ],
      );

      final json = original.toJson();
      expect(json.containsKey('swipe_metadata'), isTrue);
    });
  });

  group('swipeDurations', () {
    test('default duration is 0', () {
      final msg = ChatMessage(text: 'Hello', sender: 'Luna', isUser: false);

      expect(msg.swipeDurations[0], 0);
    });

    test('setting thinkingDurationMs pads the list', () {
      final msg = ChatMessage(text: 'Hello', sender: 'Luna', isUser: false);

      msg.thinkingDurationMs = 500;
      expect(msg.swipeDurations.length, 1);
      expect(msg.swipeDurations[0], 500);
    });

    test('setting thinkingDurationMs at higher index pads with zeros', () {
      final msg = ChatMessage(
        text: 'Hello',
        sender: 'Luna',
        isUser: false,
        swipes: ['a', 'b', 'c'],
        swipeIndex: 2,
      );

      msg.thinkingDurationMs = 1000;
      expect(msg.swipeDurations.length, 3);
      expect(msg.swipeDurations[2], 1000);
      expect(msg.swipeDurations[0], 0);
      expect(msg.swipeDurations[1], 0);
    });

    test('thinkingDurationMs reads from current swipe index', () {
      final msg = ChatMessage(
        text: 'Swipe 1',
        sender: 'Luna',
        isUser: false,
        swipes: ['a', 'b'],
        swipeDurations: [100, 500],
        swipeIndex: 1,
      );

      expect(msg.thinkingDurationMs, 500);
    });
  });
}
