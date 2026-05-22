import 'package:bot_creator_shared/bot/bot_data_store.dart';
import 'package:bot_creator_shared/engine/workflow_executor.dart';
import 'package:bot_creator_shared/engine/bot_engine_callbacks.dart';
import 'package:nyxx/nyxx.dart';
import 'package:test/test.dart';

void main() {
  group('WorkflowExecutor _transpileVisualActions Type Safety', () {
    test(
      'resilient to Map<dynamic, dynamic> payloads during transpilation',
      () async {
        final store = _MockBotDataStore();
        final callbacks = BotEngineCallbacks(
          onLog: (msg, {required String botId}) {},
          onDebugLog: (msg, {String? botId}) {},
        );

        final executor = WorkflowExecutor(store: store, callbacks: callbacks);

        // Construct a payload containing Map<dynamic, dynamic>
        final dynamicMapPayload = <dynamic, dynamic>{
          'embed': <dynamic, dynamic>{
            'title': 'Test Title',
            'description': 'Test Description',
            'fields': <dynamic>[
              <dynamic, dynamic>{'name': 'f1', 'value': 'v1'},
            ],
          },
        };

        final actionsData = <Map<String, dynamic>>[
          <String, dynamic>{
            'type': 'sendMessage',
            'payload': dynamicMapPayload,
          },
        ];

        final workflowData = <String, dynamic>{
          'response': <String, dynamic>{
            'workflow': <String, dynamic>{'autoDeferIfActions': false},
            'embeds': <dynamic>[],
          },
          'actions': actionsData,
        };

        // We expect executeGeneralWorkflow to complete successfully without throwing
        // "type '_Map<dynamic, dynamic>' is not a subtype of type 'Map<String, dynamic>' in type cast"
        expect(
          () async {
            await executor.executeGeneralWorkflow(
              workflowData: workflowData,
              gateway: _MockNyxxGateway(),
              botId: 'test-bot',
              runtimeVariables: <String, String>{},
            );
          },
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Missing or invalid channelId for sendMessage'),
            ),
          ),
        );
      },
    );
  });
}

class _MockBotDataStore implements BotDataStore {
  @override
  Future<List<Map<String, dynamic>>> getCommands(String botId) async => [];

  @override
  Future<List<Map<String, dynamic>>> getScopedVariableDefinitions(
    String botId,
  ) async => [];

  @override
  Future<void> setScopedVariableDefinition(
    String botId,
    String key,
    String scope,
    dynamic defaultValue, {
    String valueType = 'string',
  }) async {}

  @override
  Future<Map<String, dynamic>> getGlobalVariables(String botId) async => {};

  @override
  Future<dynamic> getGlobalVariable(String botId, String key) async => null;

  @override
  Future<void> setGlobalVariable(
    String botId,
    String key,
    dynamic value, {
    String? ttl,
  }) async {}

  @override
  Future<void> renameGlobalVariable(
    String botId,
    String oldKey,
    String newKey,
  ) async {}

  @override
  Future<void> removeGlobalVariable(String botId, String key) async {}

  @override
  Future<Map<String, dynamic>> getScopedVariables(
    String botId,
    String scope,
    String contextId,
  ) async => {};

  @override
  Future<dynamic> getScopedVariable(
    String botId,
    String scope,
    String contextId,
    String key,
  ) async => null;

  @override
  Future<void> setScopedVariable(
    String botId,
    String scope,
    String contextId,
    String key,
    dynamic value, {
    String? ttl,
  }) async {}

  @override
  Future<void> renameScopedVariable(
    String botId,
    String scope,
    String contextId,
    String oldKey,
    String newKey,
  ) async {}

  @override
  Future<void> removeScopedVariable(
    String botId,
    String scope,
    String contextId,
    String key,
  ) async {}

  @override
  Future<void> pushScopedArrayElement(
    String botId,
    String scope,
    String contextId,
    String key,
    dynamic element,
  ) async {}

  @override
  Future<dynamic> popScopedArrayElement(
    String botId,
    String scope,
    String contextId,
    String key,
  ) async => null;

  @override
  Future<dynamic> removeScopedArrayElement(
    String botId,
    String scope,
    String contextId,
    String key,
    int index,
  ) async => null;

  @override
  Future<dynamic> getScopedArrayElement(
    String botId,
    String scope,
    String contextId,
    String key,
    int index,
  ) async => null;

  @override
  Future<int> getScopedArrayLength(
    String botId,
    String scope,
    String contextId,
    String key,
  ) async => 0;

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
  }) async => {};

  @override
  Future<Map<String, dynamic>> queryScopedVariableIndex(
    String botId,
    String scope,
    String key, {
    int offset = 0,
    int limit = 25,
    bool descending = true,
  }) async => {};

  @override
  Future<int?> getScopedVariableTtl(
    String botId,
    String scope,
    String contextId,
    String key,
  ) async => null;

  @override
  Future<Map<String, dynamic>> getApp(String botId) async => {};

  @override
  Future<List<Map<String, dynamic>>> getWorkflows(String botId) async => [];

  @override
  Future<Map<String, dynamic>?> getWorkflowByName(
    String botId,
    String name,
  ) async => null;

  @override
  Future<List<Map<String, dynamic>>> listAppCommands(
    String botId, {
    bool forceRefresh = false,
  }) async => [];

  @override
  Future<void> saveAppCommand(
    String botId,
    String commandId,
    Map<String, dynamic> data,
  ) async {}

  @override
  Future<void> updateGuildCount(String botId, int count) async {}

  @override
  Future<void> recordCommandExecution(String botId, String commandName) async {}

  @override
  Map<String, dynamic> normalizeCommandData(Map<String, dynamic> raw) => raw;
}

class _MockNyxxGateway implements NyxxGateway {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
