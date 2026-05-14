import 'dart:convert';

import '../bot/bot_data_store.dart';
import '../types/action.dart';
import 'template_resolver.dart';

bool _isInvalidContextId(String? value) {
  final normalized = (value ?? '').trim().toLowerCase();
  return normalized.isEmpty ||
      normalized == 'unknown user' ||
      normalized == 'dm';
}

String? _normalizeContextId(String? value) {
  final trimmed = (value ?? '').trim();
  return _isInvalidContextId(trimmed) ? null : trimmed;
}

String _normalizeScopedStorageKey(String key) {
  final trimmed = key.trim();
  if (trimmed.startsWith('bc_') && trimmed.length > 3) {
    return trimmed.substring(3);
  }
  return trimmed;
}

bool _isMissingOrEmptyValue(dynamic value) {
  if (value == null) {
    return true;
  }
  if (value is String) {
    return value.trim().isEmpty;
  }
  return false;
}

List<String> _legacyContextIdsForScope(
  String scope,
  String? canonicalContextId,
) {
  switch (scope) {
    case 'user':
      return const <String>['Unknown User'];
    case 'guild':
    case 'channel':
      return const <String>['DM'];
    case 'guildMember':
      final parts = (canonicalContextId ?? '').split(':');
      final guild = parts.isNotEmpty ? parts.first.trim() : '';
      final user = parts.length > 1 ? parts[1].trim() : '';
      return <String>{
        'DM:Unknown User',
        if (guild.isNotEmpty) '$guild:Unknown User',
        if (user.isNotEmpty) 'DM:$user',
      }.toList(growable: false);
    default:
      return const <String>[];
  }
}

String stringifyRuntimeVariableValue(dynamic value) {
  if (value == null) {
    return '';
  }
  if (value is String) {
    return value;
  }
  if (value is List || value is Map) {
    return jsonEncode(value);
  }
  return value.toString();
}

Future<void> injectGlobalRuntimeVariables({
  required BotDataStore store,
  required String botId,
  required Map<String, String> runtimeVariables,
}) async {
  final globalVars = await store.getGlobalVariables(botId);
  for (final entry in globalVars.entries) {
    runtimeVariables['global.${entry.key}'] = stringifyRuntimeVariableValue(
      entry.value,
    );
  }
  runtimeVariables['variables.count'] = globalVars.length.toString();
}

Future<void> injectScopedRuntimeVariables({
  required BotDataStore store,
  required String botId,
  required String scope,
  required String? contextId,
  required Map<String, String> runtimeVariables,
  List<String> legacyContextIds = const <String>[],
  List<Map<String, dynamic>> scopedDefinitions = const <Map<String, dynamic>>[],
}) async {
  final normalizedContextId = _normalizeContextId(contextId);
  Map<String, dynamic> values = <String, dynamic>{};
  if (normalizedContextId != null) {
    values = await store.getScopedVariables(botId, scope, normalizedContextId);
  }
  if (values.isEmpty) {
    for (final candidate in legacyContextIds) {
      final legacyContextId = candidate.trim();
      if (legacyContextId.isEmpty) {
        continue;
      }
      values = await store.getScopedVariables(botId, scope, legacyContextId);
      if (values.isNotEmpty) {
        if (normalizedContextId != null &&
            normalizedContextId != legacyContextId) {
          for (final entry in values.entries) {
            await store.setScopedVariable(
              botId,
              scope,
              normalizedContextId,
              entry.key.toString(),
              entry.value,
            );
          }
        }
        break;
      }
    }
  }

  if (scopedDefinitions.isNotEmpty) {
    for (final definition in scopedDefinitions) {
      final definitionScope = (definition['scope'] ?? '').toString().trim();
      if (definitionScope != scope) {
        continue;
      }

      final normalizedKey = _normalizeScopedStorageKey(
        (definition['key'] ?? '').toString(),
      );
      if (normalizedKey.isEmpty) {
        continue;
      }

      final existingValue =
          values.containsKey(normalizedKey)
              ? values[normalizedKey]
              : values['bc_$normalizedKey'];
      if (!_isMissingOrEmptyValue(existingValue)) {
        continue;
      }

      if (!definition.containsKey('defaultValue')) {
        continue;
      }

      values[normalizedKey] = definition['defaultValue'];
    }
  }

  for (final entry in values.entries) {
    final rawKey = entry.key.toString().trim();
    if (rawKey.isEmpty) {
      continue;
    }

    final canonicalKey = rawKey.startsWith('bc_') ? rawKey : 'bc_$rawKey';
    final value = stringifyRuntimeVariableValue(entry.value);

    runtimeVariables['$scope.$canonicalKey'] = value;
    runtimeVariables['$scope.$rawKey'] = value;
    
    if (normalizedContextId != null) {
      runtimeVariables['$scope[$normalizedContextId].$canonicalKey'] = value;
      runtimeVariables['$scope[$normalizedContextId].$rawKey'] = value;
    }
  }
}

Future<void> hydrateRuntimeVariables({
  required BotDataStore store,
  required String botId,
  required Map<String, String> runtimeVariables,
  String? guildContextId,
  String? channelContextId,
  String? userContextId,
  String? messageContextId,
}) async {
  runtimeVariables['bot.id'] = botId;
  List<Map<String, dynamic>> scopedDefinitions = const <Map<String, dynamic>>[];
  try {
    scopedDefinitions = await store.getScopedVariableDefinitions(botId);
  } catch (_) {
    scopedDefinitions = const <Map<String, dynamic>>[];
  }

  await injectGlobalRuntimeVariables(
    store: store,
    botId: botId,
    runtimeVariables: runtimeVariables,
  );

  final normalizedGuildId = _normalizeContextId(guildContextId);
  final normalizedUserId = _normalizeContextId(userContextId);
  final guildMemberContextId =
      normalizedGuildId != null && normalizedUserId != null
          ? '$normalizedGuildId:$normalizedUserId'
          : null;

  await Future.wait([
    injectScopedRuntimeVariables(
      store: store,
      botId: botId,
      scope: 'guild',
      contextId: guildContextId,
      runtimeVariables: runtimeVariables,
      legacyContextIds: _legacyContextIdsForScope('guild', guildContextId),
      scopedDefinitions: scopedDefinitions,
    ),
    injectScopedRuntimeVariables(
      store: store,
      botId: botId,
      scope: 'channel',
      contextId: channelContextId,
      runtimeVariables: runtimeVariables,
      legacyContextIds: _legacyContextIdsForScope('channel', channelContextId),
      scopedDefinitions: scopedDefinitions,
    ),
    injectScopedRuntimeVariables(
      store: store,
      botId: botId,
      scope: 'user',
      contextId: userContextId,
      runtimeVariables: runtimeVariables,
      legacyContextIds: _legacyContextIdsForScope('user', userContextId),
      scopedDefinitions: scopedDefinitions,
    ),
    injectScopedRuntimeVariables(
      store: store,
      botId: botId,
      scope: 'guildMember',
      contextId: guildMemberContextId,
      runtimeVariables: runtimeVariables,
      legacyContextIds: _legacyContextIdsForScope(
        'guildMember',
        guildMemberContextId,
      ),
      scopedDefinitions: scopedDefinitions,
    ),
    injectScopedRuntimeVariables(
      store: store,
      botId: botId,
      scope: 'message',
      contextId: messageContextId,
      runtimeVariables: runtimeVariables,
      legacyContextIds: _legacyContextIdsForScope('message', messageContextId),
      scopedDefinitions: scopedDefinitions,
    ),
  ]);
}
Future<void> hydrateSpecificScopedVariables({
  required BotDataStore store,
  required String botId,
  required String scope,
  required String contextId,
  required Map<String, String> runtimeVariables,
}) async {
  final normalizedContextId = _normalizeContextId(contextId);
  if (normalizedContextId == null) return;

  final values = await store.getScopedVariables(botId, scope, normalizedContextId);
  if (values.isEmpty) return;

  for (final entry in values.entries) {
    final rawKey = entry.key.toString().trim();
    if (rawKey.isEmpty) {
      continue;
    }

    final canonicalKey = rawKey.startsWith('bc_') ? rawKey : 'bc_$rawKey';
    final value = stringifyRuntimeVariableValue(entry.value);

    runtimeVariables['$scope[$normalizedContextId].$canonicalKey'] = value;
    runtimeVariables['$scope[$normalizedContextId].$rawKey'] = value;
  }
}

Future<void> hydrateActionPlaceholders({
  required BotDataStore store,
  required String botId,
  required List<dynamic> actions,
  required Map<String, String> variables,
  Future<void> Function(
    String scope,
    String contextId,
    Map<String, String> variables,
  )?
  discordFetcher,
}) async {
  final placeholderPattern = RegExp(r'\(\(([a-z]+)\[([^\]]+)\]\.([a-zA-Z_]+)');
  final bdfdFunctionPattern = RegExp(
    r'\$(?:get(?:User|Guild|Channel|Message)Var)\[[^;]+;([^\]\s]+)\]',
  );

  final scopedContextsToFetch = <(String scope, String contextId)>{};
  final discordContextsToFetch = <(String scope, String contextId)>{};

  void scan(dynamic obj) {
    if (obj is String) {
      // 1. Scan for internal placeholders ((user[ID].username)) or ((user[ID].bc_var))
      for (final match in placeholderPattern.allMatches(obj)) {
        final scope = match.group(1)!;
        var contextId = match.group(2)!;
        final property = match.group(3)!;

        if (contextId.contains('((')) {
          contextId = resolveTemplatePlaceholders(contextId, variables);
        }
        if (contextId.isNotEmpty &&
            contextId != 'unknown user' &&
            contextId != 'dm') {
          if (property.startsWith('bc_')) {
            scopedContextsToFetch.add((scope, contextId));
          } else {
            discordContextsToFetch.add((scope, contextId));
          }
        }
      }

      // 2. Scan for BDFD functions $getUserVar[name;ID]
      for (final match in bdfdFunctionPattern.allMatches(obj)) {
        final raw = match.group(0)!;
        final scope =
            raw.contains('User')
                ? 'user'
                : (raw.contains('Guild')
                    ? 'guild'
                    : (raw.contains('Channel') ? 'channel' : 'message'));
        var contextId = match.group(1)!;
        if (contextId.contains('((')) {
          contextId = resolveTemplatePlaceholders(contextId, variables);
        }
        if (contextId.isNotEmpty &&
            contextId != 'unknown user' &&
            contextId != 'dm') {
          scopedContextsToFetch.add((scope, contextId));
        }
      }
    } else if (obj is Map) {
      for (final value in obj.values) {
        scan(value);
      }
    } else if (obj is List) {
      for (final item in obj) {
        scan(item);
      }
    }
  }

  // Scan variables first (important for $eval[$message])
  for (final value in variables.values) {
    scan(value);
  }

  for (final action in actions) {
    if (action is Map && action.containsKey('payload')) {
      scan(action['payload']);
    } else if (action is Action) {
      scan(action.payload);
    }
  }

  final futures = <Future<void>>[];

  if (scopedContextsToFetch.isNotEmpty) {
    futures.addAll(
      scopedContextsToFetch.map(
        (m) => hydrateSpecificScopedVariables(
          store: store,
          botId: botId,
          scope: m.$1,
          contextId: m.$2,
          runtimeVariables: variables,
        ),
      ),
    );
  }

  if (discordContextsToFetch.isNotEmpty && discordFetcher != null) {
    futures.addAll(
      discordContextsToFetch.map(
        (m) => discordFetcher(m.$1, m.$2, variables),
      ),
    );
  }

  if (futures.isEmpty) {
    return;
  }
  await Future.wait(futures);
}
