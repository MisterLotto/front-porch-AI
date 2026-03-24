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

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:crop_your_image/crop_your_image.dart';

/// A reusable dialog that lets the user interactively crop an image.
///
/// Returns the cropped image bytes (`Uint8List`) on "Crop & Save",
/// or `null` if the user cancels.
class ImageCropDialog extends StatefulWidget {
  /// The raw image bytes to crop.
  final Uint8List imageBytes;

  /// Aspect ratio width (default 2 for a 2:3 card ratio).
  final double aspectRatioWidth;

  /// Aspect ratio height (default 3 for a 2:3 card ratio).
  final double aspectRatioHeight;

  const ImageCropDialog({
    super.key,
    required this.imageBytes,
    this.aspectRatioWidth = 2,
    this.aspectRatioHeight = 3,
  });

  /// Show the dialog and return cropped bytes, or null if cancelled.
  static Future<Uint8List?> show(
    BuildContext context, {
    required Uint8List imageBytes,
    double aspectRatioWidth = 2,
    double aspectRatioHeight = 3,
  }) {
    return showDialog<Uint8List?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ImageCropDialog(
        imageBytes: imageBytes,
        aspectRatioWidth: aspectRatioWidth,
        aspectRatioHeight: aspectRatioHeight,
      ),
    );
  }

  @override
  State<ImageCropDialog> createState() => _ImageCropDialogState();
}

class _ImageCropDialogState extends State<ImageCropDialog> {
  final _cropController = CropController();
  bool _isCropping = false;

  void _onCropAndSave() {
    setState(() => _isCropping = true);
    _cropController.crop();
  }

  void _onCropped(CropResult result) {
    // Default to empty bytes in case of failure.
    Uint8List bytes = Uint8List(0);
    // If the crop was successful, extract the image bytes.
    if (result is CropSuccess) {
      bytes = result.croppedImage;
    }
    if (mounted) {
      Navigator.of(context).pop(bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = (screenSize.width * 0.7).clamp(400.0, 800.0);
    final dialogHeight = (screenSize.height * 0.8).clamp(500.0, 900.0);

    return Dialog(
      backgroundColor: const Color(0xFF111827),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white10)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.crop, color: Colors.blueAccent, size: 22),
                  const SizedBox(width: 10),
                  const Text(
                    'Crop Your Image',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.of(context).pop(null),
                  ),
                ],
              ),
            ),

            // Subtitle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(
                'Drag to reposition the crop area. The image will be saved at the selected region.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 13,
                ),
              ),
            ),

            // Crop area
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                clipBehavior: Clip.antiAlias,
                child: Crop(
                  controller: _cropController,
                  image: widget.imageBytes,
                  aspectRatio: widget.aspectRatioWidth / widget.aspectRatioHeight,
                  onCropped: _onCropped,
                  baseColor: const Color(0xFF111827),
                  maskColor: Colors.black.withValues(alpha: 0.6),
                  cornerDotBuilder: (size, edgeAlignment) => DotControl(
                    color: Colors.blueAccent,
                  ),
                  interactive: true,
                  fixCropRect: false,
                ),
              ),
            ),

            // Buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white10)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isCropping ? null : () => Navigator.of(context).pop(null),
                    child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _isCropping ? null : _onCropAndSave,
                    icon: _isCropping
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.crop_sharp, size: 18),
                    label: Text(_isCropping ? 'Cropping...' : 'Crop & Save'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
