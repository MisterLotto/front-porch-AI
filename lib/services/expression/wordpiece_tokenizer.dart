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

/// Pure-Dart BERT WordPiece tokenizer matching HuggingFace's
/// `DistilBertTokenizer` (uncased) closely enough for the go-emotions
/// classifier: lowercasing, Latin accent stripping, punctuation splitting,
/// CJK isolation, then greedy longest-match WordPiece.
///
/// Verified against token-id goldens generated from the exact Python
/// tokenizer the sentiment sidecar used (see
/// test/services/expression/wordpiece_tokenizer_test.dart). Known
/// divergence: accent stripping covers Latin-1 Supplement + Latin
/// Extended-A (the practical chat range) rather than full Unicode NFD;
/// exotic precomposed characters fall through to [UNK], which the
/// classifier treats as neutral-ish context — harmless for emotion labels.
class WordPieceTokenizer {
  final Map<String, int> _vocab;
  final int clsId;
  final int sepId;
  final int unkId;
  static const int _maxWordChars = 100;

  WordPieceTokenizer(this._vocab)
    : clsId = _vocab['[CLS]'] ?? 101,
      sepId = _vocab['[SEP]'] ?? 102,
      unkId = _vocab['[UNK]'] ?? 100;

  /// Encodes [text] as `[CLS] ...pieces... [SEP]`, truncated so the total
  /// length is at most [maxLength] (matching HF truncation=True semantics).
  List<int> encode(String text, {int maxLength = 512}) {
    final pieces = <int>[];
    for (final word in _basicTokenize(text)) {
      _wordPiece(word, pieces);
      if (pieces.length > maxLength) break; // no point tokenizing further
    }
    final kept = pieces.length > maxLength - 2
        ? pieces.sublist(0, maxLength - 2)
        : pieces;
    return [clsId, ...kept, sepId];
  }

  /// BasicTokenizer: clean → CJK spacing → whitespace split → per-token
  /// lowercase + accent strip + punctuation split.
  List<String> _basicTokenize(String text) {
    final cleaned = StringBuffer();
    for (final cp in text.runes) {
      if (cp == 0 || cp == 0xFFFD || _isControl(cp)) continue;
      if (_isWhitespace(cp)) {
        cleaned.writeCharCode(0x20);
      } else if (_isCjk(cp)) {
        cleaned
          ..writeCharCode(0x20)
          ..writeCharCode(cp)
          ..writeCharCode(0x20);
      } else {
        cleaned.writeCharCode(cp);
      }
    }
    final out = <String>[];
    for (final raw in cleaned.toString().split(' ')) {
      if (raw.isEmpty) continue;
      final word = _stripAccents(raw.toLowerCase());
      // Split punctuation into standalone tokens.
      final buf = StringBuffer();
      for (final cp in word.runes) {
        if (_isPunctuation(cp)) {
          if (buf.isNotEmpty) {
            out.add(buf.toString());
            buf.clear();
          }
          out.add(String.fromCharCode(cp));
        } else {
          buf.writeCharCode(cp);
        }
      }
      if (buf.isNotEmpty) out.add(buf.toString());
    }
    return out;
  }

  /// Greedy longest-match WordPiece; a word with any unmatchable remainder
  /// becomes a single [UNK] (HF behavior).
  void _wordPiece(String word, List<int> out) {
    final chars = word.runes.toList();
    if (chars.length > _maxWordChars) {
      out.add(unkId);
      return;
    }
    final ids = <int>[];
    var start = 0;
    while (start < chars.length) {
      var end = chars.length;
      int? found;
      while (start < end) {
        var sub = String.fromCharCodes(chars.sublist(start, end));
        if (start > 0) sub = '##$sub';
        final id = _vocab[sub];
        if (id != null) {
          found = id;
          break;
        }
        end--;
      }
      if (found == null) {
        out.add(unkId);
        return;
      }
      ids.add(found);
      start = end;
    }
    out.addAll(ids);
  }

  static bool _isWhitespace(int cp) =>
      cp == 0x20 ||
      cp == 0x09 ||
      cp == 0x0A ||
      cp == 0x0D ||
      cp == 0xA0 ||
      (cp >= 0x2000 && cp <= 0x200A) ||
      cp == 0x2028 ||
      cp == 0x2029 ||
      cp == 0x202F ||
      cp == 0x205F ||
      cp == 0x3000;

  static bool _isControl(int cp) =>
      (cp < 0x20 && cp != 0x09 && cp != 0x0A && cp != 0x0D) ||
      cp == 0x7F ||
      (cp >= 0x80 && cp <= 0x9F) ||
      (cp >= 0x200B && cp <= 0x200F) || // zero-width + directional marks (Cf)
      (cp >= 0x202A && cp <= 0x202E) ||
      cp == 0xFEFF;

  /// Unicode category P approximation: full ASCII punctuation plus the
  /// blocks that show up in chat text (general punctuation, CJK punctuation,
  /// fullwidth forms, inverted marks).
  static bool _isPunctuation(int cp) =>
      (cp >= 0x21 && cp <= 0x2F) ||
      (cp >= 0x3A && cp <= 0x40) ||
      (cp >= 0x5B && cp <= 0x60) ||
      (cp >= 0x7B && cp <= 0x7E) ||
      cp == 0xA1 ||
      cp == 0xBF ||
      cp == 0xAB ||
      cp == 0xBB ||
      cp == 0xB7 ||
      (cp >= 0x2010 && cp <= 0x2027) ||
      (cp >= 0x2030 && cp <= 0x205E) ||
      (cp >= 0x3001 && cp <= 0x3011) ||
      (cp >= 0xFF01 && cp <= 0xFF0F) ||
      (cp >= 0xFF1A && cp <= 0xFF20) ||
      (cp >= 0xFF3B && cp <= 0xFF40) ||
      (cp >= 0xFF5B && cp <= 0xFF65);

  static bool _isCjk(int cp) =>
      (cp >= 0x4E00 && cp <= 0x9FFF) ||
      (cp >= 0x3400 && cp <= 0x4DBF) ||
      (cp >= 0xF900 && cp <= 0xFAFF) ||
      (cp >= 0x20000 && cp <= 0x2A6DF) ||
      (cp >= 0x2A700 && cp <= 0x2CEAF) ||
      (cp >= 0x2F800 && cp <= 0x2FA1F);

  /// Latin-1 Supplement + Latin Extended-A precomposed → base letter, plus
  /// removal of already-decomposed combining marks. Applied after
  /// lowercasing, mirroring HF's lower() → NFD-strip order.
  static String _stripAccents(String s) {
    final buf = StringBuffer();
    for (final cp in s.runes) {
      if (cp >= 0x0300 && cp <= 0x036F) continue; // combining marks
      final mapped = _accentMap[cp];
      if (mapped != null) {
        buf.write(mapped);
      } else {
        buf.writeCharCode(cp);
      }
    }
    return buf.toString();
  }

  static const Map<int, String> _accentMap = {
    0xE0: 'a', 0xE1: 'a', 0xE2: 'a', 0xE3: 'a', 0xE4: 'a', 0xE5: 'a',
    0xE7: 'c',
    0xE8: 'e', 0xE9: 'e', 0xEA: 'e', 0xEB: 'e',
    0xEC: 'i', 0xED: 'i', 0xEE: 'i', 0xEF: 'i',
    0xF1: 'n',
    0xF2: 'o', 0xF3: 'o', 0xF4: 'o', 0xF5: 'o', 0xF6: 'o',
    0xF9: 'u', 0xFA: 'u', 0xFB: 'u', 0xFC: 'u',
    0xFD: 'y', 0xFF: 'y',
    // Latin Extended-A (lowercase forms; input is already lowercased)
    0x101: 'a', 0x103: 'a', 0x105: 'a',
    0x107: 'c', 0x109: 'c', 0x10B: 'c', 0x10D: 'c',
    0x10F: 'd',
    0x113: 'e', 0x115: 'e', 0x117: 'e', 0x119: 'e', 0x11B: 'e',
    0x11D: 'g', 0x11F: 'g', 0x121: 'g', 0x123: 'g',
    0x125: 'h',
    0x129: 'i', 0x12B: 'i', 0x12D: 'i', 0x12F: 'i',
    0x135: 'j', 0x137: 'k',
    0x13A: 'l', 0x13C: 'l', 0x13E: 'l',
    0x144: 'n', 0x146: 'n', 0x148: 'n',
    0x14D: 'o', 0x14F: 'o', 0x151: 'o',
    0x155: 'r', 0x157: 'r', 0x159: 'r',
    0x15B: 's', 0x15D: 's', 0x15F: 's', 0x161: 's',
    0x163: 't', 0x165: 't',
    0x169: 'u', 0x16B: 'u', 0x16D: 'u', 0x16F: 'u', 0x171: 'u', 0x173: 'u',
    0x175: 'w', 0x177: 'y',
    0x17A: 'z', 0x17C: 'z', 0x17E: 'z',
  };
}
