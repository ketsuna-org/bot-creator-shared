import 'package:bot_creator_shared/actions/executors/control_flow_executor.dart';
import 'package:bot_creator_shared/types/action.dart';
import 'package:bot_creator_shared/utils/template_resolver.dart';
import 'package:test/test.dart';

void main() {
  group('executeControlFlowAction forLoop', () {
    Future<bool> runForLoop({
      required Map<String, dynamic> payload,
      required Map<String, String> results,
      required List<List<Action>> executedBatches,
      required Map<String, String> variables,
      String Function(String input)? resolveValue,
    }) {
      return executeControlFlowAction(
        type: BotCreatorActionType.forLoop,
        payload: payload,
        resultKey: 'loop',
        results: results,
        variables: variables,
        botId: 'test_bot',
        resolveValue: resolveValue ?? (input) => input,
        onLog: null,
        activeWorkflowStack: <String>{},
        getWorkflowByName: (_) async => null,
        executeActions: (actions) async {
          final resolvedActions =
              actions.map((a) {
                final resolvedPayload = a.payload.map((key, value) {
                  if (value is String) {
                    return MapEntry(
                      key,
                      resolveTemplatePlaceholders(value, variables),
                    );
                  }
                  return MapEntry(key, value);
                });
                return Action(
                  type: a.type,
                  payload: resolvedPayload,
                  key: a.key,
                  enabled: a.enabled,
                );
              }).toList();
          executedBatches.add(resolvedActions);
          return <String, String>{'nested': 'ok'};
        },
      );
    }

    test('simple runtime loop executes N iterations', () async {
      final results = <String, String>{};
      final batches = <List<Action>>[];

      await runForLoop(
        variables: <String, String>{},
        payload: <String, dynamic>{
          'mode': 'simple',
          'iterations': '3',
          'bodyActions': <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'sendMessage',
              'payload': <String, dynamic>{'content': 'iter ((_loop.index))'},
            },
          ],
        },
        results: results,
        executedBatches: batches,
      );

      expect(batches, hasLength(3));
      expect(results['loop'], 'LOOP_3');
      // Verify loop placeholder was substituted.
      expect(batches[0][0].payload['content'], 'iter 0');
      expect(batches[1][0].payload['content'], 'iter 1');
      expect(batches[2][0].payload['content'], 'iter 2');
    });

    test(
      'simple runtime loop resolves iteration count via resolveValue',
      () async {
        final results = <String, String>{};
        final batches = <List<Action>>[];

        await runForLoop(
          variables: <String, String>{},
          payload: <String, dynamic>{
            'mode': 'simple',
            'iterations': '((message[2]))',
            'bodyActions': <Map<String, dynamic>>[
              <String, dynamic>{
                'type': 'sendMessage',
                'payload': <String, dynamic>{'content': 'hello'},
              },
            ],
          },
          results: results,
          executedBatches: batches,
          resolveValue: (input) => input.replaceAll('((message[2]))', '2'),
        );

        expect(batches, hasLength(2));
        expect(results['loop'], 'LOOP_2');
      },
    );

    test(
      'simple runtime loop resolves iteration count from temp variables',
      () async {
        final results = <String, String>{};
        final batches = <List<Action>>[];

        await runForLoop(
          variables: <String, String>{},
          payload: <String, dynamic>{
            'mode': 'simple',
            'iterations': '((temp.looping))',
            'bodyActions': <Map<String, dynamic>>[
              <String, dynamic>{
                'type': 'sendMessage',
                'payload': <String, dynamic>{'content': 'hello'},
              },
            ],
          },
          results: results,
          executedBatches: batches,
          resolveValue: (input) => input.replaceAll('((temp.looping))', '2'),
        );

        expect(batches, hasLength(2));
        expect(results['loop'], 'LOOP_2');
      },
    );

    test('simple runtime loop caps at maxIterations', () async {
      final results = <String, String>{};
      final batches = <List<Action>>[];

      await runForLoop(
        variables: <String, String>{},
        payload: <String, dynamic>{
          'mode': 'simple',
          'iterations': '500',
          'maxIterations': 5,
          'bodyActions': <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'sendMessage',
              'payload': <String, dynamic>{'content': 'x'},
            },
          ],
        },
        results: results,
        executedBatches: batches,
      );

      expect(batches, hasLength(5));
      expect(results['loop'], 'LOOP_5');
    });

    test('simple runtime loop with 0 iterations produces LOOP_0', () async {
      final results = <String, String>{};
      final batches = <List<Action>>[];

      await runForLoop(
        variables: <String, String>{},
        payload: <String, dynamic>{
          'mode': 'simple',
          'iterations': '0',
          'bodyActions': <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'sendMessage',
              'payload': <String, dynamic>{'content': 'x'},
            },
          ],
        },
        results: results,
        executedBatches: batches,
      );

      expect(batches, isEmpty);
      expect(results['loop'], 'LOOP_0');
    });

    test('C-style runtime loop executes correctly', () async {
      final results = <String, String>{};
      final batches = <List<Action>>[];

      await runForLoop(
        variables: <String, String>{},
        payload: <String, dynamic>{
          'mode': 'cstyle',
          'init': 'i=0',
          'condition': '((_loop.var.i)) < 3',
          'update': 'i++',
          'varNames': <String>['i'],
          'bodyActions': <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'sendMessage',
              'payload': <String, dynamic>{'content': 'val=((_loop.var.i))'},
            },
          ],
        },
        results: results,
        executedBatches: batches,
      );

      expect(batches, hasLength(3));
      expect(results['loop'], 'LOOP_3');
      expect(batches[0][0].payload['content'], 'val=0');
      expect(batches[1][0].payload['content'], 'val=1');
      expect(batches[2][0].payload['content'], 'val=2');
    });

    test('C-style runtime loop resolves runtime bound', () async {
      final results = <String, String>{};
      final batches = <List<Action>>[];

      await runForLoop(
        variables: <String, String>{},
        payload: <String, dynamic>{
          'mode': 'cstyle',
          'init': 'i=0',
          'condition': '((_loop.var.i)) < ((message[2]))',
          'update': 'i++',
          'varNames': <String>['i'],
          'bodyActions': <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'sendMessage',
              'payload': <String, dynamic>{'content': '((_loop.var.i))'},
            },
          ],
        },
        results: results,
        executedBatches: batches,
        resolveValue: (input) => input.replaceAll('((message[2]))', '4'),
      );

      expect(batches, hasLength(4));
      expect(results['loop'], 'LOOP_4');
    });

    test('forLoop propagates __stopped__', () async {
      final results = <String, String>{};

      await executeControlFlowAction(
        type: BotCreatorActionType.forLoop,
        payload: <String, dynamic>{
          'mode': 'simple',
          'iterations': '5',
          'bodyActions': <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'sendMessage',
              'payload': <String, dynamic>{'content': 'x'},
            },
          ],
        },
        resultKey: 'loop',
        results: results,
        variables: <String, String>{},
        botId: 'test_bot',
        resolveValue: (input) => input,
        onLog: null,
        activeWorkflowStack: <String>{},
        getWorkflowByName: (_) async => null,
        executeActions: (actions) async {
          return <String, String>{'__stopped__': 'true'};
        },
      );

      expect(results['__stopped__'], 'true');
    });
  });
}
