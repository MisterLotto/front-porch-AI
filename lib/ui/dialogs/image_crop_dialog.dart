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

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:front_porch_ai/ui/theme/app_colors.dart';
import 'package:front_porch_ai/utils/utils.dart';

/// Interactive image crop — blank-slate rewrite (2026-08-14) replacing the
/// crop_your_image package after the Discord report: the package's
/// image-must-cover-the-crop model produced the "zoomed in by default" fit,
/// the zoom-out clamp, and the Pad Canvas workaround that silently cropped
/// the un-padded original.
///
/// The new model has NO zoom: the whole image is always visible
/// (contain-fit with a fill margin around it), and the crop box may be
/// dragged PAST the image edges — the overhang previews, and saves as, the
/// crop fill background. All geometry lives in [crop_geometry.dart] as pure
/// source-space math; this widget is only paint + gestures.
///
/// Returns the cropped PNG bytes on "Crop & Save", or null on cancel.
class ImageCropDialog extends StatefulWidget {
  /// The raw image bytes to crop.
  final Uint8List imageBytes;

  const ImageCropDialog({super.key, required this.imageBytes});

  /// Show the dialog and return cropped bytes, or null if cancelled.
  static Future<Uint8List?> show(
    BuildContext context, {
    required Uint8List imageBytes,
  }) {
    return showDialog<Uint8List?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ImageCropDialog(imageBytes: imageBytes),
    );
  }

  @override
  State<ImageCropDialog> createState() => _ImageCropDialogState();
}

class _ImageCropDialogState extends State<ImageCropDialog> {
  /// Fraction of the viewport's shortest side left as fill margin around the
  /// image — the room the crop box has to extend past the edges.
  static const _marginFraction = 0.15;
  static const _grabRadius = 14.0;

  Size? _imageSize; // decoded dimensions; null while decoding
  Rect? _cropSrc; // crop rect in SOURCE pixels (may extend beyond the image)
  CropHandle? _activeHandle;
  CropHandle? _hoverHandle;
  bool _isCropping = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _decodeDimensions();
  }

  Future<void> _decodeDimensions() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.imageBytes);
      final frame = await codec.getNextFrame();
      final size = Size(
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      );
      frame.image.dispose();
      codec.dispose();
      if (!mounted) return;
      setState(() {
        _imageSize = size;
        _cropSrc = Offset.zero & size;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not read this image: $e');
    }
  }

  Future<void> _onCropAndSave() async {
    final crop = _cropSrc;
    if (crop == null || _isCropping) return;
    setState(() {
      _isCropping = true;
      _error = null;
    });
    final left = crop.left.round();
    final top = crop.top.round();
    final width = (crop.right.round() - left).clamp(1, 1 << 16);
    final height = (crop.bottom.round() - top).clamp(1, 1 << 16);
    try {
      final bytes = await compute(cropCompositeSync, <Object>[
        widget.imageBytes,
        left,
        top,
        width,
        height,
      ]);
      if (!mounted) return;
      Navigator.of(context).pop(bytes);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCropping = false;
        _error = 'Crop failed: $e';
      });
    }
  }

  // ── Geometry for the current layout ───────────────────────────────────────

  ({Rect imageVp, Rect worldSrc, double scale}) _layout(Size viewportSize) {
    final viewport = Offset.zero & viewportSize;
    final inset = _marginFraction * viewportSize.shortestSide;
    final imageVp = containFitRect(_imageSize!, viewport.deflate(inset));
    final scale = imageVp.width / _imageSize!.width;
    // The whole visible stage, expressed in source pixels — the crop box can
    // roam anywhere the user can see (WYSIWYG: nothing off-screen is
    // capturable, everything on-screen is).
    final worldSrc = Rect.fromLTRB(
      (viewport.left - imageVp.left) / scale,
      (viewport.top - imageVp.top) / scale,
      (viewport.right - imageVp.left) / scale,
      (viewport.bottom - imageVp.top) / scale,
    );
    return (imageVp: imageVp, worldSrc: worldSrc, scale: scale);
  }

  Rect _srcToVp(Rect src, Rect imageVp, double scale) => Rect.fromLTWH(
    imageVp.left + src.left * scale,
    imageVp.top + src.top * scale,
    src.width * scale,
    src.height * scale,
  );

  MouseCursor _cursorFor(CropHandle? handle) => switch (handle) {
    CropHandle.topLeft ||
    CropHandle.bottomRight => SystemMouseCursors.resizeUpLeftDownRight,
    CropHandle.topRight ||
    CropHandle.bottomLeft => SystemMouseCursors.resizeUpRightDownLeft,
    CropHandle.top || CropHandle.bottom => SystemMouseCursors.resizeUpDown,
    CropHandle.left || CropHandle.right => SystemMouseCursors.resizeLeftRight,
    CropHandle.move => SystemMouseCursors.move,
    null => SystemMouseCursors.basic,
  };

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = (screenSize.width * 0.7).clamp(400.0, 800.0);
    final dialogHeight = (screenSize.height * 0.8).clamp(500.0, 900.0);

    return Dialog(
      backgroundColor: AppColors.surfaceOf(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.borderOf(context)),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.crop,
                    color: AppColors.porchAmberOf(context),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Crop Your Image',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: AppColors.iconSecondary(context),
                    ),
                    onPressed: () => Navigator.of(context).pop(null),
                  ),
                ],
              ),
            ),

            // Subtitle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(
                'Drag the box or pull its corners. You can pull past the '
                'picture\'s edges to add background around it — what you see '
                'is exactly what gets saved.',
                style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 13,
                ),
              ),
            ),

            // Crop stage
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderOf(context)),
                ),
                clipBehavior: Clip.antiAlias,
                child: _imageSize == null
                    ? Center(
                        child: _error != null
                            ? Padding(
                                padding: const EdgeInsets.all(24),
                                child: SelectableText(
                                  _error!,
                                  style: TextStyle(
                                    color: AppColors.textSecondary(context),
                                  ),
                                ),
                              )
                            : CircularProgressIndicator(
                                color: AppColors.porchAmberOf(context),
                              ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final layout = _layout(constraints.biggest);
                          final cropVp = _srcToVp(
                            _cropSrc!,
                            layout.imageVp,
                            layout.scale,
                          );
                          return MouseRegion(
                            cursor: _cursorFor(_activeHandle ?? _hoverHandle),
                            onHover: (e) {
                              final h = hitTestCropHandle(
                                e.localPosition,
                                cropVp,
                                _grabRadius,
                              );
                              if (h != _hoverHandle) {
                                setState(() => _hoverHandle = h);
                              }
                            },
                            child: GestureDetector(
                              key: const ValueKey('crop_stage'),
                              behavior: HitTestBehavior.opaque,
                              onPanStart: (d) => setState(() {
                                _activeHandle = hitTestCropHandle(
                                  d.localPosition,
                                  cropVp,
                                  _grabRadius,
                                );
                              }),
                              onPanUpdate: (d) {
                                final handle = _activeHandle;
                                if (handle == null) return;
                                setState(() {
                                  _cropSrc = applyCropDrag(
                                    _cropSrc!,
                                    handle,
                                    d.delta / layout.scale,
                                    world: layout.worldSrc,
                                    // Never below 16 source px, and never so
                                    // small the box is ungrabbable on screen.
                                    minSize: 16.0 > 24 / layout.scale
                                        ? 16.0
                                        : 24 / layout.scale,
                                  );
                                });
                              },
                              onPanEnd: (_) =>
                                  setState(() => _activeHandle = null),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  // The fill margin — this IS the color the
                                  // saved background will be (see
                                  // crop_geometry.dart: image data, not
                                  // theme chrome).
                                  const ColoredBox(
                                    color: Color.fromARGB(
                                      255,
                                      cropFillR,
                                      cropFillG,
                                      cropFillB,
                                    ),
                                  ),
                                  Positioned.fromRect(
                                    rect: layout.imageVp,
                                    child: Image.memory(
                                      widget.imageBytes,
                                      fit: BoxFit.fill,
                                      gaplessPlayback: true,
                                      filterQuality: FilterQuality.medium,
                                    ),
                                  ),
                                  IgnorePointer(
                                    child: CustomPaint(
                                      painter: _CropOverlayPainter(
                                        cropVp: cropVp,
                                        accent: AppColors.porchAmberOf(context),
                                        scrim: Colors.black.withValues(
                                          alpha: 0.55,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),

            if (_error != null && _imageSize != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SelectableText(
                  _error!,
                  style: TextStyle(
                    color: AppColors.textSecondary(context),
                    fontSize: 12,
                  ),
                ),
              ),

            // Buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.borderOf(context)),
                ),
              ),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: (_isCropping || _imageSize == null)
                        ? null
                        : () => setState(
                            () => _cropSrc = Offset.zero & _imageSize!,
                          ),
                    icon: Icon(
                      Icons.restart_alt,
                      size: 16,
                      color: AppColors.porchAmberOf(context),
                    ),
                    label: Text(
                      'Reset',
                      style: TextStyle(color: AppColors.porchAmberOf(context)),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _isCropping
                        ? null
                        : () => Navigator.of(context).pop(null),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: AppColors.textSecondary(context)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: (_isCropping || _imageSize == null)
                        ? null
                        : _onCropAndSave,
                    icon: _isCropping
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.onChaosAccent,
                            ),
                          )
                        : const Icon(Icons.crop_sharp, size: 18),
                    label: Text(_isCropping ? 'Cropping...' : 'Crop & Save'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.porchAmberOf(context),
                      foregroundColor: AppColors.onChaosAccent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
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

/// Scrim outside the crop box + amber border, thirds guides, and the eight
/// grab handles.
class _CropOverlayPainter extends CustomPainter {
  const _CropOverlayPainter({
    required this.cropVp,
    required this.accent,
    required this.scrim,
  });

  final Rect cropVp;
  final Color accent;
  final Color scrim;

  @override
  void paint(Canvas canvas, Size size) {
    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addRect(cropVp),
    );
    canvas.drawPath(outside, Paint()..color = scrim);

    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = accent;
    canvas.drawRect(cropVp, border);

    // Rule-of-thirds guides.
    final guide = Paint()
      ..strokeWidth = 0.75
      ..color = accent.withValues(alpha: 0.35);
    for (var i = 1; i <= 2; i++) {
      final x = cropVp.left + cropVp.width * i / 3;
      final y = cropVp.top + cropVp.height * i / 3;
      canvas.drawLine(Offset(x, cropVp.top), Offset(x, cropVp.bottom), guide);
      canvas.drawLine(Offset(cropVp.left, y), Offset(cropVp.right, y), guide);
    }

    final dot = Paint()..color = accent;
    for (final c in [
      cropVp.topLeft,
      cropVp.topCenter,
      cropVp.topRight,
      cropVp.centerLeft,
      cropVp.centerRight,
      cropVp.bottomLeft,
      cropVp.bottomCenter,
      cropVp.bottomRight,
    ]) {
      canvas.drawCircle(c, 5, dot);
    }
  }

  @override
  bool shouldRepaint(_CropOverlayPainter old) =>
      old.cropVp != cropVp || old.accent != accent || old.scrim != scrim;
}
