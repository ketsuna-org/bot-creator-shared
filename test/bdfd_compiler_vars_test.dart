import 'package:bot_creator_shared/types/action.dart';
import 'package:bot_creator_shared/utils/bdfd_compiler.dart';
import 'package:bot_creator_shared/utils/template_resolver.dart';
import 'package:test/test.dart';

void main() {
  group('temporary variables via \$var', () {
    test('set and retrieve a temporary variable', () {
      final result = BdfdCompiler().compile(
        r'$var[name;World]Hello $var[name]!',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(2));
      expect(result.actions[0].type, BotCreatorActionType.setTemporaryVariable);
      expect(result.actions[0].payload['key'], 'name');
      expect(result.actions[0].payload['value'], 'World');
      expect(result.actions[1].type, BotCreatorActionType.respondWithMessage);
      expect(result.actions[1].payload['content'], 'Hello ((temp.name))!');
    });

    test('overwrite a temporary variable', () {
      final result = BdfdCompiler().compile(
        r'$var[x;first]$var[x;second]Value: $var[x]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(3));
      expect(result.actions[0].type, BotCreatorActionType.setTemporaryVariable);
      expect(result.actions[0].payload['value'], 'first');
      expect(result.actions[1].type, BotCreatorActionType.setTemporaryVariable);
      expect(result.actions[1].payload['value'], 'second');
      expect(result.actions[2].payload['content'], 'Value: ((temp.x))');
    });

    test('multiple independent temporary variables', () {
      final result = BdfdCompiler().compile(
        r'$var[a;1]$var[b;2]$var[a]+$var[b]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(3));
      expect(result.actions[0].type, BotCreatorActionType.setTemporaryVariable);
      expect(result.actions[1].type, BotCreatorActionType.setTemporaryVariable);
      expect(result.actions[2].payload['content'], '((temp.a))+((temp.b))');

      final runtimeVariables = <String, String>{'temp.a': '1', 'temp.b': '2'};
      expect(
        resolveTemplatePlaceholders(
          result.actions[2].payload['content'] as String,
          runtimeVariables,
        ),
        '1+2',
      );
    });

    test('unknown temp var falls back to runtime placeholder', () {
      final result = BdfdCompiler().compile(r'Value: $var[unknown]');

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(
        result.actions.single.payload['content'],
        'Value: ((temp.unknown))',
      );
    });

    test('temp var set produces no visible output', () {
      final result = BdfdCompiler().compile(r'$var[x;hello]$var[x]');

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(2));
      expect(result.actions[0].type, BotCreatorActionType.setTemporaryVariable);
      expect(result.actions[1].payload['content'], '((temp.x))');
      expect(
        resolveTemplatePlaceholders(
          result.actions[1].payload['content'] as String,
          <String, String>{'temp.x': 'hello'},
        ),
        'hello',
      );
    });

    test('temp var with computed value from inline function', () {
      final result = BdfdCompiler().compile(
        r'$var[upper;$toUpperCase[hello]]Result: $var[upper]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(2));
      expect(result.actions[0].type, BotCreatorActionType.setTemporaryVariable);
      expect(result.actions[0].payload['value'], 'HELLO');
      expect(result.actions[1].payload['content'], 'Result: ((temp.upper))');
    });

    test(
      'runtime inline math stays dynamic and temp vars persist through branches',
      () {
        final result = BdfdCompiler().compile(
          r'$if[$isbot[$authorID]==false]'
          '\n'
          r' $enabledecimals[yes]'
          '\n'
          r' $var[toadd;$multi[$charcount[$message];0.5]]'
          '\n'
          r' $channelSendMessage[$channelID;$message, charcount $charcount[$message], after mult $var[toadd]]'
          '\n'
          r' $if[$var[toadd]>15]'
          '\n'
          r'  $channelSendMessage[$channelID;over 15, clmaped]'
          '\n'
          r'  $var[toadd;15]'
          '\n'
          r' $endif'
          '\n'
          r' $channelSendMessage[$channelID;you have been given $var[toadd] xp]'
          '\n'
          r' $setUserVar[xp;$calculate[$getUserVar[xp]+$var[toadd]]]'
          '\n'
          r' $channelSendMessage[$channelID;new xp $getUserVar[xp]]'
          '\n'
          r'$endif',
        );

        expect(result.hasErrors, isFalse);
        expect(result.actions, hasLength(1));
        expect(result.actions.single.type, BotCreatorActionType.ifBlock);

        final thenActions = List<Map<String, dynamic>>.from(
              result.actions.single.payload['thenActions'] as List,
            )
            .map((json) => Action.fromJson(Map<String, dynamic>.from(json)))
            .toList(growable: false);
        expect(thenActions.map((action) => action.type), <BotCreatorActionType>[
          BotCreatorActionType.setTemporaryVariable,
          BotCreatorActionType.setTemporaryVariable,
          BotCreatorActionType.sendMessage,
          BotCreatorActionType.ifBlock,
          BotCreatorActionType.sendMessage,
          BotCreatorActionType.setScopedVariable,
          BotCreatorActionType.sendMessage,
        ]);

        final tempSetValue = thenActions[1].payload['value'] as String;
        expect(tempSetValue, contains('((multi['));

        final runtimeVariables = <String, String>{
          'message.content': 'bzbd',
          'author.isBot': 'false',
        };
        final resolvedTemp = resolveTemplatePlaceholders(
          tempSetValue,
          runtimeVariables,
        );
        expect(resolvedTemp, '2');
        runtimeVariables['temp.toadd'] = resolvedTemp;

        final previewContent = thenActions[2].payload['content'] as String;
        expect(
          resolveTemplatePlaceholders(previewContent, runtimeVariables),
          'bzbd, charcount 4, after mult 2',
        );

        final clampCondition =
            thenActions[3].payload['condition.variable'] as String;
        expect(
          resolveTemplatePlaceholders(clampCondition, runtimeVariables),
          '2',
        );

        final awardContent = thenActions[4].payload['content'] as String;
        expect(
          resolveTemplatePlaceholders(awardContent, runtimeVariables),
          'you have been given 2 xp',
        );

        final setXpValue = thenActions[5].payload['value'] as String;
        final resolvedXp = resolveTemplatePlaceholders(
          setXpValue,
          runtimeVariables,
        );
        expect(resolvedXp, '2');

        runtimeVariables['user.bc_xp'] = resolvedXp;
        final newXpContent = thenActions[6].payload['content'] as String;
        expect(
          resolveTemplatePlaceholders(newXpContent, runtimeVariables),
          'new xp 2',
        );
      },
    );

    test(
      'runtime uppercase keeps placeholder keys intact until resolution',
      () {
        final result = BdfdCompiler().compile(
          r'$reply$toUpperCase[$username]',
        );

        expect(result.hasErrors, isFalse);
        expect(result.actions, hasLength(1));

        final content = result.actions.single.payload['content'] as String;
        expect(content, '((touppercase[((user.username))]))');
        expect(
          resolveTemplatePlaceholders(content, <String, String>{
            'user.username': 'niek dev',
          }),
          'NIEK DEV',
        );
      },
    );
  });
}
