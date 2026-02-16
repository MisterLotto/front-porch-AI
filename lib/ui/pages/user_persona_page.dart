import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:kobold_character_card_manager/services/user_persona_service.dart';

class UserPersonaPage extends StatefulWidget {
  const UserPersonaPage({super.key});

  @override
  State<UserPersonaPage> createState() => _UserPersonaPageState();
}

class _UserPersonaPageState extends State<UserPersonaPage> {
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
          '', // Persona text unused for now
          _avatarPath,
        );
      }
      
      _cancelEditing();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Persona saved successfully')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(_isEditing 
          ? (_editingPersona == null ? 'Create Persona' : 'Edit Persona')
          : 'User Personas'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _isEditing ? IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _cancelEditing,
        ) : null,
      ),
      body: _isEditing ? _buildEditForm() : _buildList(),
      floatingActionButton: !_isEditing ? FloatingActionButton(
        onPressed: () => _startEditing(null),
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add),
      ) : null,
    );
  }

  Widget _buildList() {
    return Consumer<UserPersonaService>(
      builder: (context, service, child) {
        if (service.personas.isEmpty) {
          return const Center(child: Text('No personas found.', style: TextStyle(color: Colors.white54)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: service.personas.length,
          itemBuilder: (context, index) {
            final persona = service.personas[index];
            final isActive = persona.id == service.persona.id;
            
            return Card(
              color: isActive ? Colors.blueAccent.withOpacity(0.1) : Colors.white.withOpacity(0.05),
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: isActive ? const BorderSide(color: Colors.blueAccent) : BorderSide.none,
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(
                  radius: 24,
                  backgroundImage: persona.avatarPath != null ? FileImage(File(persona.avatarPath!)) : null,
                  child: persona.avatarPath == null ? const Icon(Icons.person) : null,
                ),
                title: Text(persona.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(persona.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70)),
                    if (isActive) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Active', style: TextStyle(color: Colors.white, fontSize: 10)),
                      ),
                    ],
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isActive)
                      TextButton(
                        onPressed: () => service.setActivePersona(persona.id),
                        child: const Text('Select'),
                      ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white70),
                      onPressed: () => _startEditing(persona),
                    ),
                    if (service.personas.length > 1)
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () => _showDeleteConfirmation(context, persona),
                      ),
                  ],
                ),
                onTap: () => service.setActivePersona(persona.id),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEditForm() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: _pickAvatar,
                    child: Container(
                      width: 120,
                      height: 120,
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
                          ? const Icon(Icons.add_a_photo, size: 40, color: Colors.white54)
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
                            hintText: 'e.g. Detective',
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
                            hintText: 'Brief description of this persona...',
                            labelStyle: TextStyle(color: Colors.white70),
                            filled: true,
                            fillColor: Color(0xFF374151),
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                          validator: (value) => value?.isEmpty ?? true ? 'Description is required' : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _cancelEditing,
                    child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _savePersona,
                    icon: const Icon(Icons.save),
                    label: const Text('Save Persona'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
