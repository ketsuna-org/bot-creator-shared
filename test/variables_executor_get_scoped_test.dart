import 'package:bot_creator_shared/actions/executors/variables_executor.dart';
import 'package:bot_creator_shared/types/action.dart';
import 'package:test/test.dart';

import 'helpers/variables_test_helpers.dart';

void main() {
  group('executeVariablesAction - get scoped variable', () {
    test(
      'getScopedVariable resolves user scope from fallback runtime identity keys',
      () async {
        final store = MemoryBotDataStore(
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
        final store = MemoryBotDataStore(
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
        expect(
          store.scopedVariables['user']?['user-99']?['profile'],
          'legacy',
        );
        expect(
          store.scopedVariables['user']?['Unknown User']?['profile'],
          'legacy',
        );
      },
    );

    test(
      'getScopedVariable falls back to defaultValue from definitions when missing in database',
      () async {
        final store = MemoryBotDataStore();
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
        expect(
          store.scopedVariables['user']?['user-100']?['streak'],
          '5',
        );
        expect(variables['user.bc_streak'], '5');
        expect(variables['user.streak'], '5');
      },
    );

    test(
      'getScopedVariable resolves defaultValue with case-insensitive and legacy key matching',
      () async {
        final store = MemoryBotDataStore();
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
        final store = MemoryBotDataStore();
        await store.setScopedVariableDefinition(
          'bot-1',
          'bc_points',
          'user',
          '100',
          valueType: 'string',
        );

        // Scenario A: User has empty value in database
        await store.setScopedVariable(
          'bot-1',
          'user',
          'user-1',
          'points',
          '',
        );

        // Scenario B: User has non-empty value in database
        await store.setScopedVariable(
          'bot-1',
          'user',
          'user-2',
          'points',
          '50',
        );

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
        expect(
          store.scopedVariables['user']?['user-1']?['points'],
          '100',
        );

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
        expect(
          store.scopedVariables['user']?['user-2']?['points'],
          '50',
        );
      },
    );
  });
}
