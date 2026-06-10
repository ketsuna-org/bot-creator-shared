import 'package:bot_creator_shared/types/action.dart';
import 'package:bot_creator_shared/utils/bdfd_compiler.dart';
import 'package:test/test.dart';

void main() {
  group('BdfdCompiler', () {
    test('simple runtime loop emits forLoop action for dynamic iterations', () {
      final result = BdfdCompiler().compile(
        r'$for[$args[2]]$reply$c[]hello$endfor',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.type, BotCreatorActionType.forLoop);
      expect(result.actions.single.payload['mode'], 'simple');
      expect(result.actions.single.payload['iterations'], contains('(('));
      final bodyActions = result.actions.single.payload['bodyActions'] as List;
      expect(bodyActions, hasLength(1));
    });

    test('runtime loop can consume a temporary runtime variable', () {
      final result = BdfdCompiler().compile(
        r'$jsonParse[$getServerVar[$args[2]]]'
        r'$var[looping;$jsonArrayCount[currencies]]'
        r'$for[$var[looping]]$reply$i$endfor',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(3));
      expect(result.actions[0].type, BotCreatorActionType.runtimeJsonBlock);
      expect(result.actions[1].type, BotCreatorActionType.setTemporaryVariable);
      expect(result.actions[2].type, BotCreatorActionType.forLoop);
      expect(result.actions[2].payload['mode'], 'simple');
      expect(result.actions[2].payload['iterations'], '((temp.looping))');

      final tempPayload = result.actions[1].payload;
      expect(tempPayload['key'], 'looping');
      expect((tempPayload['value'] ?? '').toString(), contains('rtJson_'));
      expect((tempPayload['value'] ?? '').toString(), contains('.json_0'));
    });

    test('simple runtime loop with \$loop alias', () {
      final result = BdfdCompiler().compile(
        r'$loop[$args[1]]$reply$c[]hi$endloop',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.type, BotCreatorActionType.forLoop);
      expect(result.actions.single.payload['mode'], 'simple');
    });

    test(
      'C-style runtime loop emits forLoop action when condition has placeholder',
      () {
        final result = BdfdCompiler().compile(
          r'$for[i=0;i<$args[2];i++]$reply$i$endfor',
        );

        expect(result.hasErrors, isFalse);
        expect(result.actions, hasLength(1));
        final action = result.actions.single;
        expect(action.type, BotCreatorActionType.forLoop);
        expect(action.payload['mode'], 'cstyle');
        expect(action.payload['init'], 'i=0');
        expect(action.payload['condition'], contains('(('));
        expect(action.payload['update'], 'i++');
        expect(action.payload['varNames'], contains('i'));
        final bodyActions = action.payload['bodyActions'] as List;
        expect(bodyActions, hasLength(1));
        // Body should contain loop variable placeholder.
        final bodyPayload = bodyActions[0] as Map;
        final content = (bodyPayload['payload'] as Map)['content'] as String;
        expect(content, contains('((_loop.var.i))'));
      },
    );

    test('C-style runtime loop with runtime init value', () {
      final result = BdfdCompiler().compile(
        r'$for[i=$args[0];i<$args[2];i++]$reply$i$endfor',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      final action = result.actions.single;
      expect(action.type, BotCreatorActionType.forLoop);
      expect(action.payload['mode'], 'cstyle');
      expect(action.payload['init'], contains('(('));
    });

    test('static loops still unrolled at compile-time (backward compat)', () {
      final result = BdfdCompiler().compile(r'$for[3]$reply$c[]x$endfor');

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(3));
      // Should NOT be a forLoop action – should be unrolled.
      for (final action in result.actions) {
        expect(action.type, isNot(BotCreatorActionType.forLoop));
      }
    });

    test(
      'runtime loop body uses ((_loop.index)) and ((_loop.count)) placeholders',
      () {
        final result = BdfdCompiler().compile(
          r'$for[$args[0]]$reply$i is $loopCount$endfor',
        );

        expect(result.hasErrors, isFalse);
        expect(result.actions, hasLength(1));
        final action = result.actions.single;
        expect(action.type, BotCreatorActionType.forLoop);
        final bodyActions = action.payload['bodyActions'] as List;
        final content = (bodyActions[0] as Map)['payload']['content'] as String;
        expect(content, contains('((_loop.index))'));
        expect(content, contains('((_loop.count))'));
      },
    );

    test('runtime loop body preserves temp variable actions', () {
      final result = BdfdCompiler().compile(
        r'$for[$message[1]]$var[current;$i]$reply$var[current]$endfor',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.type, BotCreatorActionType.forLoop);

      final bodyActions = List<Map<String, dynamic>>.from(
        result.actions.single.payload['bodyActions'] as List? ?? const [],
      );
      expect(bodyActions, hasLength(2));
      expect(bodyActions[0]['type'], 'setTemporaryVariable');
      expect(bodyActions[1]['type'], 'sendMessage');
      expect(
        (bodyActions[1]['payload'] as Map<String, dynamic>)['targetType'],
        'reply',
      );

      final tempPayload = Map<String, dynamic>.from(
        bodyActions[0]['payload'] as Map? ?? const <String, dynamic>{},
      );
      expect(tempPayload['key'], 'current');
      expect(tempPayload['value'], '((_loop.index))');
      expect(
        (bodyActions[1]['payload'] as Map<String, dynamic>)['content'],
        '((temp.current))',
      );
    });
  });
}
