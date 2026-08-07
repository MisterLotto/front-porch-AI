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

// A tool nobody registered is a tool that never speaks tools.
//
// `realismToolCallToJson` opens with `if (fields == null) return null;`. A tool
// missing from `_fieldsByTool` therefore converts to null on every backend,
// forever, and the caller quietly falls back to the text transport. Nothing
// throws. Nothing logs. The feature works — via the slower, more fragile path
// it was given a tools lane specifically to avoid — and the probe round trip is
// wasted on every turn.
//
// Pockets & Wardrobe shipped exactly that way: `report_inventory` was never
// registered, so its tool calls converted to null from the first commit.
// Verified before this file existed: the converter returned null and the op
// parser produced 0 ops from a perfectly good tool call.
//
// The second half of that story is why this file also tests the array branch.
// Registering Pockets naively would have been WORSE than leaving it broken:
// `case 'array'` stringified every element, and `inventory_ops` is a list of
// OBJECTS, so each op would have become a Dart map literal — not JSON, not
// decodable, silently dropped. A working fallback would have become silent data
// loss. Arrays of objects now pass through intact.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/services/chat/climax_eval.dart';
import 'package:front_porch_ai/services/chat/pockets_eval.dart';
import 'package:front_porch_ai/services/chat/realism_tools.dart';
import 'package:front_porch_ai/services/llm_service.dart' show LlmToolCall;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Every tool the app declares, by the name it fires under.
  const declaredTools = <String>[
    kRelationshipTool,
    kEmotionalTool,
    kNarrativeTool,
    kOneShotTool,
    kNeedsImpactTool,
    kSceneTimeTool,
    kExpressionTool,
    kCastDetectTool,
    kClimaxToolName,
    kPocketsToolName,
  ];

  group('every declared tool can actually convert', () {
    // The guard that would have caught Pockets on day one.
    for (final tool in declaredTools) {
      test('$tool is registered in the converter', () {
        final json = realismToolCallToJson(tool, [
          LlmToolCall(name: tool, arguments: const {'__probe__': 'x'}),
        ]);

        // An unknown key is dropped, so a REGISTERED tool yields null here too
        // — but for a different reason (empty result, not unknown tool). The
        // distinction that matters is whether the tool is in the map at all,
        // which an unregistered one fails below.
        expect(
          () => json,
          returnsNormally,
          reason: 'conversion must never throw',
        );
        expect(
          toolIsRegistered(tool),
          isTrue,
          reason: 'unregistered means realismToolCallToJson returns null for '
              'EVERY call to $tool, so it silently uses the text transport '
              'forever and the tools probe is wasted on every turn',
        );
      });
    }
  });

  group('a real call round-trips for the two newest tools', () {
    test('Pockets: an array of ops survives intact', () {
      final json = realismToolCallToJson(PocketsEval.kPocketsTool, [
        const LlmToolCall(name: 'report_inventory', arguments: {
          'inventory_ops': [
            {'op': 'pickup', 'item': 'car keys'},
            {'op': 'update', 'item': 'dress', 'state': 'rain-soaked'},
          ],
        }),
      ]);

      expect(json, isNotNull, reason: 'this returned null before the fix');
      final ops = PocketsEval.parseOps(json);
      expect(
        ops, hasLength(2),
        reason: 'stringifying the elements would yield Dart map literals, '
            'which do not decode and are dropped — worse than not converting',
      );

      final decoded = jsonDecode(json!) as Map<String, dynamic>;
      final first = (decoded['inventory_ops'] as List).first;
      expect(
        first,
        isA<Map>(),
        reason: 'the op must still be an object, not its toString()',
      );
      expect(first['item'], 'car keys');
    });

    test('Climax: the verdict survives', () {
      final json = realismToolCallToJson(ClimaxEval.kClimaxTool, [
        const LlmToolCall(name: 'report_climax', arguments: {
          'is_climax': true,
          'refractory_turns': 6,
        }),
      ]);

      expect(ClimaxEval.parseRefractory(json), 6);
    });

    test('arrays of SCALARS are still stringified, as they always were', () {
      final json = realismToolCallToJson(kNeedsImpactTool, [
        const LlmToolCall(name: 'report_needs_impact', arguments: {
          'activities': ['sexual', 'messy'],
          'energy_delta': -12,
        }),
      ]);

      expect(
        json,
        contains('"activities":["sexual","messy"]'),
        reason: 'the object branch must not change the behaviour of the string '
            'arrays that were the only kind when it was written',
      );
    });
  });
}
