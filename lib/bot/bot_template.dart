/// A predefined bot template that users can apply to quickly bootstrap
/// a bot with ready-made commands and workflows.
class BotTemplate {
  /// Unique identifier for the template (e.g. 'welcome', 'moderation').
  final String id;

  /// Human-readable name (i18n key).
  final String nameKey;

  /// Short description (i18n key).
  final String descriptionKey;

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
    required this.nameKey,
    required this.descriptionKey,
    required this.iconCodePoint,
    required this.category,
    this.intents = const {},
    this.commands = const [],
    this.workflows = const [],
  });
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
}
