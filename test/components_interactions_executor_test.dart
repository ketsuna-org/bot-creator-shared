import 'package:bot_creator_shared/actions/executors/components_interactions_executor.dart';
import 'package:bot_creator_shared/types/action.dart';
import 'package:bot_creator_shared/utils/workflow_call.dart';
import 'package:test/test.dart';

// The listen registration path never calls NyxxGateway.
const _noClient = null;

void main() {
  group('executeComponentsInteractionsAction listen guard', () {
    test(
      'listenForButtonClick in event workflow without messageId registers with null messageId',
      () async {
        final results = <String, String>{};

        final handled = await executeComponentsInteractionsAction(
          type: BotCreatorActionType.listenForButtonClick,
          client: _noClient,
          interaction: null,
          payload: <String, dynamic>{
            'customId': 'btn-ok',
            'workflowName': 'my-workflow',
          },
          resultKey: 'listener',
          results: results,
          variables: <String, String>{'workflow.type': workflowTypeEvent},
          botId: 'bot-1',
          guildId: null,
          fallbackChannelId: null,
          resolveValue: (input) => input,
        );

        expect(handled, isTrue);
        expect(results['listener'], equals('listening:btn-ok'));
      },
    );

    test(
      'listenForSelectMenu in event workflow without messageId registers with null messageId',
      () async {
        final results = <String, String>{};

        final handled = await executeComponentsInteractionsAction(
          type: BotCreatorActionType.listenForSelectMenu,
          client: _noClient,
          interaction: null,
          payload: <String, dynamic>{
            'customId': 'select-ok',
            'workflowName': 'my-workflow',
          },
          resultKey: 'listener',
          results: results,
          variables: <String, String>{'workflow.type': workflowTypeEvent},
          botId: 'bot-1',
          guildId: null,
          fallbackChannelId: null,
          resolveValue: (input) => input,
        );

        expect(handled, isTrue);
        expect(results['listener'], equals('listening:select-ok'));
      },
    );

    test(
      'listenForButtonClick in event workflow with explicit messageId succeeds',
      () async {
        final results = <String, String>{};

        final handled = await executeComponentsInteractionsAction(
          type: BotCreatorActionType.listenForButtonClick,
          client: _noClient,
          interaction: null,
          payload: <String, dynamic>{
            'customId': 'btn-explicit',
            'workflowName': 'my-workflow',
            'messageId': '123456789',
          },
          resultKey: 'listener',
          results: results,
          variables: <String, String>{'workflow.type': workflowTypeEvent},
          botId: 'bot-2',
          guildId: null,
          fallbackChannelId: null,
          resolveValue: (input) => input,
        );

        expect(handled, isTrue);
        expect(results['listener'], equals('listening:btn-explicit'));
      },
    );

    test(
      'listenForButtonClick outside event workflow without messageId succeeds',
      () async {
        final results = <String, String>{};

        final handled = await executeComponentsInteractionsAction(
          type: BotCreatorActionType.listenForButtonClick,
          client: _noClient,
          interaction: null,
          payload: <String, dynamic>{
            'customId': 'btn-command',
            'workflowName': 'my-workflow',
          },
          resultKey: 'listener',
          results: results,
          variables: <String, String>{'workflow.type': 'command'},
          botId: 'bot-3',
          guildId: null,
          fallbackChannelId: null,
          resolveValue: (input) => input,
        );

        expect(handled, isTrue);
        expect(results['listener'], equals('listening:btn-command'));
      },
    );
  });
}
