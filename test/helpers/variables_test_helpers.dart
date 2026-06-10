import 'package:bot_creator_shared/actions/executors/control_flow_executor.dart';
import 'package:bot_creator_shared/actions/executors/variables_executor.dart';
import 'package:bot_creator_shared/bot/bot_data_store.dart';
import 'package:bot_creator_shared/types/action.dart';
import 'package:bot_creator_shared/utils/template_resolver.dart';
import 'package:nyxx/nyxx.dart';
import 'package:test/test.dart';

Map<String, String> mergeRuntimeContext(
  Map<String, String> variables,
  Map<String, String> inheritedResults,
  Map<String, String> localResults,
) {
  return <String, String>{...variables, ...inheritedResults, ...localResults};
}

Future<Map<String, String>> executeCompiledActions({
  required List<Action> actions,
  required BotDataStore store,
  required Map<String, String> variables,
  required List<String> replies,
  Map<String, String> inheritedResults = const <String, String>{},
}) async {
  final localResults = <String, String>{};

  for (var index = 0; index < actions.length; index++) {
    final action = actions[index];
    final resultKey = action.key ?? 'action_$index';

    String resolveValue(String input) {
      return resolveTemplatePlaceholders(
        input,
        mergeRuntimeContext(variables, inheritedResults, localResults),
      );
    }

    final handledVariable = await executeVariablesAction(
      type: action.type,
      store: store,
      botId: 'bot-1',
      payload: action.payload,
      resultKey: resultKey,
      results: localResults,
      variables: variables,
      resolveValue: resolveValue,
      guildId: Snowflake.parse('1'),
      fallbackChannelId: null,
      interaction: null,
    );
    if (handledVariable) {
      continue;
    }

    final handledControlFlow = await executeControlFlowAction(
      type: action.type,
      payload: action.payload,
      resultKey: resultKey,
      results: localResults,
      variables: variables,
      botId: 'bot-1',
      resolveValue: resolveValue,
      onLog: null,
      activeWorkflowStack: <String>{},
      getWorkflowByName: (_) async => null,
      executeActions: (nestedActions) {
        return executeCompiledActions(
          actions: nestedActions,
          store: store,
          variables: variables,
          replies: replies,
          inheritedResults: mergeRuntimeContext(
            variables,
            inheritedResults,
            localResults,
          ),
        );
      },
    );
    if (handledControlFlow) {
      continue;
    }

    switch (action.type) {
      case BotCreatorActionType.respondWithMessage:
      case BotCreatorActionType.sendMessage:
        final content = resolveValue(
          (action.payload['content'] ?? '').toString(),
        );
        replies.add(content);
        localResults[resultKey] = content;
        break;
      default:
        fail(
          'Unsupported compiled action in test harness: ${action.type.name}',
        );
    }
  }

  return localResults;
}

class MemoryBotDataStore implements BotDataStore {
  MemoryBotDataStore({
    Map<String, dynamic>? globalVariables,
    Map<String, Map<String, Map<String, dynamic>>>? scopedVariables,
    List<Map<String, dynamic>>? scopedDefinitions,
  }) : globalVariables = globalVariables ?? <String, dynamic>{},
       scopedVariables =
           scopedVariables ?? <String, Map<String, Map<String, dynamic>>>{},
       scopedDefinitions = scopedDefinitions ?? <Map<String, dynamic>>[];

  final Map<String, dynamic> globalVariables;
  final Map<String, Map<String, Map<String, dynamic>>> scopedVariables;
  final List<Map<String, dynamic>> scopedDefinitions;

  @override
  Future<List<Map<String, dynamic>>> getCommands(String botId) async =>
      const [];

  @override
  Future<List<Map<String, dynamic>>> getScopedVariableDefinitions(
    String botId,
  ) async {
    return scopedDefinitions;
  }

  @override
  Future<void> setScopedVariableDefinition(
    String botId,
    String key,
    String scope,
    dynamic defaultValue, {
    String valueType = 'string',
  }) async {
    scopedDefinitions.add(<String, dynamic>{
      'key': key,
      'scope': scope,
      'defaultValue': defaultValue,
      'valueType': valueType,
    });
  }

  @override
  Future<Map<String, dynamic>> getGlobalVariables(String botId) async =>
      Map<String, dynamic>.from(globalVariables);

  @override
  Future<dynamic> getGlobalVariable(String botId, String key) async =>
      globalVariables[key];

  @override
  Future<void> setGlobalVariable(
    String botId,
    String key,
    dynamic value, {
    String? ttl,
  }) async {
    globalVariables[key] = value;
  }

  @override
  Future<void> renameGlobalVariable(
    String botId,
    String oldKey,
    String newKey,
  ) async {
    if (!globalVariables.containsKey(oldKey)) {
      return;
    }
    globalVariables[newKey] = globalVariables.remove(oldKey);
  }

  @override
  Future<void> removeGlobalVariable(String botId, String key) async {
    globalVariables.remove(key);
  }

  @override
  Future<Map<String, dynamic>> getScopedVariables(
    String botId,
    String scope,
    String contextId,
  ) async {
    return Map<String, dynamic>.from(
      scopedVariables[scope]?[contextId] ?? const <String, dynamic>{},
    );
  }

  @override
  Future<dynamic> getScopedVariable(
    String botId,
    String scope,
    String contextId,
    String key,
  ) async {
    return scopedVariables[scope]?[contextId]?[key];
  }

  @override
  Future<void> setScopedVariable(
    String botId,
    String scope,
    String contextId,
    String key,
    dynamic value, {
    String? ttl,
  }) async {
    scopedVariables.putIfAbsent(scope, () => <String, Map<String, dynamic>>{});
    scopedVariables[scope]!.putIfAbsent(contextId, () => <String, dynamic>{});
    scopedVariables[scope]![contextId]![key] = value;
  }

  @override
  Future<int?> getScopedVariableTtl(
    String botId,
    String scope,
    String contextId,
    String key,
  ) async {
    throw UnsupportedError('Not used in these tests');
  }

  @override
  Future<void> renameScopedVariable(
    String botId,
    String scope,
    String contextId,
    String oldKey,
    String newKey,
  ) async {
    final bucket = scopedVariables[scope]?[contextId];
    if (bucket == null || !bucket.containsKey(oldKey)) {
      return;
    }
    bucket[newKey] = bucket.remove(oldKey);
  }

  @override
  Future<void> removeScopedVariable(
    String botId,
    String scope,
    String contextId,
    String key,
  ) async {
    scopedVariables[scope]?[contextId]?.remove(key);
  }

  @override
  Future<Map<String, dynamic>> queryScopedVariableIndex(
    String botId,
    String scope,
    String key, {
    int offset = 0,
    int limit = 25,
    bool descending = true,
  }) async {
    throw UnsupportedError('Not used in these tests');
  }

  @override
  Future<void> pushScopedArrayElement(
    String botId,
    String scope,
    String contextId,
    String key,
    dynamic element,
  ) async {
    throw UnsupportedError('Not used in these tests');
  }

  @override
  Future<dynamic> popScopedArrayElement(
    String botId,
    String scope,
    String contextId,
    String key,
  ) async {
    throw UnsupportedError('Not used in these tests');
  }

  @override
  Future<dynamic> removeScopedArrayElement(
    String botId,
    String scope,
    String contextId,
    String key,
    int index,
  ) async {
    throw UnsupportedError('Not used in these tests');
  }

  @override
  Future<dynamic> getScopedArrayElement(
    String botId,
    String scope,
    String contextId,
    String key,
    int index,
  ) async {
    throw UnsupportedError('Not used in these tests');
  }

  @override
  Future<int> getScopedArrayLength(
    String botId,
    String scope,
    String contextId,
    String key,
  ) async {
    throw UnsupportedError('Not used in these tests');
  }

  @override
  Future<Map<String, dynamic>> queryScopedArray(
    String botId,
    String scope,
    String contextId,
    String key, {
    int offset = 0,
    int limit = 25,
    bool descending = true,
    String? filter,
  }) async {
    throw UnsupportedError('Not used in these tests');
  }

  @override
  Future<Map<String, dynamic>?> getWorkflowByName(
    String botId,
    String name,
  ) async {
    throw UnsupportedError('Not used in these tests');
  }

  @override
  Future<Map<String, dynamic>> getApp(String botId) async =>
      throw UnsupportedError('Not used');

  @override
  Future<List<Map<String, dynamic>>> getWorkflows(String botId) async =>
      throw UnsupportedError('Not used');

  @override
  Future<List<Map<String, dynamic>>> listAppCommands(
    String botId, {
    bool forceRefresh = false,
  }) async =>
      throw UnsupportedError('Not used');

  @override
  Future<void> saveAppCommand(
    String botId,
    String commandId,
    Map<String, dynamic> data,
  ) async =>
      throw UnsupportedError('Not used');

  @override
  Future<void> updateGuildCount(String botId, int count) async =>
      throw UnsupportedError('Not used');

  @override
  Future<void> recordCommandExecution(
    String botId,
    String commandName,
  ) async =>
      throw UnsupportedError('Not used');

  @override
  Map<String, dynamic> normalizeCommandData(Map<String, dynamic> raw) => raw;
}
