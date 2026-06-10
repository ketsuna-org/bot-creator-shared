import 'package:bot_creator_shared/actions/executors/variables_executor.dart';
import 'package:bot_creator_shared/types/action.dart';
import 'package:nyxx/nyxx.dart';
import 'package:test/test.dart';

import 'helpers/variables_test_helpers.dart';

void main() {
  group('executeVariablesAction - array operations', () {
    test('appendArrayElement appends to a global root array', () async {
      final store = MemoryBotDataStore();
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
        final store = MemoryBotDataStore(
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
        final store = MemoryBotDataStore();
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
  });
}
