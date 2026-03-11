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
import 'package:front_porch_ai/services/storage_service.dart';
import 'package:front_porch_ai/services/image_gen_service.dart';

/// Dialog for configuring image generation settings.
class ImageGenSettingsDialog extends StatefulWidget {
  const ImageGenSettingsDialog({super.key});

  @override
  State<ImageGenSettingsDialog> createState() => _ImageGenSettingsDialogState();
}

class _ImageGenSettingsDialogState extends State<ImageGenSettingsDialog> {
  List<ImageModelInfo> _models = [];
  bool _loadingModels = false;
  final _negativePromptController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final storage = Provider.of<StorageService>(context, listen: false);
    _negativePromptController.text = storage.imageGenNegativePrompt;
    _fetchModels();
  }

  @override
  void dispose() {
    _negativePromptController.dispose();
    super.dispose();
  }

  Future<void> _fetchModels() async {
    setState(() => _loadingModels = true);
    final service = Provider.of<ImageGenService>(context, listen: false);
    final models = await service.fetchImageModels();
    if (mounted) {
      setState(() {
        _models = models;
        _loadingModels = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StorageService>(
      builder: (context, storage, _) {
        return Dialog(
          backgroundColor: const Color(0xFF1F2937),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 540,
            constraints: const BoxConstraints(maxHeight: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.white10)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: Colors.purpleAccent),
                      const SizedBox(width: 12),
                      const Text('Image Generation Settings',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Enable toggle
                        SwitchListTile(
                          title: const Text('Enable Image Generation',
                              style: TextStyle(color: Colors.white)),
                          subtitle: const Text(
                              'Add image generation button to chat toolbar',
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 12)),
                          value: storage.imageGenEnabled,
                          activeTrackColor: Colors.purpleAccent,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (val) => storage.setImageGenEnabled(val),
                        ),

                        const SizedBox(height: 8),

                        // Info box — uses existing API credentials
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                storage.remoteApiKey.isNotEmpty
                                    ? Icons.check_circle
                                    : Icons.info_outline,
                                color: storage.remoteApiKey.isNotEmpty
                                    ? Colors.green
                                    : Colors.amber,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  storage.remoteApiKey.isNotEmpty
                                      ? 'Using your remote API credentials for image generation.'
                                      : 'Requires a remote API key — configure one in the Backend settings.',
                                  style: TextStyle(
                                    color: storage.remoteApiKey.isNotEmpty
                                        ? Colors.white38
                                        : Colors.amber,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Image Model selector
                        const Text('Image Model',
                            style: TextStyle(
                                color: Colors.white54,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _models
                                        .any((m) => m.id == storage.imageGenModel)
                                    ? storage.imageGenModel
                                    : null,
                                dropdownColor: const Color(0xFF374151),
                                style: const TextStyle(color: Colors.white),
                                isExpanded: true,
                                menuMaxHeight: 400,
                                decoration: InputDecoration(
                                  hintText: _loadingModels
                                      ? 'Loading models...'
                                      : _models.isEmpty
                                          ? 'No image models found'
                                          : 'Select a model',
                                  hintStyle:
                                      const TextStyle(color: Colors.white30),
                                  filled: true,
                                  fillColor: Colors.black26,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                ),
                                items: _buildGroupedModelItems(),
                                onChanged: (val) {
                                  if (val != null) {
                                    storage.setImageGenModel(val);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: _loadingModels
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.purpleAccent))
                                  : const Icon(Icons.refresh,
                                      color: Colors.white54),
                              tooltip: 'Refresh models',
                              onPressed:
                                  _loadingModels ? null : _fetchModels,
                            ),
                          ],
                        ),

                        // Allow typing a custom model name
                        const SizedBox(height: 8),
                        TextField(
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            hintText:
                                'Or type a model name manually...',
                            hintStyle:
                                const TextStyle(color: Colors.white24),
                            filled: true,
                            fillColor: Colors.black26,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            isDense: true,
                          ),
                          controller: TextEditingController(
                              text: storage.imageGenModel),
                          onSubmitted: (val) {
                            if (val.trim().isNotEmpty) {
                              storage.setImageGenModel(val.trim());
                            }
                          },
                        ),

                        const SizedBox(height: 20),

                        // Image Size selector
                        const Text('Image Size',
                            style: TextStyle(
                                color: Colors.white54,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        _buildSizeSelector(storage),

                        const SizedBox(height: 20),

                        // Default Style
                        const Text('Default Style',
                            style: TextStyle(
                                color: Colors.white54,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: ImageGenService.styleLabels.containsKey(storage.imageGenStyle)
                              ? storage.imageGenStyle
                              : 'photorealistic',
                          dropdownColor: const Color(0xFF374151),
                          style: const TextStyle(color: Colors.white),
                          isExpanded: true,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.black26,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                          items: ImageGenService.styleLabels.entries.map((e) {
                            return DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              storage.setImageGenStyle(val);
                            }
                          },
                        ),
                        const SizedBox(height: 6),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            'Pre-selected when generating images. Can be changed per generation.',
                            style: TextStyle(color: Colors.white24, fontSize: 10),
                          ),
                        ),

                        const SizedBox(height: 20),
                        const Text('Default Negative Prompt',
                            style: TextStyle(
                                color: Colors.white54,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _negativePromptController,
                          maxLines: 2,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            hintText:
                                'e.g. blurry, low quality, watermark, text',
                            hintStyle:
                                const TextStyle(color: Colors.white24),
                            filled: true,
                            fillColor: Colors.black26,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                          onChanged: (val) =>
                              storage.setImageGenNegativePrompt(val),
                        ),
                        const SizedBox(height: 6),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            'Applied automatically to all generations. Leave empty to skip.',
                            style:
                                TextStyle(color: Colors.white24, fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build dropdown items grouped by free (subscription-included) and paid.
  List<DropdownMenuItem<String>> _buildGroupedModelItems() {
    final freeModels = _models.where((m) => !m.isPaid).toList();
    final paidModels = _models.where((m) => m.isPaid).toList();
    final items = <DropdownMenuItem<String>>[];

    // ── Free models section ──
    if (freeModels.isNotEmpty) {
      items.add(DropdownMenuItem<String>(
        enabled: false,
        value: '__header_free__',
        child: Text('── Included with Pro Subscription ──',
            style: TextStyle(
                color: Colors.green.shade300,
                fontSize: 11,
                fontWeight: FontWeight.bold)),
      ));
      for (final m in freeModels) {
        items.add(DropdownMenuItem(
          value: m.id,
          child: Row(
            children: [
              const Icon(Icons.check_circle, size: 14, color: Colors.green),
              const SizedBox(width: 8),
              Expanded(
                child: Text(m.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white)),
              ),
              Text('Free', style: TextStyle(color: Colors.green.shade300, fontSize: 10)),
            ],
          ),
        ));
      }
    }

    // ── Paid models section ──
    if (paidModels.isNotEmpty) {
      items.add(DropdownMenuItem<String>(
        enabled: false,
        value: '__header_paid__',
        child: Text('── Pay Per Prompt ──',
            style: TextStyle(
                color: Colors.amber.shade300,
                fontSize: 11,
                fontWeight: FontWeight.bold)),
      ));
      for (final m in paidModels) {
        items.add(DropdownMenuItem(
          value: m.id,
          child: Row(
            children: [
              const Icon(Icons.attach_money, size: 14, color: Colors.amber),
              const SizedBox(width: 8),
              Expanded(
                child: Text(m.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white)),
              ),
              Text('Paid', style: TextStyle(color: Colors.amber.shade300, fontSize: 10)),
            ],
          ),
        ));
      }
    }

    return items;
  }

  /// Size selector — chip-style buttons.
  Widget _buildSizeSelector(StorageService storage) {
    const sizes = ['512x512', '1024x1024', '1024x1792', '1792x1024'];
    const labels = ['512²', '1024²', '1024×1792', '1792×1024'];
    const descriptions = ['Small', 'Square', 'Portrait', 'Landscape'];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(sizes.length, (i) {
        final selected = storage.imageGenSize == sizes[i];
        return GestureDetector(
          onTap: () => storage.setImageGenSize(sizes[i]),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? Colors.purpleAccent.withValues(alpha: 0.3)
                  : Colors.black26,
              borderRadius: BorderRadius.circular(8),
              border: selected
                  ? Border.all(color: Colors.purpleAccent, width: 1)
                  : Border.all(color: Colors.white10, width: 1),
            ),
            child: Column(
              children: [
                Text(labels[i],
                    style: TextStyle(
                      color: selected ? Colors.purpleAccent : Colors.white54,
                      fontSize: 12,
                      fontWeight:
                          selected ? FontWeight.bold : FontWeight.normal,
                    )),
                const SizedBox(height: 2),
                Text(descriptions[i],
                    style: TextStyle(
                      color: selected ? Colors.white38 : Colors.white24,
                      fontSize: 9,
                    )),
              ],
            ),
          ),
        );
      }),
    );
  }
}
