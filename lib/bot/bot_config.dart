import 'dart:convert';

import 'package:bot_creator_shared/utils/workflow_call.dart';

class BotStatusConfig {
  final String type;
  final String name;
  final String state;
  final String? url;
  final int minIntervalSeconds;
  final int maxIntervalSeconds;

  String get text => name;

  const BotStatusConfig({
    required this.type,
    required this.name,
    this.state = '',
    this.url,
    required this.minIntervalSeconds,
    required this.maxIntervalSeconds,
  });

  factory BotStatusConfig.fromJson(Map<String, dynamic> json) {
    final minRaw = int.tryParse((json['minIntervalSeconds'] ?? '').toString());
    final maxRaw = int.tryParse((json['maxIntervalSeconds'] ?? '').toString());
    final min = (minRaw != null && minRaw > 0) ? minRaw : 60;
    final maxCandidate = (maxRaw != null && maxRaw > 0) ? maxRaw : min;
    final max = maxCandidate < min ? min : maxCandidate;

    return BotStatusConfig(
      type: (json['type'] ?? 'playing').toString().trim().toLowerCase(),
      name: ((json['name'] ?? json['text']) ?? '').toString(),
      state: (json['state'] ?? '').toString(),
      url: _optionalString(json['url']),
      minIntervalSeconds: min,
      maxIntervalSeconds: max,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'name': name,
    'text': name,
    'state': state,
    if (url != null) 'url': url,
    'minIntervalSeconds': minIntervalSeconds,
    'maxIntervalSeconds': maxIntervalSeconds,
  };

  void validate() {
    if (name.trim().isEmpty) {
      throw ArgumentError('BotStatusConfig: name cannot be empty');
    }

    const allowedTypes = <String>{
      'playing',
      'streaming',
      'listening',
      'watching',
      'competing',
    };
    if (!allowedTypes.contains(type)) {
      throw ArgumentError('BotStatusConfig: unsupported type "$type"');
    }

    if (type == 'streaming' && url != null) {
      final parsed = Uri.tryParse(url!);
      final valid =
          parsed != null &&
          (parsed.scheme == 'http' || parsed.scheme == 'https') &&
          parsed.host.isNotEmpty;
      if (!valid) {
        throw ArgumentError('BotStatusConfig: streaming url must be valid');
      }
    }

    if (minIntervalSeconds <= 0 || maxIntervalSeconds <= 0) {
      throw ArgumentError(
        'BotStatusConfig: min/max interval must be greater than zero',
      );
    }

    if (maxIntervalSeconds < minIntervalSeconds) {
      throw ArgumentError(
        'BotStatusConfig: max interval cannot be smaller than min interval',
      );
    }
  }
}

/// Immutable configuration loaded from a bot ZIP export.
/// This is the single source of truth for the runner.
class BotConfig {
  final String token;
  final String prefix;
  final bool builtInLegacyHelpEnabled;
  final bool inboundWebhooks;
  final bool autoSharding;
  final bool autoRestart;
  final String? username;
  final String? avatarPath;
  final Map<String, bool> intents;
  final Map<String, dynamic> globalVariables;
  final Map<String, Map<String, Map<String, dynamic>>> scopedVariables;
  final List<Map<String, dynamic>> scopedVariableDefinitions;
  final List<Map<String, dynamic>> workflows;
  final List<Map<String, dynamic>> scheduledTriggers;
  final List<Map<String, dynamic>> inboundWebhookEndpoints;
  final String presenceStatus;
  final List<BotStatusConfig> statuses;

  static String normalizeScopedVariableKey(String rawKey) {
    final trimmed = rawKey.trim();
    if (trimmed.startsWith('bc_') && trimmed.length > 3) {
      return trimmed.substring(3);
    }
    return trimmed;
  }

  /// List of commands. Each entry looks like:
  /// { "id": "123456789", "name": "hello", "data": { "response": {...}, "actions": [...] } }
  final List<Map<String, dynamic>> commands;

  const BotConfig({
    required this.token,
    this.prefix = '!',
    this.builtInLegacyHelpEnabled = true,
    this.inboundWebhooks = false,
    this.autoSharding = false,
    this.autoRestart = false,
    this.username,
    this.avatarPath,
    this.intents = const {},
    this.globalVariables = const {},
    this.scopedVariables = const {},
    this.scopedVariableDefinitions = const [],
    this.workflows = const [],
    this.scheduledTriggers = const [],
    this.inboundWebhookEndpoints = const [],
    this.statuses = const [],
    this.presenceStatus = 'online',
    this.commands = const [],
  });

  BotConfig copyWith({
    String? token,
    String? prefix,
    bool? builtInLegacyHelpEnabled,
    bool? inboundWebhooks,
    bool? autoSharding,
    bool? autoRestart,
    String? username,
    String? avatarPath,
    Map<String, bool>? intents,
    Map<String, dynamic>? globalVariables,
    Map<String, Map<String, Map<String, dynamic>>>? scopedVariables,
    List<Map<String, dynamic>>? scopedVariableDefinitions,
    List<Map<String, dynamic>>? workflows,
    List<Map<String, dynamic>>? scheduledTriggers,
    List<Map<String, dynamic>>? inboundWebhookEndpoints,
    List<BotStatusConfig>? statuses,
    String? presenceStatus,
    List<Map<String, dynamic>>? commands,
  }) {
    return BotConfig(
      token: token ?? this.token,
      prefix: prefix ?? this.prefix,
      builtInLegacyHelpEnabled:
          builtInLegacyHelpEnabled ?? this.builtInLegacyHelpEnabled,
      inboundWebhooks: inboundWebhooks ?? this.inboundWebhooks,
      autoSharding: autoSharding ?? this.autoSharding,
      autoRestart: autoRestart ?? this.autoRestart,
      username: username ?? this.username,
      avatarPath: avatarPath ?? this.avatarPath,
      intents: intents ?? this.intents,
      globalVariables: globalVariables ?? this.globalVariables,
      scopedVariables: scopedVariables ?? this.scopedVariables,
      scopedVariableDefinitions:
          scopedVariableDefinitions ?? this.scopedVariableDefinitions,
      workflows: workflows ?? this.workflows,
      scheduledTriggers: scheduledTriggers ?? this.scheduledTriggers,
      inboundWebhookEndpoints:
          inboundWebhookEndpoints ?? this.inboundWebhookEndpoints,
      statuses: statuses ?? this.statuses,
      presenceStatus: presenceStatus ?? this.presenceStatus,
      commands: commands ?? this.commands,
    );
  }

  factory BotConfig.fromJson(Map<String, dynamic> json) {
    return BotConfig(
      token: (json['token'] ?? '').toString(),
      prefix:
          (json['prefix'] ?? '!').toString().trim().isEmpty
              ? '!'
              : (json['prefix'] ?? '!').toString(),
      builtInLegacyHelpEnabled: json['builtInLegacyHelpEnabled'] != false,
      inboundWebhooks: json['inboundWebhooks'] == true,
      autoSharding: json['autoSharding'] == true,
      autoRestart: json['autoRestart'] == true,
      username: _optionalString(json['username']),
      avatarPath: _optionalString(json['avatarPath']),
      intents: Map<String, bool>.from(
        (json['intents'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), v == true),
            ) ??
            const {},
      ),
      globalVariables: _normalizeVariableMap(json['globalVariables']),
      scopedVariables: _normalizeScopedVariables(json['scopedVariables']),
      scopedVariableDefinitions: _normalizeScopedVariableDefinitions(
        json['scopedVariableDefinitions'],
      ),
      workflows: List<Map<String, dynamic>>.from(
        (json['workflows'] as List?)?.whereType<Map>().map(
              (w) => normalizeStoredWorkflowDefinition(
                Map<String, dynamic>.from(w),
              ),
            ) ??
            const [],
      ),
      scheduledTriggers: List<Map<String, dynamic>>.from(
        (json['scheduledTriggers'] as List?)?.whereType<Map>().map(
              (trigger) => _normalizeScheduledTrigger(
                Map<String, dynamic>.from(trigger),
              ),
            ) ??
            const [],
      ),
      inboundWebhookEndpoints: List<Map<String, dynamic>>.from(
        (json['inboundWebhookEndpoints'] as List?)?.whereType<Map>().map(
              (entry) => _normalizeInboundWebhookEndpoint(
                Map<String, dynamic>.from(entry),
              ),
            ) ??
            const [],
      ),
      statuses: List<BotStatusConfig>.from(
        (json['statuses'] as List?)?.whereType<Map>().map(
              (s) => BotStatusConfig.fromJson(Map<String, dynamic>.from(s)),
            ) ??
            const [],
      ),
      presenceStatus: (json['presenceStatus'] ?? 'online').toString(),
      commands: List<Map<String, dynamic>>.from(
        (json['commands'] as List?)?.whereType<Map>().map(
              (c) => Map<String, dynamic>.from(c),
            ) ??
            const [],
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'token': token,
    'prefix': prefix,
    'builtInLegacyHelpEnabled': builtInLegacyHelpEnabled,
    'inboundWebhooks': inboundWebhooks,
    'autoSharding': autoSharding,
    'autoRestart': autoRestart,
    if (username != null) 'username': username,
    if (avatarPath != null) 'avatarPath': avatarPath,
    'intents': intents,
    'globalVariables': globalVariables,
    'scopedVariables': scopedVariables,
    'scopedVariableDefinitions': scopedVariableDefinitions,
    'workflows': workflows,
    'scheduledTriggers': scheduledTriggers,
    'inboundWebhookEndpoints': inboundWebhookEndpoints,
    'statuses': statuses.map((s) => s.toJson()).toList(growable: false),
    'presenceStatus': presenceStatus,
    'commands': commands,
  };

  /// Validates the minimal required fields.
  void validate() {
    if (token.trim().isEmpty) {
      throw ArgumentError('BotConfig: token cannot be empty');
    }

    if (username != null && username!.trim().isEmpty) {
      throw ArgumentError('BotConfig: username cannot be blank');
    }

    if (avatarPath != null && avatarPath!.trim().isEmpty) {
      throw ArgumentError('BotConfig: avatarPath cannot be blank');
    }

    for (final status in statuses) {
      status.validate();
    }
  }

  @override
  String toString() =>
      'BotConfig(commands: ${commands.length}, workflows: ${workflows.length}, scheduledTriggers: ${scheduledTriggers.length})';
}

Map<String, dynamic> _normalizeScheduledTrigger(Map<String, dynamic> raw) {
  final id = (raw['id'] ?? '').toString().trim();
  final workflowName = (raw['workflowName'] ?? '').toString().trim();
  final label = (raw['label'] ?? workflowName).toString().trim();
  final minutesRaw = int.tryParse((raw['everyMinutes'] ?? '').toString());
  final everyMinutes =
      (minutesRaw != null && minutesRaw > 0) ? minutesRaw.clamp(1, 10080) : 60;
  final enabled = raw['enabled'] != false;

  return <String, dynamic>{
    'id': id,
    'workflowName': workflowName,
    'label': label,
    'everyMinutes': everyMinutes,
    'enabled': enabled,
    if (raw['createdAt'] != null) 'createdAt': raw['createdAt'],
    if (raw['updatedAt'] != null) 'updatedAt': raw['updatedAt'],
  };
}

Map<String, dynamic> _normalizeInboundWebhookEndpoint(
  Map<String, dynamic> raw,
) {
  final id = (raw['id'] ?? '').toString().trim();
  final path = _normalizeInboundWebhookPath((raw['path'] ?? '').toString());
  final workflowName = (raw['workflowName'] ?? '').toString().trim();
  final secret = (raw['secret'] ?? '').toString().trim();
  final enabled = raw['enabled'] != false;

  return <String, dynamic>{
    'id': id,
    'path': path,
    'workflowName': workflowName,
    'secret': secret,
    'enabled': enabled,
    if (raw['createdAt'] != null) 'createdAt': raw['createdAt'],
    if (raw['updatedAt'] != null) 'updatedAt': raw['updatedAt'],
  };
}

String _normalizeInboundWebhookPath(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  final noLeading = trimmed.replaceFirst(RegExp(r'^/+'), '');
  return noLeading.replaceAll(RegExp(r'/+'), '/');
}

String? _optionalString(dynamic value) {
  final text = (value ?? '').toString().trim();
  return text.isEmpty ? null : text;
}

Map<String, dynamic> _normalizeVariableMap(dynamic raw) {
  final source =
      (raw is Map)
          ? Map<String, dynamic>.from(raw.cast<String, dynamic>())
          : const <String, dynamic>{};

  final normalized = <String, dynamic>{};
  for (final entry in source.entries) {
    normalized[entry.key] = _normalizeVariableValue(entry.value);
  }
  return normalized;
}

Map<String, Map<String, Map<String, dynamic>>> _normalizeScopedVariables(
  dynamic raw,
) {
  final scopes =
      (raw is Map)
          ? Map<String, dynamic>.from(raw.cast<String, dynamic>())
          : const <String, dynamic>{};

  final normalized = <String, Map<String, Map<String, dynamic>>>{};
  for (final scopeEntry in scopes.entries) {
    final ids =
        (scopeEntry.value is Map)
            ? Map<String, dynamic>.from(
              (scopeEntry.value as Map).cast<String, dynamic>(),
            )
            : const <String, dynamic>{};

    final scopeValues = <String, Map<String, dynamic>>{};
    for (final idEntry in ids.entries) {
      scopeValues[idEntry.key] = _normalizeVariableMap(idEntry.value);
    }

    normalized[scopeEntry.key] = scopeValues;
  }
  return normalized;
}

List<Map<String, dynamic>> _normalizeScopedVariableDefinitions(dynamic raw) {
  if (raw is! List) {
    return const <Map<String, dynamic>>[];
  }
  return raw
      .whereType<Map>()
      .map((entry) {
        final map = Map<String, dynamic>.from(entry.cast<String, dynamic>());
        return <String, dynamic>{
          'key': (map['key'] ?? '').toString(),
          'scope': (map['scope'] ?? '').toString(),
          'defaultValue': _normalizeVariableValue(map['defaultValue'] ?? map['default_value']),
          'valueType': (map['valueType'] ?? 'string').toString(),
        };
      })
      .where(
        (entry) =>
            (entry['key'] ?? '').toString().trim().isNotEmpty &&
            (entry['scope'] ?? '').toString().trim().isNotEmpty,
      )
      .toList(growable: false);
}

dynamic _normalizeVariableValue(dynamic value) {
  if (value == null || value is num || value is bool || value is String) {
    return value;
  }

  if (value is List) {
    return value.map(_normalizeVariableValue).toList(growable: false);
  }

  if (value is Map) {
    return value.map(
      (key, value) => MapEntry(key.toString(), _normalizeVariableValue(value)),
    );
  }

  final text = (value ?? '').toString();
  final asNum = num.tryParse(text);
  if (asNum != null) {
    return asNum;
  }
  return text;
}

/// Parses a [BotConfig] from raw JSON bytes or a JSON string.
BotConfig parseBotConfig(String jsonString) {
  final Map<String, dynamic> json =
      jsonDecode(jsonString) as Map<String, dynamic>;
  return BotConfig.fromJson(json);
}
