import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:front_porch_ai/models/character_card.dart';
import 'package:front_porch_ai/models/lorebook.dart';
import 'package:front_porch_ai/services/character_repository.dart';
import 'package:front_porch_ai/services/world_repository.dart';

class EditCharacterDialog extends StatefulWidget {
  final CharacterCard character;

  const EditCharacterDialog({super.key, required this.character});

  @override
  State<EditCharacterDialog> createState() => _EditCharacterDialogState();
}

class _EditCharacterDialogState extends State<EditCharacterDialog> with SingleTickerProviderStateMixin {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _personalityController;
  late TextEditingController _scenarioController;
  late TextEditingController _firstMessageController;
  late TextEditingController _mesExampleController;
  late TextEditingController _systemPromptController;
  late TextEditingController _postHistoryController;
  List<TextEditingController> _altGreetingControllers = [];

  late TabController _tabController;
  List<LorebookEntry> _loreEntries = [];
  List<String> _selectedWorldNames = [];
  List<String> _tags = [];
  final TextEditingController _tagInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.character.name);
    _descriptionController = TextEditingController(text: widget.character.description);
    _personalityController = TextEditingController(text: widget.character.personality);
    _scenarioController = TextEditingController(text: widget.character.scenario);
    _firstMessageController = TextEditingController(text: widget.character.firstMessage);
    _mesExampleController = TextEditingController(text: widget.character.mesExample);
    _systemPromptController = TextEditingController(text: widget.character.systemPrompt);
    _postHistoryController = TextEditingController(text: widget.character.postHistoryInstructions);

    _altGreetingControllers = widget.character.alternateGreetings
        .map((g) => TextEditingController(text: g))
        .toList();

    if (widget.character.lorebook != null) {
      _loreEntries = List.from(widget.character.lorebook!.entries);
    } else {
       _loreEntries = [];
    }

    _selectedWorldNames = List.from(widget.character.worldNames);
    _tags = List<String>.from(widget.character.tags);
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _personalityController.dispose();
    _scenarioController.dispose();
    _firstMessageController.dispose();
    _mesExampleController.dispose();
    _systemPromptController.dispose();
    _postHistoryController.dispose();
    for (final c in _altGreetingControllers) {
      c.dispose();
    }
    _tabController.dispose();
    _tagInputController.dispose();
    super.dispose();
  }



  void _openExpandedEditor(String title, TextEditingController controller, {String? hintText}) {
    final expandedController = TextEditingController(text: controller.text);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
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
                        Navigator.pop(ctx);
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
                        borderSide: const BorderSide(color: Colors.blueAccent),
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
    widget.character.systemPrompt = _systemPromptController.text;
    widget.character.postHistoryInstructions = _postHistoryController.text;
    widget.character.alternateGreetings = _altGreetingControllers
        .map((c) => c.text)
        .where((t) => t.isNotEmpty)
        .toList();
    widget.character.worldNames = _selectedWorldNames;
    widget.character.tags = List<String>.from(_tags);

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
        Navigator.pop(context, true);
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
             backgroundColor: const Color(0xFF1E293B),
             title: const Text('Edit Lorebook Entry'),
             content: SingleChildScrollView(
               child: Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   Row(
                     children: [
                       const Text('Always Active', style: TextStyle(color: Colors.white)),
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
                         Text('Trigger Depth: $stickyDepth ${stickyDepth == 1 ? "message" : "messages"}', style: const TextStyle(color: Colors.white70)),
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
                     style: const TextStyle(color: Colors.white),
                     decoration: InputDecoration(
                       labelText: isConstant ? 'Keywords (Disabled)' : 'Keywords (comma separated)',
                       helperText: isConstant ? 'Always included in context' : null,
                       filled: true,
                       fillColor: Colors.black26,
                     ),
                   ),
                   const SizedBox(height: 16),
                   TextField(
                     controller: contentController,
                     maxLines: 5,
                     style: const TextStyle(color: Colors.white),
                     decoration: const InputDecoration(
                       labelText: 'Content',
                       filled: true,
                       fillColor: Colors.black26,
                     ),
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

    return Dialog(
      backgroundColor: const Color(0xFF1F2937),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 800,
        height: 700,
        padding: const EdgeInsets.all(0),
        child: Column(
          children: [
             // Header
             Container(
               padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
               decoration: const BoxDecoration(
                 border: Border(bottom: BorderSide(color: Colors.white10)),
               ),
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   Text('Edit ${widget.character.name}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                   IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                 ],
               ),
             ),
             
             // Tabs
             Container(
               color: const Color(0xFF111827),
               child: TabBar(
                 controller: _tabController,
                 labelColor: Colors.blueAccent,
                 unselectedLabelColor: Colors.white54,
                 indicatorColor: Colors.blueAccent,
                 tabs: const [
                   Tab(text: 'Details'),
                   Tab(text: 'Lorebook'),
                   Tab(text: 'Worlds'),
                 ],
               ),
             ),

             // Content
             Expanded(
               child: TabBarView(
                 controller: _tabController,
                 children: [
                   _buildDetailsTab(),
                   _buildLorebookTab(),
                   _buildWorldsTab(),
                 ],
               ),
             ),

             // Actions
             Container(
               padding: const EdgeInsets.all(16),
               decoration: const BoxDecoration(
                 border: Border(top: BorderSide(color: Colors.white10)),
               ),
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.end,
                 children: [
                   TextButton(
                     onPressed: () => Navigator.pop(context),
                     child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                   ),
                   const SizedBox(width: 16),
                   ElevatedButton.icon(
                     onPressed: _saveCharacter,
                     icon: const Icon(Icons.save),
                     label: const Text('Save Changes'),
                     style: ElevatedButton.styleFrom(
                       backgroundColor: Colors.blueAccent,
                       foregroundColor: Colors.white,
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

     Widget _buildDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          _buildTextField(controller: _nameController, label: 'Name'),
          const SizedBox(height: 16),
          _buildTextField(controller: _descriptionController, label: 'Description', maxLines: 3, expandable: true),
          const SizedBox(height: 16),
          _buildTextField(controller: _personalityController, label: 'Personality', maxLines: 3, expandable: true),
          const SizedBox(height: 16),
          _buildTextField(controller: _scenarioController, label: 'Scenario', maxLines: 3, expandable: true),
          const SizedBox(height: 16),
          _buildTextField(controller: _firstMessageController, label: 'First Message', maxLines: 5, expandable: true),
          const SizedBox(height: 24),
          // Alternate Greetings
          Row(
            children: [
              const Text('Alternate Greetings',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white70)),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 16, color: Colors.white70),
                label: const Text('Add', style: TextStyle(color: Colors.white70)),
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
                      maxLines: 3,
                      expandable: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                    tooltip: 'Remove',
                    padding: const EdgeInsets.only(top: 24),
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
          // Example Dialogues
          _buildTextField(
            controller: _mesExampleController,
            label: 'Example Dialogues',
            maxLines: 5,
            expandable: true,
            hintText: '(Examples of chat dialog. Begin each example with <START> on a new line.)',
          ),
          const SizedBox(height: 24),
          // System Prompt
          _buildTextField(
            controller: _systemPromptController,
            label: 'System Prompt (optional)',
            maxLines: 4,
            expandable: true,
            hintText: 'Custom system prompt for this character. If blank, the global system prompt is used.',
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _postHistoryController,
            label: 'Post-History Instructions (optional)',
            maxLines: 3,
            expandable: true,
            hintText: 'Instructions injected after chat history (jailbreak/reminder).',
          ),
          const SizedBox(height: 24),
          // Tags editor
          const Text('Tags', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white54)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ..._tags.map((tag) => Chip(
                label: Text(tag, style: const TextStyle(fontSize: 12, color: Colors.white)),
                backgroundColor: Colors.blueAccent.withValues(alpha: 0.25),
                deleteIconColor: Colors.white54,
                onDeleted: () => setState(() => _tags.remove(tag)),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              )),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tagInputController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Add a tag...',
                    hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  onSubmitted: (val) {
                    final tag = val.trim();
                    if (tag.isNotEmpty && !_tags.contains(tag)) {
                      setState(() => _tags.add(tag));
                    }
                    _tagInputController.clear();
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.blueAccent, size: 22),
                tooltip: 'Add tag',
                onPressed: () {
                  final tag = _tagInputController.text.trim();
                  if (tag.isNotEmpty && !_tags.contains(tag)) {
                    setState(() => _tags.add(tag));
                  }
                  _tagInputController.clear();
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
          padding: const EdgeInsets.all(16.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: _addLoreEntry,
              icon: const Icon(Icons.add),
              label: const Text('Add Entry'),
            ),
          ),
        ),
        Expanded(
          child: _loreEntries.isEmpty
            ? const Center(child: Text('No lorebook entries.', style: TextStyle(color: Colors.white30)))
            : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _loreEntries.length,
              itemBuilder: (context, index) {
                final entry = _loreEntries[index];
                return Card(
                  color: const Color(0xFF374151),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(entry.key.isEmpty && entry.constant ? 'Always Active' : entry.key, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    subtitle: Text(entry.content, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70)),
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
                          icon: const Icon(Icons.edit, color: Colors.blueAccent),
                          onPressed: () => _editLoreEntry(index),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.redAccent),
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
          return const Center(child: Text('No worlds found. Create them in the Worlds section.', style: TextStyle(color: Colors.white54)));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: repo.worlds.length,
          itemBuilder: (context, index) {
            final world = repo.worlds[index];
            final isSelected = _selectedWorldNames.contains(world.name);
            return CheckboxListTile(
              title: Text(world.name, style: const TextStyle(color: Colors.white)),
              subtitle: Text(world.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54)),
              value: isSelected,
              checkColor: Colors.black,
              activeColor: Colors.blueAccent,
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
                fontSize: 14,
                color: Colors.white54,
              ),
            ),
            if (expandable) ...[
              const SizedBox(width: 6),
              InkWell(
                onTap: () => _openExpandedEditor(label, controller, hintText: hintText),
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(Icons.open_in_full, size: 14, color: Colors.white30),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: Colors.white24),
            filled: true,
            fillColor: Colors.black26,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }
}
