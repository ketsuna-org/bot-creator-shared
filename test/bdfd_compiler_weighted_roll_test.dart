import 'package:bot_creator_shared/types/action.dart';
import 'package:bot_creator_shared/utils/bdfd_compiler.dart';
import 'package:test/test.dart';

void main() {
  group('BdfdCompiler', () {
    test(
      'weighted roll style loop keeps nested json and if blocks runtime',
      () {
        final result = BdfdCompiler().compile(
          r'$jsonParse[$getServerVar[items_db]]'
          r'$var[in;items]'
          r'$var[target;sword]'
          r'$var[looping;$jsonArrayCount[$var[in]]]'
          r'$for[$var[looping]]'
          r'$if[$json[$var[in];$i;name]==$var[target]]'
          r'$reply$json[$var[in];$i;weight]'
          r'$endif'
          r'$endfor',
        );

        expect(result.hasErrors, isFalse);
        expect(result.actions, hasLength(6));
        expect(result.actions[0].type, BotCreatorActionType.runtimeJsonBlock);
        expect(
          result.actions[1].type,
          BotCreatorActionType.setTemporaryVariable,
        );
        expect(result.actions[1].payload['key'], 'in');
        expect(
          result.actions[2].type,
          BotCreatorActionType.setTemporaryVariable,
        );
        expect(result.actions[2].payload['key'], 'target');
        expect(result.actions[3].type, BotCreatorActionType.runtimeJsonBlock);
        expect(
          result.actions[4].type,
          BotCreatorActionType.setTemporaryVariable,
        );
        expect(result.actions[4].payload['key'], 'looping');
        expect(result.actions[5].type, BotCreatorActionType.forLoop);
        expect(result.actions[5].payload['iterations'], '((temp.looping))');

        final loopingValue =
            (result.actions[4].payload['value'] ?? '').toString();
        expect(loopingValue, contains('rtJson_'));
        expect(loopingValue, contains('.json_0'));

        final bodyActions = List<Map<String, dynamic>>.from(
          result.actions[5].payload['bodyActions'] as List? ?? const [],
        );
        expect(bodyActions, hasLength(2));
        expect(bodyActions[0]['type'], 'runtimeJsonBlock');
        expect(bodyActions[1]['type'], 'ifBlock');

        final ifPayload = Map<String, dynamic>.from(
          bodyActions[1]['payload'] as Map? ?? const <String, dynamic>{},
        );
        final conditionVariable =
            (ifPayload['condition.variable'] ?? '').toString();
        expect(conditionVariable, contains('rtJson_'));
        expect(conditionVariable, contains('.json_0'));
        expect(ifPayload['condition.value'], '((temp.target))');

        final thenActions = List<Map<String, dynamic>>.from(
          ifPayload['thenActions'] as List? ?? const [],
        );
        expect(thenActions, hasLength(2));
        expect(thenActions[0]['type'], 'runtimeJsonBlock');
        expect(thenActions[1]['type'], 'sendMessage');
        expect(
          (thenActions[1]['payload'] as Map<String, dynamic>)['targetType'],
          'reply',
        );

        final weightContent =
            (thenActions[1]['payload'] as Map<String, dynamic>)['content']
                .toString();
        expect(weightContent, contains('rtJson_'));
        expect(weightContent, contains('.json_'));
      },
    );

    test(
      'full weighted roll compiles accumulation, random threshold, and winner selection',
      () {
        final result = BdfdCompiler().compile(
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
        );

        expect(result.hasErrors, isFalse);

        final topLevelLoops = result.actions
            .where((action) => action.type == BotCreatorActionType.forLoop)
            .toList(growable: false);
        expect(topLevelLoops, hasLength(2));

        final topLevelTempKeys = result.actions
            .where(
              (action) =>
                  action.type == BotCreatorActionType.setTemporaryVariable,
            )
            .map((action) => (action.payload['key'] ?? '').toString())
            .toList(growable: false);
        expect(
          topLevelTempKeys,
          containsAll(<String>[
            'in',
            'looping',
            'totalWeight',
            'roll',
            'currentWeight',
          ]),
        );

        final rollAction = result.actions.firstWhere(
          (action) =>
              action.type == BotCreatorActionType.setTemporaryVariable &&
              action.payload['key'] == 'roll',
        );
        final rollValue = (rollAction.payload['value'] ?? '').toString();
        expect(rollValue, contains('((random[1;10]))'));

        final accumulationBody = List<Map<String, dynamic>>.from(
          topLevelLoops[0].payload['bodyActions'] as List? ?? const [],
        );
        expect(
          accumulationBody.any(
            (action) => action['type'] == 'runtimeJsonBlock',
          ),
          isTrue,
        );
        final accumulationTempKeys = accumulationBody
            .where((action) => action['type'] == 'setTemporaryVariable')
            .map(
              (action) =>
                  ((action['payload'] as Map?)?['key'] ?? '').toString(),
            )
            .toList(growable: false);
        expect(
          accumulationTempKeys,
          containsAll(<String>['itemWeight', 'totalWeight']),
        );

        final selectionBody = List<Map<String, dynamic>>.from(
          topLevelLoops[1].payload['bodyActions'] as List? ?? const [],
        );
        expect(
          selectionBody.any((action) => action['type'] == 'runtimeJsonBlock'),
          isTrue,
        );
        final selectionTempKeys = selectionBody
            .where((action) => action['type'] == 'setTemporaryVariable')
            .map(
              (action) =>
                  ((action['payload'] as Map?)?['key'] ?? '').toString(),
            )
            .toList(growable: false);
        expect(
          selectionTempKeys,
          containsAll(<String>['itemName', 'itemWeight', 'currentWeight']),
        );

        final winnerIfPayload = Map<String, dynamic>.from(
          selectionBody.firstWhere(
                    (action) => action['type'] == 'ifBlock',
                  )['payload']
                  as Map? ??
              const <String, dynamic>{},
        );
        expect(winnerIfPayload['condition.variable'], '((temp.roll))');
        expect(winnerIfPayload['condition.value'], '((temp.currentWeight))');

        final winnerThenActions = List<Map<String, dynamic>>.from(
          winnerIfPayload['thenActions'] as List? ?? const [],
        );
        final winnerTempKeys = winnerThenActions
            .where((action) => action['type'] == 'setTemporaryVariable')
            .map(
              (action) =>
                  ((action['payload'] as Map?)?['key'] ?? '').toString(),
            )
            .toList(growable: false);
        expect(winnerTempKeys, contains('winner'));

        final winnerReply = Map<String, dynamic>.from(
          winnerThenActions.firstWhere(
                    (action) => action['type'] == 'sendMessage',
                  )['payload']
                  as Map? ??
              const <String, dynamic>{},
        );
        expect(winnerReply['content'], '((temp.winner))');
      },
    );

    test('standalone if hoists runtime json condition before if action', () {
      final result = BdfdCompiler().compile(
        r'$jsonParse[$getServerVar[items_db]]'
        r'$var[in;items]'
        r'$if[$json[$var[in];$message[1];enabled]==true;$reply$c[]enabled;$reply$c[]disabled]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(4));
      expect(result.actions[0].type, BotCreatorActionType.runtimeJsonBlock);
      expect(result.actions[1].type, BotCreatorActionType.setTemporaryVariable);
      expect(result.actions[2].type, BotCreatorActionType.runtimeJsonBlock);
      expect(result.actions[3].type, BotCreatorActionType.ifBlock);

      final ifPayload = result.actions[3].payload;
      expect(
        (ifPayload['condition.variable'] ?? '').toString(),
        contains('rtJson_'),
      );
      expect(
        (ifPayload['condition.variable'] ?? '').toString(),
        contains('.json_0'),
      );
      expect(ifPayload['condition.value'], 'true');

      final thenActions = List<Map<String, dynamic>>.from(
        ifPayload['thenActions'] as List? ?? const [],
      );
      final elseActions = List<Map<String, dynamic>>.from(
        ifPayload['elseActions'] as List? ?? const [],
      );
      expect(
        (thenActions.single['payload'] as Map<String, dynamic>)['content'],
        'enabled',
      );
      expect(
        (elseActions.single['payload'] as Map<String, dynamic>)['content'],
        'disabled',
      );
    });

    test(
      'loot flow compiles tiers, enabled gate, fallback, and first-win stop',
      () {
        final result = BdfdCompiler().compile(
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
        );

        expect(result.hasErrors, isFalse);

        final topLevelLoops = result.actions
            .where((action) => action.type == BotCreatorActionType.forLoop)
            .toList(growable: false);
        expect(topLevelLoops, hasLength(1));

        final fallbackIf = result.actions.lastWhere(
          (action) => action.type == BotCreatorActionType.ifBlock,
        );
        expect(fallbackIf.payload['condition.variable'], '((temp.winner))');
        expect(fallbackIf.payload['condition.value'], '');
        final fallbackThen = List<Map<String, dynamic>>.from(
          fallbackIf.payload['thenActions'] as List? ?? const [],
        );
        expect(
          (fallbackThen.single['payload'] as Map<String, dynamic>)['content'],
          'fallback_common',
        );

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
        expect(
          enabledThen.any((action) => action['type'] == 'ifBlock'),
          isTrue,
        );
        expect(
          enabledThen.any(
            (action) =>
                action['type'] == 'setTemporaryVariable' &&
                ((action['payload'] as Map?)?['key'] ?? '') == 'currentWeight',
          ),
          isTrue,
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
        expect(rollGate['condition.variable'], '((temp.roll))');
        expect(rollGate['condition.value'], '((temp.currentWeight))');

        final winnerThen = List<Map<String, dynamic>>.from(
          rollGate['thenActions'] as List? ?? const [],
        );
        expect(
          winnerThen.any(
            (action) =>
                action['type'] == 'setTemporaryVariable' &&
                ((action['payload'] as Map?)?['key'] ?? '') == 'winner',
          ),
          isTrue,
        );
        expect(
          winnerThen.any((action) => action['type'] == 'stop'),
          isTrue,
        );
      },
    );
  });
}
