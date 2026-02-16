import 'dart:convert';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:kobold_character_card_manager/models/character_card.dart';
import 'package:kobold_character_card_manager/models/lorebook.dart';

class V2CardService {
  Future<void> saveCardAsPng(CharacterCard card, String outputPath, String? sourceImagePath) async {
    img.Image? avatar;

    try {
      if (sourceImagePath != null) {
        final bytes = await File(sourceImagePath).readAsBytes();
        avatar = img.decodeImage(bytes);
      }
    } catch (e) {
      print('Error loading source image: $e');
    }

    // Fallback if image load fails or is null
    if (avatar == null) {
      avatar = img.Image(width: 400, height: 600);
      img.fill(avatar, color: img.ColorRgb8(50, 50, 50));
    }

    // Resize if too large to save space/time, optional but good practice
    if (avatar.width > 2048 || avatar.height > 2048) {
      avatar = img.copyResize(avatar, width: 1024);
    }

    // Encode character data to Base64
    // V2 Spec: 'chara' chunk containing base64 encoded JSON
    final jsonMap = card.toJson();
    final jsonStr = jsonEncode(jsonMap);
    final base64Str = base64Encode(utf8.encode(jsonStr));

    // Add tEXt chunk
    avatar.textData ??= {};
    avatar.textData!['chara'] = base64Str;

    // Save to file
    final pngBytes = img.encodePng(avatar);
    await File(outputPath).writeAsBytes(pngBytes);
  }

  Future<CharacterCard?> readCard(String path) async {
    final bytes = await File(path).readAsBytes();
    
    // Manual PNG chunk parsing - the `image` package doesn't reliably
    // extract tEXt/iTXt chunks from externally-created character cards
    String? charaData = _extractCharaFromPng(bytes);
    
    if (charaData == null) {
      // Fallback: try the image package approach
      try {
        final avatar = img.decodePng(bytes);
        if (avatar?.textData != null && avatar!.textData!.containsKey('chara')) {
          charaData = avatar.textData!['chara']!;
        }
      } catch (e) {
        print('Image package fallback also failed: $e');
      }
    }
    
    if (charaData == null) return null;

    try {
      final jsonStr = utf8.decode(base64Decode(charaData));
      final jsonMap = jsonDecode(jsonStr);

      // Support both V1 and V2 card formats
      // V2 cards nest data under 'data', V1 cards have it at top level
      final data = jsonMap.containsKey('data') ? jsonMap['data'] : jsonMap;

      return CharacterCard(
        name: data['name'] ?? jsonMap['name'] ?? '',
        description: data['description'] ?? jsonMap['description'] ?? '',
        personality: data['personality'] ?? jsonMap['personality'] ?? '',
        scenario: data['scenario'] ?? jsonMap['scenario'] ?? '',
        firstMessage: data['first_mes'] ?? jsonMap['first_mes'] ?? '',
        alternateGreetings: (data['alternate_greetings'] ?? jsonMap['alternate_greetings']) != null
          ? List<String>.from(data['alternate_greetings'] ?? jsonMap['alternate_greetings'])
          : const [],
        tags: (data['tags'] ?? jsonMap['tags']) != null
          ? List<String>.from(data['tags'] ?? jsonMap['tags'])
          : const [],
        lorebook: (data['character_book'] ?? jsonMap['character_book']) != null 
          ? Lorebook.fromJson(data['character_book'] ?? jsonMap['character_book']) 
          : null,
        worldNames: (data['world_names'] ?? jsonMap['world_names']) != null 
          ? List<String>.from(data['world_names'] ?? jsonMap['world_names']) 
          : const [],
        imagePath: path,
      );
    } catch (e) {
      print('Error parsing card data: $e');
      return null;
    }
  }

  /// Manually parse PNG chunks to extract 'chara' tEXt or iTXt data.
  /// PNG format: 8-byte signature, then chunks of [4-byte length][4-byte type][data][4-byte CRC]
  String? _extractCharaFromPng(List<int> bytes) {
    // Verify PNG signature
    if (bytes.length < 8) return null;
    final signature = [137, 80, 78, 71, 13, 10, 26, 10];
    for (int i = 0; i < 8; i++) {
      if (bytes[i] != signature[i]) return null;
    }

    int offset = 8; // Skip PNG signature

    while (offset + 12 <= bytes.length) {
      // Read chunk length (4 bytes, big-endian)
      final length = (bytes[offset] << 24) | (bytes[offset + 1] << 16) |
                     (bytes[offset + 2] << 8) | bytes[offset + 3];
      offset += 4;

      // Read chunk type (4 bytes ASCII)
      final type = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      offset += 4;

      final dataStart = offset;
      final dataEnd = offset + length;

      if (dataEnd + 4 > bytes.length) break; // Malformed PNG

      if (type == 'tEXt') {
        // tEXt: keyword\0text
        final data = bytes.sublist(dataStart, dataEnd);
        final nullIndex = data.indexOf(0);
        if (nullIndex != -1) {
          final keyword = String.fromCharCodes(data.sublist(0, nullIndex));
          if (keyword == 'chara') {
            return String.fromCharCodes(data.sublist(nullIndex + 1));
          }
        }
      } else if (type == 'iTXt') {
        // iTXt: keyword\0compressionFlag\0compressionMethod\0languageTag\0translatedKeyword\0text
        final data = bytes.sublist(dataStart, dataEnd);
        final nullIndex = data.indexOf(0);
        if (nullIndex != -1) {
          final keyword = String.fromCharCodes(data.sublist(0, nullIndex));
          if (keyword == 'chara') {
            // Skip: compressionFlag(1), compressionMethod(1), languageTag\0, translatedKeyword\0
            int pos = nullIndex + 1;
            if (pos + 2 <= data.length) {
              pos += 2; // Skip compression flag and method
              // Skip language tag (null-terminated)
              while (pos < data.length && data[pos] != 0) pos++;
              pos++; // Skip null
              // Skip translated keyword (null-terminated)  
              while (pos < data.length && data[pos] != 0) pos++;
              pos++; // Skip null
              // Rest is the text
              if (pos < data.length) {
                return utf8.decode(data.sublist(pos));
              }
            }
          }
        }
      }

      // Move past data + CRC (4 bytes)
      offset = dataEnd + 4;

      // Stop at IEND
      if (type == 'IEND') break;
    }

    return null;
  }
}
