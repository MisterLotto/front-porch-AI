import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:kobold_character_card_manager/models/character_card.dart';
import 'package:kobold_character_card_manager/services/v2_card_service.dart';
import 'package:kobold_character_card_manager/providers/app_state.dart';
import 'package:kobold_character_card_manager/services/character_repository.dart';

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
  String? _imagePath;

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
        final directory = await getApplicationDocumentsDirectory();
        final charDir = Directory('${directory.path}/KoboldManager/Characters');
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
        );

        final service = V2CardService();
        await service.saveCardAsPng(card, outputPath, _imagePath);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Character saved to $outputPath')),
          );
          // Refresh repository
          Provider.of<CharacterRepository>(context, listen: false).loadCharacters();
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

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _personalityController.dispose();
    _scenarioController.dispose();
    _firstMessageController.dispose();
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
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
                          color: Colors.white.withOpacity(0.05),
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
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _personalityController,
                      label: 'Personality',
                      hint: 'Mind, traits, and behavior...',
                      maxLines: 3,
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
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Colors.white70,
          ),
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
            fillColor: Colors.white.withOpacity(0.05),
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
