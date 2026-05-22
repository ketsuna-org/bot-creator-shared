/// A predefined bot template that users can apply to quickly bootstrap
/// a bot with ready-made commands and workflows.
class BotTemplate {
  /// Unique identifier for the template (e.g. 'welcome', 'moderation').
  final String id;

  /// Human-readable name.
  final String name;

  /// Short description.
  final String description;

  /// Material icon code point for display.
  final int iconCodePoint;

  /// Category tag for filtering (e.g. 'community', 'moderation', 'fun').
  final String category;

  /// Required Discord gateway intents (key → enabled).
  final Map<String, bool> intents;

  /// Commands bundled with this template.
  /// Each entry is a full command data map (same format as command JSON files).
  final List<BotTemplateCommand> commands;

  /// Workflows bundled with this template.
  /// Each entry uses the normalized workflow definition format.
  final List<Map<String, dynamic>> workflows;

  const BotTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.iconCodePoint,
    required this.category,
    this.intents = const {},
    this.commands = const [],
    this.workflows = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'iconCodePoint': iconCodePoint,
        'category': category,
        'intents': intents,
        'commands': commands.map((c) => c.toJson()).toList(),
        'workflows': workflows,
      };

  factory BotTemplate.fromJson(Map<String, dynamic> json) {
    return BotTemplate(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? json['nameKey'] ?? '').toString(),
      description: (json['description'] ?? json['descriptionKey'] ?? '').toString(),
      iconCodePoint: int.tryParse(json['iconCodePoint']?.toString() ?? '') ?? 0,
      category: (json['category'] ?? '').toString(),
      intents: Map<String, bool>.from((json['intents'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), v == true),
          ) ??
          const {}),
      commands: ((json['commands'] as List?) ?? [])
          .map((c) => BotTemplateCommand.fromJson(Map<String, dynamic>.from(c)))
          .toList(),
      workflows: ((json['workflows'] as List?) ?? [])
          .map((w) => Map<String, dynamic>.from(w))
          .toList(),
    );
  }
}

/// A command definition inside a template.
class BotTemplateCommand {
  /// Slash command name (e.g. 'welcome', 'ban').
  final String name;

  /// Command description.
  final String description;

  /// Full command `data` payload — same structure as the JSON files
  /// saved by [AppManager.saveAppCommand].
  final Map<String, dynamic> data;

  const BotTemplateCommand({
    required this.name,
    required this.description,
    required this.data,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'data': data,
      };

  factory BotTemplateCommand.fromJson(Map<String, dynamic> json) {
    return BotTemplateCommand(
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      data: Map<String, dynamic>.from(json['data'] ?? const {}),
    );
  }
}

/// Helper to load a list of templates dynamically from a JSON structure.
List<BotTemplate> loadTemplatesFromJsonList(List<dynamic> jsonList) {
  return jsonList
      .map((item) => BotTemplate.fromJson(Map<String, dynamic>.from(item)))
      .toList();
}
