import 'package:bot_creator_shared/actions/executors/control_flow_executor.dart';
import 'package:bot_creator_shared/types/action.dart';
import 'package:test/test.dart';

void main() {
  group('executeControlFlowAction ifBlock', () {
    test(
      'keeps legacy IF/ELSE behavior when no else-if branches exist',
      () async {
        final results = <String, String>{};
        final executed = <String>[];

        final handled = await executeControlFlowAction(
          type: BotCreatorActionType.ifBlock,
          payload: <String, dynamic>{
            'condition.variable': 'score',
            'condition.operator': 'greaterThan',
            'condition.value': '90',
            'thenActions': <Map<String, dynamic>>[],
            'elseActions': <Map<String, dynamic>>[
              <String, dynamic>{
                'type': 'sendMessage',
                'payload': <String, dynamic>{'content': 'fallback'},
              },
            ],
          },
          resultKey: 'branch',
          results: results,
          variables: <String, String>{'score': '60'},
          resolveValue: (input) => input,
          onLog: null,
          activeWorkflowStack: <String>{},
          getWorkflowByName: (_) async => null,
          executeActions: (actions) async {
            executed.addAll(actions.map((action) => action.type.name));
            return <String, String>{'nested': 'ok'};
          },
          botId: 'test-bot',
        );

        expect(handled, isTrue);
        expect(results['branch'], 'IF_FALSE');
        expect(executed, <String>['sendMessage']);
        expect(results['branch.nested'], 'ok');
      },
    );

    test('executes the first matching else-if branch in order', () async {
      final results = <String, String>{};
      final executed = <String>[];

      final handled = await executeControlFlowAction(
        type: BotCreatorActionType.ifBlock,
        payload: <String, dynamic>{
          'condition.variable': 'score',
          'condition.operator': 'greaterThan',
          'condition.value': '90',
          'thenActions': <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'sendMessage',
              'payload': <String, dynamic>{},
            },
          ],
          'elseIfConditions': <Map<String, dynamic>>[
            <String, dynamic>{
              'condition.variable': 'score',
              'condition.operator': 'greaterThan',
              'condition.value': '80',
              'actions': <Map<String, dynamic>>[
                <String, dynamic>{
                  'type': 'editMessage',
                  'payload': <String, dynamic>{},
                },
              ],
            },
            <String, dynamic>{
              'condition.variable': 'score',
              'condition.operator': 'greaterThan',
              'condition.value': '70',
              'actions': <Map<String, dynamic>>[
                <String, dynamic>{
                  'type': 'addReaction',
                  'payload': <String, dynamic>{},
                },
              ],
            },
          ],
          'elseActions': <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'removeReaction',
              'payload': <String, dynamic>{},
            },
          ],
        },
        resultKey: 'branch',
        results: results,
        variables: <String, String>{'score': '82'},
        botId: 'test_bot',
        resolveValue: (input) => input,
        onLog: null,
        activeWorkflowStack: <String>{},
        getWorkflowByName: (_) async => null,
        executeActions: (actions) async {
          executed.addAll(actions.map((action) => action.type.name));
          return <String, String>{};
        },
      );

      expect(handled, isTrue);
      expect(results['branch'], 'ELSE_IF_1');
      expect(executed, <String>['editMessage']);
    });

    test('falls back to ELSE when no ELSE IF branch matches', () async {
      final results = <String, String>{};
      final executed = <String>[];

      final handled = await executeControlFlowAction(
        type: BotCreatorActionType.ifBlock,
        payload: <String, dynamic>{
          'condition.variable': 'score',
          'condition.operator': 'greaterThan',
          'condition.value': '90',
          'thenActions': <Map<String, dynamic>>[],
          'elseIfConditions': <Map<String, dynamic>>[
            <String, dynamic>{
              'condition.variable': 'score',
              'condition.operator': 'greaterThan',
              'condition.value': '80',
              'actions': <Map<String, dynamic>>[
                <String, dynamic>{
                  'type': 'editMessage',
                  'payload': <String, dynamic>{},
                },
              ],
            },
          ],
          'elseActions': <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'removeReaction',
              'payload': <String, dynamic>{},
            },
          ],
        },
        resultKey: 'branch',
        results: results,
        variables: <String, String>{'score': '50'},
        botId: 'test_bot',
        resolveValue: (input) => input,
        onLog: null,
        activeWorkflowStack: <String>{},
        getWorkflowByName: (_) async => null,
        executeActions: (actions) async {
          executed.addAll(actions.map((action) => action.type.name));
          return <String, String>{};
        },
      );

      expect(handled, isTrue);
      expect(results['branch'], 'IF_FALSE');
      expect(executed, <String>['removeReaction']);
    });
  });
}
