import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:kobold_character_card_manager/services/user_persona_service.dart';

class UserPersonaDialog extends StatefulWidget {
  const UserPersonaDialog({super.key});

  @override
  State<UserPersonaDialog> createState() => _UserPersonaDialogState();
}

class _UserPersonaDialogState extends State<UserPersonaDialog> {
  bool _isEditing = false;
  UserPersona? _editingPersona;
  
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  String? _avatarPath;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _startEditing(UserPersona? persona) {
    setState(() {
      _isEditing = true;
      _editingPersona = persona;
      _nameController.text = persona?.name ?? '';
      _descriptionController.text = persona?.description ?? '';
      _avatarPath = persona?.avatarPath;
    });
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _editingPersona = null;
      _nameController.clear();
      _descriptionController.clear();
      _avatarPath = null;
    });
  }

  Future<void> _pickAvatar() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _avatarPath = result.files.single.path;
      });
    }
  }

  Future<void> _savePersona() async {
    if (_formKey.currentState!.validate()) {
      final service = Provider.of<UserPersonaService>(context, listen: false);
      
      if (_editingPersona != null) {
        // Update
        final updated = _editingPersona!.copyWith(
          name: _nameController.text,
          description: _descriptionController.text,
          avatarPath: _avatarPath,
        );
        await service.updatePersona(updated);
      } else {
        // Create
        await service.createPersona(
          _nameController.text,
          _descriptionController.text,
          '', // Persona text unused for now? Or maybe add a field later.
          _avatarPath,
        );
      }
      
      _cancelEditing();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1F2937),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        height: 500,
        padding: const EdgeInsets.all(24),
        child: _isEditing ? _buildEditForm() : _buildList(),
      ),
    );
  }

  Widget _buildList() {
    return Consumer<UserPersonaService>(
      builder: (context, service, child) {
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'User Personas',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: service.personas.length,
                itemBuilder: (context, index) {
                  final persona = service.personas[index];
                  final isActive = persona.id == service.persona.id;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.blueAccent.withOpacity(0.1) : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: isActive ? Border.all(color: Colors.blueAccent) : null,
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: persona.avatarPath != null ? FileImage(File(persona.avatarPath!)) : null,
                        child: persona.avatarPath == null ? const Icon(Icons.person) : null,
                      ),
                      title: Text(persona.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: Text(persona.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isActive)
                            TextButton(
                              onPressed: () => service.setActivePersona(persona.id),
                              child: const Text('Select'),
                            ),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20, color: Colors.white70),
                            onPressed: () => _startEditing(persona),
                          ),
                          if (service.personas.length > 1)
                            IconButton(
                              icon: const Icon(Icons.delete, size: 20, color: Colors.redAccent),
                              onPressed: () => _showDeleteConfirmation(context, persona),
                            ),
                        ],
                      ),
                      onTap: () => service.setActivePersona(persona.id),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _startEditing(null),
                icon: const Icon(Icons.add),
                label: const Text('Add New Persona'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEditForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _editingPersona == null ? 'Create Persona' : 'Edit Persona',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: _cancelEditing,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: _pickAvatar,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    shape: BoxShape.circle,
                    image: _avatarPath != null
                        ? DecorationImage(
                            image: FileImage(File(_avatarPath!)),
                            fit: BoxFit.cover,
                          )
                        : null,
                    border: Border.all(color: Colors.white24),
                  ),
                  child: _avatarPath == null
                      ? const Icon(Icons.add_a_photo, size: 32, color: Colors.white54)
                      : null,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        labelStyle: TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: Color(0xFF374151),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value?.isEmpty ?? true ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        labelStyle: TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: Color(0xFF374151),
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                      validator: (value) => value?.isEmpty ?? true ? 'Description is required' : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _cancelEditing,
                child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: _savePersona,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, UserPersona persona) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: const Text('Delete Persona'),
        content: Text('Are you sure you want to delete "${persona.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
               Provider.of<UserPersonaService>(context, listen: false).deletePersona(persona.id);
               Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
