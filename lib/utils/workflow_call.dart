import 'dart:convert';

const String workflowTypeGeneral = 'general';
const String workflowTypeEvent = 'event';
const String workflowTypeInboundWebhook = 'inboundWebhook';

class WorkflowArgumentDefinition {
  final String name;
  final bool required;
  final String defaultValue;

  const WorkflowArgumentDefinition({
    required this.name,
    this.required = false,
    this.defaultValue = '',
  });

  factory WorkflowArgumentDefinition.fromJson(Map<String, dynamic> json) {
    return WorkflowArgumentDefinition(
      name: (json['name'] ?? '').toString().trim(),
      required: json['required'] == true,
      defaultValue: (json['defaultValue'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'required': required,
    'defaultValue': defaultValue,
  };
}

String normalizeWorkflowEntryPoint(dynamic raw, {String fallback = 'main'}) {
  final value = (raw ?? '').toString().trim();
  if (value.isNotEmpty) {
    return value;
  }
  final normalizedFallback = fallback.trim();
  return normalizedFallback.isEmpty ? 'main' : normalizedFallback;
}

String normalizeWorkflowType(dynamic raw) {
  final value = (raw ?? '').toString().trim().toLowerCase();
  if (value == workflowTypeEvent) {
    return workflowTypeEvent;
  }
  if (value == workflowTypeInboundWebhook.toLowerCase()) {
    return workflowTypeInboundWebhook;
  }
  return workflowTypeGeneral;
}

Map<String, dynamic> normalizeWorkflowEventTrigger(
  dynamic raw, {
  String fallbackCategory = 'messages',
  String fallbackEvent = 'messageCreate',
}) {
  final source = <String, dynamic>{};
  if (raw is Map) {
    source.addAll(raw.map((key, value) => MapEntry(key.toString(), value)));
  } else {
    final value = (raw ?? '').toString().trim();
    if (value.isNotEmpty) {
      source['event'] = value;
    }
  }

  final category =
      (source['category'] ?? fallbackCategory).toString().trim().isEmpty
          ? fallbackCategory
          : (source['category'] ?? fallbackCategory).toString().trim();
  final event =
      (source['event'] ?? source['listenFor'] ?? fallbackEvent)
              .toString()
              .trim()
              .isEmpty
          ? fallbackEvent
          : (source['event'] ?? source['listenFor'] ?? fallbackEvent)
              .toString()
              .trim();

  return <String, dynamic>{'category': category, 'event': event};
}

List<WorkflowArgumentDefinition> parseWorkflowArgumentDefinitions(dynamic raw) {
  if (raw is! List) {
    return const [];
  }

  final byKey = <String, WorkflowArgumentDefinition>{};
  for (final item in raw) {
    WorkflowArgumentDefinition? definition;
    if (item is Map) {
      definition = WorkflowArgumentDefinition.fromJson(
        Map<String, dynamic>.from(
          item.map((key, value) => MapEntry(key.toString(), value)),
        ),
      );
    } else if (item is String) {
      final name = item.trim();
      if (name.isNotEmpty) {
        definition = WorkflowArgumentDefinition(name: name);
      }
    }

    if (definition == null || definition.name.isEmpty) {
      continue;
    }

    byKey[definition.name.toLowerCase()] = definition;
  }

  return byKey.values.toList(growable: false);
}

List<Map<String, dynamic>> serializeWorkflowArgumentDefinitions(
  List<WorkflowArgumentDefinition> definitions,
) {
  return definitions
      .where((definition) => definition.name.trim().isNotEmpty)
      .map((definition) => definition.toJson())
      .toList(growable: false);
}

Map<String, dynamic> normalizeStoredWorkflowDefinition(
  Map<String, dynamic> workflow,
) {
  final normalized = Map<String, dynamic>.from(workflow);
  final rawType = (normalized['workflowType'] ?? '').toString().trim();
  final hasLegacyEventHints =
      normalized['eventTrigger'] != null ||
      (normalized['event']?.toString().trim().isNotEmpty ?? false) ||
      (normalized['listenFor']?.toString().trim().isNotEmpty ?? false);
  if (rawType.isEmpty && hasLegacyEventHints) {
    normalized['workflowType'] = workflowTypeEvent;
    if (normalized['eventTrigger'] == null) {
      normalized['eventTrigger'] = normalizeWorkflowEventTrigger(
        <String, dynamic>{
          'event': normalized['event'],
          'listenFor': normalized['listenFor'],
        },
      );
    }
  }
  normalized['name'] = (normalized['name'] ?? '').toString().trim();
  normalized['workflowType'] = normalizeWorkflowType(
    normalized['workflowType'],
  );
  normalized['entryPoint'] = normalizeWorkflowEntryPoint(
    normalized['entryPoint'],
  );
  normalized['arguments'] = serializeWorkflowArgumentDefinitions(
    parseWorkflowArgumentDefinitions(normalized['arguments']),
  );
  normalized['actions'] = List<Map<String, dynamic>>.from(
    (normalized['actions'] as List?)?.whereType<Map>().map(
          (item) => Map<String, dynamic>.from(item),
        ) ??
        const <Map<String, dynamic>>[],
  );
  if (normalized['workflowType'] == workflowTypeEvent) {
    normalized['eventTrigger'] = normalizeWorkflowEventTrigger(
      normalized['eventTrigger'],
    );
  } else {
    normalized.remove('eventTrigger');
  }
  return normalized;
}

Map<String, String> normalizeWorkflowCallArguments(dynamic raw) {
  if (raw is! Map) {
    return const <String, String>{};
  }

  final result = <String, String>{};
  for (final entry in raw.entries) {
    final key = entry.key.toString().trim();
    if (key.isEmpty) {
      continue;
    }
    result[key] = entry.value?.toString() ?? '';
  }
  return result;
}

Map<String, String> resolveWorkflowCallArguments(
  dynamic raw,
  String Function(String) resolve,
) {
  final normalized = normalizeWorkflowCallArguments(raw);
  if (normalized.isEmpty) {
    return normalized;
  }

  return Map<String, String>.fromEntries(
    normalized.entries.map((entry) {
      return MapEntry(entry.key, resolve(entry.value));
    }),
  );
}

Map<String, String> resolveWorkflowInvocationArguments({
  required List<WorkflowArgumentDefinition> definitions,
  required Map<String, String> providedArguments,
  bool enforceRequired = true,
}) {
  if (definitions.isEmpty) {
    return Map<String, String>.from(providedArguments);
  }

  final resolved = <String, String>{};
  final providedByLowercase = <String, MapEntry<String, String>>{
    for (final entry in providedArguments.entries)
      entry.key.toLowerCase(): MapEntry(entry.key, entry.value),
  };

  for (final definition in definitions) {
    final fromProvided = providedByLowercase[definition.name.toLowerCase()];
    final value =
        fromProvided != null ? fromProvided.value : definition.defaultValue;
    if (enforceRequired && definition.required && value.trim().isEmpty) {
      throw Exception(
        'Missing required workflow argument "${definition.name}"',
      );
    }
    resolved[definition.name] = value;
  }

  for (final entry in providedArguments.entries) {
    if (!resolved.containsKey(entry.key)) {
      resolved[entry.key] = entry.value;
    }
  }

  return resolved;
}

void applyWorkflowInvocationContext({
  required Map<String, String> variables,
  required String workflowName,
  required String entryPoint,
  required List<WorkflowArgumentDefinition> definitions,
  required Map<String, String> providedArguments,
  bool enforceRequired = true,
}) {
  final args = resolveWorkflowInvocationArguments(
    definitions: definitions,
    providedArguments: providedArguments,
    enforceRequired: enforceRequired,
  );

  variables['workflow.name'] = workflowName;
  variables['workflow.entryPoint'] = entryPoint;
  variables['workflow.args'] = jsonEncode(args);

  for (final entry in args.entries) {
    variables['arg.${entry.key}'] = entry.value;
    variables['workflow.arg.${entry.key}'] = entry.value;
  }
}
