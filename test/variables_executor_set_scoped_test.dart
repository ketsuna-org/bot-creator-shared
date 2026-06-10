import 'package:bot_creator_shared/actions/executors/variables_executor.dart';
import 'package:bot_creator_shared/types/action.dart';
import 'package:bot_creator_shared/utils/template_resolver.dart';
import 'package:nyxx/nyxx.dart';
import 'package:test/test.dart';

import 'helpers/variables_test_helpers.dart';

void main() {
  group('executeVariablesAction - set scoped variable', () {
    test(
      'setScopedVariable falls back to merged variables/results for placeholders',
      () async {
        final store = MemoryBotDataStore();
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
          resolveValue:
              (input) => input == '((rtJson_0.json_0))' ? '' : input,
          guildId: Snowflake.parse('1'),
          fallbackChannelId: null,
          interaction: null,
        );

        expect(handled, isTrue);
        expect(
          store.scopedVariables['guild']?['guild-1']?['items_db'],
          '{"items":["sword"]}',
        );
        expect(
          variables['guild.bc_items_db'],
          '{"items":["sword"]}',
        );
        expect(
          variables['setItems.persisted'],
          '{"items":["sword"]}',
        );
        expect(results['setItems'], 'OK');
      },
    );

    test(
      'setScopedVariable resolves .dataUrl dynamically from merged context',
      () async {
        final store = MemoryBotDataStore();
        final results = <String, String>{
          'rtImage_0': 'Zm9vYmFy',
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
            'value': '((rtImage_0.dataUrl))',
          },
          resultKey: 'setDataUrl',
          results: results,
          variables: variables,
          resolveValue: (input) =>
              resolveTemplatePlaceholders(input, <String, String>{
                ...variables,
                ...results,
              }),
          guildId: Snowflake.parse('1'),
          fallbackChannelId: null,
          interaction: null,
        );

        expect(handled, isTrue);
        expect(
          store.scopedVariables['guild']?['guild-1']?['items_db'],
          'data:image/png;base64,Zm9vYmFy',
        );
      },
    );

    test(
      'setScopedVariable resolves non-empty unresolved placeholders from merged context',
      () async {
        final store = MemoryBotDataStore();
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
        expect(
          variables['guild.bc_items_db'],
          '{"items":["epee"]}',
        );
        expect(results['setItems2'], 'OK');
      },
    );

    test(
      'setScopedVariable falls back to rtJson root when json index key is missing',
      () async {
        final store = MemoryBotDataStore();
        final results = <String, String>{
          'rtJson_0': '{"items":["axe"]}',
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
            'value': '((rtJson_0.json_9))',
          },
          resultKey: 'setItems3',
          results: results,
          variables: variables,
          // Simulate a resolver that does not know action results.
          resolveValue:
              (input) => input == '((rtJson_0.json_9))' ? '' : input,
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
        final store = MemoryBotDataStore();
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
          resolveValue:
              (input) => input == '((rtJson_0.json_0))' ? '' : input,
          guildId: Snowflake.parse('1'),
          fallbackChannelId: null,
          interaction: null,
        );

        expect(handled, isTrue);
        expect(
          store.scopedVariables['guild']?['guild-1']?['items_db'],
          '{"items":["bow"]}',
        );
        expect(
          variables['setItems4.directFallback'],
          '{"items":["bow"]}',
        );
        expect(variables['setItems4.persisted'], '{"items":["bow"]}');
        expect(results['setItems4'], 'OK');
      },
    );

    test(
      'setScopedVariable rtJson alias prefers JSON action value over status strings',
      () async {
        final store = MemoryBotDataStore();
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
        expect(
          variables['setItems6.persisted'],
          '{"items":["shield"]}',
        );
        expect(results['setItems6'], 'OK');
      },
    );

    test(
      r'setScopedVariable resolves literal $jsonStringify from runtime json results',
      () async {
        final store = MemoryBotDataStore();
        final results = <String, String>{
          'rtJson_0': '{"items":["hammer"]}',
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
            'value': r'$jsonStringify',
          },
          resultKey: 'setItems5',
          results: results,
          variables: variables,
          resolveValue: (input) =>
              input == r'$jsonStringify' ? '' : input,
          guildId: Snowflake.parse('1'),
          fallbackChannelId: null,
          interaction: null,
        );

        expect(handled, isTrue);
        expect(
          store.scopedVariables['guild']?['guild-1']?['items_db'],
          '{"items":["hammer"]}',
        );
        expect(
          variables['setItems5.persisted'],
          '{"items":["hammer"]}',
        );
        expect(results['setItems5'], 'OK');
      },
    );
  });
}
