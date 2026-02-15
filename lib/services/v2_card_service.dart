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
    final avatar = img.decodePng(bytes);

    if (avatar == null || avatar.textData == null || !avatar.textData!.containsKey('chara')) {
      return null;
    }

    try {
      final base64Str = avatar.textData!['chara']!;
      final jsonStr = utf8.decode(base64Decode(base64Str));
      final jsonMap = jsonDecode(jsonStr);

      return CharacterCard(
        name: jsonMap['name'] ?? '',
        description: jsonMap['description'] ?? '',
        personality: jsonMap['personality'] ?? '',
        scenario: jsonMap['scenario'] ?? '',
        firstMessage: jsonMap['first_mes'] ?? '',
        lorebook: jsonMap['character_book'] != null 
          ? Lorebook.fromJson(jsonMap['character_book']) 
          : null,
        worldNames: jsonMap['world_names'] != null 
          ? List<String>.from(jsonMap['world_names']) 
          : const [],
        imagePath: path,
      );
    } catch (e) {
      print('Error parsing card data: $e');
      return null;
    }
  }
}
