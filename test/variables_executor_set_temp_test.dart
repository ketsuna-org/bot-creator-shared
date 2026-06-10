import 'package:bot_creator_shared/actions/executors/variables_executor.dart';
import 'package:bot_creator_shared/types/action.dart';
import 'package:bot_creator_shared/utils/template_resolver.dart';
import 'package:test/test.dart';

import 'helpers/variables_test_helpers.dart';

void main() {
  group('executeVariablesAction - set temporary variable', () {
    test(
      'setTemporaryVariable stores a resolved runtime value in the temp namespace',
      () async {
        final store = MemoryBotDataStore();
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
          resolveValue:
              (input) => input == '((rtJson_0.json_0))' ? '' : input,
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
        final store = MemoryBotDataStore();
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
  });
}
