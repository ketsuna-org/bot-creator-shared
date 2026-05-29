import 'dart:convert';

import 'package:bot_creator_shared/actions/executors/control_flow_executor.dart';
import 'package:bot_creator_shared/actions/executors/variables_executor.dart';
import 'package:bot_creator_shared/bot/bot_data_store.dart';
import 'package:bot_creator_shared/types/action.dart';
import 'package:bot_creator_shared/utils/bdfd_compiler.dart';
import 'package:bot_creator_shared/utils/runtime_variables.dart';
import 'package:bot_creator_shared/utils/template_resolver.dart';
import 'package:nyxx/nyxx.dart';
import 'package:test/test.dart';

Map<String, String> _mergeRuntimeContext(
  Map<String, String> variables,
  Map<String, String> inheritedResults,
  Map<String, String> localResults,
) {
  return <String, String>{...variables, ...inheritedResults, ...localResults};
}

Future<Map<String, String>> _executeCompiledActions({
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
        _mergeRuntimeContext(variables, inheritedResults, localResults),
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
        return _executeCompiledActions(
          actions: nestedActions,
          store: store,
          variables: variables,
          replies: replies,
          inheritedResults: _mergeRuntimeContext(
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

void main() {
  group('executeVariablesAction', () {
    test('appendArrayElement appends to a global root array', () async {
      final store = _MemoryBotDataStore();
      final results = <String, String>{};
      final variables = <String, String>{};

      final handled = await executeVariablesAction(
        type: BotCreatorActionType.appendArrayElement,
        store: store,
        botId: 'bot-1',
        payload: <String, dynamic>{
          'target': 'global',
          'key': 'scores',
          'valueType': 'number',
          'numberValue': '4',
        },
        resultKey: 'append',
        results: results,
        variables: variables,
        resolveValue: (input) => input,
        guildId: null,
        fallbackChannelId: null,
        interaction: null,
      );

      expect(handled, isTrue);
      expect(store.globalVariables['scores'], <dynamic>[4]);
      expect(results['append'], '[4]');
      expect(variables['global.scores'], '[4]');
      expect(variables['append.items'], '[4]');
      expect(variables['append.length'], '1');
    });

    test(
      'appendArrayElement and removeArrayElement support scoped JSON paths',
      () async {
        final store = _MemoryBotDataStore(
          scopedVariables: <String, Map<String, Map<String, dynamic>>>{
            'guild': <String, Map<String, dynamic>>{
              'guild-1': <String, dynamic>{
                'stats': <String, dynamic>{
                  'items': <Map<String, dynamic>>[
                    <String, dynamic>{'name': 'Alice'},
                  ],
                },
              },
            },
          },
        );
        final variables = <String, String>{'guildId': 'guild-1'};
        final appendResults = <String, String>{};

        await executeVariablesAction(
          type: BotCreatorActionType.appendArrayElement,
          store: store,
          botId: 'bot-1',
          payload: <String, dynamic>{
            'target': 'scoped',
            'scope': 'guild',
            'key': 'stats',
            'path': r'$.items',
            'valueType': 'json',
            'jsonValue': '{"name":"Bob"}',
          },
          resultKey: 'appendScoped',
          results: appendResults,
          variables: variables,
          resolveValue: (input) => input,
          guildId: Snowflake.parse('1'),
          fallbackChannelId: null,
          interaction: null,
        );

        expect(
          store.scopedVariables['guild']?['guild-1']?['stats'],
          <String, dynamic>{
            'items': <Map<String, dynamic>>[
              <String, dynamic>{'name': 'Alice'},
              <String, dynamic>{'name': 'Bob'},
            ],
          },
        );
        expect(variables['appendScoped.length'], '2');

        final removeResults = <String, String>{};
        await executeVariablesAction(
          type: BotCreatorActionType.removeArrayElement,
          store: store,
          botId: 'bot-1',
          payload: <String, dynamic>{
            'target': 'scoped',
            'scope': 'guild',
            'key': 'stats',
            'path': r'$.items',
            'index': '0',
          },
          resultKey: 'removeScoped',
          results: removeResults,
          variables: variables,
          resolveValue: (input) => input,
          guildId: Snowflake.parse('1'),
          fallbackChannelId: null,
          interaction: null,
        );

        expect(
          store.scopedVariables['guild']?['guild-1']?['stats'],
          <String, dynamic>{
            'items': <Map<String, dynamic>>[
              <String, dynamic>{'name': 'Bob'},
            ],
          },
        );
        expect(removeResults['removeScoped'], '[{"name":"Bob"}]');
        expect(variables['removeScoped.length'], '1');
        expect(variables['removeScoped.removed'], '{"name":"Alice"}');
      },
    );

    test(
      'queryArray filters, sorts, paginates and stores runtime aliases',
      () async {
        final store = _MemoryBotDataStore();
        final results = <String, String>{};
        final variables = <String, String>{};

        final handled = await executeVariablesAction(
          type: BotCreatorActionType.queryArray,
          store: store,
          botId: 'bot-1',
          payload: <String, dynamic>{
            'input':
                '{"items":[{"name":"Charlie","score":7},{"name":"Alice","score":12},{"name":"Bob","score":10}]}',
            'path': r'$.items',
            'filterTemplate': '{score}',
            'filterOperator': 'gte',
            'filterValue': '10',
            'sortTemplate': '{name}',
            'order': 'desc',
            'offset': '0',
            'limit': '1',
            'storeAs': 'topScores',
          },
          resultKey: 'query',
          results: results,
          variables: variables,
          resolveValue: (input) => input,
          guildId: null,
          fallbackChannelId: null,
          interaction: null,
        );

        expect(handled, isTrue);
        expect(results['query'], '[{"name":"Bob","score":10}]');
        expect(variables['query.items'], '[{"name":"Bob","score":10}]');
        expect(variables['query.count'], '1');
        expect(variables['query.total'], '2');
        expect(variables['topScores'], '[{"name":"Bob","score":10}]');
      },
    );

    test(
      'getScopedVariable resolves user scope from fallback runtime identity keys',
      () async {
        final store = _MemoryBotDataStore(
          scopedVariables: <String, Map<String, Map<String, dynamic>>>{
            'user': <String, Map<String, dynamic>>{
              'user-42': <String, dynamic>{'profile': 'dark'},
            },
          },
        );
        final results = <String, String>{};
        final variables = <String, String>{
          'userId': 'Unknown User',
          'interaction.user.id': 'user-42',
        };

        final handled = await executeVariablesAction(
          type: BotCreatorActionType.getScopedVariable,
          store: store,
          botId: 'bot-1',
          payload: <String, dynamic>{'scope': 'user', 'key': 'profile'},
          resultKey: 'getProfile',
          results: results,
          variables: variables,
          resolveValue: (input) => input,
          guildId: null,
          fallbackChannelId: null,
          interaction: null,
        );

        expect(handled, isTrue);
        expect(results['getProfile'], 'dark');
        expect(variables['user.bc_profile'], 'dark');
        expect(variables['user.profile'], 'dark');
        expect(variables['user[user-42].bc_profile'], 'dark');
        expect(variables['user[user-42].profile'], 'dark');
      },
    );

    test(
      'getScopedVariable reads legacy user context and copies to canonical context',
      () async {
        final store = _MemoryBotDataStore(
          scopedVariables: <String, Map<String, Map<String, dynamic>>>{
            'user': <String, Map<String, dynamic>>{
              'Unknown User': <String, dynamic>{'profile': 'legacy'},
            },
          },
        );
        final results = <String, String>{};
        final variables = <String, String>{'userId': 'user-99'};

        final handled = await executeVariablesAction(
          type: BotCreatorActionType.getScopedVariable,
          store: store,
          botId: 'bot-1',
          payload: <String, dynamic>{'scope': 'user', 'key': 'profile'},
          resultKey: 'getProfile',
          results: results,
          variables: variables,
          resolveValue: (input) => input,
          guildId: null,
          fallbackChannelId: null,
          interaction: null,
        );

        expect(handled, isTrue);
        expect(results['getProfile'], 'legacy');
        expect(store.scopedVariables['user']?['user-99']?['profile'], 'legacy');
        expect(
          store.scopedVariables['user']?['Unknown User']?['profile'],
          'legacy',
        );
      },
    );

    test(
      'getScopedVariable falls back to defaultValue from definitions when missing in database',
      () async {
        final store = _MemoryBotDataStore();
        await store.setScopedVariableDefinition(
          'bot-1',
          'streak',
          'user',
          '5',
          valueType: 'string',
        );

        final results = <String, String>{};
        final variables = <String, String>{'userId': 'user-100'};

        final handled = await executeVariablesAction(
          type: BotCreatorActionType.getScopedVariable,
          store: store,
          botId: 'bot-1',
          payload: <String, dynamic>{'scope': 'user', 'key': 'streak'},
          resultKey: 'getStreak',
          results: results,
          variables: variables,
          resolveValue: (input) => input,
          guildId: null,
          fallbackChannelId: null,
          interaction: null,
        );

        expect(handled, isTrue);
        expect(results['getStreak'], '5');
        expect(store.scopedVariables['user']?['user-100']?['streak'], '5');
        expect(variables['user.bc_streak'], '5');
        expect(variables['user.streak'], '5');
      },
    );

    test(
      'getScopedVariable resolves defaultValue with case-insensitive and legacy key matching',
      () async {
        final store = _MemoryBotDataStore();
        await store.setScopedVariableDefinition(
          'bot-1',
          'bc_DAILY_STREAK',
          'User',
          '42',
          valueType: 'string',
        );

        final results = <String, String>{};
        final variables = <String, String>{'userId': 'user-100'};

        final handled = await executeVariablesAction(
          type: BotCreatorActionType.getScopedVariable,
          store: store,
          botId: 'bot-1',
          payload: <String, dynamic>{'scope': 'user', 'key': 'daily_streak'},
          resultKey: 'getStreak',
          results: results,
          variables: variables,
          resolveValue: (input) => input,
          guildId: null,
          fallbackChannelId: null,
          interaction: null,
        );

        expect(handled, isTrue);
        expect(results['getStreak'], '42');
        expect(variables['user.bc_daily_streak'], '42');
      },
    );

    test(
      'getScopedVariable upgrades empty/null variables to non-empty default value while preserving non-empty stored values',
      () async {
        final store = _MemoryBotDataStore();
        await store.setScopedVariableDefinition(
          'bot-1',
          'bc_points',
          'user',
          '100',
          valueType: 'string',
        );

        // Scenario A: User has empty value in database
        await store.setScopedVariable('bot-1', 'user', 'user-1', 'points', '');
        
        // Scenario B: User has non-empty value in database
        await store.setScopedVariable('bot-1', 'user', 'user-2', 'points', '50');

        final resultsA = <String, String>{};
        final variablesA = <String, String>{'userId': 'user-1'};

        final handledA = await executeVariablesAction(
          type: BotCreatorActionType.getScopedVariable,
          store: store,
          botId: 'bot-1',
          payload: <String, dynamic>{'scope': 'user', 'key': 'points'},
          resultKey: 'getPoints',
          results: resultsA,
          variables: variablesA,
          resolveValue: (input) => input,
          guildId: null,
          fallbackChannelId: null,
          interaction: null,
        );

        expect(handledA, isTrue);
        // Should upgrade empty string to definition's defaultValue of '100'
        expect(resultsA['getPoints'], '100');
        expect(store.scopedVariables['user']?['user-1']?['points'], '100');

        final resultsB = <String, String>{};
        final variablesB = <String, String>{'userId': 'user-2'};

        final handledB = await executeVariablesAction(
          type: BotCreatorActionType.getScopedVariable,
          store: store,
          botId: 'bot-1',
          payload: <String, dynamic>{'scope': 'user', 'key': 'points'},
          resultKey: 'getPoints',
          results: resultsB,
          variables: variablesB,
          resolveValue: (input) => input,
          guildId: null,
          fallbackChannelId: null,
          interaction: null,
        );

        expect(handledB, isTrue);
        // Should preserve existing value '50'
        expect(resultsB['getPoints'], '50');
        expect(store.scopedVariables['user']?['user-2']?['points'], '50');
      },
    );

    test(
      'runtimeJsonBlock bootstraps empty source and supports append/index',
      () async {
        final store = _MemoryBotDataStore();
        final results = <String, String>{};
        final variables = <String, String>{};

        final handled = await executeVariablesAction(
          type: BotCreatorActionType.runtimeJsonBlock,
          store: store,
          botId: 'bot-1',
          payload: <String, dynamic>{
            'source': '((guild.bc_items_db))',
            'operations': <Map<String, dynamic>>[
              <String, dynamic>{
                'op': 'arrayAppend',
                'path': <String>['items'],
                'value': 'sword',
              },
              <String, dynamic>{
                'op': 'arrayIndex',
                'path': <String>['items'],
                'value': 'sword',
                'readIndex': 0,
              },
            ],
          },
          resultKey: 'rtJson',
          results: results,
          variables: variables,
          resolveValue:
              (input) => input == '((guild.bc_items_db))' ? '' : input,
          guildId: null,
          fallbackChannelId: null,
          interaction: null,
        );

        expect(handled, isTrue);
        expect(results['rtJson'], '{"items":["sword"]}');
        expect(variables['rtJson.json_0'], '0');
      },
    );

    test(
      'runtimeJsonBlock reuses same-block json reads inside later path segments',
      () async {
        final store = _MemoryBotDataStore();
        final results = <String, String>{};
        final variables = <String, String>{};

        final handled = await executeVariablesAction(
          type: BotCreatorActionType.runtimeJsonBlock,
          store: store,
          botId: 'bot-1',
          payload: <String, dynamic>{
            'source': '((guild.bc_items_db))',
            'operations': <Map<String, dynamic>>[
              <String, dynamic>{
                'op': 'arrayAppend',
                'path': <String>['items'],
                'value': 'shield',
              },
              <String, dynamic>{
                'op': 'arrayAppend',
                'path': <String>['items'],
                'value': 'potion',
              },
              <String, dynamic>{
                'op': 'arrayIndex',
                'path': <String>['items'],
                'value': 'potion',
                'readIndex': 0,
              },
              <String, dynamic>{
                'op': 'get',
                'path': <String>['items', '((rtJson.json_0))'],
                'readIndex': 1,
              },
            ],
          },
          resultKey: 'rtJson',
          results: results,
          variables: variables,
          resolveValue:
              (input) => input == '((guild.bc_items_db))' ? '' : input,
          guildId: null,
          fallbackChannelId: null,
          interaction: null,
        );

        expect(handled, isTrue);
        expect(results['rtJson'], '{"items":["shield","potion"]}');
        expect(variables['rtJson.json_0'], '1');
        expect(variables['rtJson.json_1'], 'potion');
      },
    );

    test(
      'runtimeJsonBlock stores root json in variables for nested branch reuse',
      () async {
        final store = _MemoryBotDataStore();
        final parentResults = <String, String>{};
        final variables = <String, String>{};

        final parentHandled = await executeVariablesAction(
          type: BotCreatorActionType.runtimeJsonBlock,
          store: store,
          botId: 'bot-1',
          payload: <String, dynamic>{
            'source': '((guild.bc_items_db))',
            'operations': <Map<String, dynamic>>[
              <String, dynamic>{
                'op': 'arrayIndex',
                'path': <String>['items'],
                'value': 'bow',
                'readIndex': 0,
              },
            ],
          },
          resultKey: 'rtJson_0',
          results: parentResults,
          variables: variables,
          resolveValue:
              (input) =>
                  input == '((guild.bc_items_db))'
                      ? '{"items":["axe","bow","wand"]}'
                      : input,
          guildId: null,
          fallbackChannelId: null,
          interaction: null,
        );

        expect(parentHandled, isTrue);
        expect(parentResults['rtJson_0'], '{"items":["axe","bow","wand"]}');
        expect(variables['rtJson_0'], '{"items":["axe","bow","wand"]}');
        expect(variables['rtJson_0.json_0'], '1');

        // Simulate nested if/else execution where branch actions get a fresh
        // results map but still share the same variables map.
        final branchResults = <String, String>{};
        final branchHandled = await executeVariablesAction(
          type: BotCreatorActionType.runtimeJsonBlock,
          store: store,
          botId: 'bot-1',
          payload: <String, dynamic>{
            'source': '((rtJson_0))',
            'operations': <Map<String, dynamic>>[
              <String, dynamic>{
                'op': 'get',
                'path': <String>['items', '((rtJson_0.json_0))'],
                'readIndex': 0,
              },
            ],
          },
          resultKey: 'rtJson_1',
          results: branchResults,
          variables: variables,
          resolveValue: (input) => input,
          guildId: null,
          fallbackChannelId: null,
          interaction: null,
        );

        expect(branchHandled, isTrue);
        expect(branchResults['rtJson_1.json_0'], 'bow');
        expect(variables['rtJson_1.json_0'], 'bow');
      },
    );

    test(
      'runtimeJsonBlock resolves temp scope and loop index inside weighted item paths',
      () async {
        final store = _MemoryBotDataStore();
        final results = <String, String>{};
        final variables = <String, String>{
          'temp.in': 'items',
          '_loop.index': '1',
        };

        final handled = await executeVariablesAction(
          type: BotCreatorActionType.runtimeJsonBlock,
          store: store,
          botId: 'bot-1',
          payload: <String, dynamic>{
            'source': '((guild.bc_items_db))',
            'operations': <Map<String, dynamic>>[
              <String, dynamic>{
                'op': 'get',
                'path': <String>['((temp.in))', '((_loop.index))', 'name'],
                'readIndex': 0,
              },
              <String, dynamic>{
                'op': 'get',
                'path': <String>['((temp.in))', '((_loop.index))', 'weight'],
                'readIndex': 1,
              },
            ],
          },
          resultKey: 'rtJson',
          results: results,
          variables: variables,
          resolveValue:
              (input) =>
                  input == '((guild.bc_items_db))'
                      ? '{"items":[{"name":"axe","weight":2},{"name":"sword","weight":5}]}'
                      : input,
          guildId: null,
          fallbackChannelId: null,
          interaction: null,
        );

        expect(handled, isTrue);
        expect(
          results['rtJson'],
          '{"items":[{"name":"axe","weight":2},{"name":"sword","weight":5}]}',
        );
        expect(variables['rtJson.json_0'], 'sword');
        expect(variables['rtJson.json_1'], '5');
      },
    );

    test(
      'runtimeJsonBlock resolves enabled rarity name and weight for one loot item',
      () async {
        final store = _MemoryBotDataStore();
        final results = <String, String>{};
        final variables = <String, String>{
          'temp.in': 'items',
          '_loop.index': '0',
        };

        final handled = await executeVariablesAction(
          type: BotCreatorActionType.runtimeJsonBlock,
          store: store,
          botId: 'bot-1',
          payload: <String, dynamic>{
            'source': '((guild.bc_items_db))',
            'operations': <Map<String, dynamic>>[
              <String, dynamic>{
                'op': 'get',
                'path': <String>['((temp.in))', '((_loop.index))', 'enabled'],
                'readIndex': 0,
              },
              <String, dynamic>{
                'op': 'get',
                'path': <String>['((temp.in))', '((_loop.index))', 'rarity'],
                'readIndex': 1,
              },
              <String, dynamic>{
                'op': 'get',
                'path': <String>['((temp.in))', '((_loop.index))', 'name'],
                'readIndex': 2,
              },
              <String, dynamic>{
                'op': 'get',
                'path': <String>['((temp.in))', '((_loop.index))', 'weight'],
                'readIndex': 3,
              },
            ],
          },
          resultKey: 'rtJson',
          results: results,
          variables: variables,
          resolveValue:
              (input) =>
                  input == '((guild.bc_items_db))'
                      ? '{"items":[{"enabled":true,"rarity":"legendary","name":"phoenix_blade","weight":8}]}'
                      : input,
          guildId: null,
          fallbackChannelId: null,
          interaction: null,
        );

        expect(handled, isTrue);
        expect(variables['rtJson.json_0'], 'true');
        expect(variables['rtJson.json_1'], 'legendary');
        expect(variables['rtJson.json_2'], 'phoenix_blade');
        expect(variables['rtJson.json_3'], '8');
      },
    );

    test(
      'runtimeJsonBlock recovers from scalar source by promoting to object',
      () async {
        final store = _MemoryBotDataStore();
        final results = <String, String>{};
        final variables = <String, String>{};

        final handled = await executeVariablesAction(
          type: BotCreatorActionType.runtimeJsonBlock,
          store: store,
          botId: 'bot-1',
          payload: <String, dynamic>{
            'source': '((guild.bc_items_db))',
            'operations': <Map<String, dynamic>>[
              <String, dynamic>{
                'op': 'arrayAppend',
                'path': <String>['items'],
                'value': 'sword',
              },
            ],
          },
          resultKey: 'rtJson',
          results: results,
          variables: variables,
          resolveValue:
              (input) =>
                  input == '((guild.bc_items_db))'
                      ? '1453848265786396794'
                      : input,
          guildId: null,
          fallbackChannelId: null,
          interaction: null,
        );

        expect(handled, isTrue);
        expect(results['rtJson'], '{"items":["sword"]}');
      },
    );

    test(
      'setTemporaryVariable stores a resolved runtime value in the temp namespace',
      () async {
        final store = _MemoryBotDataStore();
        final results = <String, String>{'rtJson_0.json_0': '2'};
        final variables = <String, String>{};

        final handled = await executeVariablesAction(
          type: BotCreatorActionType.setTemporaryVariable,
          store: store,
          botId: 'bot-1',
          payload: <String, dynamic>{
            'key': 'looping',
            'valueType': 'string',
            'value': '((rtJson_0.json_0))',
          },
          resultKey: 'setTemp',
          results: results,
          variables: variables,
          resolveValue: (input) => input == '((rtJson_0.json_0))' ? '' : input,
          guildId: null,
          fallbackChannelId: null,
          interaction: null,
        );

        expect(handled, isTrue);
        expect(results['setTemp'], 'OK');
        expect(variables['temp.looping'], '2');
        expect(variables['setTemp.value'], '2');
        expect(variables['setTemp.sourceRaw'], '((rtJson_0.json_0))');
        expect(variables['setTemp.scope'], 'temp');
        expect(variables['setTemp.key'], 'looping');
      },
    );

    test(
      'setTemporaryVariable can resolve a runtime random threshold template',
      () async {
        final store = _MemoryBotDataStore();
        final results = <String, String>{};
        final variables = <String, String>{};

        final handled = await executeVariablesAction(
          type: BotCreatorActionType.setTemporaryVariable,
          store: store,
          botId: 'bot-1',
          payload: <String, dynamic>{
            'key': 'roll',
            'valueType': 'string',
            'value': '((randomint(1, 10)))',
          },
          resultKey: 'setRoll',
          results: results,
          variables: variables,
          resolveValue:
              (input) => resolveTemplatePlaceholders(input, <String, String>{
                ...variables,
                ...results,
              }),
          guildId: null,
          fallbackChannelId: null,
          interaction: null,
        );

        expect(handled, isTrue);
        final rollValue = int.tryParse(variables['temp.roll'] ?? '');
        expect(rollValue, isNotNull);
        expect(rollValue!, inInclusiveRange(1, 10));
      },
    );

    test(
      'setScopedVariable falls back to merged variables/results for placeholders',
      () async {
        final store = _MemoryBotDataStore();
        final results = <String, String>{
          'rtJson_0.json_0': '{"items":["sword"]}',
        };
        final variables = <String, String>{'guildId': 'guild-1'};

        final handled = await executeVariablesAction(
          type: BotCreatorActionType.setScopedVariable,
          store: store,
          botId: 'bot-1',
          payload: <String, dynamic>{
            'scope': 'guild',
            'key': 'items_db',
            'valueType': 'string',
            'value': '((rtJson_0.json_0))',
          },
          resultKey: 'setItems',
          results: results,
          variables: variables,
          // Simulate a resolver that does not know action results.
          resolveValue: (input) => input == '((rtJson_0.json_0))' ? '' : input,
          guildId: Snowflake.parse('1'),
          fallbackChannelId: null,
          interaction: null,
        );

        expect(handled, isTrue);
        expect(
          store.scopedVariables['guild']?['guild-1']?['items_db'],
          '{"items":["sword"]}',
        );
        expect(variables['guild.bc_items_db'], '{"items":["sword"]}');
        expect(variables['setItems.persisted'], '{"items":["sword"]}');
        expect(results['setItems'], 'OK');
      },
    );

    test(
      'setScopedVariable resolves non-empty unresolved placeholders from merged context',
      () async {
        final store = _MemoryBotDataStore();
        final results = <String, String>{
          'rtJson_0.json_0': '{"items":["epee"]}',
        };
        final variables = <String, String>{'guildId': 'guild-1'};

        final handled = await executeVariablesAction(
          type: BotCreatorActionType.setScopedVariable,
          store: store,
          botId: 'bot-1',
          payload: <String, dynamic>{
            'scope': 'guild',
            'key': 'items_db',
            'valueType': 'string',
            'value': '((rtJson_0.json_0))',
          },
          resultKey: 'setItems2',
          results: results,
          variables: variables,
          // Simulate a resolver that leaves unknown placeholders unchanged.
          resolveValue: (input) => input,
          guildId: Snowflake.parse('1'),
          fallbackChannelId: null,
          interaction: null,
        );

        expect(handled, isTrue);
        expect(
          store.scopedVariables['guild']?['guild-1']?['items_db'],
          '{"items":["epee"]}',
        );
        expect(variables['guild.bc_items_db'], '{"items":["epee"]}');
        expect(results['setItems2'], 'OK');
      },
    );

    test(
      'setScopedVariable falls back to rtJson root when json index key is missing',
      () async {
        final store = _MemoryBotDataStore();
        final results = <String, String>{'rtJson_0': '{"items":["axe"]}'};
        final variables = <String, String>{'guildId': 'guild-1'};

        final handled = await executeVariablesAction(
          type: BotCreatorActionType.setScopedVariable,
          store: store,
          botId: 'bot-1',
          payload: <String, dynamic>{
            'scope': 'guild',
            'key': 'items_db',
            'valueType': 'string',
            'value': '((rtJson_0.json_9))',
          },
          resultKey: 'setItems3',
          results: results,
          variables: variables,
          // Simulate a resolver that does not know action results.
          resolveValue: (input) => input == '((rtJson_0.json_9))' ? '' : input,
          guildId: Snowflake.parse('1'),
          fallbackChannelId: null,
          interaction: null,
        );

        expect(handled, isTrue);
        expect(
          store.scopedVariables['guild']?['guild-1']?['items_db'],
          '{"items":["axe"]}',
        );
        expect(variables['guild.bc_items_db'], '{"items":["axe"]}');
        expect(variables['setItems3.persisted'], '{"items":["axe"]}');
        expect(results['setItems3'], 'OK');
      },
    );

    test(
      'setScopedVariable resolves rtJson placeholder from action alias keys',
      () async {
        final store = _MemoryBotDataStore();
        final results = <String, String>{
          'action_1.json_0': '{"items":["bow"]}',
          'action_1': '{"items":["bow"]}',
        };
        final variables = <String, String>{'guildId': 'guild-1'};

        final handled = await executeVariablesAction(
          type: BotCreatorActionType.setScopedVariable,
          store: store,
          botId: 'bot-1',
          payload: <String, dynamic>{
            'scope': 'guild',
            'key': 'items_db',
            'valueType': 'string',
            'value': '((rtJson_0.json_0))',
          },
          resultKey: 'setItems4',
          results: results,
          variables: variables,
          // Simulate a resolver that does not know action results.
          resolveValue: (input) => input == '((rtJson_0.json_0))' ? '' : input,
          guildId: Snowflake.parse('1'),
          fallbackChannelId: null,
          interaction: null,
        );

        expect(handled, isTrue);
        expect(
          store.scopedVariables['guild']?['guild-1']?['items_db'],
          '{"items":["bow"]}',
        );
        expect(variables['setItems4.directFallback'], '{"items":["bow"]}');
        expect(variables['setItems4.persisted'], '{"items":["bow"]}');
        expect(results['setItems4'], 'OK');
      },
    );

    test(
      'setScopedVariable rtJson alias prefers JSON action value over status strings',
      () async {
        final store = _MemoryBotDataStore();
        final results = <String, String>{
          'action_0': 'OK',
          'action_1': 'store',
          'action_2': '{"items":["shield"]}',
        };
        final variables = <String, String>{'guildId': 'guild-1'};

        final handled = await executeVariablesAction(
          type: BotCreatorActionType.setScopedVariable,
          store: store,
          botId: 'bot-1',
          payload: <String, dynamic>{
            'scope': 'guild',
            'key': 'items_db',
            'valueType': 'string',
            'value': '((rtJson_0))',
          },
          resultKey: 'setItems6',
          results: results,
          variables: variables,
          resolveValue: (input) => input == '((rtJson_0))' ? '' : input,
          guildId: Snowflake.parse('1'),
          fallbackChannelId: null,
          interaction: null,
        );

        expect(handled, isTrue);
        expect(
          store.scopedVariables['guild']?['guild-1']?['items_db'],
          '{"items":["shield"]}',
        );
        expect(variables['setItems6.persisted'], '{"items":["shield"]}');
        expect(results['setItems6'], 'OK');
      },
    );

    test(
      r'setScopedVariable resolves literal $jsonStringify from runtime json results',
      () async {
        final store = _MemoryBotDataStore();
        final results = <String, String>{'rtJson_0': '{"items":["hammer"]}'};
        final variables = <String, String>{'guildId': 'guild-1'};

        final handled = await executeVariablesAction(
          type: BotCreatorActionType.setScopedVariable,
          store: store,
          botId: 'bot-1',
          payload: <String, dynamic>{
            'scope': 'guild',
            'key': 'items_db',
            'valueType': 'string',
            'value': r'$jsonStringify',
          },
          resultKey: 'setItems5',
          results: results,
          variables: variables,
          resolveValue: (input) => input == r'$jsonStringify' ? '' : input,
          guildId: Snowflake.parse('1'),
          fallbackChannelId: null,
          interaction: null,
        );

        expect(handled, isTrue);
        expect(
          store.scopedVariables['guild']?['guild-1']?['items_db'],
          '{"items":["hammer"]}',
        );
        expect(variables['setItems5.persisted'], '{"items":["hammer"]}');
        expect(results['setItems5'], 'OK');
      },
    );

    test(
      'compiled BDFD script resolves dynamic getServerVar keys with bc_ prefix args',
      () async {
        final store = _MemoryBotDataStore(
          scopedVariables: <String, Map<String, Map<String, dynamic>>>{
            'guild': <String, Map<String, dynamic>>{
              'guild-1': <String, dynamic>{
                'wallet_db':
                    '{"currencies":[{"name":"bunbux"},{"name":"carrots"},{"name":"test"}]}',
              },
            },
          },
        );
        final variables = <String, String>{
          'guildId': 'guild-1',
          'args.2': 'bc_wallet_db',
          'args.3': 'carrots',
          'args.4': 'currencies',
        };
        await hydrateRuntimeVariables(
          store: store,
          botId: 'bot-1',
          runtimeVariables: variables,
          guildContextId: 'guild-1',
        );

        final compileResult = BdfdCompiler().compile(
          r'$var[s;$args[3]]'
          r'$var[in;$args[4]]'
          r'$jsonParse[$getServerVar[$args[2]]]'
          r'$for[$jsonArrayCount[$var[in]]]'
          r'$if[$json[$var[in];$i;name]==$var[s]]'
          r'$var[r;$i]'
          r'$endif'
          r'$endfor'
          r'$reply$var[r]',
        );

        expect(compileResult.hasErrors, isFalse);

        final replies = <String>[];
        final results = await _executeCompiledActions(
          actions: compileResult.actions,
          store: store,
          variables: variables,
          replies: replies,
        );

        expect(
          variables['rtJson_0'],
          '{"currencies":[{"name":"bunbux"},{"name":"carrots"},{"name":"test"}]}',
        );
        expect(variables['rtJson_1.json_0'], '3');
        expect(variables['temp.r'], '1');
        expect(replies, <String>['1']);
        expect(results.values, contains('1'));
      },
    );

    group(r'runtime $jsonSet array support', () {
      // Helper: compile BDFD script + run, return (variables, replies).
      Future<(Map<String, String>, List<String>)> runScript(
        String script, {
        Map<String, String> vars = const <String, String>{},
      }) async {
        final compiled = BdfdCompiler().compile(script);
        expect(compiled.hasErrors, isFalse, reason: 'Compile errors: $script');
        final store = _MemoryBotDataStore();
        final variables = <String, String>{
          'guild.id': 'guild-1',
          'bot.id': 'bot-1',
          ...vars,
        };
        final replies = <String>[];
        await _executeCompiledActions(
          actions: compiled.actions,
          store: store,
          variables: variables,
          replies: replies,
        );
        return (variables, replies);
      }

      test('creates array element from empty object', () async {
        // Source JSON is empty (guild.bc_db not pre-set → jsonCtx defaults to {}).
        // $jsonSet[currency;0;name;carrot] should produce
        // {"currency":[{"name":"carrot"}]}
        final (_, replies) = await runScript(
          r'$jsonParse[$getServerVar[db]]'
          r'$jsonSet[currency;0;name;carrot]'
          r'$reply$jsonStringify',
        );
        expect(replies, hasLength(1));
        final decoded = jsonDecode(replies.first) as Map<String, dynamic>;
        expect(decoded['currency'], isA<List>());
        expect(
          (decoded['currency'] as List).first,
          containsPair('name', 'carrot'),
        );
      });

      test('mutates existing array element', () async {
        // Pre-populate the guild variable in variables map (as the runtime does).
        // $jsonSet[currency;1;name;carrot] → index 1 updated
        final (_, replies) = await runScript(
          r'$jsonParse[$getServerVar[db]]'
          r'$jsonSet[currency;1;name;carrot]'
          r'$reply$jsonStringify',
          vars: <String, String>{
            'guild.bc_db': '{"currency":[{"name":"bunbux"},{"name":"old"}]}',
          },
        );
        expect(replies, hasLength(1));
        final decoded = jsonDecode(replies.first) as Map<String, dynamic>;
        final list = decoded['currency'] as List;
        expect(list[0], containsPair('name', 'bunbux'));
        expect(list[1], containsPair('name', 'carrot'));
      });

      test('extends list with nulls when index is out of bounds', () async {
        // Pre-populate guild.bc_db = '{"arr":[]}'.
        // $jsonSet[arr;2;x;1] → arr=[null,null,{"x":1}]
        final (_, replies) = await runScript(
          r'$jsonParse[$getServerVar[db]]'
          r'$jsonSet[arr;2;x;1]'
          r'$reply$jsonStringify',
          vars: <String, String>{'guild.bc_db': '{"arr":[]}'},
        );
        expect(replies, hasLength(1));
        final decoded = jsonDecode(replies.first) as Map<String, dynamic>;
        final arr = decoded['arr'] as List;
        expect(arr.length, 3);
        expect(arr[0], isNull);
        expect(arr[1], isNull);
        expect(arr[2], containsPair('x', 1));
      });

      test(
        r'nested $jsonParse inside $if does not leak prefix to outer scope',
        () async {
          // After $endif, $json[outerKey] must read from outer block (rtJson_0),
          // not from the inner block created inside the $if branch.
          final (vars, _) = await runScript(
            r'$jsonParse[$getServerVar[outer]]'
            r'$if[$json[flag]==yes]'
            r'$jsonParse[$getServerVar[inner]]'
            r'$var[inner;$json[innerKey]]'
            r'$endif'
            r'$var[outer;$json[outerKey]]',
            vars: <String, String>{
              'guild.bc_outer': '{"outerKey":"outer_val","flag":"no"}',
              'guild.bc_inner': '{"innerKey":"inner_val"}',
            },
          );
          expect(vars['temp.outer'], 'outer_val');
          // inner branch was not taken (flag=="no"), inner var absent/empty.
          expect(vars['temp.inner'] ?? '', isEmpty);
        },
      );
    });
  });
}

class _MemoryBotDataStore implements BotDataStore {
  _MemoryBotDataStore({
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
