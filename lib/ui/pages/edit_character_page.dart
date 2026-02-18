import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:front_porch_ai/models/character_card.dart';
import 'package:front_porch_ai/models/lorebook.dart';
import 'package:front_porch_ai/services/character_repository.dart';
import 'package:front_porch_ai/services/world_repository.dart';

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
  late TextEditingController _mesExampleController;

  late TabController _tabController;
  List<LorebookEntry> _loreEntries = [];
  List<String> _selectedWorldNames = [];
  List<TextEditingController> _altGreetingControllers = [];
  List<String> _tags = [];
  final _tagController = TextEditingController();
  int _estimatedTokens = 0;

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
    _mesExampleController =
        TextEditingController(text: widget.character.mesExample);

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

    // Listen for token count updates
    for (final c in [
      _nameController,
      _descriptionController,
      _personalityController,
      _scenarioController,
      _firstMessageController,
      _mesExampleController,
    ]) {
      c.addListener(_updateTokenCount);
    }
    for (final c in _altGreetingControllers) {
      c.addListener(_updateTokenCount);
    }
    _updateTokenCount();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _personalityController.dispose();
    _scenarioController.dispose();
    _firstMessageController.dispose();
    _mesExampleController.dispose();
    for (final c in _altGreetingControllers) {
      c.dispose();
    }
    _tagController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _updateTokenCount() {
    int totalChars = _nameController.text.length +
        _descriptionController.text.length +
        _personalityController.text.length +
        _scenarioController.text.length +
        _firstMessageController.text.length +
        _mesExampleController.text.length;
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveCharacter() async {
    // Update model
    widget.character.name = _nameController.text;
    widget.character.description = _descriptionController.text;
    widget.character.personality = _personalityController.text;
    widget.character.scenario = _scenarioController.text;
    widget.character.firstMessage = _firstMessageController.text;
    widget.character.mesExample = _mesExampleController.text;
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
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildDetailsTab(),
              _buildLorebookTab(),
              _buildWorldsTab(),
            ],
          ),
          // Token counter - bottom right
          Positioned(
            right: 16,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1a1a2e).withOpacity(0.95),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _tokenCountColor().withOpacity(0.4),
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
          // Example Dialogues section
          _buildTextField(
            controller: _mesExampleController,
            label: 'Example Dialogues',
            maxLines: 6,
            expandable: true,
            hintText: '(Examples of chat dialog. Begin each example with <START> on a new line.)',
          ),
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
    bool expandable = false,
    String? hintText,
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
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hintText,
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
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }
}
