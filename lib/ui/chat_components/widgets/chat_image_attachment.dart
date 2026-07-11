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

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import 'package:front_porch_ai/ui/theme/app_colors.dart';
import 'package:front_porch_ai/utils/picker_prefs.dart';

/// Pick a photo to attach to the next chat message and normalize it for the
/// vision transport: long side capped at 1024 (the avatar-import precedent —
/// plenty for any projector, keeps the base64 payload and stored copy small)
/// and re-encoded as PNG so the `data:image/png` content part is truthful for
/// every source format. Decode/resize runs off the UI isolate — a 12 MP phone
/// photo would jank the composer otherwise. Returns null when the user
/// cancels or the file can't be decoded as an image.
Future<Uint8List?> pickChatImageAttachment() async {
  final result = await PickerPrefs.pickFiles(
    category: PickerPrefs.catImage,
    dialogTitle: 'Attach a photo',
    type: FileType.image,
    withData: true,
  );
  final raw = result?.files.firstOrNull?.bytes;
  if (raw == null) return null;
  return compute(_downscaleToPng, raw);
}

/// Isolate body for [pickChatImageAttachment]: decode → cap long side at
/// 1024 → PNG. Null when the bytes aren't a decodable image.
Uint8List? _downscaleToPng(Uint8List raw) {
  final decoded = img.decodeImage(raw);
  if (decoded == null) return null;
  final longSide = decoded.width >= decoded.height
      ? decoded.width
      : decoded.height;
  final resized = longSide <= 1024
      ? decoded
      : img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? 1024 : null,
          height: decoded.width >= decoded.height ? null : 1024,
          interpolation: img.Interpolation.cubic,
        );
  return img.encodePng(resized);
}

/// The pending-attachment strip shown above the chat composer: thumbnail,
/// label, a remove ✕, and — when the capability resolver says the active
/// model can't see images ([visionOk] false) — either an informational note
/// that the offline Photo Understanding fallback will describe the photo
/// ([fallbackAvailable]), or a non-blocking warning that the character will
/// reply blind. Deliberately never blocks the send: capability detection
/// can't interrogate externally-started servers, and KoboldCpp degrades
/// gracefully by ignoring the image.
class PendingImageChip extends StatelessWidget {
  const PendingImageChip({
    super.key,
    required this.bytes,
    required this.visionOk,
    required this.onRemove,
    this.fallbackAvailable = false,
  });

  /// The prepared (downscaled PNG) attachment bytes, used for the thumbnail.
  final Uint8List bytes;

  /// Vision verdict for the active model: true = can see, false = blind,
  /// null = still resolving (no warning shown while unknown).
  final bool? visionOk;

  /// Whether the offline captioner (Photo Understanding) is installed and
  /// will describe the photo to a blind model.
  final bool fallbackAvailable;

  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.surfaceContainerOf(context),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              bytes,
              height: 56,
              width: 56,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Photo attached',
                  style: TextStyle(
                    color: AppColors.textSecondary(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (visionOk == false) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        fallbackAvailable
                            ? Icons.description_outlined
                            : Icons.visibility_off,
                        size: 13,
                        color: fallbackAvailable
                            ? Colors.tealAccent
                            : Colors.orangeAccent,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          fallbackAvailable
                              ? "Model can't see images — a detailed text "
                                    'description will be sent instead.'
                              : "Current model can't see images — the "
                                    'character will reply without seeing it.',
                          style: TextStyle(
                            color: fallbackAvailable
                                ? Colors.tealAccent
                                : Colors.orangeAccent,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              size: 18,
              color: AppColors.iconSecondary(context),
            ),
            tooltip: 'Remove photo',
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
