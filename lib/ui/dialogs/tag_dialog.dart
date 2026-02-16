import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kobold_character_card_manager/models/character_card.dart';
import 'package:kobold_character_card_manager/services/character_repository.dart';

/// Dialog shown after character import to let user add/edit tags.
/// Pre-populates with any tags from the V2 card data (e.g. from Chub.ai).
class TagDialog extends StatefulWidget {
  final CharacterCard character;

  const TagDialog({super.key, required this.character});

  @override
  State<TagDialog> createState() => _TagDialogState();

  /// Shows the tag dialog and returns the updated tag list (or null if skipped)
  static Future<List<String>?> show(BuildContext context, CharacterCard character) {
    return showDialog<List<String>>(
      context: context,
      builder: (_) => TagDialog(character: character),
    );
  }
}

class _TagDialogState extends State<TagDialog> {
  late List<String> _tags;
  final _controller = TextEditingController();
  List<String> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _tags = List.from(widget.character.tags);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addTag(String tag) {
    final trimmed = tag.trim().toLowerCase();
    if (trimmed.isNotEmpty && !_tags.contains(trimmed)) {
      setState(() {
        _tags.add(trimmed);
        _controller.clear();
        _suggestions = [];
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  void _updateSuggestions(String query) {
    if (query.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    final repo = Provider.of<CharacterRepository>(context, listen: false);
    final allTags = repo.allTags;
    setState(() {
      _suggestions = allTags
          .where((t) => t.toLowerCase().contains(query.toLowerCase()) && !_tags.contains(t))
          .take(8)
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1F2937),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 450,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.label_outline, color: Colors.amber, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tag "${widget.character.name}"',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              widget.character.tags.isNotEmpty
                  ? 'Tags imported from card data. Add more or edit below.'
                  : 'Add tags to organize this character.',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 16),

            // Current tags
            if (_tags.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _tags.map((tag) => Chip(
                  label: Text(tag, style: const TextStyle(color: Colors.white, fontSize: 13)),
                  backgroundColor: const Color(0xFF374151),
                  deleteIcon: const Icon(Icons.close, size: 16, color: Colors.white54),
                  onDeleted: () => _removeTag(tag),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                )).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Tag input
            TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Type a tag and press Enter...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF374151),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add, color: Colors.amber),
                  onPressed: () => _addTag(_controller.text),
                ),
              ),
              onChanged: _updateSuggestions,
              onSubmitted: (value) {
                _addTag(value);
              },
            ),

            // Autocomplete suggestions
            if (_suggestions.isNotEmpty) ...[
              const SizedBox(height: 4),
              Container(
                constraints: const BoxConstraints(maxHeight: 150),
                decoration: BoxDecoration(
                  color: const Color(0xFF374151),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _suggestions.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      dense: true,
                      title: Text(_suggestions[index], style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      leading: const Icon(Icons.label, size: 16, color: Colors.white38),
                      onTap: () => _addTag(_suggestions[index]),
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null), // Skip
                  child: const Text('Skip', style: TextStyle(color: Colors.white54)),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, _tags),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Save Tags'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
