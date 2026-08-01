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

import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/utils/utils.dart';

/// Service for reading and writing Front Porch Group Cards (single PNG containing
/// multiple full character definitions + group orchestration settings).
///
/// The on-disk format uses a dedicated `fpa_group` tEXt chunk (base64-encoded JSON)
/// so that the file is completely invisible to SillyTavern and other standard
/// character-card importers. This is intentional for safety and to establish a
/// clean new standard.
class GroupCardService {
  static const String groupChunkKeyword = 'fpa_group';
  static const String specName = 'front_porch_group_card';
  static const String specVersion = '1.0';

  /// Saves a GroupCard as a PNG with embedded metadata.
  ///
  /// If [sourceImagePath] is provided, that image is used as the visual cover.
  /// Otherwise a collage is automatically generated from the member avatars
  /// (the recommended "magic" path for group exports).
  Future<void> saveGroupCardAsPng(
    GroupCard groupCard,
    String outputPath, {
    String? sourceImagePath,
  }) async {
    img.Image? visual;

    if (sourceImagePath != null) {
      try {
        final bytes = await File(sourceImagePath).readAsBytes();
        visual = img.decodeImage(bytes);
      } catch (_) {}
    }

    if (visual == null) {
      // Auto-generate a nice collage from the member avatars
      final avatarPaths = groupCard.members
          .map((c) => c.imagePath)
          .whereType<String>()
          .where((p) => p.isNotEmpty)
          .toList();

      if (avatarPaths.isNotEmpty) {
        final collageBytes = await createGroupAvatarCollage(avatarPaths);
        visual = img.decodePng(collageBytes) ?? img.decodeImage(collageBytes);
      }
    }

    // Build the portable JSON payload
    final payload = groupCard.toJson();
    payload['spec'] = specName;
    payload['spec_version'] = specVersion;

    final jsonString = jsonEncode(payload);
    final base64Data = base64Encode(utf8.encode(jsonString));

    // Encode the image with the custom chunk
    final encoded = PngMetadataUtils.encodeWithTextChunk(
      visual ?? img.Image(width: 512, height: 512),
      groupChunkKeyword,
      base64Data,
    );

    await File(outputPath).writeAsBytes(encoded);
  }

  /// Loads a GroupCard from a PNG file.
  Future<GroupCard?> loadGroupCardFromPng(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final base64Data = PngMetadataUtils.extractTextChunk(
        bytes,
        groupChunkKeyword,
      );

      if (base64Data == null) return null;

      final jsonString = utf8.decode(base64Decode(base64Data));
      final json = jsonDecode(jsonString) as Map<String, dynamic>;

      return GroupCard.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  /// Convenience alias matching the naming style of V2CardService.readCard.
  Future<GroupCard?> readGroupCard(String path) => loadGroupCardFromPng(path);
}
