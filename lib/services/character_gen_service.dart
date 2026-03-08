import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:front_porch_ai/models/character_card.dart';
import 'package:front_porch_ai/models/lorebook.dart';
import 'package:front_porch_ai/services/llm_service.dart';

/// Service for AI-powered character generation.
///
/// Takes minimal user input (name, concept, personality keywords)
/// and uses the LLM to generate a complete V2 character card.
///
/// Generation is split into multiple API calls:
/// 1. Base card (description, personality, scenario, etc.)
/// 2. First message (dedicated call for quality)
/// 3. Alternate greetings (one per call, with prior context for uniqueness)
class CharacterGenService {
  final LLMService _llmService;

  /// The raw LLM output from the last base card generation, for image prompt extraction.
  String? lastRawOutput;

  CharacterGenService(this._llmService);

  /// Generate a complete character card from user-provided creative inputs.
  ///
  /// Uses multi-step generation: base card first, then greetings separately.
  Future<CharacterCard?> generateCharacter({
    required String name,
    required String concept,
    String personalityKeywords = '',
    String artStyle = '',
    String greetingLength = 'Medium (2-4 paragraphs)',
    int altGreetingCount = 2,
    List<String> greetingTones = const ['Neutral'],
    bool generateLorebook = true,
    List<String> loreCategories = const [],
    String loreDepth = 'Standard',
    String apiSystemPrompt = '',
    String age = '',
    String sex = '',
    String relationship = '',
    String descriptionDetail = '2-3 paragraphs',
    String backstory = '',
    String characterContext = '',
    String userPersonaContext = '',
    void Function(String accumulated)? onProgress,
    void Function(String error)? onError,
    void Function(String status)? onStatus,
  }) async {
    // ── Step 1: Generate base card ──────────────────────────────
    onStatus?.call('Generating character profile...');
    final basePrompt = _buildBasePrompt(
      name: name,
      concept: concept,
      personalityKeywords: personalityKeywords,
      generateLorebook: generateLorebook,
      loreCategories: loreCategories,
      loreDepth: loreDepth,
      apiSystemPrompt: apiSystemPrompt,
      age: age,
      sex: sex,
      relationship: relationship,
      descriptionDetail: descriptionDetail,
      backstory: backstory,
    );

    debugPrint('CharacterGen: Starting generation for "$name"');

    final baseOutput = await _callLLM(basePrompt, onProgress: onProgress);
    lastRawOutput = baseOutput; // Store for image prompt extraction
    if (baseOutput == null) {
      onError?.call('LLM returned empty response for base card.');
      return null;
    }

    final cleaned = _stripContent(baseOutput);
    debugPrint('CharacterGen: Base output cleaned (${cleaned.length} chars)');

    final card = _parseCharacterJson(cleaned, name);
    if (card == null) {
      onError?.call('Failed to parse base card JSON. Try a different model.');
      return null;
    }

    // ── Step 1b: Truncation recovery ────────────────────────────
    // If critical fields are empty, the JSON was likely truncated.
    // Make a focused retry asking only for the missing fields.
    final missingFields = <String>[];
    if (card.personality.trim().isEmpty) missingFields.add('personality');
    if (card.scenario.trim().isEmpty) missingFields.add('scenario');
    if (card.systemPrompt.trim().isEmpty) missingFields.add('system_prompt');
    if (card.mesExample.trim().isEmpty) missingFields.add('example_dialogue');

    if (missingFields.isNotEmpty) {
      debugPrint('CharacterGen: Truncation detected — missing: ${missingFields.join(", ")}');
      onStatus?.call('Recovering truncated fields...');
      onProgress?.call('');

      final recoveryCard = await _recoverMissingFields(
        name: name,
        concept: concept,
        personalityKeywords: personalityKeywords,
        missingFields: missingFields,
        apiSystemPrompt: apiSystemPrompt,
        age: age,
        sex: sex,
        relationship: relationship,
        backstory: backstory,
        onProgress: onProgress,
      );

      if (recoveryCard != null) {
        if (card.personality.trim().isEmpty && recoveryCard.personality.trim().isNotEmpty) {
          card.personality = recoveryCard.personality;
        }
        if (card.scenario.trim().isEmpty && recoveryCard.scenario.trim().isNotEmpty) {
          card.scenario = recoveryCard.scenario;
        }
        if (card.systemPrompt.trim().isEmpty && recoveryCard.systemPrompt.trim().isNotEmpty) {
          card.systemPrompt = recoveryCard.systemPrompt;
        }
        if (card.mesExample.trim().isEmpty && recoveryCard.mesExample.trim().isNotEmpty) {
          card.mesExample = recoveryCard.mesExample;
        }
        debugPrint('CharacterGen: Recovery filled ${missingFields.length - [
          if (card.personality.trim().isEmpty) 'personality',
          if (card.scenario.trim().isEmpty) 'scenario',
          if (card.systemPrompt.trim().isEmpty) 'system_prompt',
          if (card.mesExample.trim().isEmpty) 'example_dialogue',
        ].length} fields');
      }
    }

    // ── Step 1c: Separate lorebook generation ───────────────────
    // If lorebook was requested but missing (truncated out), generate separately.
    if (generateLorebook && (card.lorebook == null || card.lorebook!.entries.isEmpty)) {
      debugPrint('CharacterGen: Lorebook missing from base card, generating separately...');
      onStatus?.call('Generating world lore...');
      onProgress?.call('');
      await _generateLorebookSeparately(
        card: card,
        name: name,
        concept: concept,
        loreCategories: loreCategories,
        loreDepth: loreDepth,
        onProgress: onProgress,
      );
    }

    // ── Step 2: Generate first message ────────────────────────
    onStatus?.call('Writing first message...');
    onProgress?.call(''); // Clear preview
    final firstMsgPrompt = _buildGreetingPrompt(
      name: name,
      description: card.description,
      personality: card.personality,
      scenario: card.scenario,
      length: greetingLength,
      tone: greetingTones.isNotEmpty ? greetingTones[0] : 'Neutral',
      previousGreetings: [],
      characterContext: characterContext,
      userPersonaContext: userPersonaContext,
    );

    final firstMsgOutput = await _callLLM(firstMsgPrompt,
        maxLen: 4096, minLen: 512, onProgress: onProgress);
    if (firstMsgOutput != null && firstMsgOutput.trim().isNotEmpty) {
      card.firstMessage = _cleanGreeting(firstMsgOutput);
    }

    // ── Step 3: Generate alternate greetings ──────────────────
    if (altGreetingCount > 0) {
      final alts = <String>[];
      for (int i = 0; i < altGreetingCount; i++) {
        onStatus?.call('Writing alternate greeting ${i + 1} of $altGreetingCount...');
        onProgress?.call(''); // Clear preview

        final altPrompt = _buildGreetingPrompt(
          name: name,
          description: card.description,
          personality: card.personality,
          scenario: card.scenario,
          length: greetingLength,
          tone: greetingTones.isNotEmpty ? greetingTones[(i + 1) % greetingTones.length] : 'Neutral',
          previousGreetings: [card.firstMessage, ...alts],
          characterContext: characterContext,
          userPersonaContext: userPersonaContext,
        );

        final altOutput = await _callLLM(altPrompt,
            maxLen: 4096, minLen: 512, onProgress: onProgress);
        if (altOutput != null && altOutput.trim().isNotEmpty) {
          alts.add(_cleanGreeting(altOutput));
        }
      }
      card.alternateGreetings = alts;
    }

    onStatus?.call('Character generated!');
    return card;
  }

  // ═════════════════════════════════════════════════════════════
  //  LLM Calling
  // ═════════════════════════════════════════════════════════════

  /// Call the LLM and collect all tokens. Returns raw text or null.
  /// Retries up to [maxRetries] times with exponential backoff on failure.
  Future<String?> _callLLM(String prompt, {
    int maxLen = 8192,
    int minLen = 64,
    int maxRetries = 3,
    void Function(String accumulated)? onProgress,
  }) async {
    final promptEstTokens = (prompt.length / 4).ceil();
    debugPrint('CharacterGen: Prompt size: ${prompt.length} chars (~$promptEstTokens tokens), maxLen: $maxLen');
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      String accumulated = '';
      int tokenCount = 0;
      try {
        await for (final token in _llmService.generateStream(GenerationParams(
          prompt: prompt,
          maxLength: maxLen,
          minLength: minLen,
          temperature: 0.8,
          repeatPenalty: 1.15,
          minP: 0.05,
          reasoningEnabled: false,
          stopSequences: ['<END>', '</END>'],
        ))) {
          accumulated += token;
          tokenCount++;
          // Strip <think> blocks from preview so reasoning isn't shown
          if (onProgress != null) {
            String preview = accumulated;
            // Remove completed <think>...</think> blocks
            preview = preview.replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '');
            // Remove in-progress <think> block (no closing tag yet)
            preview = preview.replaceAll(RegExp(r'<think>[\s\S]*$'), '');
            onProgress(preview.trim());
          }
        }

        debugPrint('CharacterGen: Stream done. Tokens: $tokenCount, '
            'Raw: ${accumulated.length} chars');

        if (accumulated.isNotEmpty) return accumulated;

        // Empty response — retry with diagnostics
        debugPrint('CharacterGen: Empty response on attempt $attempt/$maxRetries. '
            'Prompt ~$promptEstTokens tokens. If this exceeds your model\'s context window, '
            'try a shorter concept or reduce lore depth.');
      } catch (e) {
        debugPrint('CharacterGen: LLM error on attempt $attempt/$maxRetries: $e');
      }

      // Wait before retrying (exponential backoff: 2s, 4s, 8s)
      if (attempt < maxRetries) {
        final delay = Duration(seconds: 2 * (1 << (attempt - 1)));
        debugPrint('CharacterGen: Retrying in ${delay.inSeconds}s...');
        onProgress?.call('[Retrying in ${delay.inSeconds}s... (attempt ${attempt + 1}/$maxRetries)]');
        await Future.delayed(delay);
        onProgress?.call(''); // Clear retry message
      }
    }

    debugPrint('CharacterGen: All $maxRetries attempts failed');
    return null;
  }

  // ═════════════════════════════════════════════════════════════
  //  Truncation Recovery
  // ═════════════════════════════════════════════════════════════

  /// Generate only the missing fields after a truncated base card output.
  /// Uses a focused prompt with no lorebook/image_prompt to fit in limited context.
  Future<CharacterCard?> _recoverMissingFields({
    required String name,
    required String concept,
    required String personalityKeywords,
    required List<String> missingFields,
    String apiSystemPrompt = '',
    String age = '',
    String sex = '',
    String relationship = '',
    String backstory = '',
    void Function(String accumulated)? onProgress,
  }) async {
    final keywordsLine = personalityKeywords.isNotEmpty
        ? 'Personality keywords: $personalityKeywords\n'
        : '';
    final ageLine = age.isNotEmpty ? 'Age: $age\n' : '';
    final sexLine = sex.isNotEmpty ? 'Sex: $sex\n' : '';
    final relationshipLine = relationship.isNotEmpty
        ? 'Relationship to {{user}}: $relationship\n'
        : '';
    final backstoryLine = backstory.isNotEmpty
        ? 'Backstory: $backstory\n'
        : '';

    // Build spec only for the missing keys
    final fieldSpecs = <String>[];
    for (final field in missingFields) {
      switch (field) {
        case 'personality':
          fieldSpecs.add('- "personality": (string) 1-2 paragraphs, third person, core traits + motivations + quirks');
          break;
        case 'scenario':
          fieldSpecs.add('- "scenario": (string) 1 paragraph, the default conversation setting');
          break;
        case 'system_prompt':
          String spec = '- "system_prompt": (string) brief instruction for how to portray this character';
          if (apiSystemPrompt.isNotEmpty) {
            spec += '. Incorporate: "$apiSystemPrompt"';
          }
          fieldSpecs.add(spec);
          break;
        case 'example_dialogue':
          fieldSpecs.add('- "example_dialogue": (string) format: <START>\\n{{user}}: message\\n{{char}}: response\\n<START>\\n{{user}}: message\\n{{char}}: response');
          break;
      }
    }

    final prompt = '''Generate ONLY the following fields for a roleplay character as a JSON object. Output ONLY the JSON, no markdown, no explanation.

Character name: $name
Concept: $concept
$ageLine$sexLine$relationshipLine$backstoryLine$keywordsLine
Required JSON keys:
${fieldSpecs.join('\n')}

Use {{char}} for character name and {{user}} for user name. Respond with ONLY the JSON:''';

    debugPrint('CharacterGen: Recovery prompt for ${missingFields.length} fields');

    final output = await _callLLM(prompt, maxLen: 4096, onProgress: onProgress);
    if (output == null) return null;

    final cleaned = _stripContent(output);
    return _parseCharacterJson(cleaned, name);
  }

  /// Generate lorebook entries as a separate call when truncated from base card.
  Future<void> _generateLorebookSeparately({
    required CharacterCard card,
    required String name,
    required String concept,
    required List<String> loreCategories,
    required String loreDepth,
    void Function(String accumulated)? onProgress,
  }) async {
    String countRange;
    switch (loreDepth) {
      case 'Light':
        countRange = '3-4';
        break;
      case 'Deep':
        countRange = '10-15';
        break;
      default:
        countRange = '5-8';
    }
    final categoryHint = loreCategories.isNotEmpty
        ? ' Focus on: ${loreCategories.join(", ")}.'
        : '';

    final prompt = '''Generate world-building lorebook entries for a roleplay character. Output ONLY a JSON object with a single key "lorebook" containing an array of $countRange entry objects.$categoryHint

Character: $name
Description: ${concept.length > 300 ? '${concept.substring(0, 300)}...' : concept}
Personality: ${card.personality.length > 200 ? '${card.personality.substring(0, 200)}...' : card.personality}

Each entry format: {"name": "title", "key": "trigger,keywords", "content": "1-2 paragraphs of lore"}

Output ONLY the JSON:''';

    final output = await _callLLM(prompt, maxLen: 4096, onProgress: onProgress);
    if (output == null) return;

    final cleaned = _stripContent(output);
    try {
      // Try direct parse
      Map<String, dynamic>? data;
      try {
        data = json.decode(cleaned) as Map<String, dynamic>;
      } catch (_) {
        // Try newline fix
        final fixed = _fixJsonNewlines(cleaned)
            .replaceAll(RegExp(r',\s*}'), '}')
            .replaceAll(RegExp(r',\s*]'), ']');
        data = json.decode(fixed) as Map<String, dynamic>;
      }

      final lorebookData = data['lorebook'];
      if (lorebookData is List && lorebookData.isNotEmpty) {
        final entries = <LorebookEntry>[];
        for (final entry in lorebookData) {
          if (entry is Map<String, dynamic>) {
            entries.add(LorebookEntry(
              name: entry['name']?.toString() ?? '',
              key: entry['key']?.toString() ?? '',
              content: entry['content']?.toString() ?? '',
              enabled: true,
            ));
          }
        }
        if (entries.isNotEmpty) {
          card.lorebook = Lorebook(entries: entries);
          debugPrint('CharacterGen: Separate lorebook generated ${entries.length} entries');
        }
      }
    } catch (e) {
      debugPrint('CharacterGen: Separate lorebook parse failed: $e');
    }
  }

  // ═════════════════════════════════════════════════════════════
  //  Prompt Builders
  // ═════════════════════════════════════════════════════════════

  /// Build prompt for the base card (everything except greetings).
  String _buildBasePrompt({
    required String name,
    required String concept,
    String personalityKeywords = '',
    bool generateLorebook = true,
    List<String> loreCategories = const [],
    String loreDepth = 'Standard',
    String apiSystemPrompt = '',
    String age = '',
    String sex = '',
    String relationship = '',
    String descriptionDetail = '2-3 paragraphs',
    String backstory = '',
  }) {
    final keywordsLine = personalityKeywords.isNotEmpty
        ? 'Personality keywords: $personalityKeywords\n'
        : '';
    final ageLine = age.isNotEmpty ? 'Age: $age\n' : '';
    final sexLine = sex.isNotEmpty ? 'Sex: $sex\n' : '';
    final relationshipLine = relationship.isNotEmpty
        ? 'Relationship to {{user}}: $relationship\n'
        : '';
    final backstoryLine = backstory.isNotEmpty
        ? 'Backstory: $backstory\n'
        : '';

    // Build lorebook spec with depth and categories
    String lorebookSpec = '';
    if (generateLorebook) {
      String countRange;
      switch (loreDepth) {
        case 'Light':
          countRange = '3-4';
          break;
        case 'Deep':
          countRange = '10-15';
          break;
        default:
          countRange = '5-8';
      }
      final categoryHint = loreCategories.isNotEmpty
          ? ' focusing on: ${loreCategories.join(", ")}'
          : '';
      lorebookSpec = '- "lorebook": (array of $countRange objects) world-building entries$categoryHint, each: {"name": "title", "key": "trigger,keywords", "content": "1-2 paragraphs of lore"}\n';
    }

    String sysSpec = '- "system_prompt": (string) brief instruction for how to portray this character';
    if (apiSystemPrompt.isNotEmpty) {
      sysSpec += '. Incorporate this existing prompt: "$apiSystemPrompt"';
    }

    // Key order: critical small fields FIRST so they survive output truncation.
    // Lorebook (the largest field) goes LAST so it gets clipped first if the
    // model runs out of output tokens — we can regenerate it separately.
    return '''Create a roleplay character card as a single JSON object. Do NOT analyze, plan, or explain. Output ONLY the JSON object starting with { and ending with }. No markdown. No lists. Just raw JSON.

Character name: $name
Concept: $concept
$ageLine$sexLine$relationshipLine$backstoryLine$keywordsLine
Required JSON keys (generate them IN THIS ORDER):
- "personality": (string) 1-2 paragraphs, third person, core traits + motivations + quirks
- "scenario": (string) 1 paragraph, the default conversation setting
$sysSpec
- "tags": (array of strings) 3-5 relevant tags
- "image_prompt": (string) flat comma-separated visual tags for an image generator. NO prose, NO sentences, NO character names. Format: "skin tone + gender, hair, eyes, body type, outfit pieces, pose, setting, expression". Under 80 words total
- "example_dialogue": (string) format: <START>\\n{{user}}: message\\n{{char}}: response\\n<START>\\n{{user}}: message\\n{{char}}: response
$lorebookSpec
IMPORTANT: Do NOT generate a "description" key — the description is handled separately. Do NOT include first_message or alternate_greetings. Use {{char}} for character name and {{user}} for user name. Respond with ONLY the JSON:''';
  }

  /// Build prompt for a single greeting message.
  String _buildGreetingPrompt({
    required String name,
    required String description,
    required String personality,
    required String scenario,
    required String length,
    required String tone,
    required List<String> previousGreetings,
    String characterContext = '',
    String userPersonaContext = '',
  }) {
    String lengthSpec;
    String lengthEnforcement;
    switch (length) {
      case 'Short (1-2 paragraphs)':
        lengthSpec = '1-2 substantial paragraphs (minimum 100 words)';
        lengthEnforcement = 'Write at least 100 words. Each paragraph should be 3-5 sentences minimum.';
        break;
      case 'Long (4-6 paragraphs)':
        lengthSpec = '4-6 rich paragraphs (minimum 500 words)';
        lengthEnforcement = 'Write at least 500 words across 4-6 full paragraphs. Each paragraph MUST be 4-6 sentences. Include detailed scene-setting, inner monologue, environmental descriptions, and character mannerisms. DO NOT stop early or summarize. Fill the space with vivid, immersive prose.';
        break;
      default:
        lengthSpec = '2-4 paragraphs (minimum 250 words)';
        lengthEnforcement = 'Write at least 250 words across 2-4 paragraphs. Each paragraph should be 3-5 sentences.';
    }

    String toneSpec = '';
    switch (tone) {
      case 'Romantic':
        toneSpec = '\nTone: Romantic — Warm intimacy, emotional vulnerability, longing glances, and heartfelt connection. Focus on the emotional bond between {{char}} and {{user}}. Include tender physical awareness (proximity, warmth, touch) without being explicit.';
        break;
      case 'Spicy/NSFW':
        toneSpec = '\nTone: Spicy/NSFW — Sensual tension, physical chemistry, and charged atmosphere. Include suggestive descriptions, body language, and desire. Be bold with attraction and intimacy. Push boundaries while keeping literary quality.';
        break;
      case 'Flirty/Playful':
        toneSpec = '\nTone: Flirty/Playful — Light teasing, witty banter, confident energy, and playful tension. {{char}} should be charming and a little daring. Include smirks, raised eyebrows, and double meanings. Keep it fun, not heavy.';
        break;
      case 'Wholesome':
        toneSpec = '\nTone: Wholesome — Warm, cozy, and comforting. Focus on kindness, gentle humor, and genuine care. Think shared meals, soft laughter, safe spaces. The greeting should feel like a warm blanket — inviting and safe.';
        break;
      case 'Slice of Life':
        toneSpec = '\nTone: Slice of Life — Everyday mundane moments made interesting. Casual, grounded, realistic. Focus on small details: morning routines, grocery shopping, waiting for the bus. Beauty in the ordinary.';
        break;
      case 'Story/Narrative':
        toneSpec = '\nTone: Story/Narrative — Rich literary prose with strong scene-setting. Open like a novel chapter with atmospheric description, inner monologue, and world-building. Prioritize immersion and vivid imagery over action.';
        break;
      case 'Adventure':
        toneSpec = '\nTone: Adventure — Excitement, exploration, and the thrill of the unknown. {{char}} is in motion — discovering something, embarking on a journey, or inviting {{user}} along for the ride. High energy, forward momentum, wonder.';
        break;
      case 'Combat/Action':
        toneSpec = '\nTone: Combat/Action — Adrenaline, danger, and physical intensity. Open mid-fight, mid-chase, or in the aftermath of violence. Sharp pacing, visceral descriptions, and tactical awareness. {{char}} is in their element.';
        break;
      case 'Comedy/Humor':
        toneSpec = '\nTone: Comedy/Humor — Genuinely funny. Include witty observations, absurd situations, comic timing, or self-deprecating humor. {{char}} should make {{user}} want to laugh. Avoid being cringey — aim for clever over random.';
        break;
      case 'Suspense/Thriller':
        toneSpec = '\nTone: Suspense/Thriller — Tension, urgency, and unease. Something is wrong or about to go wrong. Use short sentences for pacing, environmental unease, and a sense that time is running out. End with a hook that demands a response.';
        break;
      case 'Dark/Mystery':
        toneSpec = '\nTone: Dark/Mystery — Brooding atmosphere, secrets, and moral ambiguity. Shadows, whispered conversations, hidden motives. {{char}} knows something {{user}} doesn\'t — or vice versa. Atmospheric and ominous.';
        break;
      case 'Melancholy':
        toneSpec = '\nTone: Melancholy — Bittersweet, introspective, and emotionally heavy. Focus on loss, nostalgia, quiet pain, or fading hope. Beautiful sadness. The greeting should ache a little — poetic but not melodramatic.';
        break;
      default: // 'Neutral'
        toneSpec = '';
    }

    final previousContext = previousGreetings.isNotEmpty
        ? '\n\nIMPORTANT: The following greetings have ALREADY been written. Write something COMPLETELY DIFFERENT — a new scenario, new setting, new mood. Do NOT repeat or paraphrase these:\n---\n${previousGreetings.map((g) => g.length > 200 ? '${g.substring(0, 200)}...' : g).join('\n---\n')}\n---'
        : '';

    // Build persona context section
    String personaSection;
    if (userPersonaContext.isNotEmpty) {
      personaSection = '''

{{user}} Persona (for context — you may reference these traits but NEVER act as {{user}}):
$userPersonaContext''';
    } else {
      personaSection = '';
    }

    // Build character context section
    String characterSection = '';
    if (characterContext.isNotEmpty) {
      characterSection = '''

Character Details (weave these naturally into the scene — SHOW through action, environment, and description, don't just list them):
$characterContext''';
    }

    return '''Write an opening roleplay message as $name (first person: "I", "my", "me"). This is the very first moment of the story — set the scene and introduce who $name is through vivid prose. Output ONLY the message text.

== WHO $name IS ==
Description: $description
Personality: $personality
Scenario: $scenario$characterSection$personaSection
$toneSpec

== NARRATIVE STRUCTURE (follow this order) ==
1. SCENE — Open with the environment. Where are we? What time of day? What's the atmosphere? Paint the world with sensory detail (sights, sounds, smells, textures). Minimum 1 full paragraph of scene-setting.
2. CHARACTER — Describe $name's physical appearance through action. Show race/species features, body, clothing, hair, distinguishing marks AS $name moves through the scene. The reader should be able to picture $name vividly. Minimum 1 full paragraph focused on $name's appearance and mannerisms.
3. ENCOUNTER — The moment $name notices or interacts with {{user}}. Include inner thoughts, emotional reactions, and end with spoken dialogue that invites {{user}} to respond.

== RULES ==
- First person ONLY ("I", "my", "me") — never third person, never use "$name" to refer to yourself
- *Asterisks* for physical actions only. "Quotes" for dialogue. Plain text for narration/thoughts/description.
- Use {{user}} (with curly braces) when mentioning the other person — never vague references like "the stranger"
- NEVER write actions, thoughts, feelings, appearance, or dialogue for {{user}} — {{user}} is a blank slate
- Do NOT start the message by addressing {{user}} — start with scene description

== LENGTH ==
$lengthEnforcement
This is MANDATORY — do NOT write less. Fill the space with rich, immersive prose.$previousContext

Begin:''';
  }

  /// Clean raw greeting output — remove quotes, labels, fix truncation.
String _cleanGreeting(String raw) {
  String cleaned = raw.trim();

  // Remove wrapping quotes if present
  if (cleaned.startsWith('"') && cleaned.endsWith('"')) {
    cleaned = cleaned.substring(1, cleaned.length - 1);
  }

  // Remove common leading labels
  cleaned = cleaned
      .replaceAll(RegExp(r'^(First message|Opening message|Greeting):?\s*', caseSensitive: false), '')
      .trim();

  return cleaned;
}

/// Check if a greeting was truncated (cut off mid-sentence).
bool _isGreetingTruncated(String text) {
  if (text.isEmpty) return true;
  final trimmed = text.trimRight();
  if (trimmed.isEmpty) return true;

  // Check for unclosed formatting
  final asteriskCount = '*'.allMatches(trimmed).length;
  if (asteriskCount % 2 != 0) return true; // Unclosed *asterisk*
  final quoteCount = '"'.allMatches(trimmed).length;
  if (quoteCount % 2 != 0) return true; // Unclosed "quote"

  // Check if it ends with proper sentence-ending punctuation
  final lastChar = trimmed[trimmed.length - 1];
  final endsWithPunctuation = '.!?*"\u201D'.contains(lastChar);
  if (!endsWithPunctuation) return true;

  return false;
}

/// Editor pass: complete a truncated greeting.
Future<String?> editorCompletionPass(String greeting, {void Function(String)? onProgress}) async {
  if (greeting.trim().isEmpty) return null;
  if (!_isGreetingTruncated(greeting)) return null; // Not truncated

  final prompt = '''OUTPUT FORMAT: Respond with ONLY the complete greeting text. Your entire response must be the greeting and nothing else. Do NOT include analysis, reasoning, or commentary.

TASK: This greeting was cut off mid-sentence. Complete it naturally. Write the ENTIRE greeting from the beginning (copy the existing text) and add just enough to finish the final thought properly. Do NOT add significant new content — just complete the sentence/paragraph that was cut off.

FORMATTING:
- *Asterisks* ONLY for physical actions
- "Quotation marks" for spoken dialogue
- Plain text for narration and description
- Maintain the same voice, tense, and style

TRUNCATED GREETING:
$greeting''';

  final result = await _callLLM(prompt, maxLen: 4096, minLen: 128, onProgress: onProgress);
  if (result != null && result.trim().isNotEmpty) {
    final cleaned = _cleanEditorOutput(result);
    // Only accept if it's at least as long as original (completion, not replacement)
    if (cleaned.length >= greeting.length * 0.9) {
      return cleaned;
    }
  }
  return null;
}
  // ═════════════════════════════════════════════════════════════
  //  Editor Passes
  // ═════════════════════════════════════════════════════════════

  /// Anti-puppet check: find and fix lines that describe {{user}}.
  Future<String?> editorAntiPuppetCheck(String greeting, {void Function(String)? onProgress}) async {
    if (greeting.trim().isEmpty) return null;

    final prompt = '''OUTPUT FORMAT: Respond with ONLY the corrected greeting text. Start immediately with the first word of the greeting (usually *). Do NOT include analysis, reasoning, line-by-line breakdown, numbered lists, explanations of changes, or any other commentary. Your entire response must be the greeting and nothing else.

TASK: Fix "puppeting" in this greeting. Puppeting = describing {{user}}'s actions, thoughts, feelings, appearance, body, or dialogue.

FIXES TO APPLY:
- "you feel nervous" → rephrase as {{char}}'s observation or delete
- "your heart races" → delete
- "your hair / your eyes / your jaw" → delete physical descriptions of {{user}}
- "your movements fluid" → delete or rephrase as {{char}}'s impression
- "you sit down" → let {{char}} gesture to a seat instead
- If NO puppeting exists, return the greeting UNCHANGED

FORMATTING — PRESERVE EXACTLY:
- *Asterisks* ONLY for physical actions (things the character does)
- "Quotation marks" for spoken dialogue
- Plain text for narration, description, and inner thoughts — no special formatting
- Keep same length, tone, style. Rephrase from {{char}}'s perspective.

$greeting''';

    final result = await _callLLM(prompt, maxLen: 4096, minLen: 128, onProgress: onProgress);
    if (result != null && result.trim().isNotEmpty) {
      final cleaned = _cleanEditorOutput(result);
      if (cleaned.length > greeting.length * 0.4) {
        return cleaned;
      }
    }
    return null;
  }

  /// Consistency check: verify greeting matches character profile.
  Future<String?> editorConsistencyCheck(
    String greeting,
    String description,
    String personality,
    String scenario, {
    void Function(String)? onProgress,
  }) async {
    if (greeting.trim().isEmpty) return null;

    final prompt = '''OUTPUT FORMAT: Respond with ONLY the corrected greeting text. Start immediately with the first word of the greeting (usually *). Do NOT include analysis, reasoning, or any commentary. Your entire response must be the greeting and nothing else.

TASK: Check this greeting for consistency with the character profile. Fix contradictions in personality, appearance, setting, or tone. If consistent, return UNCHANGED.

FORMATTING — PRESERVE EXACTLY:
- *Asterisks* ONLY for physical actions (things the character does)
- "Quotation marks" for spoken dialogue
- Plain text for narration, description, and inner thoughts — no special formatting

CHARACTER: $description | $personality | $scenario

$greeting''';

    final result = await _callLLM(prompt, maxLen: 4096, minLen: 128, onProgress: onProgress);
    if (result != null && result.trim().isNotEmpty) {
      final cleaned = _cleanEditorOutput(result);
      if (cleaned.length > greeting.length * 0.4) {
        return cleaned;
      }
    }
    return null;
  }

  /// Quality polish: improve prose quality and immersiveness.
  Future<String?> editorQualityPolish(String greeting, {void Function(String)? onProgress}) async {
    if (greeting.trim().isEmpty) return null;

    final prompt = '''OUTPUT FORMAT: Respond with ONLY the polished greeting text. Start immediately with the first word of the greeting (usually *). Do NOT include analysis, reasoning, or any commentary. Your entire response must be the greeting and nothing else.

TASK: Polish this greeting's prose. Improve vivid descriptions, sensory details, sentence rhythm, immersiveness. Keep same meaning, length, voice, and {{user}}/{{char}} placeholders. NEVER add puppeting of {{user}}.

FORMATTING — ENFORCE STRICTLY:
- *Asterisks* ONLY for physical actions (things the character does)
- "Quotation marks" for spoken dialogue
- Plain text for narration, description, and inner thoughts — no special formatting
- If narration is incorrectly wrapped in *asterisks*, unwrap it to plain text

$greeting''';

    final result = await _callLLM(prompt, maxLen: 4096, minLen: 128, onProgress: onProgress);
    if (result != null && result.trim().isNotEmpty) {
      final cleaned = _cleanEditorOutput(result);
      if (cleaned.length > greeting.length * 0.4) {
        return cleaned;
      }
    }
    return null;
  }

  /// Strip analysis preamble/postamble from editor output.
  /// Models often include reasoning/analysis before the actual corrected greeting.
  String _cleanEditorOutput(String raw) {
    String text = _stripContent(raw).trim();

    // Strategy 1: Look for explicit section markers that precede the actual greeting.
    // The actual greeting typically follows markers like "polished version:", etc.
    final sectionMarkers = RegExp(
      r'(polished version|corrected version|corrected greeting|revised greeting|'
      r'polished greeting|here is the|here.s the|the polished|the corrected|'
      r'now let me write|final version|edited version|cleaned version|'
      r'output:|result:)\s*:?\s*$',
      caseSensitive: false,
      multiLine: true,
    );
    final markerMatch = sectionMarkers.allMatches(text).lastOrNull;
    if (markerMatch != null) {
      final afterMarker = text.substring(markerMatch.end).trim();
      if (afterMarker.isNotEmpty) {
        text = afterMarker;
      }
    }

    // Strategy 2: If text still has analysis lines (Current:, Enhancement:, Line X:, etc.)
    // split into paragraphs and keep only the ones that look like prose, not analysis.
    final analysisLinePattern = RegExp(
      r'^(Current:|Enhancement:|Original:|Revised?:|Rewrite:|'
      r'Line \d|Paragraph \d|Instance \d|\d+\.\s+"|\d+\.\s+\*|'
      r'- ".*" →|Check:|Note:|Summary:|Wait,|Actually,|Let me|Looking at|'
      r'So the|I need to|Better:|Try:|Hmm|The issue|'
      r'Enhancement|puppeting|This is)',
      caseSensitive: false,
    );

    final lines = text.split('\n');
    bool hasAnalysis = lines.any((l) => analysisLinePattern.hasMatch(l.trim()));

    if (hasAnalysis) {
      // Find the last large block of consecutive non-analysis lines
      List<String> bestBlock = [];
      List<String> currentBlock = [];

      for (final line in lines) {
        if (analysisLinePattern.hasMatch(line.trim()) || 
            (line.trim().isEmpty && currentBlock.isEmpty)) {
          // Analysis line or leading blank — save best block and reset
          if (currentBlock.length > bestBlock.length) {
            bestBlock = List.from(currentBlock);
          }
          currentBlock = [];
        } else {
          currentBlock.add(line);
        }
      }
      // Check final block
      if (currentBlock.length > bestBlock.length) {
        bestBlock = currentBlock;
      }

      if (bestBlock.length >= 3) {
        text = bestBlock.join('\n');
      }
    }

    // Strategy 3: Strip any remaining trailing analysis
    final trailingAnalysis = RegExp(
      r'\n\s*(Note:|Summary:|Changes? made|I (?:changed|removed|fixed|revised)|'
      r'The (?:changes|edits|fixes)|Wait,|Actually,|Let me check)[\s\S]*$',
      caseSensitive: false,
    );
    text = text.replaceAll(trailingAnalysis, '');

    return _cleanGreeting(text.trim());
  }

  // ═════════════════════════════════════════════════════════════
  //  Content Stripping
  // ═════════════════════════════════════════════════════════════

  /// Strip thinking tags, markdown wrappers, and other LLM artifacts.
  String _stripContent(String raw) {
    String cleaned = raw;

    // Strip <think> blocks (closed and unclosed)
    cleaned = cleaned
        .replaceAll(RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<think>[\s\S]*$', caseSensitive: false), '');

    // Strip markdown code fences
    cleaned = cleaned
        .replaceAll(RegExp(r'^```json\s*', multiLine: true), '')
        .replaceAll(RegExp(r'^```\s*$', multiLine: true), '');

    // Strip leading/trailing whitespace
    cleaned = cleaned.trim();

    // If there's a "JSON:" marker, take only what follows
    final jsonMarker = RegExp(r'JSON:\s*').firstMatch(cleaned);
    if (jsonMarker != null) {
      cleaned = cleaned.substring(jsonMarker.end).trim();
    }

    // Try to extract just the JSON object if there's surrounding text
    final jsonStart = cleaned.indexOf('{');
    final jsonEnd = cleaned.lastIndexOf('}');
    if (jsonStart >= 0 && jsonEnd > jsonStart) {
      cleaned = cleaned.substring(jsonStart, jsonEnd + 1);
    }

    return cleaned;
  }

  // ═════════════════════════════════════════════════════════════
  //  JSON Parsing (with multiple fallback strategies)
  // ═════════════════════════════════════════════════════════════

  /// Parse the cleaned JSON into a [CharacterCard].
  /// Tries three strategies: direct decode → newline fix → regex extraction.
  CharacterCard? _parseCharacterJson(String jsonStr, String fallbackName) {
    // Strategy 1: Direct JSON parse
    try {
      final data = json.decode(jsonStr) as Map<String, dynamic>;
      debugPrint('CharacterGen: Direct JSON parse succeeded');
      return _buildCard(data, fallbackName);
    } catch (e) {
      debugPrint('CharacterGen: Direct parse failed: $e');
    }

    // Strategy 2: Fix newlines inside strings
    try {
      String fixed = _fixJsonNewlines(jsonStr);
      fixed = fixed
          .replaceAll(RegExp(r',\s*}'), '}')
          .replaceAll(RegExp(r',\s*]'), ']');
      final data = json.decode(fixed) as Map<String, dynamic>;
      debugPrint('CharacterGen: Newline-fixed parse succeeded');
      return _buildCard(data, fallbackName);
    } catch (e) {
      debugPrint('CharacterGen: Newline-fixed parse failed: $e');
    }

    // Strategy 3: Regex-based extraction (handles unescaped quotes in prose)
    try {
      final data = _regexExtract(jsonStr);
      if (data.isNotEmpty) {
        debugPrint('CharacterGen: Regex extraction succeeded (${data.length} keys)');
        return _buildCard(data, fallbackName);
      }
    } catch (e) {
      debugPrint('CharacterGen: Regex extraction failed: $e');
    }

    debugPrint('CharacterGen: All parse strategies failed');
    return null;
  }

  /// Regex-based key extraction for malformed JSON.
  ///
  /// Since we know the expected keys, we find each key and extract
  /// the value text between keys. This handles unescaped quotes,
  /// literal newlines, and other LLM mangling.
  Map<String, dynamic> _regexExtract(String raw) {
    final result = <String, dynamic>{};
    final knownKeys = [
      'description', 'personality', 'scenario', 'first_message',
      'alternate_greetings', 'example_dialogue', 'system_prompt',
      'tags', 'image_prompt', 'lorebook',
    ];

    for (int i = 0; i < knownKeys.length; i++) {
      final key = knownKeys[i];
      // Find "key": or "key" :
      final keyPattern = RegExp('"$key"\\s*:\\s*');
      final keyMatch = keyPattern.firstMatch(raw);
      if (keyMatch == null) continue;

      final valueStart = keyMatch.end;

      // Determine if value is a string, array, or other
      final firstChar = raw.substring(valueStart).trimLeft();
      if (firstChar.startsWith('[')) {
        // Array value — find matching ]
        final arrStart = raw.indexOf('[', valueStart);
        final arrEnd = _findMatchingBracket(raw, arrStart, '[', ']');
        if (arrEnd > arrStart) {
          final arrStr = raw.substring(arrStart, arrEnd + 1);
          try {
            // Fix newlines and attempt parse
            final fixed = _fixJsonNewlines(arrStr)
                .replaceAll(RegExp(r',\s*]'), ']');
            result[key] = json.decode(fixed);
          } catch (_) {
            // Fall back to splitting on simple patterns
            result[key] = _extractArrayStrings(arrStr);
          }
        }
      } else if (firstChar.startsWith('"')) {
        // String value — find end by looking for next known key or end of object
        final strStart = raw.indexOf('"', valueStart);
        String? value = _extractStringValue(raw, strStart, knownKeys, i);
        if (value != null) {
          result[key] = value;
        }
      }
    }

    return result;
  }

  /// Extract a string value starting at [start] (the opening quote).
  /// Looks for the next known key as the boundary.
  String? _extractStringValue(String raw, int start, List<String> keys, int currentIdx) {
    if (start < 0 || start >= raw.length) return null;

    // Look past the opening quote
    final contentStart = start + 1;

    // Find the end by looking for the next key pattern or closing brace
    int? nextBoundary;
    for (int j = currentIdx + 1; j < keys.length; j++) {
      final nextKeyPattern = RegExp('"${keys[j]}"\\s*:');
      final nextMatch = nextKeyPattern.firstMatch(raw.substring(contentStart));
      if (nextMatch != null) {
        nextBoundary = contentStart + nextMatch.start;
        break;
      }
    }

    // If no next key found, look for final }
    nextBoundary ??= raw.lastIndexOf('}');
    if (nextBoundary == null || nextBoundary <= contentStart) return null;

    // Extract and clean the value
    var value = raw.substring(contentStart, nextBoundary);

    // Strip trailing: comma, quote, whitespace
    value = value.replaceAll(RegExp(r'[\s,]*"?\s*,?\s*$'), '');
    // Strip trailing quote
    if (value.endsWith('"')) value = value.substring(0, value.length - 1);

    // Unescape JSON escapes
    value = value
        .replaceAll('\\n', '\n')
        .replaceAll('\\t', '\t')
        .replaceAll('\\"', '"')
        .replaceAll('\\\\', '\\');

    return value.trim();
  }

  /// Extract string items from a JSON array that may have malformed quotes.
  List<String> _extractArrayStrings(String arrStr) {
    final results = <String>[];
    // Remove brackets
    var inner = arrStr.trim();
    if (inner.startsWith('[')) inner = inner.substring(1);
    if (inner.endsWith(']')) inner = inner.substring(0, inner.length - 1);

    // Split on ", " pattern (quotes followed by comma)
    final parts = inner.split(RegExp(r'"\s*,\s*"'));
    for (var part in parts) {
      part = part.trim();
      if (part.startsWith('"')) part = part.substring(1);
      if (part.endsWith('"')) part = part.substring(0, part.length - 1);
      if (part.isNotEmpty) results.add(part);
    }
    return results;
  }

  /// Find matching closing bracket, accounting for nesting.
  int _findMatchingBracket(String s, int start, String open, String close) {
    int depth = 0;
    bool inStr = false;
    for (int i = start; i < s.length; i++) {
      final ch = s[i];
      if (ch == '"' && (i == 0 || s[i - 1] != '\\')) {
        inStr = !inStr;
      } else if (!inStr) {
        if (ch == open) depth++;
        if (ch == close) {
          depth--;
          if (depth == 0) return i;
        }
      }
    }
    return -1;
  }

  /// Build a [CharacterCard] from parsed JSON data, including lorebook.
  CharacterCard _buildCard(Map<String, dynamic> data, String fallbackName) {
    final card = CharacterCard(
      name: fallbackName,
      description: _getString(data, 'description'),
      personality: _getString(data, 'personality'),
      scenario: _getString(data, 'scenario'),
      firstMessage: _getString(data, 'first_message'),
      mesExample: _getString(data, 'example_dialogue'),
      systemPrompt: _getString(data, 'system_prompt'),
      alternateGreetings: _getStringList(data, 'alternate_greetings'),
      tags: _getStringList(data, 'tags'),
    );

    // Parse lorebook entries if present
    final lorebookData = data['lorebook'];
    if (lorebookData is List && lorebookData.isNotEmpty) {
      final entries = <LorebookEntry>[];
      for (final entry in lorebookData) {
        if (entry is Map<String, dynamic>) {
          entries.add(LorebookEntry(
            name: entry['name']?.toString() ?? '',
            key: entry['key']?.toString() ?? '',
            content: entry['content']?.toString() ?? '',
            enabled: true,
          ));
        }
      }
      if (entries.isNotEmpty) {
        card.lorebook = Lorebook(entries: entries);
        debugPrint('CharacterGen: Parsed ${entries.length} lorebook entries');
      }
    }

    return card;
  }

  /// Fix literal newlines/tabs inside JSON string values.
  String _fixJsonNewlines(String input) {
    final buf = StringBuffer();
    bool inString = false;
    for (int i = 0; i < input.length; i++) {
      final ch = input[i];

      if (ch == '"' && (i == 0 || input[i - 1] != '\\')) {
        inString = !inString;
        buf.write(ch);
      } else if (inString) {
        switch (ch) {
          case '\n':
            buf.write('\\n');
            break;
          case '\r':
            buf.write('\\r');
            break;
          case '\t':
            buf.write('\\t');
            break;
          default:
            buf.write(ch);
        }
      } else {
        buf.write(ch);
      }
    }
    return buf.toString();
  }

  /// Safely extract a String from a JSON map.
  String _getString(Map<String, dynamic> data, String key) {
    final val = data[key];
    if (val is String) return val;
    if (val != null) return val.toString();
    return '';
  }

  /// Safely extract a List<String> from a JSON map.
  List<String> _getStringList(Map<String, dynamic> data, String key) {
    final val = data[key];
    if (val is List) return val.map((e) => e.toString()).toList();
    return [];
  }

  /// Extract the image prompt from the generated JSON (if present).
  String? extractImagePrompt(String rawOutput) {
    final cleaned = _stripContent(rawOutput);
    try {
      final data = json.decode(cleaned) as Map<String, dynamic>;
      return _getString(data, 'image_prompt');
    } catch (_) {
      // Try regex extraction as fallback
      try {
        final data = _regexExtract(cleaned);
        return data['image_prompt'] as String?;
      } catch (_) {
        return null;
      }
    }
  }
}
