class LorebookEntry {
  String name; // Display name for the entry
  String key; // Keywords to trigger this entry (comma-separated)
  String content; // The actual lore content
  bool enabled;
  bool isTriggered; // Runtime state for UI indication
  bool constant; // Always active if true
  int stickyDepth; // How many messages it stays active
  int remainingDepth; // Runtime counter

  LorebookEntry({
    this.name = '',
    required this.key,
    required this.content,
    this.enabled = true,
    this.isTriggered = false,
    this.constant = false,
    this.stickyDepth = 1,
    this.remainingDepth = 0,
  });

  /// Display label: name if available, otherwise key, otherwise 'Unnamed Entry'
  String get displayName {
    if (name.isNotEmpty) return name;
    if (key.isNotEmpty) return key;
    return 'Unnamed Entry';
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'key': key,
      'keys': key.split(',').map((k) => k.trim()).where((k) => k.isNotEmpty).toList(),
      'content': content,
      'enabled': enabled,
      'constant': constant,
      'sticky_depth': stickyDepth,
    };
  }

  factory LorebookEntry.fromJson(Map<String, dynamic> json) {
    // Handle V2 'keys' (array) or V1 'key' (string)
    String keyStr = '';
    if (json['keys'] != null && json['keys'] is List && (json['keys'] as List).isNotEmpty) {
      keyStr = (json['keys'] as List).map((k) => k.toString()).join(', ');
    } else {
      keyStr = json['key']?.toString() ?? '';
    }

    return LorebookEntry(
      name: json['name']?.toString() ?? '',
      key: keyStr,
      content: json['content']?.toString() ?? '',
      enabled: json['enabled'] ?? true,
      constant: json['constant'] ?? false,
      stickyDepth: json['sticky_depth'] ?? json['insertion_order'] ?? 1,
    );
  }
}

class Lorebook {
  List<LorebookEntry> entries;

  Lorebook({required this.entries});

  Map<String, dynamic> toJson() {
    return {
      'entries': entries.map((e) => e.toJson()).toList(),
    };
  }

  factory Lorebook.fromJson(Map<String, dynamic> json) {
    var entriesList = json['entries'] as List?;
    List<LorebookEntry> entries = [];
    if (entriesList != null) {
      entries = entriesList.map((e) => LorebookEntry.fromJson(e)).toList();
    }
    return Lorebook(entries: entries);
  }
}
