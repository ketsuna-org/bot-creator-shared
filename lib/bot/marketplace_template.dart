/// A marketplace template stored on R2 that users can browse, apply,
/// and publish. Extends the old BotTemplate with author info, versioning,
/// usage documentation, interactive variables, and stats.
class MarketplaceVariable {
  /// Variable name (e.g. 'TOKEN_OPENAI').
  final String name;

  /// Human-readable description shown in the UI.
  final String description;

  /// If true, the user MUST provide a value before applying the template.
  final bool required;

  /// Optional default value. Shown as placeholder in the form.
  final String? defaultValue;

  /// If true, the value is masked (password field) in the UI.
  final bool sensitive;

  const MarketplaceVariable({
    required this.name,
    required this.description,
    this.required = false,
    this.defaultValue,
    this.sensitive = false,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'required': required,
        if (defaultValue != null) 'defaultValue': defaultValue,
        'sensitive': sensitive,
      };

  factory MarketplaceVariable.fromJson(Map<String, dynamic> json) {
    return MarketplaceVariable(
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      required: json['required'] == true,
      defaultValue: json['defaultValue']?.toString(),
      sensitive: json['sensitive'] == true,
    );
  }
}

/// A template published to the Marketplace.
class MarketplaceTemplate {
  /// Unique slug (e.g. 'ai-chatbot', 'welcome-v2').
  final String id;

  /// Display name.
  final String name;

  /// Short tagline shown in cards.
  final String description;

  /// Full markdown usage documentation.
  final String? descriptionLong;

  /// Firebase UID of the author.
  final String authorId;

  /// Display name of the author.
  final String authorName;

  /// Semver version string (e.g. '1.0.0').
  final String version;

  /// Category slug for filtering (e.g. 'ai', 'moderation', 'fun').
  final String category;

  /// Searchable tags.
  final List<String> tags;

  /// Display emoji (e.g. '🤖', '🛡️').
  final String icon;

  /// Required Discord gateway intents (key → enabled).
  final Map<String, bool> intents;

  /// Commands bundled with this template.
  final List<BotTemplateCommand> commands;

  /// Workflows bundled with this template.
  final List<Map<String, dynamic>> workflows;

  /// Global variables — some may be marked `required` for interactive setup.
  final List<MarketplaceVariable> globalVariables;

  /// When the template was first published.
  final DateTime createdAt;

  /// When the template was last updated.
  final DateTime updatedAt;

  /// Number of times applied.
  final int downloads;

  /// Average rating (0.0 – 5.0).
  final double rating;

  const MarketplaceTemplate({
    required this.id,
    required this.name,
    required this.description,
    this.descriptionLong,
    required this.authorId,
    required this.authorName,
    required this.version,
    required this.category,
    this.tags = const [],
    required this.icon,
    this.intents = const {},
    this.commands = const [],
    this.workflows = const [],
    this.globalVariables = const [],
    required this.createdAt,
    required this.updatedAt,
    this.downloads = 0,
    this.rating = 0.0,
  });

  /// The variables that the user must fill in before applying.
  List<MarketplaceVariable> get requiredVariables =>
      globalVariables.where((v) => v.required).toList();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        if (descriptionLong != null) 'descriptionLong': descriptionLong,
        'authorId': authorId,
        'authorName': authorName,
        'version': version,
        'category': category,
        'tags': tags,
        'icon': icon,
        'intents': intents,
        'commands': commands.map((c) => c.toJson()).toList(),
        'workflows': workflows,
        'globalVariables': globalVariables.map((v) => v.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'downloads': downloads,
        'rating': rating,
      };

  factory MarketplaceTemplate.fromJson(Map<String, dynamic> json) {
    return MarketplaceTemplate(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      descriptionLong: json['descriptionLong']?.toString(),
      authorId: (json['authorId'] ?? '').toString(),
      authorName: (json['authorName'] ?? '').toString(),
      version: (json['version'] ?? '1.0.0').toString(),
      category: (json['category'] ?? '').toString(),
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      icon: (json['icon'] ?? '📦').toString(),
      intents: Map<String, bool>.from(
        (json['intents'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), v == true),
            ) ??
            const {},
      ),
      commands: ((json['commands'] as List?) ?? [])
          .map((c) => BotTemplateCommand.fromJson(Map<String, dynamic>.from(c)))
          .toList(),
      workflows: ((json['workflows'] as List?) ?? [])
          .map((w) => Map<String, dynamic>.from(w))
          .toList(),
      globalVariables: ((json['globalVariables'] as List?) ?? [])
          .map((v) =>
              MarketplaceVariable.fromJson(Map<String, dynamic>.from(v)))
          .toList(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
      downloads: int.tryParse(json['downloads']?.toString() ?? '') ?? 0,
      rating: double.tryParse(json['rating']?.toString() ?? '') ?? 0.0,
    );
  }
}

/// A command definition inside a template/marketplace item.
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
