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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:front_porch_ai/services/caption/local_caption_service.dart';
import 'package:front_porch_ai/services/storage_service.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';

/// Settings card for Photo Understanding — the optional offline captioner
/// (SmolVLM-500M via in-process ONNX) that describes chat photo attachments
/// to text-only models. Drives LocalCaptionService's download/delete and
/// mirrors its live state (not installed / downloading / installed).
class PhotoUnderstandingCard extends StatelessWidget {
  const PhotoUnderstandingCard({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = Provider.of<StorageService>(context, listen: false);
    final service = LocalCaptionService.instance..configure(storage.rootPath);
    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.cardOf(context),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.image_search,
                    color: AppColors.relationshipAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Photo Understanding (offline)',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          service.isInstalled
                              ? 'Installed — photos you attach are described '
                                    'to models that can\'t see images.'
                              : 'When your model can\'t see images, a small '
                                    'offline vision model can describe '
                                    'attached photos so the character still '
                                    'gets the picture. One-time download '
                                    '(${LocalCaptionService.downloadSizeLabel}), '
                                    'runs fully on your machine.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (service.isDownloading)
                    TextButton(
                      onPressed: service.cancelDownload,
                      child: const Text('Cancel'),
                    )
                  else if (service.isInstalled)
                    TextButton.icon(
                      onPressed: service.isCaptioning
                          ? null
                          : () => service.deleteModel(),
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Remove'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: () => service.download(),
                      icon: const Icon(Icons.download, size: 16),
                      label: Text(
                        'Download ${LocalCaptionService.downloadSizeLabel}',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.userBubble,
                        foregroundColor: AppColors.textPrimary(context),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                ],
              ),
              if (service.isDownloading) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: service.downloadProgress,
                    minHeight: 6,
                    backgroundColor: AppColors.surfaceContainerOf(context),
                    color: AppColors.relationshipAccent,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Downloading… '
                  '${(service.downloadProgress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary(context),
                  ),
                ),
              ],
              if (service.lastError != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Download failed: ${service.lastError}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.orangeAccent,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
