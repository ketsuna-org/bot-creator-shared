import 'package:bot_creator_shared/actions/executors/control_flow_executor.dart';
import 'package:bot_creator_shared/types/action.dart';
import 'package:bot_creator_shared/utils/template_resolver.dart';
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

  group('executeControlFlowAction runBdfdScript', () {
    Future<bool> runBdfdScript({
      required Map<String, dynamic> payload,
      required Map<String, String> results,
      required List<String> executed,
      Map<String, String> variables = const <String, String>{},
    }) {
      return executeControlFlowAction(
        type: BotCreatorActionType.runBdfdScript,
        payload: payload,
        resultKey: 'bdfd',
        results: results,
        variables: Map<String, String>.of(variables),
        botId: 'test_bot',
        resolveValue: (input) => input,
        onLog: null,
        activeWorkflowStack: <String>{},
        getWorkflowByName: (_) async => null,
        executeActions: (actions) async {
          executed.addAll(actions.map((action) => action.type.name));
          return <String, String>{'nested': 'ok'};
        },
      );
    }

    test('compiles and executes a simple BDFD script', () async {
      final results = <String, String>{};
      final executed = <String>[];

      final handled = await runBdfdScript(
        payload: <String, dynamic>{'scriptContent': r'Hello $username!'},
        results: results,
        executed: executed,
      );

      expect(handled, isTrue);
      expect(results['bdfd'], 'BDFD_OK');
      expect(executed, contains('respondWithMessage'));
    });

    test(
      'runBdfdScript supports loot flow with enabled gate fallback and first-win stop',
      () async {
        final results = <String, String>{};
        List<Action> capturedActions = const <Action>[];

        final handled = await executeControlFlowAction(
          type: BotCreatorActionType.runBdfdScript,
          payload: <String, dynamic>{
            'scriptContent':
                r'$jsonParse[$getServerVar[items_db]]'
                r'$var[in;items]'
                r'$var[looping;$jsonArrayCount[$var[in]]]'
                r'$var[roll;$random[1;10]]'
                r'$var[currentWeight;0]'
                r'$var[winner;]'
                r'$for[$var[looping]]'
                r'$if[$json[$var[in];$i;enabled]==true]'
                r'$if[$json[$var[in];$i;rarity]==legendary]'
                r'$var[bonus;2]'
                r'$else'
                r'$var[bonus;0]'
                r'$endif'
                r'$var[itemWeight;$json[$var[in];$i;weight]]'
                r'$var[currentWeight;$calculate[$var[currentWeight]+$var[itemWeight]+$var[bonus]]]'
                r'$if[$var[winner]==]'
                r'$if[$var[roll]<=$var[currentWeight]]'
                r'$var[winner;$json[$var[in];$i;name]]'
                r'$reply$var[winner]'
                r'$stop'
                r'$endif'
                r'$endif'
                r'$endif'
                r'$endfor'
                r'$if[$var[winner]==]'
                r'$reply$c[]fallback_common'
                r'$endif',
          },
          resultKey: 'bdfd',
          results: results,
          variables: <String, String>{},
          resolveValue: (input) => input,
          onLog: null,
          activeWorkflowStack: <String>{},
          getWorkflowByName: (_) async => null,
          executeActions: (actions) async {
            capturedActions = List<Action>.from(actions);
            return <String, String>{};
          },
          botId: 'test-bot',
        );

        expect(handled, isTrue);
        expect(results['bdfd'], 'BDFD_OK');

        final topLevelLoops = capturedActions
            .where((action) => action.type == BotCreatorActionType.forLoop)
            .toList(growable: false);
        expect(topLevelLoops, hasLength(1));

        final fallbackIf = capturedActions.lastWhere(
          (action) => action.type == BotCreatorActionType.ifBlock,
        );
        expect(fallbackIf.payload['condition.variable'], '((temp.winner))');
        expect(fallbackIf.payload['condition.value'], '');

        final loopBody = List<Map<String, dynamic>>.from(
          topLevelLoops.single.payload['bodyActions'] as List? ?? const [],
        );
        expect(
          loopBody.any((action) => action['type'] == 'runtimeJsonBlock'),
          isTrue,
        );

        final enabledIf = Map<String, dynamic>.from(
          loopBody.firstWhere(
                    (action) => action['type'] == 'ifBlock',
                  )['payload']
                  as Map? ??
              const <String, dynamic>{},
        );
        expect(
          (enabledIf['condition.variable'] ?? '').toString(),
          contains('rtJson_'),
        );
        expect(enabledIf['condition.value'], 'true');

        final enabledThen = List<Map<String, dynamic>>.from(
          enabledIf['thenActions'] as List? ?? const [],
        );
        final winnerGate = Map<String, dynamic>.from(
          enabledThen
              .where((action) => action['type'] == 'ifBlock')
              .map(
                (action) => Map<String, dynamic>.from(
                  action['payload'] as Map? ?? const <String, dynamic>{},
                ),
              )
              .firstWhere(
                (payload) => payload['condition.variable'] == '((temp.winner))',
              ),
        );
        final rollGate = Map<String, dynamic>.from(
          List<Map<String, dynamic>>.from(
                    winnerGate['thenActions'] as List? ?? const [],
                  ).firstWhere(
                    (action) => action['type'] == 'ifBlock',
                  )['payload']
                  as Map? ??
              const <String, dynamic>{},
        );

        final winnerThen = List<Map<String, dynamic>>.from(
          rollGate['thenActions'] as List? ?? const [],
        );
        expect(winnerThen.any((action) => action['type'] == 'stop'), isTrue);
      },
    );

    test('returns BDFD_EMPTY for blank script', () async {
      final results = <String, String>{};
      final executed = <String>[];

      final handled = await runBdfdScript(
        payload: <String, dynamic>{'scriptContent': '   '},
        results: results,
        executed: executed,
      );

      expect(handled, isTrue);
      expect(results['bdfd'], 'BDFD_EMPTY');
      expect(executed, isEmpty);
    });

    test('returns BDFD_EMPTY when scriptContent is missing', () async {
      final results = <String, String>{};
      final executed = <String>[];

      final handled = await runBdfdScript(
        payload: <String, dynamic>{},
        results: results,
        executed: executed,
      );

      expect(handled, isTrue);
      expect(results['bdfd'], 'BDFD_EMPTY');
    });

    test('throws on compile error', () async {
      final results = <String, String>{};
      final executed = <String>[];

      expect(
        () => runBdfdScript(
          payload: <String, dynamic>{'scriptContent': r'$if['},
          results: results,
          executed: executed,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('BDFD compile error'),
          ),
        ),
      );
    });

    test('propagates nested results', () async {
      final results = <String, String>{};
      final executed = <String>[];

      await runBdfdScript(
        payload: <String, dynamic>{'scriptContent': 'Hello world!'},
        results: results,
        executed: executed,
      );

      expect(results['bdfd.nested'], 'ok');
    });

    test(
      'forwards compiled runtime loop temp var actions to executeActions',
      () async {
        final results = <String, String>{};
        List<Action> capturedActions = const <Action>[];

        final handled = await executeControlFlowAction(
          type: BotCreatorActionType.runBdfdScript,
          payload: <String, dynamic>{
            'scriptContent':
                r'$for[$message[1]]$var[current;$i]$reply$var[current]$endfor',
          },
          resultKey: 'bdfd',
          results: results,
          variables: <String, String>{},
          resolveValue: (input) => input,
          onLog: null,
          activeWorkflowStack: <String>{},
          getWorkflowByName: (_) async => null,
          executeActions: (actions) async {
            capturedActions = List<Action>.from(actions);
            return <String, String>{};
          },
          botId: 'test-bot',
        );

        expect(handled, isTrue);
        expect(results['bdfd'], 'BDFD_OK');
        expect(capturedActions, hasLength(1));
        expect(capturedActions.single.type, BotCreatorActionType.forLoop);

        final bodyActions = List<Map<String, dynamic>>.from(
          capturedActions.single.payload['bodyActions'] as List? ?? const [],
        );
        expect(bodyActions, hasLength(2));
        expect(bodyActions[0]['type'], 'setTemporaryVariable');
        expect(bodyActions[1]['type'], 'sendMessage');
      },
    );

    test(
      'forwards weighted roll style runtime loop with nested if blocks',
      () async {
        final results = <String, String>{};
        List<Action> capturedActions = const <Action>[];

        final handled = await executeControlFlowAction(
          type: BotCreatorActionType.runBdfdScript,
          payload: <String, dynamic>{
            'scriptContent':
                r'$jsonParse[$getServerVar[items_db]]'
                r'$var[in;items]'
                r'$var[target;sword]'
                r'$var[looping;$jsonArrayCount[$var[in]]]'
                r'$for[$var[looping]]'
                r'$if[$json[$var[in];$i;name]==$var[target]]'
                r'$reply$json[$var[in];$i;weight]'
                r'$endif'
                r'$endfor',
          },
          resultKey: 'bdfd',
          results: results,
          variables: <String, String>{},
          resolveValue: (input) => input,
          onLog: null,
          activeWorkflowStack: <String>{},
          getWorkflowByName: (_) async => null,
          executeActions: (actions) async {
            capturedActions = List<Action>.from(actions);
            return <String, String>{};
          },
          botId: 'test-bot',
        );

        expect(handled, isTrue);
        expect(results['bdfd'], 'BDFD_OK');
        expect(capturedActions, hasLength(6));
        expect(capturedActions.last.type, BotCreatorActionType.forLoop);

        final bodyActions = List<Map<String, dynamic>>.from(
          capturedActions.last.payload['bodyActions'] as List? ?? const [],
        );
        expect(bodyActions, hasLength(2));
        expect(bodyActions[0]['type'], 'runtimeJsonBlock');
        expect(bodyActions[1]['type'], 'ifBlock');
      },
    );

    test(
      'forwards full weighted roll script with accumulation and winner selection',
      () async {
        final results = <String, String>{};
        List<Action> capturedActions = const <Action>[];

        final handled = await executeControlFlowAction(
          type: BotCreatorActionType.runBdfdScript,
          payload: <String, dynamic>{
            'scriptContent':
                r'$jsonParse[$getServerVar[items_db]]'
                r'$var[in;items]'
                r'$var[looping;$jsonArrayCount[$var[in]]]'
                r'$var[totalWeight;0]'
                r'$for[$var[looping]]'
                r'$var[itemWeight;$json[$var[in];$i;weight]]'
                r'$var[totalWeight;$calculate[$var[totalWeight]+$var[itemWeight]]]'
                r'$endfor'
                r'$var[roll;$random[1;10]]'
                r'$var[currentWeight;0]'
                r'$for[$var[looping]]'
                r'$var[itemName;$json[$var[in];$i;name]]'
                r'$var[itemWeight;$json[$var[in];$i;weight]]'
                r'$var[currentWeight;$calculate[$var[currentWeight]+$var[itemWeight]]]'
                r'$if[$var[roll]<=$var[currentWeight]]'
                r'$var[winner;$var[itemName]]'
                r'$reply$var[winner]'
                r'$endif'
                r'$endfor',
          },
          resultKey: 'bdfd',
          results: results,
          variables: <String, String>{},
          resolveValue: (input) => input,
          onLog: null,
          activeWorkflowStack: <String>{},
          getWorkflowByName: (_) async => null,
          executeActions: (actions) async {
            capturedActions = List<Action>.from(actions);
            return <String, String>{};
          },
          botId: 'test-bot',
        );

        expect(handled, isTrue);
        expect(results['bdfd'], 'BDFD_OK');

        final topLevelLoops = capturedActions
            .where((action) => action.type == BotCreatorActionType.forLoop)
            .toList(growable: false);
        expect(topLevelLoops, hasLength(2));

        final selectionBody = List<Map<String, dynamic>>.from(
          topLevelLoops[1].payload['bodyActions'] as List? ?? const [],
        );
        expect(
          selectionBody.any((action) => action['type'] == 'runtimeJsonBlock'),
          isTrue,
        );
        expect(
          selectionBody.any((action) => action['type'] == 'ifBlock'),
          isTrue,
        );
      },
    );

    test('propagates __stopped__ from nested execution', () async {
      final results = <String, String>{};

      await executeControlFlowAction(
        type: BotCreatorActionType.runBdfdScript,
        payload: <String, dynamic>{'scriptContent': 'Hello!'},
        resultKey: 'bdfd',
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
      expect(results['bdfd'], 'BDFD_OK');
    });
  });

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

  group('executeControlFlowAction runBdfdScript nestedActionsPreprocessor', () {
    test(
      'preprocessor is applied to compiled sub-actions before executeActions',
      () async {
        final results = <String, String>{};
        final executedTypes = <String>[];

        // The BDFD script compiles to a respondWithMessage action.
        // The preprocessor replaces it with sendMessage, simulating Legacy
        // messageCreate adaptation.
        final handled = await executeControlFlowAction(
          type: BotCreatorActionType.runBdfdScript,
          payload: <String, dynamic>{'scriptContent': r'Hello $username!'},
          resultKey: 'bdfd',
          results: results,
          variables: <String, String>{},
          resolveValue: (input) => input,
          onLog: null,
          activeWorkflowStack: <String>{},
          getWorkflowByName: (_) async => null,
          executeActions: (actions) async {
            executedTypes.addAll(actions.map((a) => a.type.name));
            return <String, String>{};
          },
          nestedActionsPreprocessor:
              (actions) =>
                  actions
                      .map(
                        (a) =>
                            a.type == BotCreatorActionType.respondWithMessage
                                ? Action(
                                  type: BotCreatorActionType.sendMessage,
                                  payload: Map<String, dynamic>.from(a.payload),
                                )
                                : a,
                      )
                      .toList(),
          botId: 'test-bot',
        );

        expect(handled, isTrue);
        expect(results['bdfd'], 'BDFD_OK');
        // respondWithMessage must have been replaced by sendMessage
        expect(executedTypes, isNot(contains('respondWithMessage')));
        expect(executedTypes, contains('sendMessage'));
      },
    );
  });

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
