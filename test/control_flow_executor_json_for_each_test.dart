import 'package:bot_creator_shared/actions/executors/control_flow_executor.dart';
import 'package:bot_creator_shared/types/action.dart';
import 'package:bot_creator_shared/utils/template_resolver.dart';
import 'package:test/test.dart';

void main() {
  group('executeControlFlowAction jsonForEachLoop', () {
    test(
      'iterates over compile-time JSON source embedded in payload',
      () async {
        final results = <String, String>{};
        final variables = <String, String>{};
        final collectedKeys = <String>[];
        final collectedValues = <String>[];

        final handled = await executeControlFlowAction(
          type: BotCreatorActionType.jsonForEachLoop,
          payload: <String, dynamic>{
            'source': '{"data":{"x":1,"y":2,"z":3}}',
            'path': ['data'],
            'bodyActions': <Map<String, dynamic>>[
              <String, dynamic>{
                'type': 'setTemporaryVariable',
                'payload': <String, dynamic>{
                  'key': 'test',
                  'valueType': 'string',
                  'value': '((_loop.var.jsonkey)): ((_loop.var.jsonvalue))',
                },
              },
            ],
            'maxIterations': 100,
          },
          resultKey: 'fe',
          results: results,
          variables: variables,
          resolveValue: (input) => input,
          onLog: null,
          activeWorkflowStack: <String>{},
          getWorkflowByName: (_) async => null,
          executeActions: (actions) async {
            for (final a in actions) {
              if (a.type == BotCreatorActionType.setTemporaryVariable) {
                final key = a.payload['key'] as String;
                final value = resolveTemplatePlaceholders(
                  a.payload['value'] as String,
                  variables,
                );
                variables[key] = value;
                // Collect for assertions
                final parts = value.split(': ');
                collectedKeys.add(parts[0]);
                collectedValues.add(parts[1]);
              }
            }
            return <String, String>{};
          },
          botId: 'test-bot',
        );

        expect(handled, isTrue);
        expect(results['fe'], 'JSONFE_3');
        expect(collectedKeys, ['x', 'y', 'z']);
        expect(collectedValues, ['1', '2', '3']);
        // After the last iteration, $var[test] should be "z: 3"
        expect(variables['test'], 'z: 3');
      },
    );

    test('uses runtime context when no compile-time source', () async {
      final results = <String, String>{};
      final variables = <String, String>{
        'rtjson_0': '{"a":"hello","b":"world"}',
      };
      final collectedKeys = <String>[];

      final handled = await executeControlFlowAction(
        type: BotCreatorActionType.jsonForEachLoop,
        payload: <String, dynamic>{
          'path': <String>[],
          'bodyActions': <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'setTemporaryVariable',
              'payload': <String, dynamic>{
                'key': 'k',
                'valueType': 'string',
                'value': '((_loop.var.jsonkey))',
              },
            },
          ],
          'maxIterations': 100,
        },
        resultKey: 'fe',
        results: results,
        variables: variables,
        resolveValue: (input) => input,
        onLog: null,
        activeWorkflowStack: <String>{},
        getWorkflowByName: (_) async => null,
        executeActions: (actions) async {
          for (final a in actions) {
            if (a.type == BotCreatorActionType.setTemporaryVariable) {
              final value = resolveTemplatePlaceholders(
                a.payload['value'] as String,
                variables,
              );
              collectedKeys.add(value);
            }
          }
          return <String, String>{};
        },
        botId: 'test-bot',
      );

      expect(handled, isTrue);
      expect(results['fe'], 'JSONFE_2');
      expect(collectedKeys, ['a', 'b']);
    });
  });
}
