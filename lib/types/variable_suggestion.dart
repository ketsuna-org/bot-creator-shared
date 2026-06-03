enum VariableSuggestionKind { numeric, nonNumeric, unknown }

/// Logical category for grouping suggestions in autocomplete UI.
enum VariableCategory {
  context_,
  interaction,
  bot,
  guild,
  channel,
  member,
  message,
  author,
  user,
  temp,
  function_,
  other,
}

class VariableSuggestion {
  final String name;
  final VariableSuggestionKind kind;
  final String? description;
  final VariableCategory category;

  const VariableSuggestion({
    required this.name,
    required this.kind,
    this.description,
    this.category = VariableCategory.other,
  });

  bool get isNumeric => kind == VariableSuggestionKind.numeric;
  bool get isUnknown => kind == VariableSuggestionKind.unknown;
}
