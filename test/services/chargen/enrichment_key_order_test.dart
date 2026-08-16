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

// A MODEL THAT WRITES THE FIELDS IN A DIFFERENT ORDER MUST NOT BLEED THEM
// INTO EACH OTHER.
//
// The enrichment stage parses its reply with the regex extractor on purpose
// (models emit unescaped quotes — 5'9" — that break json.decode). That
// extractor found a value's end by walking the CANONICAL key list forward and
// stopping at the first key it could find, not the nearest one in the text.
// So a reply ordering scenario before personality made the description run all
// the way to "personality": the whole scenario field, quotes and commas
// included, was swallowed into the description and shipped on the card. The
// length guards are floors, so nothing downstream noticed.
//
// Proven to fail: restore the `for (int j = currentIdx + 1; ...) break;` scan
// in character_gen_parsing.dart and the description assertions go red.

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/services/character_gen_service.dart';
import 'package:front_porch_ai/services/chargen/chargen.dart';
import 'package:front_porch_ai/services/llm_service.dart';

const _description =
    'Tall, with calloused hands and a crooked smile, always in the same worn '
    'leather jacket she refuses to replace no matter the season.';
const _scenario =
    'The bar is closing and {{char}} has locked the door with {{user}} still '
    'inside, a bottle of the good stuff already on the counter between them.';
const _personality =
    'Sharp-tongued but secretly soft; she deflects sincerity with bar jokes '
    'and only drops the act around people who have earned it over months.';

/// Answers the enrichment call with VALID JSON whose keys are in a different
/// order than the prompt listed them — exactly what a local model does often
/// enough to matter. Hand-written (not jsonEncode) so the key order is fixed.
class _OutOfOrderLlm extends LLMService {
  @override
  Stream<String> generateStream(GenerationParams params) async* {
    if (params.prompt.contains('rewrite these three fields')) {
      yield '{\n'
          '  "description": "$_description",\n'
          '  "scenario": "$_scenario",\n'
          '  "personality": "$_personality"\n'
          '}';
      return;
    }
    // Interview answer.
    yield 'I talk like the bar taught me: fast, warm, and armored.';
  }

  @override
  bool get isReady => true;

  @override
  String get backendName => 'out-of-order-test';
}

void main() {
  test('out-of-order enrichment keys do not swallow each other', () async {
    final gen = CharacterGenService(_OutOfOrderLlm());
    final result = await gen.enhanceCharacter(
      source: CharacterCard(
        name: 'Nina',
        description: 'Original description of Nina.',
        personality: 'Original personality of Nina.',
        scenario: 'Original scenario: a quiet bar after hours, {{user}} walks in.',
        firstMessage: 'Original first message.',
      ),
      selection: const EnhanceSelection(
        description: true,
        personality: true,
        scenario: true,
        exampleDialogue: false,
      ),
      chatGrounding: 'User: hey Nina\nNina: well, look who wandered in',
    );

    expect(result, isNotNull);
    expect(
      result!.description,
      isNot(contains('"scenario"')),
      reason:
          'THE BUG: description ran to the far "personality" key and dragged '
          'the entire scenario field — raw JSON punctuation and all — with it',
    );
    expect(result.description, isNot(contains('locked the door')));
    expect(result.description.replaceAll('{{char}}', 'Nina'),
        _description.replaceAll('{{char}}', 'Nina'));
    expect(result.personality.replaceAll('{{char}}', 'Nina'),
        _personality.replaceAll('{{char}}', 'Nina'));
    expect(result.scenario, isNot(contains('"personality"')));
    expect(result.scenario, contains('locked the door'));
  });
}
