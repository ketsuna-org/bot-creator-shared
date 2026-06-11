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

  // Collect defaults that replaced empty/missing values so they can be
  // persisted back to the store.  Without this, `$getUserVar[cash]`
  // would return "" forever even though the definition says the default
  // is 0, because the empty string is never corrected in the DB.
  final defaultsToPersist = <(String key, dynamic value)>[];

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

      final defaultValue = definition['defaultValue'];

      // Only persist non-trivial defaults (not null / empty-string).
      // This prevents overwriting a legitimate empty-string value or
      // writing stale defaults for definitions that intentionally
      // default to "".
      if (defaultValue != null &&
          !(defaultValue is String && defaultValue.trim().isEmpty)) {
        defaultsToPersist.add((normalizedKey, defaultValue));
      }

      values[normalizedKey] = defaultValue;
    }
  }

  // Persist the defaults that replaced empty/missing values so that
  // subsequent reads (including the admin UI table) see the correct
  // value instead of "".
  if (normalizedContextId != null && defaultsToPersist.isNotEmpty) {
    for (final (key, value) in defaultsToPersist) {
      await store.setScopedVariable(
        botId,
        scope,
        normalizedContextId,
        key,
        value,
      );
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
  int guildCount = 0,
  int uptimeMs = 0,
  int pingMs = 0,
}) async {
  injectAlwaysAvailableVariables(
    runtimeVariables,
    botId: botId,
    guildCount: guildCount,
    uptimeMs: uptimeMs,
    pingMs: pingMs,
  );
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

/// Walks [input] and collects all `scope[contextId].property` patterns using
/// bracket-depth-aware matching. Unlike a naive regex `[^\]]+`, this correctly
/// handles nested `[...]` inside `((...))` placeholders such as
/// `member[((message.mentions[0]))].displayName`.
void _collectScopedPlaceholders(
  String input,
  List<(String, String, String)> out,
) {
  // Look for a known scope name followed by '['
  final scopeStartPattern = RegExp(r'\b(member|user|guild|channel|role|emoji|message|webhook|temp|bot)\[');
  for (final match in scopeStartPattern.allMatches(input)) {
    final scope = match.group(1)!;
    final bracketStart = match.end - 1; // position of '['
    var depth = 0;
    var pos = bracketStart;
    // Walk until we find the matching ']'
    while (pos < input.length) {
      final ch = input[pos];
      if (ch == '[') {
        depth++;
      } else if (ch == ']') {
        depth--;
        if (depth == 0) {
          // Found the closing bracket. Check if followed by '.property'
          final afterBracket = pos + 1;
          if (afterBracket < input.length && input[afterBracket] == '.') {
            // Read the property name
            final propStart = afterBracket + 1;
            var propEnd = propStart;
            while (propEnd < input.length &&
                RegExp(r'[a-zA-Z_]').hasMatch(input[propEnd])) {
              propEnd++;
            }
            if (propEnd > propStart) {
              final contextId = input.substring(bracketStart + 1, pos);
              final property = input.substring(propStart, propEnd);
              out.add((scope, contextId, property));
            }
          }
          break;
        }
      }
      pos++;
    }
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
  Set<dynamic>? hydratedActions,
}) async {
  // Legacy regex pattern kept for reference; bracket-depth-aware walker
  // (_collectScopedPlaceholders) is used instead for correctness with
  // nested placeholders like member[((message.mentions[0]))].displayName.
  // ignore: unused_local_variable
  final placeholderPattern = RegExp(r'\b([a-z]+)\[([^\]]+)\]\.([a-zA-Z_]+)');
  final bdfdFunctionPattern = RegExp(
    r'\$(?:get(?:User|Guild|Channel|Message)Var)\[[^;]+;([^\]\s]+)\]',
  );

  final scopedContextsToFetch = <(String scope, String contextId)>{};
  final discordContextsToFetch = <(String scope, String contextId)>{};
  final activeHydratedActions = hydratedActions ?? <dynamic>{};

  void scan(dynamic obj) {
    if (obj == null) return;
    if (activeHydratedActions.contains(obj)) return;
    
    if (obj is String) {
      // String scanning is still needed as its content might contain placeholders
      // that resolve differently based on current variables.
      // However, if the string doesn't contain placeholders, we could skip it.
      if (!obj.contains('((') && !obj.contains(r'$')) {
         activeHydratedActions.add(obj);
         return;
      }
      
      // 1. Scan for internal placeholders ((user[ID].username)) or ((user[ID].bc_var))
      //
      // Use a bracket-depth-aware walker instead of a naive regex so that
      // nested [...] inside ((...)) placeholders (e.g.
      // member[((message.mentions[0]))].displayName) are handled correctly.
      // The regex [^\]]+ would stop at the first ']' inside mentions[0],
      // producing a malformed contextId like "((message.mentions[0".
      final matches = <(String, String, String)>[];
      _collectScopedPlaceholders(obj, matches);
      
      for (final match in matches) {
        final scope = match.$1;
        var contextId = match.$2;
        final property = match.$3;
        
        // Resolve any remaining ((...)) in the contextId (e.g. when
        // the ID was a bare placeholder like user[(("author.id"))].username).
        if (contextId.contains('((')) {
          contextId = resolveTemplatePlaceholders(contextId, variables).trim();
          if (contextId.isEmpty) continue;
        }
        if (contextId.isNotEmpty &&
            contextId != 'unknown user' &&
            contextId != 'dm') {
          if (property.startsWith('bc_')) {
            final varKey = '$scope[$contextId].$property';
            if (!variables.containsKey(varKey)) {
              scopedContextsToFetch.add((scope, contextId));
            }
          } else {
            final varKey = '$scope[$contextId].$property';
            if (!variables.containsKey(varKey)) {
              discordContextsToFetch.add((scope, contextId));
            }
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
      
      // We don't mark strings as hydrated because they are values, 
      // and the same string literal might appear multiple times.
      // But we can mark the Action objects.
    } else if (obj is Map) {
      activeHydratedActions.add(obj);
      for (final value in obj.values) {
        scan(value);
      }
    } else if (obj is List) {
      activeHydratedActions.add(obj);
      for (final item in obj) {
        scan(item);
      }
    } else if (obj is Action) {
      activeHydratedActions.add(obj);
      scan(obj.payload);
    }
  }

  // Scan variables first (important for $eval[$message])
  for (final value in variables.values) {
    scan(value);
  }

  for (final action in actions) {
     scan(action);
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
        ).catchError((e) {
          // Ignore individual hydration errors to allow fallbacks
        }),
      ),
    );
  }

  if (discordContextsToFetch.isNotEmpty && discordFetcher != null) {
    futures.addAll(
      discordContextsToFetch.map(
        (m) => discordFetcher(m.$1, m.$2, variables).catchError((e) {
          // Ignore individual hydration errors to allow fallbacks
        }),
      ),
    );
  }

  if (futures.isEmpty) {
    return;
  }
  await Future.wait(futures);
}

/// Applies workflow-level event variable aliases to a runtime variables map.
///
/// If the workflow defines [eventVariableAliases] (originalName → alias),
/// each aliased name is set to the value of its original. The original keys
/// are kept intact for backward compatibility.
void applyEventVariableAliases(
  Map<String, String> runtimeVariables,
  Map<String, dynamic>? workflowData,
) {
  final rawAliases = workflowData?['eventVariableAliases'];
  if (rawAliases is! Map || rawAliases.isEmpty) return;

  for (final entry in rawAliases.entries) {
    final original = entry.key.toString();
    final alias = entry.value?.toString() ?? '';
    if (original.isEmpty || alias.isEmpty) continue;

    final value = runtimeVariables[original];
    if (value != null) {
      runtimeVariables[alias] = value;
    }
  }
}
