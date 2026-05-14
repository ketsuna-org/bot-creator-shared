import 'package:nyxx/nyxx.dart';

/// Resolves the subcommand route from a list of interaction options.
///
/// Returns `"subcommandName"` for a top-level subcommand, or
/// `"groupName/subcommandName"` for a grouped subcommand.
/// Returns `null` when no subcommand is found.
String? resolveSubcommandRoute(dynamic rootOptions) {
  if (rootOptions is! Iterable) {
    return null;
  }

  for (final option in rootOptions) {
    final optionType = normalizeOptionType(readOptionField(option, 'type'));
    final optionName = normalizeOptionName(readOptionField(option, 'name'));

    if (optionType == 'subcommand' && optionName.isNotEmpty) {
      return optionName;
    }

    if (optionType != 'subcommandgroup' || optionName.isEmpty) {
      continue;
    }

    final nestedOptions = readOptionField(option, 'options');
    if (nestedOptions is! Iterable) {
      continue;
    }

    for (final child in nestedOptions) {
      final childType = normalizeOptionType(readOptionField(child, 'type'));
      final childName = normalizeOptionName(readOptionField(child, 'name'));
      if (childType == 'subcommand' && childName.isNotEmpty) {
        return '$optionName/$childName';
      }
    }
  }

  return null;
}

/// Returns the route-specific workflow payload from a command data map,
/// or `null` when the route is not found.
Map<String, dynamic>? resolveSubcommandWorkflowPayload(
  Map<String, dynamic> commandValue,
  String route,
) {
  final normalizedRoute = route.trim();
  if (normalizedRoute.isEmpty) {
    return null;
  }

  final raw = commandValue['subcommandWorkflows'];
  if (raw is! Map) {
    return null;
  }

  final routePayload = raw[normalizedRoute];
  if (routePayload is! Map) {
    return null;
  }

  return Map<String, dynamic>.from(routePayload.cast<String, dynamic>());
}

/// Normalizes a raw option type value (enum, numeric, string) to a canonical
/// lowercase string: `"subcommand"`, `"subcommandgroup"`, etc.
String normalizeOptionType(dynamic rawType) {
  if (rawType == CommandOptionType.subCommand) {
    return 'subcommand';
  }
  if (rawType == CommandOptionType.subCommandGroup) {
    return 'subcommandgroup';
  }

  // Discord API numeric constants for command option types.
  if (rawType is num) {
    final value = rawType.toInt();
    if (value == 1) {
      return 'subcommand';
    }
    if (value == 2) {
      return 'subcommandgroup';
    }
  }

  final enumName = _tryReadEnumName(rawType);
  final normalized = (enumName ?? rawType.toString())
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]'), '');

  if (normalized.endsWith('subcommandgroup')) {
    return 'subcommandgroup';
  }
  if (normalized.endsWith('subcommand')) {
    return 'subcommand';
  }

  return normalized;
}

/// Normalizes an option name by trimming whitespace.
String normalizeOptionName(dynamic rawName) {
  return (rawName ?? '').toString().trim();
}

/// Reads a named field from an option that may be a [Map] or a typed object.
dynamic readOptionField(dynamic option, String field) {
  if (option is Map) {
    return option[field];
  }

  try {
    switch (field) {
      case 'type':
        return (option as dynamic).type;
      case 'name':
        return (option as dynamic).name;
      case 'options':
        return (option as dynamic).options;
    }
  } catch (_) {
    return null;
  }

  return null;
}

String? _tryReadEnumName(dynamic value) {
  try {
    final dynamicValue = value as dynamic;
    final name = dynamicValue.name;
    if (name is String && name.trim().isNotEmpty) {
      return name;
    }
  } catch (_) {
    // Not an enum-like value with a `name` getter.
  }
  return null;
}
