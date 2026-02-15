import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kobold_character_card_manager/services/user_persona_service.dart';

class UserPersonaPage extends StatefulWidget {
  const UserPersonaPage({super.key});

  @override
  State<UserPersonaPage> createState() => _UserPersonaPageState();
}

class _UserPersonaPageState extends State<UserPersonaPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _personaController;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    final service = Provider.of<UserPersonaService>(context, listen: false);
    _nameController = TextEditingController(text: service.persona.name);
    _descriptionController = TextEditingController(text: service.persona.description);
    _personaController = TextEditingController(text: service.persona.persona);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _personaController.dispose();
    super.dispose();
  }

  void _toggleEdit() {
    if (_isEditing) {
      // Save changes
      if (_formKey.currentState!.validate()) {
        final service = Provider.of<UserPersonaService>(context, listen: false);
        service.updatePersona(service.persona.copyWith(
          name: _nameController.text,
          description: _descriptionController.text,
          persona: _personaController.text,
        ));
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Persona updated successfully')),
        );
        setState(() => _isEditing = false);
      }
    } else {
      setState(() => _isEditing = true);
    }
  }

  void _resetChanges() {
    final service = Provider.of<UserPersonaService>(context, listen: false);
    setState(() {
      _nameController.text = service.persona.name;
      _descriptionController.text = service.persona.description;
      _personaController.text = service.persona.persona;
      _isEditing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch for external updates
    final service = Provider.of<UserPersonaService>(context);
    // Only update controllers if not editing to avoid overwriting user input
    if (!_isEditing) {
       if (_nameController.text != service.persona.name) _nameController.text = service.persona.name;
       if (_descriptionController.text != service.persona.description) _descriptionController.text = service.persona.description;
       if (_personaController.text != service.persona.persona) _personaController.text = service.persona.persona;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('User Persona'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_isEditing)
             IconButton(
              icon: const Icon(Icons.close),
              onPressed: _resetChanges,
              tooltip: 'Cancel Changes',
            ),
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit),
            onPressed: _toggleEdit,
            tooltip: _isEditing ? 'Save Changes' : 'Edit Persona',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               _buildSectionHeader('Identity'),
               const SizedBox(height: 16),
               _buildTextField(
                 controller: _nameController, 
                 label: 'Name', 
                 hint: 'How characters should address you',
                 enabled: _isEditing,
               ),
               const SizedBox(height: 16),
               _buildTextField(
                 controller: _descriptionController, 
                 label: 'Description', 
                 hint: 'Physical appearance or brief context...',
                 enabled: _isEditing,
                 maxLines: 3,
               ),
               const SizedBox(height: 24),
               _buildSectionHeader('Persona / Context'),
               const SizedBox(height: 8),
               const Text(
                 'This text is injected into the prompt to describe YOU to the AI. Use it to define your personality, role, or specific scenario details.',
                 style: TextStyle(color: Colors.white54, fontSize: 12),
               ),
               const SizedBox(height: 16),
               _buildTextField(
                 controller: _personaController, 
                 label: 'Persona Detail', 
                 hint: 'e.g. "I am a wandering merchant...", "I am the captain of the starship..."',
                 enabled: _isEditing,
                 maxLines: 10,
               ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.blueAccent,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool enabled = true,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      style: TextStyle(color: enabled ? Colors.white : Colors.white70),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        filled: true,
        fillColor: enabled ? Colors.white.withOpacity(0.05) : Colors.black12,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white10),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blueAccent),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty && label == 'Name') {
          return 'Name is required';
        }
        return null;
      },
    );
  }
}
