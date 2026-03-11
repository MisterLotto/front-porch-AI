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

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:front_porch_ai/models/character_card.dart';
import 'package:front_porch_ai/services/v2_card_service.dart';
import 'package:front_porch_ai/services/storage_service.dart';
import 'package:front_porch_ai/providers/app_state.dart';
import 'package:front_porch_ai/services/character_repository.dart';

class CreateCharacterPage extends StatefulWidget {
  const CreateCharacterPage({super.key});

  @override
  State<CreateCharacterPage> createState() => _CreateCharacterPageState();
}

class _CreateCharacterPageState extends State<CreateCharacterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _personalityController = TextEditingController();
  final _scenarioController = TextEditingController();
  final _firstMessageController = TextEditingController();
  final _mesExampleController = TextEditingController();
  final _systemPromptController = TextEditingController();
  final _postHistoryController = TextEditingController();
  final List<TextEditingController> _altGreetingControllers = [];
  String? _imagePath;

  int _estimatedTokens = 0;

  @override
  void initState() {
    super.initState();
    // Listen to all controllers for token count updates
    for (final c in [
      _nameController,
      _descriptionController,
      _personalityController,
      _scenarioController,
      _firstMessageController,
      _mesExampleController,
      _systemPromptController,
      _postHistoryController,
    ]) {
      c.addListener(_updateTokenCount);
    }
  }

  void _updateTokenCount() {
    int totalChars = _nameController.text.length +
        _descriptionController.text.length +
        _personalityController.text.length +
        _scenarioController.text.length +
        _firstMessageController.text.length +
        _mesExampleController.text.length +
        _systemPromptController.text.length +
        _postHistoryController.text.length;
    for (final c in _altGreetingControllers) {
      totalChars += c.text.length;
    }
    setState(() {
      _estimatedTokens = (totalChars / 4).ceil();
    });
  }

  Color _tokenCountColor() {
    if (_estimatedTokens >= 2000) return Colors.redAccent;
    if (_estimatedTokens >= 1500) return Colors.amber;
    return Colors.white54;
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _imagePath = result.files.single.path;
      });
    }
  }

  Future<void> _saveCharacter() async {
    if (_formKey.currentState!.validate()) {
      try {
        final storageService = Provider.of<StorageService>(context, listen: false);
        final charDir = storageService.charactersDir;
        if (!await charDir.exists()) {
          await charDir.create(recursive: true);
        }

        String filename = '${_nameController.text.replaceAll(RegExp(r'[<>:"/\\|?*]'), '')}.png';
        String outputPath = '${charDir.path}/$filename';

        // Check if file exists to avoid overwrite (simple check)
        int counter = 1;
        while (await File(outputPath).exists()) {
           outputPath = '${charDir.path}/${filename.substring(0, filename.length - 4)}_$counter.png';
           counter++;
        }

        final card = CharacterCard(
          name: _nameController.text,
          description: _descriptionController.text,
          personality: _personalityController.text,
          scenario: _scenarioController.text,
          firstMessage: _firstMessageController.text,
          mesExample: _mesExampleController.text,
          systemPrompt: _systemPromptController.text,
          postHistoryInstructions: _postHistoryController.text,
          alternateGreetings: _altGreetingControllers
              .map((c) => c.text)
              .where((t) => t.isNotEmpty)
              .toList(),
        );

        final service = V2CardService();
        await service.saveCardAsPng(card, outputPath, _imagePath);

        if (mounted) {
          // Import the saved PNG into the SQL database
          final charRepo = Provider.of<CharacterRepository>(context, listen: false);
          await charRepo.importCharacter(File(outputPath));

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Character "${card.name}" created!')),
          );
          // Go to home
          Provider.of<AppState>(context, listen: false).setIndex(0);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving character: $e')),
          );
        }
      }
    }
  }

  void _openExpandedEditor(String title, TextEditingController controller) {
    final expandedController = TextEditingController(text: controller.text);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.edit_note, color: Colors.white70, size: 22),
                    const SizedBox(width: 8),
                    Text(title, style: const TextStyle(
                      color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Done'),
                      style: TextButton.styleFrom(foregroundColor: Colors.greenAccent),
                      onPressed: () {
                        controller.text = expandedController.text;
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.white12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: expandedController,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
                    decoration: InputDecoration(
                      hintText: title == 'Example Dialogues'
                          ? '(Examples of chat dialog. Begin each example with <START> on a new line.)'
                          : 'The character\'s opening line...',
                      hintStyle: const TextStyle(color: Colors.white24),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _personalityController.dispose();
    _scenarioController.dispose();
    _firstMessageController.dispose();
    _mesExampleController.dispose();
    for (var c in _altGreetingControllers) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Create New Character'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 80),
            child: Form(
              key: _formKey,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column: Image Picker
                  SizedBox(
                    width: 300,
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            width: 300,
                            height: 450,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white24),
                              image: _imagePath != null
                                  ? DecorationImage(
                                      image: FileImage(File(_imagePath!)),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: _imagePath == null
                                ? const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_photo_alternate_outlined,
                                          size: 48, color: Colors.white54),
                                      SizedBox(height: 16),
                                      Text(
                                        'Click to upload avatar',
                                        style: TextStyle(color: Colors.white54),
                                      ),
                                    ],
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _saveCharacter,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Save Character'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 32),
                  // Right Column: Form Fields
                  Expanded(
                    child: Column(
                      children: [
                        _buildTextField(
                          controller: _nameController,
                          label: 'Name',
                          hint: 'e.g. Seraphina',
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _descriptionController,
                          label: 'Description',
                          hint: 'Physical description and traits...',
                          maxLines: 3,
                          expandable: true,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _personalityController,
                          label: 'Personality',
                          hint: 'Mind, traits, and behavior...',
                          maxLines: 3,
                          expandable: true,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _scenarioController,
                          label: 'Scenario',
                          hint: 'Current situation and context...',
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _firstMessageController,
                          label: 'First Message',
                          hint: 'The character\'s opening line...',
                          maxLines: 5,
                          expandable: true,
                        ),
                        const SizedBox(height: 24),
                        // Alternate greetings section
                        Row(
                          children: [
                            const Text('Alternate Greetings', 
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white70)),
                            const Spacer(),
                            TextButton.icon(
                              icon: const Icon(Icons.add, size: 16, color: Colors.white70),
                              label: const Text('Add', style: TextStyle(color: Colors.white70)),
                              onPressed: () {
                                setState(() {
                                  final c = TextEditingController();
                                  c.addListener(_updateTokenCount);
                                  _altGreetingControllers.add(c);
                                });
                              },
                            ),
                          ],
                        ),
                        ..._altGreetingControllers.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final controller = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    controller: controller,
                                    label: 'Greeting ${idx + 2}',
                                    hint: 'Another opening line...',
                                    maxLines: 4,
                                    expandable: true,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 24),
                                  tooltip: 'Remove this greeting',
                                  padding: const EdgeInsets.only(top: 32),
                                  onPressed: () {
                                    setState(() {
                                      _altGreetingControllers[idx].dispose();
                                      _altGreetingControllers.removeAt(idx);
                                      _updateTokenCount();
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 24),
                        // Example Dialogues section
                        _buildTextField(
                          controller: _mesExampleController,
                          label: 'Example Dialogues',
                          hint: '(Examples of chat dialog. Begin each example with <START> on a new line.)',
                          maxLines: 6,
                          expandable: true,
                        ),
                        const SizedBox(height: 24),
                        // System Prompt section
                        _buildTextField(
                          controller: _systemPromptController,
                          label: 'System Prompt (optional)',
                          hint: 'Custom system prompt for this character. If blank, the global system prompt is used.',
                          maxLines: 4,
                          expandable: true,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _postHistoryController,
                          label: 'Post-History Instructions (optional)',
                          hint: 'Instructions injected after chat history (jailbreak/reminder).',
                          maxLines: 3,
                          expandable: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Token counter - bottom right
          Positioned(
            right: 24,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1a1a2e).withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _tokenCountColor().withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.token_outlined, size: 16, color: _tokenCountColor()),
                  const SizedBox(width: 6),
                  Text(
                    '$_estimatedTokens tokens',
                    style: TextStyle(
                      color: _tokenCountColor(),
                      fontSize: 13,
                      fontWeight: _estimatedTokens >= 1500 ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    String? Function(String?)? validator,
    bool expandable = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            if (expandable) ...[
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _openExpandedEditor(label, controller),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(Icons.open_in_full, size: 16, color: Colors.white38),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white24),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
