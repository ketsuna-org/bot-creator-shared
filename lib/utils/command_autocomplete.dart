import 'package:nyxx/nyxx.dart';

bool commandOptionSupportsAutocomplete(CommandOptionType type) {
  return type == CommandOptionType.string ||
      type == CommandOptionType.integer ||
      type == CommandOptionType.number;
}

String commandOptionTypeToText(CommandOptionType type) {
  if (type == CommandOptionType.subCommand) return 'subCommand';
  if (type == CommandOptionType.subCommandGroup) return 'subCommandGroup';
  if (type == CommandOptionType.string) return 'string';
  if (type == CommandOptionType.integer) return 'integer';
  if (type == CommandOptionType.boolean) return 'boolean';
  if (type == CommandOptionType.user) return 'user';
  if (type == CommandOptionType.channel) return 'channel';
  if (type == CommandOptionType.role) return 'role';
  if (type == CommandOptionType.mentionable) return 'mentionable';
  if (type == CommandOptionType.number) return 'number';
  if (type == CommandOptionType.attachment) return 'attachment';
  return 'string';
}

Map<String, dynamic>? normalizeSerializedAutocompleteConfig(dynamic raw) {
  if (raw is! Map) {
    return null;
  }

  final source = Map<String, dynamic>.from(
    raw.map((key, value) => MapEntry(key.toString(), value)),
  );
  final workflow = (source['workflow'] ?? '').toString().trim();
  final entryPoint = (source['entryPoint'] ?? 'main').toString().trim();

  final arguments = <String, dynamic>{};
  if (source['arguments'] is Map) {
    final rawArguments = Map<String, dynamic>.from(
      (source['arguments'] as Map).map(
        (key, value) => MapEntry(key.toString(), value),
      ),
    );
    for (final entry in rawArguments.entries) {
      final key = entry.key.trim();
      if (key.isEmpty) {
        continue;
      }
      arguments[key] = entry.value;
    }
  }

  final enabled =
      source['enabled'] == true ||
      (source['enabled'] == null &&
          (workflow.isNotEmpty || arguments.isNotEmpty));

  if (!enabled && workflow.isEmpty && arguments.isEmpty) {
    return null;
  }

  return <String, dynamic>{
    'enabled': enabled,
    'workflow': workflow,
    'entryPoint': entryPoint.isEmpty ? 'main' : entryPoint,
    'arguments': arguments,
  };
}

InteractionOption? findFocusedInteractionOption(
  List<InteractionOption>? options,
) {
  if (options == null) {
    return null;
  }

  for (final option in options) {
    if (option.isFocused == true) {
      return option;
    }

    final nested = findFocusedInteractionOption(option.options);
    if (nested != null) {
      return nested;
    }
  }

  return null;
}

List<Map<String, dynamic>> _coerceSerializedOptions(dynamic raw) {
  if (raw is! List) {
    return const <Map<String, dynamic>>[];
  }

  return raw
      .whereType<Map>()
      .map(
        (entry) => Map<String, dynamic>.from(
          entry.map((key, value) => MapEntry(key.toString(), value)),
        ),
      )
      .toList(growable: false);
}

Map<String, dynamic>? _findSerializedOption(
  List<Map<String, dynamic>> options,
  String name,
) {
  final normalizedName = name.trim().toLowerCase();
  if (normalizedName.isEmpty) {
    return null;
  }

  for (final option in options) {
    final optionName = (option['name'] ?? '').toString().trim().toLowerCase();
    if (optionName == normalizedName) {
      return option;
    }
  }

  return null;
}

Map<String, dynamic>? resolveAutocompleteConfigForInteraction({
  required dynamic storedOptions,
  required List<InteractionOption>? interactionOptions,
}) {
  final focused = findFocusedInteractionOption(interactionOptions);
  if (focused == null) {
    return null;
  }

  var currentStoredOptions = _coerceSerializedOptions(storedOptions);
  var currentInteractionOptions =
      interactionOptions ?? const <InteractionOption>[];

  while (true) {
    final subcommandGroup = currentInteractionOptions
        .where((option) => option.type == CommandOptionType.subCommandGroup)
        .cast<InteractionOption?>()
        .firstWhere((_) => true, orElse: () => null);
    if (subcommandGroup != null) {
      final storedGroup = _findSerializedOption(
        currentStoredOptions,
        subcommandGroup.name,
      );
      currentStoredOptions = _coerceSerializedOptions(storedGroup?['options']);
      currentInteractionOptions = subcommandGroup.options ?? const [];
      continue;
    }

    final subcommand = currentInteractionOptions
        .where((option) => option.type == CommandOptionType.subCommand)
        .cast<InteractionOption?>()
        .firstWhere((_) => true, orElse: () => null);
    if (subcommand != null) {
      final storedSubcommand = _findSerializedOption(
        currentStoredOptions,
        subcommand.name,
      );
      currentStoredOptions = _coerceSerializedOptions(
        storedSubcommand?['options'],
      );
      currentInteractionOptions = subcommand.options ?? const [];
      continue;
    }

    break;
  }

  final storedFocused = _findSerializedOption(
    currentStoredOptions,
    focused.name,
  );
  return normalizeSerializedAutocompleteConfig(storedFocused?['autocomplete']);
}
