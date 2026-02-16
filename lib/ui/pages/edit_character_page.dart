import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kobold_character_card_manager/models/character_card.dart';
import 'package:kobold_character_card_manager/models/lorebook.dart';
import 'package:kobold_character_card_manager/services/character_repository.dart';
import 'package:kobold_character_card_manager/services/world_repository.dart';

class EditCharacterPage extends StatefulWidget {
  final CharacterCard character;

  const EditCharacterPage({super.key, required this.character});

  @override
  State<EditCharacterPage> createState() => _EditCharacterPageState();
}

class _EditCharacterPageState extends State<EditCharacterPage>
    with SingleTickerProviderStateMixin {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _personalityController;
  late TextEditingController _scenarioController;
  late TextEditingController _firstMessageController;

  late TabController _tabController;
  List<LorebookEntry> _loreEntries = [];
  List<String> _selectedWorldNames = [];
  List<TextEditingController> _altGreetingControllers = [];
  List<String> _tags = [];
  final _tagController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.character.name);
    _descriptionController =
        TextEditingController(text: widget.character.description);
    _personalityController =
        TextEditingController(text: widget.character.personality);
    _scenarioController = TextEditingController(text: widget.character.scenario);
    _firstMessageController =
        TextEditingController(text: widget.character.firstMessage);

    if (widget.character.lorebook != null) {
      _loreEntries = List.from(widget.character.lorebook!.entries);
    } else {
      widget.character.lorebook = Lorebook(entries: []);
      _loreEntries = widget.character.lorebook!.entries;
    }

    _selectedWorldNames = List.from(widget.character.worldNames);

    _altGreetingControllers = widget.character.alternateGreetings
        .map((g) => TextEditingController(text: g))
        .toList();

    _tags = List.from(widget.character.tags);

    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _personalityController.dispose();
    _scenarioController.dispose();
    _firstMessageController.dispose();
    for (final c in _altGreetingControllers) {
      c.dispose();
    }
    _tagController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _saveCharacter() async {
    // Update model
    widget.character.name = _nameController.text;
    widget.character.description = _descriptionController.text;
    widget.character.personality = _personalityController.text;
    widget.character.scenario = _scenarioController.text;
    widget.character.firstMessage = _firstMessageController.text;
    widget.character.alternateGreetings = _altGreetingControllers
        .map((c) => c.text)
        .where((t) => t.isNotEmpty)
        .toList();
    widget.character.tags = List.from(_tags);
    widget.character.worldNames = _selectedWorldNames;
    
    // Update Lorebook
    if (widget.character.lorebook == null) {
       widget.character.lorebook = Lorebook(entries: _loreEntries);
    } else {
       widget.character.lorebook!.entries = _loreEntries;
    }

    try {
      await Provider.of<CharacterRepository>(context, listen: false)
          .updateCharacter(widget.character);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Character updated successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating character: $e')),
        );
      }
    }
  }

  void _addLoreEntry() {
    setState(() {
      _loreEntries.add(LorebookEntry(key: 'New Key', content: 'New Content'));
    });
  }

  void _removeLoreEntry(int index) {
    setState(() {
      _loreEntries.removeAt(index);
    });
  }
  
  void _editLoreEntry(int index) {
     final entry = _loreEntries[index];
     final keyController = TextEditingController(text: entry.key);
     final contentController = TextEditingController(text: entry.content);
     bool isConstant = entry.constant;
     int stickyDepth = entry.stickyDepth;

     showDialog(
       context: context,
       builder: (context) => StatefulBuilder(
         builder: (context, setStateDialog) {
           return AlertDialog(
             title: const Text('Edit Lorebook Entry'),
             content: SingleChildScrollView(
               child: Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   Row(
                     children: [
                       const Text('Always Active'),
                       const Spacer(),
                       Switch(
                         value: isConstant,
                         onChanged: (val) {
                           setStateDialog(() {
                             isConstant = val;
                           });
                         },
                       ),
                     ],
                   ),
                   if (!isConstant) ...[
                     const SizedBox(height: 8),
                     Row(
                       children: [
                         Text('Trigger Depth: $stickyDepth ${stickyDepth == 1 ? "message" : "messages"}'),
                       ],
                     ),
                     Slider(
                       value: stickyDepth.toDouble(),
                       min: 1,
                       max: 100,
                       divisions: 99,
                       label: stickyDepth.toString(),
                       onChanged: (val) {
                         setStateDialog(() {
                           stickyDepth = val.toInt();
                         });
                       },
                     ),
                   ],
                   const SizedBox(height: 8),
                   TextField(
                     controller: keyController,
                     enabled: !isConstant,
                     decoration: InputDecoration(
                       labelText: isConstant ? 'Keywords (Disabled)' : 'Keywords (comma separated)',
                       helperText: isConstant ? 'Always included in context' : null,
                     ),
                   ),
                   const SizedBox(height: 8),
                   TextField(
                     controller: contentController,
                     decoration: const InputDecoration(labelText: 'Content'),
                     maxLines: 5,
                   ),
                 ],
               ),
             ),
             actions: [
               TextButton(
                 onPressed: () => Navigator.pop(context),
                 child: const Text('Cancel'),
               ),
               TextButton(
                 onPressed: () {
                   setState(() {
                     entry.key = keyController.text;
                     entry.content = contentController.text;
                     entry.constant = isConstant;
                     entry.stickyDepth = stickyDepth;
                   });
                   Navigator.pop(context);
                 },
                 child: const Text('Save'),
               ),
             ],
           );
         }
       ),
     );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit ${widget.character.name}'),
        backgroundColor: Theme.of(context).cardColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveCharacter,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Theme.of(context).textTheme.bodyMedium?.color,
          tabs: const [
            Tab(text: 'Details'),
            Tab(text: 'Lorebook'),
            Tab(text: 'Worlds'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDetailsTab(),
          _buildLorebookTab(),
          _buildWorldsTab(),
        ],
      ),
    );
  }

  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildTextField(
            controller: _nameController,
            label: 'Name',
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _descriptionController,
            label: 'Description',
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _personalityController,
            label: 'Personality',
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _scenarioController,
            label: 'Scenario',
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _firstMessageController,
            label: 'First Message',
            maxLines: 5,
          ),
          const SizedBox(height: 24),
          // Alternate greetings section
          Row(
            children: [
              const Text('Alternate Greetings', 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white70)),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add'),
                onPressed: () {
                  setState(() {
                    _altGreetingControllers.add(TextEditingController());
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
                      maxLines: 4,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                    tooltip: 'Remove this greeting',
                    onPressed: () {
                      setState(() {
                        _altGreetingControllers[idx].dispose();
                        _altGreetingControllers.removeAt(idx);
                      });
                    },
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 24),
          // Tags section
          Row(
            children: [
              const Icon(Icons.label_outline, color: Colors.amber, size: 18),
              const SizedBox(width: 8),
              const Text('Tags', 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white70)),
            ],
          ),
          const SizedBox(height: 8),
          if (_tags.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tags.map((tag) => Chip(
                label: Text(tag, style: const TextStyle(color: Colors.white, fontSize: 13)),
                backgroundColor: const Color(0xFF374151),
                deleteIcon: const Icon(Icons.close, size: 16, color: Colors.white54),
                onDeleted: () => setState(() => _tags.remove(tag)),
                side: BorderSide.none,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              )).toList(),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tagController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Add a tag...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xFF374151),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onSubmitted: (value) {
                    final trimmed = value.trim().toLowerCase();
                    if (trimmed.isNotEmpty && !_tags.contains(trimmed)) {
                      setState(() {
                        _tags.add(trimmed);
                        _tagController.clear();
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.add, color: Colors.amber),
                tooltip: 'Add tag',
                onPressed: () {
                  final trimmed = _tagController.text.trim().toLowerCase();
                  if (trimmed.isNotEmpty && !_tags.contains(trimmed)) {
                    setState(() {
                      _tags.add(trimmed);
                      _tagController.clear();
                    });
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLorebookTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton.icon(
            onPressed: _addLoreEntry,
            icon: const Icon(Icons.add),
            label: const Text('Add Entry'),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _loreEntries.length,
            itemBuilder: (context, index) {
              final entry = _loreEntries[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(entry.content, maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: entry.enabled,
                        onChanged: (val) {
                          setState(() {
                            entry.enabled = val;
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _editLoreEntry(index),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _removeLoreEntry(index),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWorldsTab() {
    return Consumer<WorldRepository>(
      builder: (context, repo, child) {
        if (repo.worlds.isEmpty) {
          return const Center(child: Text('No worlds found. Create them in the Worlds section.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: repo.worlds.length,
          itemBuilder: (context, index) {
            final world = repo.worlds[index];
            final isSelected = _selectedWorldNames.contains(world.name);
            return CheckboxListTile(
              title: Text(world.name),
              subtitle: Text(world.description, maxLines: 1, overflow: TextOverflow.ellipsis),
              value: isSelected,
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selectedWorldNames.add(world.name);
                  } else {
                    _selectedWorldNames.remove(world.name);
                  }
                });
              },
            );
          },
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      maxLines: maxLines,
    );
  }
}
