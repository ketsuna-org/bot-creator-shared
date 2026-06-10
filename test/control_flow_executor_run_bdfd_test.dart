import 'package:bot_creator_shared/actions/executors/control_flow_executor.dart';
import 'package:bot_creator_shared/types/action.dart';
import 'package:test/test.dart';

void main() {
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
}
