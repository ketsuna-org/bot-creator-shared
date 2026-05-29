import 'dart:convert';

import 'package:bot_creator_shared/bot/bot_data_store.dart';
import 'package:bot_creator_shared/utils/command_autocomplete.dart';
import 'package:bot_creator_shared/utils/template_resolver.dart';
import 'package:nyxx/nyxx.dart';

import '../../types/action.dart';
import 'control_flow_executor.dart';

const _supportedVariableScopes = <String>{
  'guild',
  'user',
  'channel',
  'guildMember',
  'message',
};

String _scopedStorageKey(String rawKey) {
  final key = rawKey.trim();
  if (key.isEmpty) {
    throw Exception('key is required for scoped variables');
  }
  if (key.startsWith('bc_')) {
    if (key.length <= 3) {
      throw Exception('key is required for scoped variables');
    }
    return key.substring(3);
  }
  return key;
}

String _scopedReferenceKey(String rawKey) {
  final key = rawKey.trim();
  if (key.isEmpty) {
    throw Exception('key is required for scoped variables');
  }
  return key.startsWith('bc_') ? key : 'bc_$key';
}

String _inferDefinitionValueType(dynamic value) {
  if (value is num) {
    return 'number';
  }
  if (value is bool) {
    return 'bool';
  }
  if (value is List || value is Map<String, dynamic>) {
    return 'json';
  }
  return 'string';
}

Future<void> _ensureScopedDefinitionExists({
  required BotDataStore store,
  required String botId,
  required String scope,
  required String storageKey,
  required dynamic defaultValue,
}) async {
  final definitions = await store.getScopedVariableDefinitions(botId);
  final exists = definitions.any((entry) {
    final entryScope = (entry['scope'] ?? '').toString().trim().toLowerCase();
    final entryKeyRaw = (entry['key'] ?? '').toString().trim().toLowerCase();
    if (entryScope != scope.toLowerCase() || entryKeyRaw.isEmpty) {
      return false;
    }
    try {
      return _scopedStorageKey(entryKeyRaw).toLowerCase() == storageKey.toLowerCase();
    } catch (_) {
      return false;
    }
  });
  if (exists) {
    return;
  }

  await store.setScopedVariableDefinition(
    botId,
    storageKey,
    scope,
    defaultValue,
    valueType: _inferDefinitionValueType(defaultValue),
  );
}

dynamic _resolveVariableValuePayload(
  Map<String, dynamic> payload,
  String Function(String input) resolveValue,
) {
  final valueType =
      (payload['valueType'] ?? '').toString().trim().toLowerCase();
  if (valueType == 'number') {
    final rawNumber =
        resolveValue((payload['numberValue'] ?? '').toString()).trim();
    final number = num.tryParse(rawNumber);
    if (number == null) {
      throw Exception(
        'numberValue is required and must be numeric when valueType=number',
      );
    }
    return number;
  }

  if (payload.containsKey('value') && payload['value'] is num) {
    return payload['value'] as num;
  }

  if (payload.containsKey('element') && payload['element'] is num) {
    return payload['element'] as num;
  }

  if (valueType == 'boolean' || valueType == 'bool') {
    final rawBool =
        resolveValue(
          (payload['boolValue'] ?? '').toString(),
        ).trim().toLowerCase();
    if (rawBool == 'true') {
      return true;
    }
    if (rawBool == 'false') {
      return false;
    }
    throw Exception(
      'boolValue is required and must be true or false when valueType=boolean',
    );
  }

  if (valueType == 'json') {
    final rawJson =
        resolveValue((payload['jsonValue'] ?? '').toString()).trim();
    if (rawJson.isEmpty) {
      throw Exception('jsonValue is required when valueType=json');
    }
    try {
      return jsonDecode(rawJson);
    } catch (error) {
      throw Exception('jsonValue must be valid JSON: $error');
    }
  }

  final rawValue =
      payload.containsKey('value') ? payload['value'] : payload['element'];
  return resolveValue((rawValue ?? '').toString());
}

({
  dynamic value,
  String rawValueSource,
  String resolvedByResolver,
  String fallbackResolved,
  String directFallbackResolved,
})
_resolveRuntimeVariableWriteValue({
  required Map<String, dynamic> payload,
  required String Function(String input) resolveValue,
  required Map<String, String> variables,
  required Map<String, String> results,
}) {
  final rawValueSource =
      payload.containsKey('value')
          ? (payload['value'] ?? '').toString()
          : (payload['element'] ?? '').toString();
  dynamic value = _resolveVariableValuePayload(payload, resolveValue);
  final resolvedByResolver = value is String ? value : value.toString();
  var fallbackResolved = '';
  var directFallbackResolved = '';

  if (value is String &&
      rawValueSource.contains('((') &&
      rawValueSource.contains('))') &&
      (value.isEmpty || (value.contains('((') && value.contains('))')))) {
    final mergedContext = <String, String>{...variables, ...results};
    final fallback = resolveTemplatePlaceholders(rawValueSource, mergedContext);
    fallbackResolved = fallback;
    if (fallback.isNotEmpty && fallback != rawValueSource) {
      value = fallback;
    } else {
      final directFallback = _lookupMergedContextValue(
        rawValueSource,
        mergedContext,
      );
      directFallbackResolved = directFallback;
      if (directFallback.isNotEmpty) {
        value = directFallback;
      }
    }
  }

  if (value is String &&
      value.isEmpty &&
      rawValueSource.trim().toLowerCase() == r'$jsonstringify') {
    final mergedContext = <String, String>{...variables, ...results};
    final latestJson = _lookupLatestRuntimeJsonValue(mergedContext);
    if (latestJson.isNotEmpty) {
      value = latestJson;
    }
  }

  return (
    value: value,
    rawValueSource: rawValueSource,
    resolvedByResolver: resolvedByResolver,
    fallbackResolved: fallbackResolved,
    directFallbackResolved: directFallbackResolved,
  );
}

String _stringifyRuntimeValue(dynamic value) {
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

bool _looksLikeJsonPayload(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return false;
  }
  if (!((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
      (trimmed.startsWith('[') && trimmed.endsWith(']')))) {
    return false;
  }
  try {
    jsonDecode(trimmed);
    return true;
  } catch (_) {
    return false;
  }
}

int _actionKeyIndex(String key) {
  final match = RegExp(r'^action_(\d+)').firstMatch(key.toLowerCase());
  return int.tryParse(match?.group(1) ?? '') ?? -1;
}

String _lookupMergedContextValue(
  String rawValueSource,
  Map<String, String> mergedContext,
) {
  final match = RegExp(r'^\s*\(\((.+)\)\)\s*$').firstMatch(rawValueSource);
  if (match == null) {
    return '';
  }

  final requestedKey = (match.group(1) ?? '').trim();
  if (requestedKey.isEmpty) {
    return '';
  }

  if (mergedContext.containsKey(requestedKey)) {
    return mergedContext[requestedKey] ?? '';
  }

  final jsonReadKeyMatch = RegExp(r'^(.+)\.json_\d+$').firstMatch(requestedKey);
  if (jsonReadKeyMatch != null) {
    final rootKey = (jsonReadKeyMatch.group(1) ?? '').trim();
    if (rootKey.isNotEmpty && mergedContext.containsKey(rootKey)) {
      return mergedContext[rootKey] ?? '';
    }
  }

  final requestedKeyLower = requestedKey.toLowerCase();
  for (final entry in mergedContext.entries) {
    if (entry.key.toLowerCase() == requestedKeyLower) {
      return entry.value;
    }
  }

  if (jsonReadKeyMatch != null) {
    final rootKey = (jsonReadKeyMatch.group(1) ?? '').trim().toLowerCase();
    if (rootKey.isNotEmpty) {
      for (final entry in mergedContext.entries) {
        if (entry.key.toLowerCase() == rootKey) {
          return entry.value;
        }
      }
    }
  }

  // Some execution paths may rewrite action keys (for example from rtJson_0 to
  // action_1). If the script still references rtJson_* placeholders, map them
  // to equivalent action_* keys.
  final aliasMatch = RegExp(
    r'^(rtJson_\d+)(\.json_\d+)?$',
    caseSensitive: false,
  ).firstMatch(requestedKey);
  if (aliasMatch != null) {
    final suffix = aliasMatch.group(2) ?? '';
    final actionKeyPattern =
        suffix.isEmpty
            ? RegExp(r'^action_\d+$', caseSensitive: false)
            : RegExp(
              '^action_\\d+${RegExp.escape(suffix)}'
              r'$',
              caseSensitive: false,
            );
    final matching = mergedContext.entries
        .where(
          (entry) =>
              actionKeyPattern.hasMatch(entry.key) &&
              entry.value.trim().isNotEmpty,
        )
        .toList(growable: false);
    if (matching.isNotEmpty) {
      matching.sort((left, right) {
        final leftJson = _looksLikeJsonPayload(left.value) ? 1 : 0;
        final rightJson = _looksLikeJsonPayload(right.value) ? 1 : 0;
        if (leftJson != rightJson) {
          return rightJson.compareTo(leftJson);
        }
        return _actionKeyIndex(right.key).compareTo(_actionKeyIndex(left.key));
      });
      return matching.first.value;
    }
  }

  return '';
}

String _lookupLatestRuntimeJsonValue(Map<String, String> mergedContext) {
  final candidates = mergedContext.entries
      .where((entry) {
        final key = entry.key.toLowerCase();
        if (entry.value.trim().isEmpty) {
          return false;
        }
        if (key.startsWith('rtjson_')) {
          return true;
        }
        if (RegExp(r'^action_\d+(\.json_\d+)?$').hasMatch(key)) {
          return true;
        }
        return false;
      })
      .toList(growable: false);

  if (candidates.isEmpty) {
    return '';
  }

  candidates.sort((left, right) {
    final leftJson = _looksLikeJsonPayload(left.value) ? 1 : 0;
    final rightJson = _looksLikeJsonPayload(right.value) ? 1 : 0;
    if (leftJson != rightJson) {
      return rightJson.compareTo(leftJson);
    }
    final leftPriority = left.key.toLowerCase().contains('.json_') ? 1 : 0;
    final rightPriority = right.key.toLowerCase().contains('.json_') ? 1 : 0;
    if (leftPriority != rightPriority) {
      return rightPriority.compareTo(leftPriority);
    }
    return _actionKeyIndex(right.key).compareTo(_actionKeyIndex(left.key));
  });

  return candidates.first.value;
}

bool _isInvalidContextId(String? value) {
  final normalized = (value ?? '').trim().toLowerCase();
  return normalized.isEmpty ||
      normalized == 'unknown user' ||
      normalized == 'dm';
}

String? resolveScopeContextId({
  required String scope,
  required Map<String, String> variables,
  Snowflake? guildId,
  Snowflake? channelId,
  Interaction? interaction,
}) {
  String? normalize(dynamic value) {
    final text = (value ?? '').toString().trim();
    return _isInvalidContextId(text) ? null : text;
  }

  String? fromVariables(List<String> keys) {
    for (final key in keys) {
      final value = normalize(variables[key]);
      if (value != null) {
        return value;
      }
    }
    return null;
  }

  String? fromSnowflake(Snowflake? value) {
    return normalize(value?.toString());
  }

  String? interactionUserId() {
    final dynamic raw = interaction;
    return normalize(
      raw?.user?.id ??
          raw?.member?.user?.id ??
          raw?.member?.id ??
          raw?.interaction?.user?.id ??
          raw?.interaction?.member?.user?.id ??
          raw?.author?.id,
    );
  }

  String? interactionGuildId() {
    final dynamic raw = interaction;
    return normalize(
      raw?.guildId ?? raw?.guild?.id ?? raw?.interaction?.guildId,
    );
  }

  String? interactionChannelId() {
    final dynamic raw = interaction;
    return normalize(
      raw?.channelId ??
          raw?.channel?.id ??
          raw?.message?.channelId ??
          raw?.interaction?.channelId,
    );
  }

  String? interactionMessageId() {
    final dynamic raw = interaction;
    return normalize(raw?.message?.id ?? raw?.id);
  }

  switch (scope) {
    case 'guild':
      return fromVariables(<String>[
            'guildId',
            'guild.id',
            'interaction.guildId',
            'interaction.guild.id',
          ]) ??
          interactionGuildId() ??
          fromSnowflake(guildId);
    case 'channel':
      return fromVariables(<String>[
            'channelId',
            'channel.id',
            'interaction.channelId',
            'interaction.channel.id',
          ]) ??
          interactionChannelId() ??
          fromSnowflake(channelId);
    case 'user':
      return fromVariables(<String>[
            'userId',
            'user.id',
            'interaction.userId',
            'interaction.user.id',
            'author.id',
            'member.id',
            'interaction.member.id',
          ]) ??
          interactionUserId();
    case 'guildMember':
      final guild =
          fromVariables(<String>[
            'guildId',
            'guild.id',
            'interaction.guildId',
            'interaction.guild.id',
          ]) ??
          interactionGuildId() ??
          fromSnowflake(guildId);
      final user =
          fromVariables(<String>[
            'userId',
            'user.id',
            'interaction.userId',
            'interaction.user.id',
            'author.id',
            'member.id',
            'interaction.member.id',
          ]) ??
          interactionUserId();
      if (guild == null || user == null) {
        return null;
      }
      return '$guild:$user';
    case 'message':
      return fromVariables(<String>[
            'messageId',
            'message.id',
            'interaction.messageId',
            'interaction.message.id',
          ]) ??
          interactionMessageId();
    default:
      return null;
  }
}

dynamic _deepCloneJsonValue(dynamic value) {
  if (value == null) {
    return null;
  }
  return jsonDecode(jsonEncode(value));
}

String _normalizeJsonPath(dynamic rawPath) {
  final text = (rawPath ?? '').toString().trim();
  return text.isEmpty ? r'$' : text;
}

String _normalizeVariableTarget(Map<String, dynamic> payload) {
  final explicit = (payload['target'] ?? '').toString().trim().toLowerCase();
  if (explicit == 'global' || explicit == 'scoped') {
    return explicit;
  }
  return (payload['scope'] ?? '').toString().trim().isNotEmpty
      ? 'scoped'
      : 'global';
}

({String scope, String contextId, String storageKey, String referenceKey})
_resolveScopedBinding({
  required Map<String, dynamic> payload,
  required String Function(String input) resolveValue,
  required Map<String, String> variables,
  required Snowflake? guildId,
  required Snowflake? fallbackChannelId,
  required Interaction? interaction,
}) {
  final scope = resolveValue((payload['scope'] ?? '').toString()).trim();
  if (!_supportedVariableScopes.contains(scope)) {
    throw Exception(
      'scope is required and must be one of ${_supportedVariableScopes.join(', ')}',
    );
  }

  final rawKey = resolveValue((payload['key'] ?? '').toString()).trim();
  final storageKey = _scopedStorageKey(rawKey);
  final referenceKey = _scopedReferenceKey(rawKey);
  final explicitContextId =
      resolveValue((payload['contextId'] ?? '').toString()).trim();
  final contextId =
      explicitContextId.isNotEmpty
          ? explicitContextId
          : resolveScopeContextId(
            scope: scope,
            variables: variables,
            guildId: guildId,
            channelId: fallbackChannelId,
            interaction: interaction,
          );
  if (contextId == null || contextId.trim().isEmpty) {
    throw Exception('Unable to resolve context ID for scope "$scope"');
  }

  return (
    scope: scope,
    contextId: contextId,
    storageKey: storageKey,
    referenceKey: referenceKey,
  );
}

List<String> _legacyContextIdsForScope(
  String scope,
  String canonicalContextId,
) {
  switch (scope) {
    case 'user':
      return const <String>['Unknown User'];
    case 'guild':
    case 'channel':
      return const <String>['DM'];
    case 'guildMember':
      final parts = canonicalContextId.split(':');
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

Future<dynamic> _readPersistedVariable({
  required BotDataStore store,
  required String botId,
  required String target,
  required Map<String, dynamic> payload,
  required String Function(String input) resolveValue,
  required Map<String, String> variables,
  required Snowflake? guildId,
  required Snowflake? fallbackChannelId,
  required Interaction? interaction,
}) async {
  if (target == 'global') {
    final key = resolveValue((payload['key'] ?? '').toString()).trim();
    if (key.isEmpty) {
      throw Exception('key is required for global variables');
    }
    var value = await store.getGlobalVariable(botId, key);
    if (value == null) {
      // Auto-create missing global variables to simplify BDFD imports.
      value = '';
      await store.setGlobalVariable(botId, key, value);
    }
    return value;
  }

  final binding = _resolveScopedBinding(
    payload: payload,
    resolveValue: resolveValue,
    variables: variables,
    guildId: guildId,
    fallbackChannelId: fallbackChannelId,
    interaction: interaction,
  );
  var value = await store.getScopedVariable(
    botId,
    binding.scope,
    binding.contextId,
    binding.storageKey,
  );
  if (value == null && binding.referenceKey != binding.storageKey) {
    value = await store.getScopedVariable(
      botId,
      binding.scope,
      binding.contextId,
      binding.referenceKey,
    );
    if (value != null) {
      await store.setScopedVariable(
        botId,
        binding.scope,
        binding.contextId,
        binding.storageKey,
        value,
      );
    }
  }
  if (value == null) {
    // Auto-create missing scoped variables to simplify BDFD imports.
    value = '';
    await store.setScopedVariable(
      botId,
      binding.scope,
      binding.contextId,
      binding.storageKey,
      value,
    );
    await _ensureScopedDefinitionExists(
      store: store,
      botId: botId,
      scope: binding.scope,
      storageKey: binding.storageKey,
      defaultValue: value,
    );
  }
  return value;
}

Future<void> _writePersistedVariable({
  required BotDataStore store,
  required String botId,
  required String target,
  required Map<String, dynamic> payload,
  required String Function(String input) resolveValue,
  required Map<String, String> variables,
  required Snowflake? guildId,
  required Snowflake? fallbackChannelId,
  required Interaction? interaction,
  required dynamic value,
}) async {
  if (target == 'global') {
    final key = resolveValue((payload['key'] ?? '').toString()).trim();
    if (key.isEmpty) {
      throw Exception('key is required for global variables');
    }
    await store.setGlobalVariable(botId, key, value);
    variables['global.$key'] = _stringifyRuntimeValue(value);
    return;
  }

  final binding = _resolveScopedBinding(
    payload: payload,
    resolveValue: resolveValue,
    variables: variables,
    guildId: guildId,
    fallbackChannelId: fallbackChannelId,
    interaction: interaction,
  );
  await store.setScopedVariable(
    botId,
    binding.scope,
    binding.contextId,
    binding.storageKey,
    value,
  );
  await _ensureScopedDefinitionExists(
    store: store,
    botId: botId,
    scope: binding.scope,
    storageKey: binding.storageKey,
    defaultValue: value,
  );
  final runtimeValue = _stringifyRuntimeValue(value);
  variables['${binding.scope}.${binding.referenceKey}'] = runtimeValue;
  if ((payload['key'] ?? '').toString().trim() != binding.referenceKey) {
    variables['${binding.scope}.${(payload['key'] ?? '').toString().trim()}'] =
        runtimeValue;
  }
}

void _storeArrayOutputs({
  required String resultKey,
  required Map<String, String> variables,
  required List<dynamic> items,
  dynamic removed,
}) {
  final itemsJson = jsonEncode(items);
  final length = items.length.toString();
  variables['action.$resultKey.items'] = itemsJson;
  variables['$resultKey.items'] = itemsJson;
  variables['action.$resultKey.length'] = length;
  variables['$resultKey.length'] = length;
  if (removed != null) {
    final removedValue = _stringifyRuntimeValue(removed);
    variables['action.$resultKey.removed'] = removedValue;
    variables['$resultKey.removed'] = removedValue;
  }
}

void _storePagedOutputs({
  required String resultKey,
  required Map<String, String> variables,
  required List<dynamic> items,
  required int total,
}) {
  final itemsJson = jsonEncode(items);
  variables['action.$resultKey.items'] = itemsJson;
  variables['$resultKey.items'] = itemsJson;
  variables['action.$resultKey.count'] = items.length.toString();
  variables['$resultKey.count'] = items.length.toString();
  variables['action.$resultKey.total'] = total.toString();
  variables['$resultKey.total'] = total.toString();
}

bool _mutateJsonPathList(
  dynamic root,
  String rawPath,
  List<dynamic> Function(List<dynamic>? current) update,
) {
  final path = _normalizeJsonPath(rawPath);
  if (path == r'$') {
    if (root is! List<dynamic>) {
      final next = update(null);
      if (root is List) {
        root
          ..clear()
          ..addAll(next);
      }
      return false;
    }
    final next = update(root);
    root
      ..clear()
      ..addAll(next);
    return true;
  }

  final segments = parseJsonPathSegments(path);
  if (segments == null || segments.isEmpty) {
    return false;
  }

  dynamic current = root;
  for (var index = 0; index < segments.length - 1; index++) {
    final segment = segments[index];
    final nextSegment = segments[index + 1];
    if (segment is String) {
      if (current is! Map) {
        return false;
      }
      if (!current.containsKey(segment) || current[segment] == null) {
        current[segment] =
            nextSegment is int ? <dynamic>[] : <String, dynamic>{};
      }
      current = current[segment];
      continue;
    }

    if (segment is int) {
      if (current is! List || segment < 0 || segment >= current.length) {
        return false;
      }
      current = current[segment];
    }
  }

  final last = segments.last;
  if (last is String) {
    if (current is! Map) {
      return false;
    }
    final next = update(
      current[last] is List ? List<dynamic>.from(current[last] as List) : null,
    );
    current[last] = next;
    return true;
  }

  if (last is int) {
    if (current is! List || last < 0 || last >= current.length) {
      return false;
    }
    final currentValue = current[last];
    final next = update(
      currentValue is List ? List<dynamic>.from(currentValue) : null,
    );
    current[last] = next;
    return true;
  }

  return false;
}

List<dynamic> _ensureUpdatedArray(dynamic root, String rawPath) {
  if (_normalizeJsonPath(rawPath) == r'$') {
    if (root is List) {
      return List<dynamic>.from(root);
    }
    return const <dynamic>[];
  }

  final extracted = extractJsonPathValue(root, rawPath);
  if (extracted is List) {
    return List<dynamic>.from(extracted);
  }
  return const <dynamic>[];
}

List<dynamic> _extractArrayFromJsonInput(String input, String rawPath) {
  final decoded = decodeJsonStringIfNeeded(input);
  final target =
      _normalizeJsonPath(rawPath) == r'$'
          ? decoded
          : extractJsonPathValue(decoded, rawPath);
  if (target is List) {
    return List<dynamic>.from(target);
  }
  return <dynamic>[];
}

bool _matchesFilter({
  required String candidate,
  required String operator,
  required String expected,
}) {
  final op = operator.trim().toLowerCase();
  final leftLower = candidate.toLowerCase();
  final rightLower = expected.toLowerCase();

  switch (op) {
    case 'contains':
      return leftLower.contains(rightLower);
    case 'equals':
      final leftNum = num.tryParse(candidate);
      final rightNum = num.tryParse(expected);
      if (leftNum != null && rightNum != null) {
        return leftNum == rightNum;
      }
      return candidate == expected;
    case 'startswith':
      return leftLower.startsWith(rightLower);
    case 'endswith':
      return leftLower.endsWith(rightLower);
    case 'gt':
    case 'gte':
    case 'lt':
    case 'lte':
      final leftNum = num.tryParse(candidate);
      final rightNum = num.tryParse(expected);
      if (leftNum == null || rightNum == null) {
        return false;
      }
      switch (op) {
        case 'gt':
          return leftNum > rightNum;
        case 'gte':
          return leftNum >= rightNum;
        case 'lt':
          return leftNum < rightNum;
        case 'lte':
          return leftNum <= rightNum;
        default:
          return false;
      }
    default:
      return false;
  }
}

int _compareSortValues(String left, String right, bool descending) {
  final leftNum = num.tryParse(left);
  final rightNum = num.tryParse(right);
  final comparison =
      leftNum != null && rightNum != null
          ? leftNum.compareTo(rightNum)
          : left.toLowerCase().compareTo(right.toLowerCase());
  return descending ? -comparison : comparison;
}

Future<bool> executeVariablesAction({
  required BotCreatorActionType type,
  required BotDataStore store,
  required String botId,
  required Map<String, dynamic> payload,
  required String resultKey,
  required Map<String, String> results,
  required Map<String, String> variables,
  required String Function(String input) resolveValue,
  required Snowflake? guildId,
  required Snowflake? fallbackChannelId,
  required Interaction? interaction,
  void Function(String message)? onLog,
}) async {
  switch (type) {
    case BotCreatorActionType.setTemporaryVariable:
      final rawKey = resolveValue((payload['key'] ?? '').toString()).trim();
      final storageKey = _scopedStorageKey(rawKey);
      final resolvedWrite = _resolveRuntimeVariableWriteValue(
        payload: payload,
        resolveValue: resolveValue,
        variables: variables,
        results: results,
      );
      final runtimeValue = _stringifyRuntimeValue(resolvedWrite.value);
      variables['temp.$storageKey'] = runtimeValue;
      if (rawKey.isNotEmpty && rawKey != storageKey) {
        variables['temp.$rawKey'] = runtimeValue;
      }
      variables['$resultKey.value'] = runtimeValue;
      variables['$resultKey.sourceRaw'] = resolvedWrite.rawValueSource;
      variables['$resultKey.resolved'] = resolvedWrite.resolvedByResolver;
      variables['$resultKey.fallback'] = resolvedWrite.fallbackResolved;
      variables['$resultKey.directFallback'] =
          resolvedWrite.directFallbackResolved;
      variables['$resultKey.scope'] = 'temp';
      variables['$resultKey.key'] = storageKey;
      results[resultKey] = 'OK';
      return true;

    case BotCreatorActionType.setScopedVariable:
      final scope = resolveValue((payload['scope'] ?? '').toString()).trim();
      if (!_supportedVariableScopes.contains(scope)) {
        throw Exception(
          'scope is required for setScopedVariable and must be one of ${_supportedVariableScopes.join(', ')}',
        );
      }

      final rawKey = resolveValue((payload['key'] ?? '').toString()).trim();
      final storageKey = _scopedStorageKey(rawKey);
      final referenceKey = _scopedReferenceKey(rawKey);
      final explicitContextId =
          resolveValue((payload['contextId'] ?? '').toString()).trim();
      final contextId =
          explicitContextId.isNotEmpty
              ? explicitContextId
              : resolveScopeContextId(
                scope: scope,
                variables: variables,
                guildId: guildId,
                channelId: fallbackChannelId,
                interaction: interaction,
              );
      if (contextId == null || contextId.trim().isEmpty) {
        throw Exception('Unable to resolve context ID for scope "$scope"');
      }

      final resolvedWrite = _resolveRuntimeVariableWriteValue(
        payload: payload,
        resolveValue: resolveValue,
        variables: variables,
        results: results,
      );
      final rawValueSource = resolvedWrite.rawValueSource;
      final value = resolvedWrite.value;
      final resolvedByResolver = resolvedWrite.resolvedByResolver;
      final fallbackResolved = resolvedWrite.fallbackResolved;
      final directFallbackResolved = resolvedWrite.directFallbackResolved;
      final isCooldown = storageKey.startsWith('cooldown_');
      final ttl = payload['ttl']?.toString();

      if (!isCooldown) {
        await store.setScopedVariable(
          botId,
          scope,
          contextId,
          storageKey,
          value,
          ttl: ttl,
        );
      } else if (ttl != null) {
        ControlFlowExecutor.setRuntimeCooldown(
          variables['bot.id'] ?? botId,
          scope,
          storageKey,
          variables,
          ttl,
        );
      }
      if (!isCooldown) {
        dynamic persisted = await store.getScopedVariable(
          botId,
          scope,
          contextId,
          storageKey,
        );
        final expectedRuntimeValue = _stringifyRuntimeValue(value);
        if ((_stringifyRuntimeValue(persisted).isEmpty) &&
            expectedRuntimeValue.isNotEmpty) {
          await store.setScopedVariable(
            botId,
            scope,
            contextId,
            storageKey,
            expectedRuntimeValue,
            ttl: ttl,
          );
          persisted = await store.getScopedVariable(
            botId,
            scope,
            contextId,
            storageKey,
          );
        }
        await _ensureScopedDefinitionExists(
          store: store,
          botId: botId,
          scope: scope,
          storageKey: storageKey,
          defaultValue: value,
        );
        final defaultContextId = resolveScopeContextId(
          scope: scope,
          variables: variables,
          guildId: guildId,
          channelId: fallbackChannelId,
          interaction: interaction,
        );

        final runtimeValue = _stringifyRuntimeValue(
          persisted ?? expectedRuntimeValue,
        );

        // Update default key if this is the default context
        if (contextId == defaultContextId) {
          variables['$scope.$referenceKey'] = runtimeValue;
          if (rawKey.isNotEmpty && rawKey != referenceKey) {
            variables['$scope.$rawKey'] = runtimeValue;
          }
        }

        // Always update the specific context key to ensure placeholders like ((user[ID].key)) work
        final specificKey = '$scope[$contextId].$referenceKey';
        variables[specificKey] = runtimeValue;
        if (rawKey.isNotEmpty && rawKey != referenceKey) {
          variables['$scope[$contextId].$rawKey'] = runtimeValue;
        }

        onLog?.call(
          '[SetScopedVariable] scope: $scope, key: $rawKey (normalized storageKey: $storageKey, referenceKey: $referenceKey), '
          'contextId: $contextId, defaultContextId: $defaultContextId, '
          'value: $runtimeValue',
        );

        variables['temp.debug_last_var'] = 'Key: $specificKey, Value: $runtimeValue';

        variables['$resultKey.value'] = runtimeValue;
        variables['$resultKey.persisted'] = runtimeValue;
        variables['$resultKey.sourceRaw'] = rawValueSource;
        variables['$resultKey.resolved'] = resolvedByResolver;
        variables['$resultKey.fallback'] = fallbackResolved;
        variables['$resultKey.directFallback'] = directFallbackResolved;
        variables['$resultKey.scope'] = scope;
        variables['$resultKey.key'] = referenceKey;
      }
      results[resultKey] = 'OK';
      return true;

    case BotCreatorActionType.getScopedVariable:
      final scope = resolveValue((payload['scope'] ?? '').toString()).trim();
      if (!_supportedVariableScopes.contains(scope)) {
        throw Exception(
          'scope is required for getScopedVariable and must be one of ${_supportedVariableScopes.join(', ')}',
        );
      }

      final rawKey = resolveValue((payload['key'] ?? '').toString()).trim();
      final storageKey = _scopedStorageKey(rawKey);
      final referenceKey = _scopedReferenceKey(rawKey);
      final explicitContextId =
          resolveValue((payload['contextId'] ?? '').toString()).trim();
      final contextId = explicitContextId.isNotEmpty ? explicitContextId : resolveScopeContextId(
        scope: scope,
        variables: variables,
        guildId: guildId,
        channelId: fallbackChannelId,
        interaction: interaction,
      );
      if (contextId == null || contextId.trim().isEmpty) {
        throw Exception('Unable to resolve context ID for scope "$scope"');
      }

      var value = await store.getScopedVariable(
        botId,
        scope,
        contextId,
        storageKey,
      );
      if (value == null) {
        final legacyContextIds = _legacyContextIdsForScope(scope, contextId);
        for (final legacyContextId in legacyContextIds) {
          value = await store.getScopedVariable(
            botId,
            scope,
            legacyContextId,
            storageKey,
          );
          if (value != null) {
            // Legacy compatibility: copy forward to canonical context, keep legacy data untouched.
            await store.setScopedVariable(
              botId,
              scope,
              contextId,
              storageKey,
              value,
            );
            break;
          }
        }
      }
      if (value == null && referenceKey != storageKey) {
        value = await store.getScopedVariable(
          botId,
          scope,
          contextId,
          referenceKey,
        );
        if (value != null) {
          await store.setScopedVariable(
            botId,
            scope,
            contextId,
            storageKey,
            value,
          );
        }
      }
      if (value == null && referenceKey != storageKey) {
        final legacyContextIds = _legacyContextIdsForScope(scope, contextId);
        for (final legacyContextId in legacyContextIds) {
          value = await store.getScopedVariable(
            botId,
            scope,
            legacyContextId,
            referenceKey,
          );
          if (value != null) {
            await store.setScopedVariable(
              botId,
              scope,
              contextId,
              storageKey,
              value,
            );
            break;
          }
        }
      }
      bool isValueEmpty(dynamic v) {
        if (v == null) return true;
        final s = v.toString().trim();
        return s.isEmpty || s == 'null' || s == 'empty/null';
      }

      var defaulted = false;
      if (isValueEmpty(value)) {
        // Resolve definition default value
        dynamic defaultValue = '';
        var hasDef = false;
        try {
          final definitions = await store.getScopedVariableDefinitions(botId);
          final def = definitions.firstWhere(
            (entry) {
              final entryScope = (entry['scope'] ?? '').toString().trim().toLowerCase();
              final entryKeyRaw = (entry['key'] ?? '').toString().trim().toLowerCase();
              return entryScope == scope.toLowerCase() &&
                  _scopedStorageKey(entryKeyRaw).toLowerCase() == storageKey.toLowerCase();
            },
            orElse: () => const <String, dynamic>{},
          );
          if (def.containsKey('defaultValue')) {
            defaultValue = def['defaultValue'];
            hasDef = true;
          } else if (def.containsKey('default_value')) {
            defaultValue = def['default_value'];
            hasDef = true;
          }
        } catch (_) {}

        // If the current value is missing/empty, and the definition has a non-empty/non-null default value,
        // we apply the definition-based default value.
        if (hasDef && !isValueEmpty(defaultValue)) {
          value = defaultValue;
          defaulted = true;
          await store.setScopedVariable(
            botId,
            scope,
            contextId,
            storageKey,
            value,
          );
          await _ensureScopedDefinitionExists(
            store: store,
            botId: botId,
            scope: scope,
            storageKey: storageKey,
            defaultValue: value,
          );
        } else if (value == null) {
          // If no non-empty default value definition exists, but value was completely null,
          // we fallback to empty string and write it.
          value = '';
          defaulted = true;
          await store.setScopedVariable(
            botId,
            scope,
            contextId,
            storageKey,
            value,
          );
        }
      }
      final runtimeValue = _stringifyRuntimeValue(value);
      final storeAs =
          resolveValue(
            (payload['storeAs'] ?? '$scope.$referenceKey').toString(),
          ).trim();
      if (storeAs.isNotEmpty) {
        variables[storeAs] = runtimeValue;
      }

      final defaultContextId = resolveScopeContextId(
        scope: scope,
        variables: variables,
        guildId: guildId,
        channelId: fallbackChannelId,
        interaction: interaction,
      );

      // Update default key if this is the default context
      if (contextId == defaultContextId) {
        variables['$scope.$referenceKey'] = runtimeValue;
        if (rawKey.isNotEmpty && rawKey != referenceKey) {
          variables['$scope.$rawKey'] = runtimeValue;
        }
      }

      // Always update the specific context key to ensure placeholders like ((user[ID].key)) work
      final specificKey = '$scope[$contextId].$referenceKey';
      variables[specificKey] = runtimeValue;
      if (rawKey.isNotEmpty && rawKey != referenceKey) {
        variables['$scope[$contextId].$rawKey'] = runtimeValue;
      }

      onLog?.call(
        '[GetScopedVariable] scope: $scope, key: $rawKey (normalized storageKey: $storageKey, referenceKey: $referenceKey), '
        'contextId: $contextId, defaultContextId: $defaultContextId, '
        'value: $runtimeValue, defaulted: $defaulted, storeAs: $storeAs',
      );

      results[resultKey] = runtimeValue;
      return true;

    case BotCreatorActionType.removeScopedVariable:
      final scope = resolveValue((payload['scope'] ?? '').toString()).trim();
      if (!_supportedVariableScopes.contains(scope)) {
        throw Exception(
          'scope is required for removeScopedVariable and must be one of ${_supportedVariableScopes.join(', ')}',
        );
      }

      final rawKey = resolveValue((payload['key'] ?? '').toString()).trim();
      final storageKey = _scopedStorageKey(rawKey);
      final referenceKey = _scopedReferenceKey(rawKey);
      final contextId = resolveScopeContextId(
        scope: scope,
        variables: variables,
        guildId: guildId,
        channelId: fallbackChannelId,
        interaction: interaction,
      );
      if (contextId == null || contextId.trim().isEmpty) {
        throw Exception('Unable to resolve context ID for scope "$scope"');
      }

      final isCooldown = storageKey.startsWith('cooldown_');
      if (!isCooldown) {
        await store.removeScopedVariable(botId, scope, contextId, storageKey);
        if (referenceKey != storageKey) {
          await store.removeScopedVariable(
            botId,
            scope,
            contextId,
            referenceKey,
          );
        }
      } else {
        ControlFlowExecutor.removeRuntimeCooldown(
          variables['bot.id'] ?? botId,
          scope,
          storageKey,
          variables,
        );
      }

      if (!isCooldown) {
        variables.remove('$scope.$referenceKey');
        if (rawKey.isNotEmpty && rawKey != referenceKey) {
          variables.remove('$scope.$rawKey');
        }
      }

      results[resultKey] = 'REMOVED';

      return true;

    case BotCreatorActionType.renameScopedVariable:
      final scope = resolveValue((payload['scope'] ?? '').toString()).trim();
      if (!_supportedVariableScopes.contains(scope)) {
        throw Exception(
          'scope is required for renameScopedVariable and must be one of ${_supportedVariableScopes.join(', ')}',
        );
      }

      final oldRawKey =
          resolveValue((payload['oldKey'] ?? '').toString()).trim();
      final newRawKey =
          resolveValue((payload['newKey'] ?? '').toString()).trim();
      final oldStorageKey = _scopedStorageKey(oldRawKey);
      final newStorageKey = _scopedStorageKey(newRawKey);
      final oldReferenceKey = _scopedReferenceKey(oldRawKey);
      final newReferenceKey = _scopedReferenceKey(newRawKey);
      final contextId = resolveScopeContextId(
        scope: scope,
        variables: variables,
        guildId: guildId,
        channelId: fallbackChannelId,
        interaction: interaction,
      );
      if (contextId == null || contextId.trim().isEmpty) {
        throw Exception('Unable to resolve context ID for scope "$scope"');
      }

      await store.renameScopedVariable(
        botId,
        scope,
        contextId,
        oldStorageKey,
        newStorageKey,
      );
      if (oldReferenceKey != oldStorageKey) {
        final legacyValue = await store.getScopedVariable(
          botId,
          scope,
          contextId,
          oldReferenceKey,
        );
        if (legacyValue != null) {
          await store.setScopedVariable(
            botId,
            scope,
            contextId,
            newStorageKey,
            legacyValue,
          );
          await store.removeScopedVariable(
            botId,
            scope,
            contextId,
            oldReferenceKey,
          );
        }
      }
      final oldRuntimeKey = '$scope.$oldReferenceKey';
      final newRuntimeKey = '$scope.$newReferenceKey';
      if (variables.containsKey(oldRuntimeKey)) {
        final runtimeValue = variables.remove(oldRuntimeKey);
        if (runtimeValue != null) {
          variables[newRuntimeKey] = runtimeValue;
          if (oldRawKey.isNotEmpty && oldRawKey != oldReferenceKey) {
            variables.remove('$scope.$oldRawKey');
          }
          if (newRawKey.isNotEmpty && newRawKey != newReferenceKey) {
            variables['$scope.$newRawKey'] = runtimeValue;
          }
        }
      }
      results[resultKey] = 'RENAMED';
      return true;

    case BotCreatorActionType.listScopedVariableIndex:
      final scope = resolveValue((payload['scope'] ?? '').toString()).trim();
      if (!_supportedVariableScopes.contains(scope)) {
        throw Exception(
          'scope is required for listScopedVariableIndex and must be one of ${_supportedVariableScopes.join(', ')}',
        );
      }

      final rawKey = resolveValue((payload['key'] ?? '').toString()).trim();
      final storageKey = _scopedStorageKey(rawKey);
      final offset =
          int.tryParse(
            resolveValue((payload['offset'] ?? '0').toString()).trim(),
          ) ??
          0;
      final limit =
          int.tryParse(
            resolveValue((payload['limit'] ?? '25').toString()).trim(),
          ) ??
          25;
      final safeOffset = offset < 0 ? 0 : offset;
      final safeLimit = limit < 1 ? 1 : (limit > 25 ? 25 : limit);
      final order =
          resolveValue(
            (payload['order'] ?? 'desc').toString(),
          ).trim().toLowerCase();

      final page = await store.queryScopedVariableIndex(
        botId,
        scope,
        storageKey,
        offset: safeOffset,
        limit: safeLimit,
        descending: order != 'asc',
      );
      final items = List<Map<String, dynamic>>.from(
        (page['items'] as List?)?.whereType<Map>().map(
              (entry) => Map<String, dynamic>.from(entry),
            ) ??
            const <Map<String, dynamic>>[],
      );
      _storePagedOutputs(
        resultKey: resultKey,
        variables: variables,
        items: items,
        total: (page['total'] ?? items.length) as int,
      );

      final storeAs =
          resolveValue((payload['storeAs'] ?? '').toString()).trim();
      if (storeAs.isNotEmpty) {
        variables[storeAs] = jsonEncode(items);
      }

      results[resultKey] = jsonEncode(items);
      return true;

    case BotCreatorActionType.appendArrayElement:
      final target = _normalizeVariableTarget(payload);
      final path = _normalizeJsonPath(
        resolveValue((payload['path'] ?? r'$').toString()),
      );
      final rootValue = await _readPersistedVariable(
        store: store,
        botId: botId,
        target: target,
        payload: payload,
        resolveValue: resolveValue,
        variables: variables,
        guildId: guildId,
        fallbackChannelId: fallbackChannelId,
        interaction: interaction,
      );
      final clonedRoot =
          path == r'$'
              ? <dynamic>[]
              : (_deepCloneJsonValue(rootValue) ?? <String, dynamic>{});
      final element = _resolveVariableValuePayload(payload, resolveValue);
      if (path == r'$') {
        final list =
            rootValue is List ? List<dynamic>.from(rootValue) : <dynamic>[];
        list.add(element);
        await _writePersistedVariable(
          store: store,
          botId: botId,
          target: target,
          payload: payload,
          resolveValue: resolveValue,
          variables: variables,
          guildId: guildId,
          fallbackChannelId: fallbackChannelId,
          interaction: interaction,
          value: list,
        );
        _storeArrayOutputs(
          resultKey: resultKey,
          variables: variables,
          items: list,
        );
        results[resultKey] = jsonEncode(list);
        return true;
      }

      _mutateJsonPathList(clonedRoot, path, (current) {
        final next = List<dynamic>.from(current ?? const <dynamic>[]);
        next.add(element);
        return next;
      });
      final updated = _ensureUpdatedArray(clonedRoot, path);
      await _writePersistedVariable(
        store: store,
        botId: botId,
        target: target,
        payload: payload,
        resolveValue: resolveValue,
        variables: variables,
        guildId: guildId,
        fallbackChannelId: fallbackChannelId,
        interaction: interaction,
        value: clonedRoot,
      );
      _storeArrayOutputs(
        resultKey: resultKey,
        variables: variables,
        items: updated,
      );
      results[resultKey] = jsonEncode(updated);
      return true;

    case BotCreatorActionType.removeArrayElement:
      final target = _normalizeVariableTarget(payload);
      final path = _normalizeJsonPath(
        resolveValue((payload['path'] ?? r'$').toString()),
      );
      final index = int.tryParse(
        resolveValue((payload['index'] ?? '').toString()).trim(),
      );
      if (index == null) {
        throw Exception('index is required for removeArrayElement');
      }

      final rootValue = await _readPersistedVariable(
        store: store,
        botId: botId,
        target: target,
        payload: payload,
        resolveValue: resolveValue,
        variables: variables,
        guildId: guildId,
        fallbackChannelId: fallbackChannelId,
        interaction: interaction,
      );
      dynamic removed;
      if (path == r'$') {
        final list =
            rootValue is List ? List<dynamic>.from(rootValue) : <dynamic>[];
        if (index >= 0 && index < list.length) {
          removed = list.removeAt(index);
        }
        await _writePersistedVariable(
          store: store,
          botId: botId,
          target: target,
          payload: payload,
          resolveValue: resolveValue,
          variables: variables,
          guildId: guildId,
          fallbackChannelId: fallbackChannelId,
          interaction: interaction,
          value: list,
        );
        _storeArrayOutputs(
          resultKey: resultKey,
          variables: variables,
          items: list,
          removed: removed,
        );
        results[resultKey] = jsonEncode(list);
        return true;
      }

      final clonedRoot = _deepCloneJsonValue(rootValue) ?? <String, dynamic>{};
      _mutateJsonPathList(clonedRoot, path, (current) {
        final next = List<dynamic>.from(current ?? const <dynamic>[]);
        if (index >= 0 && index < next.length) {
          removed = next.removeAt(index);
        }
        return next;
      });
      final updated = _ensureUpdatedArray(clonedRoot, path);
      await _writePersistedVariable(
        store: store,
        botId: botId,
        target: target,
        payload: payload,
        resolveValue: resolveValue,
        variables: variables,
        guildId: guildId,
        fallbackChannelId: fallbackChannelId,
        interaction: interaction,
        value: clonedRoot,
      );
      _storeArrayOutputs(
        resultKey: resultKey,
        variables: variables,
        items: updated,
        removed: removed,
      );
      results[resultKey] = jsonEncode(updated);
      return true;

    case BotCreatorActionType.queryArray:
      final input = resolveValue((payload['input'] ?? '').toString());
      final path = _normalizeJsonPath(
        resolveValue((payload['path'] ?? r'$').toString()),
      );
      final items = _extractArrayFromJsonInput(input, path);
      final filterTemplate =
          (payload['filterTemplate'] ?? '{value}').toString();
      final filterOperator =
          resolveValue((payload['filterOperator'] ?? '').toString()).trim();
      final filterValue =
          resolveValue((payload['filterValue'] ?? '').toString()).trim();
      final sortTemplate = (payload['sortTemplate'] ?? '{value}').toString();
      final order =
          resolveValue(
            (payload['order'] ?? 'asc').toString(),
          ).trim().toLowerCase();
      final offset =
          int.tryParse(
            resolveValue((payload['offset'] ?? '0').toString()).trim(),
          ) ??
          0;
      final limit =
          int.tryParse(
            resolveValue((payload['limit'] ?? '25').toString()).trim(),
          ) ??
          25;

      var working = List<dynamic>.from(items);
      if (filterOperator.isNotEmpty && filterValue.isNotEmpty) {
        working = working
            .where((item) {
              final candidate = resolveItemTemplate(
                filterTemplate,
                item,
                variables,
              );
              return _matchesFilter(
                candidate: candidate,
                operator: filterOperator,
                expected: filterValue,
              );
            })
            .toList(growable: false);
      }

      working.sort((left, right) {
        final leftValue = resolveItemTemplate(sortTemplate, left, variables);
        final rightValue = resolveItemTemplate(sortTemplate, right, variables);
        return _compareSortValues(leftValue, rightValue, order == 'desc');
      });

      final safeOffset = offset < 0 ? 0 : offset;
      final safeLimit = limit < 1 ? 1 : (limit > 100 ? 100 : limit);
      final start = safeOffset.clamp(0, working.length);
      final end = (start + safeLimit).clamp(start, working.length);
      final page = working.sublist(start, end);

      _storePagedOutputs(
        resultKey: resultKey,
        variables: variables,
        items: page,
        total: working.length,
      );
      final storeAs =
          resolveValue((payload['storeAs'] ?? '').toString()).trim();
      if (storeAs.isNotEmpty) {
        variables[storeAs] = jsonEncode(page);
      }
      results[resultKey] = jsonEncode(page);
      return true;
    case BotCreatorActionType.randomChoice:
      final rawChoices = resolveValue((payload['choices'] ?? '').toString());
      final variableName = resolveValue((payload['variableName'] ?? 'random_choice').toString()).trim();
      
      List<String> choices;
      if (rawChoices.trim().startsWith('[') && rawChoices.trim().endsWith(']')) {
        try {
          final decoded = jsonDecode(rawChoices);
          if (decoded is List) {
            choices = decoded.map((e) => e.toString()).toList();
          } else {
            choices = rawChoices.split(';').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
          }
        } catch (_) {
          choices = rawChoices.split(';').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        }
      } else {
        choices = rawChoices.split(';').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }

      if (choices.isEmpty) {
        variables[variableName] = '';
        results[resultKey] = '';
        return true;
      }

      final random = (DateTime.now().millisecondsSinceEpoch % choices.length);
      final picked = choices[random];
      
      variables[variableName] = picked;
      results[resultKey] = picked;
      return true;
    case BotCreatorActionType.respondWithAutocomplete:
      if (interaction is! ApplicationCommandAutocompleteInteraction) {
        throw Exception(
          'respondWithAutocomplete requires an autocomplete interaction context',
        );
      }

      final itemsInput = resolveValue((payload['items'] ?? '').toString());
      final path = _normalizeJsonPath(
        resolveValue((payload['path'] ?? r'$').toString()),
      );
      final items = _extractArrayFromJsonInput(itemsInput, path);
      final labelTemplate = (payload['labelTemplate'] ?? '{value}').toString();
      final valueTemplate = (payload['valueTemplate'] ?? '{value}').toString();

      final focused =
          variables['autocomplete.optionType']?.trim().toLowerCase() ??
          commandOptionTypeToText(
            findFocusedInteractionOption(interaction.data.options)?.type ??
                CommandOptionType.string,
          ).toLowerCase();

      final builders = <CommandOptionChoiceBuilder<dynamic>>[];
      for (final item in items) {
        if (builders.length >= 25) {
          break;
        }
        final label =
            resolveItemTemplate(labelTemplate, item, variables).trim();
        final rawValue =
            resolveItemTemplate(valueTemplate, item, variables).trim();
        if (label.isEmpty || rawValue.isEmpty) {
          continue;
        }

        dynamic typedValue;
        switch (focused) {
          case 'integer':
            typedValue = int.tryParse(rawValue);
            break;
          case 'number':
            typedValue = double.tryParse(rawValue);
            break;
          default:
            typedValue = rawValue;
            break;
        }

        if (typedValue == null) {
          continue;
        }

        builders.add(
          CommandOptionChoiceBuilder<dynamic>(name: label, value: typedValue),
        );
      }

      await interaction.respond(builders);
      results[resultKey] = 'RESPONDED';
      results['__stopped__'] = 'AUTOCOMPLETE';
      return true;

    case BotCreatorActionType.setGlobalVariable:
      final key = resolveValue((payload['key'] ?? '').toString()).trim();
      if (key.isEmpty) {
        throw Exception('key is required for setGlobalVariable');
      }
      final rawValueSource =
          payload.containsKey('value')
              ? (payload['value'] ?? '').toString()
              : (payload['element'] ?? '').toString();
      dynamic value = _resolveVariableValuePayload(payload, resolveValue);
      final resolvedByResolver = value is String ? value : value.toString();
      String fallbackResolved = '';
      String directFallbackResolved = '';
      if (value is String &&
          rawValueSource.contains('((') &&
          rawValueSource.contains('))') &&
          (value.isEmpty || (value.contains('((') && value.contains('))')))) {
        final mergedContext = <String, String>{...variables, ...results};
        final fallback = resolveTemplatePlaceholders(
          rawValueSource,
          mergedContext,
        );
        fallbackResolved = fallback;
        if (fallback.isNotEmpty && fallback != rawValueSource) {
          value = fallback;
        } else {
          final directFallback = _lookupMergedContextValue(
            rawValueSource,
            mergedContext,
          );
          directFallbackResolved = directFallback;
          if (directFallback.isNotEmpty) {
            value = directFallback;
          }
        }
      }
      if (value is String &&
          value.isEmpty &&
          rawValueSource.trim().toLowerCase() == r'$jsonstringify') {
        final mergedContext = <String, String>{...variables, ...results};
        final latestJson = _lookupLatestRuntimeJsonValue(mergedContext);
        if (latestJson.isNotEmpty) {
          value = latestJson;
        }
      }
      await store.setGlobalVariable(
        botId,
        key,
        value,
        ttl: payload['ttl']?.toString(),
      );
      dynamic persisted = await store.getGlobalVariable(botId, key);
      final expectedRuntimeValue = _stringifyRuntimeValue(value);
      if ((_stringifyRuntimeValue(persisted).isEmpty) &&
          expectedRuntimeValue.isNotEmpty) {
        await store.setGlobalVariable(botId, key, expectedRuntimeValue);
        persisted = await store.getGlobalVariable(botId, key);
      }
      final runtimeValue = _stringifyRuntimeValue(
        persisted ?? expectedRuntimeValue,
      );
      variables['global.$key'] = runtimeValue;
      variables['$resultKey.value'] = runtimeValue;
      variables['$resultKey.persisted'] = runtimeValue;
      variables['$resultKey.sourceRaw'] = rawValueSource;
      variables['$resultKey.resolved'] = resolvedByResolver;
      variables['$resultKey.fallback'] = fallbackResolved;
      variables['$resultKey.directFallback'] = directFallbackResolved;
      variables['$resultKey.scope'] = 'global';
      variables['$resultKey.key'] = key;
      results[resultKey] = 'OK';
      return true;

    case BotCreatorActionType.getGlobalVariable:
      final key = resolveValue((payload['key'] ?? '').toString()).trim();
      if (key.isEmpty) {
        throw Exception('key is required for getGlobalVariable');
      }
      var value = await store.getGlobalVariable(botId, key);
      if (value == null) {
        // Auto-create missing global variables on first read.
        value = '';
        await store.setGlobalVariable(botId, key, value);
      }
      final valueAsString = _stringifyRuntimeValue(value);
      final storeAs =
          resolveValue((payload['storeAs'] ?? 'global.$key').toString()).trim();
      if (storeAs.isNotEmpty) {
        variables[storeAs] = valueAsString;
      }
      variables['global.$key'] = valueAsString;
      results[resultKey] = valueAsString;
      return true;

    case BotCreatorActionType.removeGlobalVariable:
      final key = resolveValue((payload['key'] ?? '').toString()).trim();
      if (key.isEmpty) {
        throw Exception('key is required for removeGlobalVariable');
      }
      await store.removeGlobalVariable(botId, key);
      variables.remove('global.$key');
      results[resultKey] = 'REMOVED';
      return true;

    case BotCreatorActionType.runtimeJsonBlock:
      _executeRuntimeJsonBlock(
        payload: payload,
        resultKey: resultKey,
        results: results,
        variables: variables,
        resolveValue: resolveValue,
      );
      return true;

    case BotCreatorActionType.log:
      final message = resolveValue((payload['message'] ?? '').toString());
      if (message.isNotEmpty) {
        onLog?.call(message);
      }
      results[resultKey] = 'LOGGED';
      return true;

    default:
      return false;
  }
}

/// Executes a deferred JSON block at runtime.
///
/// The transpiler emits this action when `$jsonParse` receives an argument
/// containing a runtime placeholder (e.g. `$getServerVar[data]`).  All
/// subsequent JSON operations (`$json`, `$jsonSet`, `$jsonArrayAppend`, etc.)
/// are collected as a list of operations and executed here once the source
/// string has been resolved.
void _executeRuntimeJsonBlock({
  required Map<String, dynamic> payload,
  required String resultKey,
  required Map<String, String> results,
  required Map<String, String> variables,
  required String Function(String input) resolveValue,
}) {
  String resolveRuntimeJsonInput(String input) {
    final resolved = resolveValue(input);
    final mergedContext = <String, String>{...variables, ...results};
    final hasTemplatePlaceholder = input.contains('((') && input.contains('))');
    if (hasTemplatePlaceholder) {
      if (resolved.isNotEmpty &&
          !(resolved.contains('((') && resolved.contains('))'))) {
        return resolved;
      }
      final fallbackResolved = resolveTemplatePlaceholders(
        input,
        mergedContext,
      );
      if (fallbackResolved != input) {
        return fallbackResolved;
      }
      final directFallback = _lookupMergedContextValue(input, mergedContext);
      if (directFallback.isNotEmpty) {
        return directFallback;
      }
    }

    if (resolved.isEmpty && input.trim().toLowerCase() == r'$jsonstringify') {
      final latestJson = _lookupLatestRuntimeJsonValue(mergedContext);
      if (latestJson.isNotEmpty) {
        return latestJson;
      }
    }

    return resolved;
  }

  final rawSource = (payload['source'] ?? '').toString();
  final resolvedSource = resolveRuntimeJsonInput(rawSource).trim();
  dynamic jsonCtx;
  if (resolvedSource.isEmpty) {
    // Empty source means variable not initialized yet. Bootstrap with an
    // object so jsonSet/jsonArrayAppend can materialize paths.
    jsonCtx = <String, dynamic>{};
  } else {
    try {
      jsonCtx = jsonDecode(resolvedSource);
      // Scalars (number/string/bool/null) cannot host object paths like
      // `items`. Promote to an empty object so runtime JSON ops can recover.
      if (jsonCtx is! Map && jsonCtx is! List) {
        jsonCtx = <String, dynamic>{};
      }
    } catch (_) {
      // Corrupted or non-JSON payload: recover by reinitializing as object.
      jsonCtx = <String, dynamic>{};
    }
  }

  final operations = payload['operations'];
  if (operations is! List) {
    final encoded = jsonEncode(jsonCtx);
    results[resultKey] = encoded;
    variables[resultKey] = encoded;
    return;
  }

  for (final rawOp in operations) {
    if (rawOp is! Map) continue;
    final op = rawOp['op']?.toString() ?? '';
    final pathRaw = rawOp['path'];
    final path =
        (pathRaw is List)
            ? pathRaw.map((e) => e.toString()).toList()
            : const <String>[];
    final resolvedPath = path
        .map(resolveRuntimeJsonInput)
        .toList(growable: false);

    switch (op) {
      case 'get':
        final readIndex = rawOp['readIndex'];
        final value = _rtJsonGetPath(jsonCtx, resolvedPath);
        final stringified = _rtJsonStringifyValue(value);
        if (readIndex != null) {
          results['$resultKey.json_$readIndex'] = stringified;
          variables['$resultKey.json_$readIndex'] = stringified;
        }
        break;

      case 'set':
        final rawValue = resolveRuntimeJsonInput(
          (rawOp['value'] ?? '').toString(),
        );
        final forceString = rawOp['forceString'] == true;
        final value = forceString ? rawValue : _rtCoerceJsonValue(rawValue);
        jsonCtx = _rtJsonSetPath(jsonCtx, resolvedPath, value);
        break;

      case 'unset':
        jsonCtx = _rtJsonRemovePath(jsonCtx, resolvedPath);
        break;

      case 'clear':
        jsonCtx = null;
        break;

      case 'exists':
        final readIndex = rawOp['readIndex'];
        final exists = _rtJsonPathExists(jsonCtx, resolvedPath);
        if (readIndex != null) {
          results['$resultKey.json_$readIndex'] = exists ? 'true' : 'false';
          variables['$resultKey.json_$readIndex'] = exists ? 'true' : 'false';
        }
        break;

      case 'stringify':
        final readIndex = rawOp['readIndex'];
        final value = jsonCtx != null ? jsonEncode(jsonCtx) : '';
        if (readIndex != null) {
          results['$resultKey.json_$readIndex'] = value;
          variables['$resultKey.json_$readIndex'] = value;
        }
        break;

      case 'pretty':
        final readIndex = rawOp['readIndex'];
        final indentRaw = resolveRuntimeJsonInput(
          (rawOp['indent'] ?? '').toString(),
        );
        final indent = int.tryParse(indentRaw);
        final spaces = (indent == null || indent < 0) ? 2 : indent;
        final value =
            jsonCtx != null
                ? const JsonEncoder.withIndent(
                  '  ',
                ).convert(jsonCtx).replaceAll('  ', ' ' * spaces)
                : '';
        if (readIndex != null) {
          results['$resultKey.json_$readIndex'] = value;
          variables['$resultKey.json_$readIndex'] = value;
        }
        break;

      case 'initArray':
        jsonCtx = _rtJsonSetPath(jsonCtx, resolvedPath, <dynamic>[]);
        break;

      case 'arrayAppend':
        final rawValue = resolveRuntimeJsonInput(
          (rawOp['value'] ?? '').toString(),
        );
        final value = _rtCoerceJsonValue(rawValue);
        final list = _rtJsonEnsureArray(jsonCtx, resolvedPath);
        list.add(value);
        break;

      case 'arrayUnshift':
        final rawValue = resolveRuntimeJsonInput(
          (rawOp['value'] ?? '').toString(),
        );
        final value = _rtCoerceJsonValue(rawValue);
        final list = _rtJsonEnsureArray(jsonCtx, resolvedPath);
        list.insert(0, value);
        break;

      case 'arrayPop':
        final readIndex = rawOp['readIndex'];
        final list = _rtJsonEnsureArray(jsonCtx, resolvedPath);
        final removed =
            list.isNotEmpty ? _rtJsonStringifyValue(list.removeLast()) : '';
        if (readIndex != null) {
          results['$resultKey.json_$readIndex'] = removed;
          variables['$resultKey.json_$readIndex'] = removed;
        }
        break;

      case 'arrayShift':
        final readIndex = rawOp['readIndex'];
        final list = _rtJsonEnsureArray(jsonCtx, resolvedPath);
        final removed =
            list.isNotEmpty ? _rtJsonStringifyValue(list.removeAt(0)) : '';
        if (readIndex != null) {
          results['$resultKey.json_$readIndex'] = removed;
          variables['$resultKey.json_$readIndex'] = removed;
        }
        break;

      case 'arraySort':
        final list = _rtJsonEnsureArray(jsonCtx, resolvedPath);
        list.sort((a, b) {
          final aNum = a is num ? a : num.tryParse(a.toString());
          final bNum = b is num ? b : num.tryParse(b.toString());
          if (aNum != null && bNum != null) return aNum.compareTo(bNum);
          if (aNum != null) return -1;
          if (bNum != null) return 1;
          return a.toString().compareTo(b.toString());
        });
        break;

      case 'arrayReverse':
        final list = _rtJsonEnsureArray(jsonCtx, resolvedPath);
        final reversed = list.reversed.toList(growable: false);
        list
          ..clear()
          ..addAll(reversed);
        break;

      case 'arrayCount':
        final readIndex = rawOp['readIndex'];
        final value = _rtJsonGetPath(jsonCtx, resolvedPath);
        final count = value is List ? value.length.toString() : '0';
        if (readIndex != null) {
          results['$resultKey.json_$readIndex'] = count;
          variables['$resultKey.json_$readIndex'] = count;
        }
        break;

      case 'arrayIndex':
        final readIndex = rawOp['readIndex'];
        final expected = _rtCoerceJsonValue(
          resolveRuntimeJsonInput((rawOp['value'] ?? '').toString()),
        );
        final list = _rtJsonGetPath(jsonCtx, resolvedPath);
        final index =
            list is List
                ? list.indexWhere((item) => item == expected).toString()
                : '-1';
        if (readIndex != null) {
          results['$resultKey.json_$readIndex'] = index;
          variables['$resultKey.json_$readIndex'] = index;
        }
        break;

      case 'joinArray':
        final readIndex = rawOp['readIndex'];
        final separator = resolveRuntimeJsonInput(
          (rawOp['separator'] ?? '').toString(),
        );
        final value = _rtJsonGetPath(jsonCtx, resolvedPath);
        final joined =
            value is List
                ? value.map(_rtJsonStringifyValue).join(separator)
                : '';
        if (readIndex != null) {
          results['$resultKey.json_$readIndex'] = joined;
          variables['$resultKey.json_$readIndex'] = joined;
        }
        break;

      case 'keys':
        final readIndex = rawOp['readIndex'];
        final separator = resolveRuntimeJsonInput(
          (rawOp['separator'] ?? ',').toString(),
        );
        final value = _rtJsonGetPath(jsonCtx, resolvedPath);
        final keys =
            value is Map
                ? value.keys.map((k) => k.toString()).join(separator)
                : '';
        if (readIndex != null) {
          results['$resultKey.json_$readIndex'] = keys;
          variables['$resultKey.json_$readIndex'] = keys;
        }
        break;
    }
  }

  final encodedRoot = jsonCtx != null ? jsonEncode(jsonCtx) : '';
  results[resultKey] = encodedRoot;
  variables[resultKey] = encodedRoot;
}

// ── Runtime JSON helpers ────────────────────────────────────────────────────

dynamic _rtJsonGetPath(dynamic root, List<String> path) {
  dynamic current = root;
  for (final segment in path) {
    final index = int.tryParse(segment);
    if (index != null && current is List) {
      if (index < 0 || index >= current.length) return null;
      current = current[index];
    } else if (current is Map) {
      if (!current.containsKey(segment)) return null;
      current = current[segment];
    } else {
      return null;
    }
  }
  return current;
}

bool _rtJsonPathExists(dynamic root, List<String> path) {
  dynamic current = root;
  for (final segment in path) {
    final index = int.tryParse(segment);
    if (index != null && current is List) {
      if (index < 0 || index >= current.length) return false;
      current = current[index];
    } else if (current is Map) {
      if (!current.containsKey(segment)) return false;
      current = current[segment];
    } else {
      return false;
    }
  }
  return true;
}

dynamic _rtJsonSetPath(dynamic root, List<String> path, dynamic value) {
  if (path.isEmpty) return value;
  final nextIsNumeric = path.length > 1 && int.tryParse(path[0]) != null;
  root ??= nextIsNumeric ? <dynamic>[] : <String, dynamic>{};
  dynamic current = root;
  for (var i = 0; i < path.length - 1; i++) {
    final segment = path[i];
    final index = int.tryParse(segment);
    final nextSegment = path[i + 1];
    final nextIndex = int.tryParse(nextSegment);
    if (index != null) {
      if (current is! List || index < 0) return root;
      while (current.length <= index) {
        current.add(null);
      }
      current[index] ??= nextIndex != null ? <dynamic>[] : <String, dynamic>{};
      current = current[index];
    } else if (current is Map) {
      if (!current.containsKey(segment) || current[segment] == null) {
        current[segment] =
            nextIndex != null ? <dynamic>[] : <String, dynamic>{};
      }
      current = current[segment];
    } else {
      return root;
    }
  }
  final lastSegment = path.last;
  final lastIndex = int.tryParse(lastSegment);
  if (lastIndex != null) {
    if (current is! List || lastIndex < 0) return root;
    while (current.length <= lastIndex) {
      current.add(null);
    }
    current[lastIndex] = value;
  } else if (current is Map) {
    current[lastSegment] = value;
  }
  return root;
}

dynamic _rtJsonRemovePath(dynamic root, List<String> path) {
  if (path.isEmpty) return null;
  dynamic current = root;
  for (var i = 0; i < path.length - 1; i++) {
    final segment = path[i];
    final index = int.tryParse(segment);
    if (index != null && current is List) {
      if (index < 0 || index >= current.length) return root;
      current = current[index];
    } else if (current is Map) {
      if (!current.containsKey(segment)) return root;
      current = current[segment];
    } else {
      return root;
    }
  }
  final lastSegment = path.last;
  final lastIndex = int.tryParse(lastSegment);
  if (lastIndex != null && current is List) {
    if (lastIndex >= 0 && lastIndex < current.length) {
      current.removeAt(lastIndex);
    }
  } else if (current is Map) {
    current.remove(lastSegment);
  }
  return root;
}

List<dynamic> _rtJsonEnsureArray(dynamic root, List<String> path) {
  final existing = _rtJsonGetPath(root, path);
  if (existing is List<dynamic>) return existing;
  _rtJsonSetPath(root, path, <dynamic>[]);
  final resolved = _rtJsonGetPath(root, path);
  return resolved is List<dynamic> ? resolved : <dynamic>[];
}

dynamic _rtCoerceJsonValue(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
    try {
      return jsonDecode(trimmed);
    } catch (_) {}
  }
  if (trimmed.toLowerCase() == 'true') return true;
  if (trimmed.toLowerCase() == 'false') return false;
  if (trimmed.toLowerCase() == 'null') return null;
  final asInt = int.tryParse(trimmed);
  if (asInt != null) return asInt;
  final asDouble = double.tryParse(trimmed);
  if (asDouble != null) return asDouble;
  return raw;
}

String _rtJsonStringifyValue(dynamic value) {
  if (value == null) return '';
  if (value is String) return value;
  if (value is num || value is bool) return value.toString();
  return jsonEncode(value);
}
