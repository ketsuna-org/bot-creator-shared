import 'package:bot_creator_shared/bot/bot_data_store.dart';
import 'package:bot_creator_shared/utils/runtime_variables.dart';
import 'package:bot_creator_shared/utils/template_resolver.dart';
import 'package:test/test.dart';

void main() {
  group('hydrateActionPlaceholders', () {
    test('correctly identifies fallback and nested placeholders', () async {
      final variables = <String, String>{};
      final actions = [
        {
          'payload': {
            'content': '((member[123].displayName|user[123].displayName))',
            'embed': {
              'description': '((tolowercase(user[456].username)))'
            }
          }
        }
      ];

      final hydrated = <String>[];

      Future<void> mockDiscordFetcher(
        String scope,
        String contextId,
        Map<String, String> vars,
      ) async {
        hydrated.add('$scope[$contextId]');
      }

      final store = _FakeBotDataStore(
        globalVariables: const {},
        scopedVariables: const {},
      );

      await hydrateActionPlaceholders(
        store: store,
        botId: 'bot-1',
        actions: actions,
        variables: variables,
        discordFetcher: mockDiscordFetcher,
      );

      expect(hydrated, contains('member[123]'));
      expect(hydrated, contains('user[123]'));
      expect(hydrated, contains('user[456]'));
      expect(hydrated.length, 3);
    });

    test('is resilient to individual hydration failures', () async {
      final variables = <String, String>{};
      final actions = [
        {
          'payload': {
            'content': '((member[123].displayName|user[123].displayName))'
          }
        }
      ];

      final hydrated = <String>[];

      Future<void> mockDiscordFetcher(
        String scope,
        String contextId,
        Map<String, String> vars,
      ) async {
        if (scope == 'member') {
          throw Exception('Simulated member fetch failure');
        }
        hydrated.add('$scope[$contextId]');
        vars['$scope[$contextId].displayName'] = 'Resolved $scope';
      }

      final store = _FakeBotDataStore(
        globalVariables: const {},
        scopedVariables: const {},
      );

      // Should not throw even though member fetch fails
      await hydrateActionPlaceholders(
        store: store,
        botId: 'bot-1',
        actions: actions,
        variables: variables,
        discordFetcher: mockDiscordFetcher,
      );

      expect(hydrated, contains('user[123]'));
      expect(hydrated, isNot(contains('member[123]')));

      // Fallback should work
      final resolved = resolveTemplatePlaceholders(
        '((member[123].displayName|user[123].displayName))',
        variables,
      );
      expect(resolved, 'Resolved user');
    });
  });
}

class _FakeBotDataStore implements BotDataStore {
  _FakeBotDataStore({
    required this.globalVariables,
    required this.scopedVariables,
  });

  final Map<String, dynamic> globalVariables;
  final Map<String, Map<String, Map<String, dynamic>>> scopedVariables;

  @override
  Future<List<Map<String, dynamic>>> getCommands(String botId) async =>
      const [];

  @override
  Future<List<Map<String, dynamic>>> getScopedVariableDefinitions(
    String botId,
  ) async => const [];

  @override
  Future<void> setScopedVariableDefinition(
    String botId,
    String key,
    String scope,
    dynamic defaultValue, {
    String valueType = 'string',
  }) {
    throw UnsupportedError('Not used in this test');
  }

  @override
  Future<Map<String, dynamic>> getGlobalVariables(String botId) async =>
      Map<String, dynamic>.from(globalVariables);

  @override
  Future<dynamic> getGlobalVariable(String botId, String key) async =>
      globalVariables[key];

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
  Future<Map<String, dynamic>?> getWorkflowByName(
    String botId,
    String name,
  ) async {
    throw UnsupportedError('Not used in these tests');
  }

  @override
  Future<int> getScopedArrayLength(
    String botId,
    String scope,
    String contextId,
    String key,
  ) {
    throw UnsupportedError('Not used in this test');
  }

  @override
  Future<dynamic> getScopedArrayElement(
    String botId,
    String scope,
    String contextId,
    String key,
    int index,
  ) {
    throw UnsupportedError('Not used in this test');
  }

  @override
  Future<dynamic> popScopedArrayElement(
    String botId,
    String scope,
    String contextId,
    String key,
  ) {
    throw UnsupportedError('Not used in this test');
  }

  @override
  Future<void> pushScopedArrayElement(
    String botId,
    String scope,
    String contextId,
    String key,
    element,
  ) {
    throw UnsupportedError('Not used in this test');
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
  }) {
    throw UnsupportedError('Not used in this test');
  }

  @override
  Future<Map<String, dynamic>> queryScopedVariableIndex(
    String botId,
    String scope,
    String key, {
    int offset = 0,
    int limit = 25,
    bool descending = true,
  }) {
    throw UnsupportedError('Not used in this test');
  }

  @override
  Future<void> removeGlobalVariable(String botId, String key) {
    throw UnsupportedError('Not used in this test');
  }

  @override
  Future<void> removeScopedArrayElement(
    String botId,
    String scope,
    String contextId,
    String key,
    int index,
  ) {
    throw UnsupportedError('Not used in this test');
  }

  @override
  Future<void> removeScopedVariable(
    String botId,
    String scope,
    String contextId,
    String key,
  ) {
    throw UnsupportedError('Not used in this test');
  }

  @override
  Future<void> renameGlobalVariable(
    String botId,
    String oldKey,
    String newKey,
  ) {
    throw UnsupportedError('Not used in this test');
  }

  @override
  Future<void> renameScopedVariable(
    String botId,
    String scope,
    String contextId,
    String oldKey,
    String newKey,
  ) {
    throw UnsupportedError('Not used in this test');
  }

  @override
  Future<void> setGlobalVariable(
    String botId,
    String key,
    dynamic value, {
    String? ttl,
  }) {
    throw UnsupportedError('Not used in this test');
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
  ) {
    throw UnsupportedError('Not used in this test');
  }

  @override
  Future<Map<String, dynamic>> getApp(String botId) async => throw UnsupportedError('Not used');

  @override
  Future<List<Map<String, dynamic>>> getWorkflows(String botId) async => throw UnsupportedError('Not used');

  @override
  Future<List<Map<String, dynamic>>> listAppCommands(String botId, {bool forceRefresh = false}) async => throw UnsupportedError('Not used');

  @override
  Future<void> saveAppCommand(String botId, String commandId, Map<String, dynamic> data) async => throw UnsupportedError('Not used');

  @override
  Future<void> updateGuildCount(String botId, int count) async => throw UnsupportedError('Not used');

  @override
  Future<void> recordCommandExecution(String botId, String commandName) async => throw UnsupportedError('Not used');

  @override
  Map<String, dynamic> normalizeCommandData(Map<String, dynamic> raw) => raw;
}
