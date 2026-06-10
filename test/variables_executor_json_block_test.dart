import 'package:bot_creator_shared/actions/executors/variables_executor.dart';
import 'package:bot_creator_shared/types/action.dart';
import 'package:test/test.dart';

import 'helpers/variables_test_helpers.dart';

void main() {
  group('executeVariablesAction - runtime JSON block', () {
    test(
      'runtimeJsonBlock bootstraps empty source and supports append/index',
      () async {
        final store = MemoryBotDataStore();
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
        final store = MemoryBotDataStore();
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
        final store = MemoryBotDataStore();
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
        expect(
          parentResults['rtJson_0'],
          '{"items":["axe","bow","wand"]}',
        );
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
        final store = MemoryBotDataStore();
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
        final store = MemoryBotDataStore();
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
        final store = MemoryBotDataStore();
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
  });
}
