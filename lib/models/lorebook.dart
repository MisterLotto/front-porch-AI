class LorebookEntry {
  String key; // Keywords to trigger this entry
  String content; // The actual lore content
  bool enabled;
  bool isTriggered; // Runtime state for UI indication
  bool constant; // Always active if true
  int stickyDepth; // How many messages it stays active
  int remainingDepth; // Runtime counter

  LorebookEntry({
    required this.key,
    required this.content,
    this.enabled = true,
    this.isTriggered = false,
    this.constant = false,
    this.stickyDepth = 1,
    this.remainingDepth = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'content': content,
      'enabled': enabled,
      'constant': constant,
      'sticky_depth': stickyDepth,
    };
  }

  factory LorebookEntry.fromJson(Map<String, dynamic> json) {
    return LorebookEntry(
      key: json['key'] ?? '',
      content: json['content'] ?? '',
      enabled: json['enabled'] ?? true,
      constant: json['constant'] ?? false,
      stickyDepth: json['sticky_depth'] ?? 1,
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
