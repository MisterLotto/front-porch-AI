import 'dart:convert';

/// A utility for sanitizing and recovering broken JSON outputs from LLMs.
class JsonSanitizer {
  /// Cleans markdown boundaries, trailing commas, and inline unescaped newlines.
  static String sanitize(String input) {
    if (input.isEmpty) return input;
    
    var cleaned = input;
    
    // 1. Strip markdown fences and thought blocks
    cleaned = cleaned
        .replaceAll(RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<think>[\s\S]*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'^```json\s*', multiLine: true), '')
        .replaceAll(RegExp(r'^```\s*$', multiLine: true), '');
        
    final jsonMarker = RegExp(r'JSON:\s*').firstMatch(cleaned);
    if (jsonMarker != null) {
      cleaned = cleaned.substring(jsonMarker.end).trim();
    }
    
    // Attempt to extract the JSON object bounding box
    final jsonStart = cleaned.indexOf('{');
    final jsonEnd = cleaned.lastIndexOf('}');
    if (jsonStart >= 0 && jsonEnd > jsonStart) {
      cleaned = cleaned.substring(jsonStart, jsonEnd + 1);
    }

    // 2. Remove trailing commas for objects and arrays
    cleaned = cleaned.replaceAll(RegExp(r',\s*}'), '}');
    cleaned = cleaned.replaceAll(RegExp(r',\s*]'), ']');

    // 3. Fix literal newlines and tabs inside string values
    final buf = StringBuffer();
    bool inString = false;
    for (int i = 0; i < cleaned.length; i++) {
      final ch = cleaned[i];
      if (ch == '"' && (i == 0 || cleaned[i - 1] != '\\')) {
        inString = !inString;
        buf.write(ch);
      } else if (inString) {
        switch (ch) {
          case '\n': buf.write('\\n'); break;
          case '\r': buf.write('\\r'); break;
          case '\t': buf.write('\\t'); break;
          default: buf.write(ch);
        }
      } else {
        buf.write(ch);
      }
    }
    
    return buf.toString().trim();
  }
  
  /// Attempts to parse JSON, returning null if it utterly fails.
  /// Automatically runs the sanitizer before parsing.
  static Map<String, dynamic>? tryParse(String input) {
    try {
      final cleaned = sanitize(input);
      return json.decode(cleaned) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
